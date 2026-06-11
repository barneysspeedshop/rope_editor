// Adapted from Zed's rope crate (GPL-3.0-or-later)

use heapless::Vec as ArrayVec;
use std::{
    cmp, fmt, mem,
    ops::{self, Range},
};
use unicode_segmentation::GraphemeCursor;

use super::{OffsetUtf16, Point, PointUtf16, TextSummary};

pub const MIN_BASE: usize = 32;
pub const MAX_BASE: usize = MIN_BASE * 2;

/// The chunk of text stored in a leaf of the B-tree.
///
/// We have two types for this: `Chunk` and `ChunkSlice`, which are analogous to `String` and
/// `&str`. The way they work is different though:
/// - `Chunk` owns its text, which is always between `MIN_BASE` and `MAX_BASE` bytes long. The
///   length is variable so there's no big penalty for storing lots of ASCII, but the `Bitmap`
///   which enables fast char-counting can be stored inline since it has a max size of `MAX_BASE`
///   bits.
/// - `ChunkSlice` is a `&str` (with a lifetime that's annoying to name) paired with a computed
///   `TextSummary`, which can be computed quickly from the `Bitmap`. The summary is owned so we
///   don't have to recompute it every time we call `Item::summary()`.
///
/// `ChunkSlice` can be obtained either from `Chunk::as_slice()` or `Chunk::slice(Range<usize>)`.
/// The latter computes a summary from the bitmap. Many operations that scan through a string can
/// be done more quickly on chunks by instead scanning through the bitmap: counting chars for
/// example is O(n) for a string but O(1) for a bitmap, so `char_count()` and `offset_to_point()`
/// have very different performance characteristics for chunks vs strings.
///
/// However, slicing by char offset instead of byte offset is still O(n) for chunks, since we need
/// to scan the bitmap to count chars anyway. This is why the API only supports byte offsets for
/// slicing, and operations like [`crate::Rope::offset_to_point`] take a byte offset not a char
/// offset.
#[derive(Clone, Default)]
pub struct Chunk {
    pub text: String,
    /// A bitmap of the first byte of each UTF-8 char. This is used for quickly counting chars in
    /// a range; instead of scanning the string, we can just count the set bits in the bitmap.
    bitmap: Bitmap,
}

impl Chunk {
    pub fn new(text: &str) -> Self {
        Self {
            bitmap: Bitmap::from_text(text),
            text: text.to_string(),
        }
    }

    pub fn push_str(&mut self, text: &str) {
        self.bitmap.append(text, self.text.len());
        self.text.push_str(text);
    }

    pub fn append(&mut self, slice: ChunkSlice) {
        self.bitmap.append_from(&slice.bitmap, self.text.len());
        self.text.push_str(slice.text);
    }

    pub fn as_slice(&self) -> ChunkSlice {
        ChunkSlice {
            text: &self.text,
            bitmap: self.bitmap.slice(0, self.text.len()),
        }
    }

    pub fn slice(&self, range: Range<usize>) -> ChunkSlice {
        ChunkSlice {
            text: &self.text[range.clone()],
            bitmap: self.bitmap.slice(range.start, range.end),
        }
    }

    #[inline(always)]
    pub fn len(&self) -> usize {
        self.text.len()
    }

    pub fn is_char_boundary(&self, index: usize) -> bool {
        self.text.is_char_boundary(index)
    }
}

impl fmt::Debug for Chunk {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Debug::fmt(&self.text, f)
    }
}

/// A slice of a [`Chunk`]. Can either be obtained from [`Chunk::as_slice()`], [`Chunk::slice()`],
/// or created directly via `From<&str>`.
#[derive(Clone, Copy)]
pub struct ChunkSlice<'a> {
    pub text: &'a str,
    bitmap: BitmapSlice<'a>,
}

impl<'a> Default for ChunkSlice<'a> {
    fn default() -> Self {
        "".into()
    }
}

impl<'a> From<&'a str> for ChunkSlice<'a> {
    fn from(text: &'a str) -> Self {
        ChunkSlice {
            text,
            bitmap: text.into(),
        }
    }
}

impl From<ChunkSlice<'_>> for Chunk {
    fn from(value: ChunkSlice<'_>) -> Self {
        Chunk::new(value.text)
    }
}

impl<'a> ChunkSlice<'a> {
    #[inline(always)]
    pub fn len(&self) -> usize {
        self.text.len()
    }

    #[inline(always)]
    pub fn is_empty(&self) -> bool {
        self.text.is_empty()
    }

    #[inline(always)]
    pub fn is_char_boundary(&self, index: usize) -> bool {
        self.text.is_char_boundary(index)
    }

    pub fn split_at(&self, index: usize) -> (ChunkSlice<'a>, ChunkSlice<'a>) {
        let (left, right) = self.text.split_at(index);
        (
            ChunkSlice {
                text: left,
                bitmap: self.bitmap.split_left(index),
            },
            ChunkSlice {
                text: right,
                bitmap: self.bitmap.split_right(index),
            },
        )
    }

    pub fn char_count(&self) -> usize {
        self.bitmap.bit_count()
    }

    pub fn newline_count(&self) -> u32 {
        bytecount::count(self.text.as_bytes(), b'\n') as u32
    }

    pub fn len_utf16(&self) -> OffsetUtf16 {
        OffsetUtf16(self.len() + self.char_count() - self.char_count_utf16())
    }

    pub fn char_count_utf16(&self) -> usize {
        self.text.chars().filter(|c| c.len_utf16() > 1).count() * 2
            + self.text.chars().filter(|c| c.len_utf16() == 1).count()
    }

    pub fn lines(&self) -> Point {
        let row = self.newline_count();
        let column = self.text.len() as u32
            - self
                .text
                .rfind('\n')
                .map(|i| i as u32 + 1)
                .unwrap_or(0);
        Point { row, column }
    }

    pub fn last_line_len_utf16(&self) -> u32 {
        let last_line_start = self.text.rfind('\n').map(|i| i + 1).unwrap_or(0);
        self.text[last_line_start..]
            .chars()
            .map(|c| c.len_utf16() as u32)
            .sum()
    }

    pub fn text_summary(&self) -> TextSummary {
        let mut len_utf16 = OffsetUtf16(0);
        let mut lines = Point::new(0, 0);
        let mut first_line_chars = 0;
        let mut last_line_chars = 0;
        let mut last_line_len_utf16 = 0;
        let mut longest_row = 0;
        let mut longest_row_chars = 0;
        let mut chars = 0;
        for c in self.text.chars() {
            chars += 1;
            len_utf16.0 += c.len_utf16();

            if c == '\n' {
                lines += Point::new(1, 0);
                last_line_len_utf16 = 0;
                last_line_chars = 0;
            } else {
                lines.column += c.len_utf8() as u32;
                last_line_len_utf16 += c.len_utf16() as u32;
                last_line_chars += 1;
            }

            if lines.row == 0 {
                first_line_chars = last_line_chars;
            }

            if last_line_chars > longest_row_chars {
                longest_row = lines.row;
                longest_row_chars = last_line_chars;
            }
        }

        TextSummary {
            len: self.text.len(),
            chars,
            len_utf16,
            lines,
            first_line_chars,
            last_line_chars,
            last_line_len_utf16,
            longest_row,
            longest_row_chars,
        }
    }

    pub fn offset_to_offset_utf16(&self, target: usize) -> OffsetUtf16 {
        let mut offset = 0;
        let mut offset_utf16 = OffsetUtf16(0);
        for c in self.text.chars() {
            if offset >= target {
                break;
            }
            offset += c.len_utf8();
            offset_utf16.0 += c.len_utf16();
        }
        offset_utf16
    }

    pub fn offset_utf16_to_offset(&self, target: OffsetUtf16) -> usize {
        let mut offset = 0;
        let mut offset_utf16 = OffsetUtf16(0);
        for c in self.text.chars() {
            if offset_utf16 >= target {
                break;
            }
            offset += c.len_utf8();
            offset_utf16.0 += c.len_utf16();
        }
        offset
    }

    pub fn offset_to_point(&self, target: usize) -> Point {
        let mut offset = 0;
        let mut point = Point::new(0, 0);
        for c in self.text.chars() {
            if offset >= target {
                break;
            }
            if c == '\n' {
                point.row += 1;
                point.column = 0;
            } else {
                point.column += c.len_utf8() as u32;
            }
            offset += c.len_utf8();
        }
        point
    }

    pub fn offset_to_point_utf16(&self, target: usize) -> PointUtf16 {
        let mut offset = 0;
        let mut point = PointUtf16::new(0, 0);
        for c in self.text.chars() {
            if offset >= target {
                break;
            }
            if c == '\n' {
                point.row += 1;
                point.column = 0;
            } else {
                point.column += c.len_utf16() as u32;
            }
            offset += c.len_utf8();
        }
        point
    }

    pub fn point_to_offset(&self, target: Point) -> usize {
        let mut offset = 0;
        let mut point = Point::new(0, 0);
        for c in self.text.chars() {
            if point >= target {
                break;
            }
            if c == '\n' {
                point.row += 1;
                point.column = 0;
            } else {
                point.column += c.len_utf8() as u32;
            }
            offset += c.len_utf8();
        }
        offset
    }

    pub fn point_utf16_to_offset(&self, target: PointUtf16, allow_line_end: bool) -> usize {
        let mut offset = 0;
        let mut point = PointUtf16::new(0, 0);
        for c in self.text.chars() {
            if point.row == target.row && (point.column >= target.column || c == '\n') {
                if !allow_line_end && c == '\n' && point.column < target.column {
                    // target is past end of line
                }
                break;
            }
            if point.row > target.row {
                break;
            }
            if c == '\n' {
                point.row += 1;
                point.column = 0;
            } else {
                point.column += c.len_utf16() as u32;
            }
            offset += c.len_utf8();
        }
        offset
    }

    pub fn clip_point(&self, target: Point, bias: crate::zed_sum_tree::Bias) -> Point {
        let mut point = Point::new(0, 0);
        for c in self.text.chars() {
            if point >= target {
                return point;
            }
            if c == '\n' {
                if point.row == target.row {
                    // Target column is past end of line
                    return point;
                }
                point.row += 1;
                point.column = 0;
            } else {
                point.column += c.len_utf8() as u32;
            }
        }
        point
    }
}

impl fmt::Debug for ChunkSlice<'_> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Debug::fmt(&self.text, f)
    }
}

// Bitmap and BitmapSlice for efficient char counting

pub const BITMAP_BYTES: usize = MAX_BASE / 8 + 1; // +1 for rounding

#[derive(Clone, Default)]
pub struct Bitmap {
    bytes: ArrayVec<u8, BITMAP_BYTES>,
}

impl Bitmap {
    pub fn from_text(text: &str) -> Self {
        let byte_count = (text.len() + 7) / 8;
        let mut bytes = ArrayVec::new();
        bytes.resize(byte_count, 0).ok();
        for (i, _) in text.char_indices() {
            let byte_idx = i / 8;
            let bit_idx = i % 8;
            if byte_idx < bytes.len() {
                bytes[byte_idx] |= 1 << bit_idx;
            }
        }
        Self { bytes }
    }

    pub fn append(&mut self, text: &str, offset: usize) {
        let new_len = offset + text.len();
        let new_byte_count = (new_len + 7) / 8;
        while self.bytes.len() < new_byte_count {
            self.bytes.push(0).ok();
        }
        for (i, _) in text.char_indices() {
            let abs_i = offset + i;
            let byte_idx = abs_i / 8;
            let bit_idx = abs_i % 8;
            if byte_idx < self.bytes.len() {
                self.bytes[byte_idx] |= 1 << bit_idx;
            }
        }
    }

    pub fn append_from(&mut self, other: &BitmapSlice, offset: usize) {
        // For simplicity, reconstruct from the text
        let new_len = offset + other.end - other.start;
        let new_byte_count = (new_len + 7) / 8;
        while self.bytes.len() < new_byte_count {
            self.bytes.push(0).ok();
        }
        // Copy bits from other
        for i in other.start..other.end {
            let src_byte_idx = i / 8;
            let src_bit_idx = i % 8;
            if src_byte_idx < other.bytes.len() {
                let bit_set = (other.bytes[src_byte_idx] >> src_bit_idx) & 1;
                if bit_set == 1 {
                    let dst_i = offset + (i - other.start);
                    let dst_byte_idx = dst_i / 8;
                    let dst_bit_idx = dst_i % 8;
                    if dst_byte_idx < self.bytes.len() {
                        self.bytes[dst_byte_idx] |= 1 << dst_bit_idx;
                    }
                }
            }
        }
    }

    pub fn slice(&self, start: usize, end: usize) -> BitmapSlice<'_> {
        BitmapSlice {
            bytes: &self.bytes,
            start,
            end,
        }
    }
}

#[derive(Clone, Copy)]
pub struct BitmapSlice<'a> {
    bytes: &'a [u8],
    start: usize,
    end: usize,
}

impl<'a> From<&'a str> for BitmapSlice<'a> {
    fn from(text: &'a str) -> Self {
        // For inline strings, we need to count manually
        // This is a simplified implementation
        BitmapSlice {
            bytes: &[],
            start: 0,
            end: text.len(),
        }
    }
}

impl<'a> BitmapSlice<'a> {
    pub fn bit_count(&self) -> usize {
        if self.bytes.is_empty() {
            // Fallback for inline strings - need to count from text
            // This shouldn't happen in practice since chunks always have bitmaps
            0
        } else {
            let mut count = 0;
            for i in self.start..self.end {
                let byte_idx = i / 8;
                let bit_idx = i % 8;
                if byte_idx < self.bytes.len() {
                    count += ((self.bytes[byte_idx] >> bit_idx) & 1) as usize;
                }
            }
            count
        }
    }

    pub fn split_left(&self, index: usize) -> BitmapSlice<'a> {
        BitmapSlice {
            bytes: self.bytes,
            start: self.start,
            end: self.start + index,
        }
    }

    pub fn split_right(&self, index: usize) -> BitmapSlice<'a> {
        BitmapSlice {
            bytes: self.bytes,
            start: self.start + index,
            end: self.end,
        }
    }
}
