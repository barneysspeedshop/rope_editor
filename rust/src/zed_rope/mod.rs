// Adapted from Zed's rope crate (GPL-3.0-or-later)
// https://github.com/zed-industries/zed

mod chunk;
mod offset_utf16;
mod point;
mod point_utf16;
mod unclipped;

use heapless::Vec as ArrayVec;
use rayon::iter::{IntoParallelIterator, ParallelIterator as _};
use std::{
    cmp, fmt, io, mem,
    ops::{self, AddAssign, Range},
    str,
};
use crate::zed_sum_tree::{Bias, Dimension, Dimensions, SumTree};

pub use chunk::{Chunk, ChunkSlice};
pub use offset_utf16::OffsetUtf16;
pub use point::Point;
pub use point_utf16::PointUtf16;
pub use unclipped::Unclipped;

use chunk::Bitmap;

#[derive(Clone, Default)]
pub struct Rope {
    chunks: SumTree<Chunk>,
}

impl Rope {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn is_char_boundary(&self, offset: usize) -> bool {
        if self.chunks.is_empty() {
            return offset == 0;
        }
        let (start, _, item) = self.chunks.find::<usize, _>((), &offset, Bias::Left);
        let chunk_offset = offset - start;
        item.map(|chunk| chunk.is_char_boundary(chunk_offset))
            .unwrap_or(false)
    }

    pub fn floor_char_boundary(&self, index: usize) -> usize {
        if index >= self.len() {
            self.len()
        } else {
            let (start, _, item) = self.chunks.find::<usize, _>((), &index, Bias::Left);
            let chunk_offset = index - start;
            let lower_idx = item.map(|chunk| chunk.text.floor_char_boundary(chunk_offset));
            lower_idx.map_or_else(|| self.len(), |idx| start + idx)
        }
    }

    pub fn ceil_char_boundary(&self, index: usize) -> usize {
        if index > self.len() {
            self.len()
        } else {
            let (start, _, item) = self.chunks.find::<usize, _>((), &index, Bias::Left);
            let chunk_offset = index - start;
            let upper_idx = item.map(|chunk| chunk.text.ceil_char_boundary(chunk_offset));
            upper_idx.map_or_else(|| self.len(), |idx| start + idx)
        }
    }

    pub fn append(&mut self, rope: Rope) {
        if let Some(chunk) = rope.chunks.first() {
            if self.chunks.last().is_some_and(|c| c.text.len() < chunk::MIN_BASE)
                || chunk.text.len() < chunk::MIN_BASE
            {
                self.push_chunk(chunk.as_slice());
                let mut chunks = rope.chunks.cursor::<()>(());
                chunks.next();
                chunks.next();
                self.chunks.append(chunks.suffix(), ());
            } else {
                self.chunks.append(rope.chunks, ());
            }
        } else {
            self.chunks.append(rope.chunks, ());
        }
    }

    pub fn replace(&mut self, range: Range<usize>, text: &str) {
        let mut new_rope = Rope::new();
        let mut cursor = self.cursor(0);
        new_rope.append(cursor.slice(range.start));
        cursor.seek_forward(range.end);
        new_rope.push(text);
        new_rope.append(cursor.suffix());
        *self = new_rope;
    }

    pub fn slice(&self, range: Range<usize>) -> Rope {
        let mut cursor = self.cursor(0);
        cursor.seek_forward(range.start);
        cursor.slice(range.end)
    }

    pub fn push(&mut self, mut text: &str) {
        self.chunks.update_last(
            |last_chunk| {
                let split_ix = if last_chunk.text.len() + text.len() <= chunk::MAX_BASE {
                    text.len()
                } else {
                    let mut split_ix = cmp::min(
                        chunk::MIN_BASE.saturating_sub(last_chunk.text.len()),
                        text.len(),
                    );
                    while !text.is_char_boundary(split_ix) {
                        split_ix += 1;
                    }
                    split_ix
                };

                let (suffix, remainder) = text.split_at(split_ix);
                last_chunk.push_str(suffix);
                text = remainder;
            },
            (),
        );

        if text.is_empty() {
            return;
        }

        const NUM_CHUNKS: usize = 4;

        if text.len() > NUM_CHUNKS * chunk::MAX_BASE - NUM_CHUNKS * 4 {
            return self.push_large(text);
        }

        let mut new_chunks = ArrayVec::<_, NUM_CHUNKS>::new();

        while !text.is_empty() {
            let mut split_ix = cmp::min(chunk::MAX_BASE, text.len());
            while !text.is_char_boundary(split_ix) {
                split_ix -= 1;
            }
            let (chunk, remainder) = text.split_at(split_ix);
            new_chunks.push(chunk).unwrap();
            text = remainder;
        }
        self.chunks
            .extend(new_chunks.into_iter().map(Chunk::new), ());
    }

    fn push_large(&mut self, mut text: &str) {
        const MIN_CHUNK_SIZE: usize = chunk::MAX_BASE - 3;

        let capacity = text.len().div_ceil(MIN_CHUNK_SIZE);
        let mut new_chunks = Vec::with_capacity(capacity);

        while !text.is_empty() {
            let mut split_ix = cmp::min(chunk::MAX_BASE, text.len());
            while !text.is_char_boundary(split_ix) {
                split_ix -= 1;
            }
            let (chunk, remainder) = text.split_at(split_ix);
            new_chunks.push(chunk);
            text = remainder;
        }

        const PARALLEL_THRESHOLD: usize = 84 * 12; // 84 * (2 * TREE_BASE)

        if new_chunks.len() >= PARALLEL_THRESHOLD {
            self.chunks
                .par_extend(new_chunks.into_par_iter().map(Chunk::new), ());
        } else {
            self.chunks
                .extend(new_chunks.into_iter().map(Chunk::new), ());
        }
    }

    fn push_chunk(&mut self, mut chunk: ChunkSlice) {
        self.chunks.update_last(
            |last_chunk| {
                let split_ix = if last_chunk.text.len() + chunk.len() <= chunk::MAX_BASE {
                    chunk.len()
                } else {
                    let mut split_ix = cmp::min(
                        chunk::MIN_BASE.saturating_sub(last_chunk.text.len()),
                        chunk.len(),
                    );
                    while !chunk.is_char_boundary(split_ix) {
                        split_ix += 1;
                    }
                    split_ix
                };

                let (suffix, remainder) = chunk.split_at(split_ix);
                last_chunk.append(suffix);
                chunk = remainder;
            },
            (),
        );

        if !chunk.is_empty() {
            self.chunks.push(chunk.into(), ());
        }
    }

    pub fn summary(&self) -> TextSummary {
        self.chunks.summary().text
    }

    pub fn len(&self) -> usize {
        self.chunks.extent(())
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    pub fn max_point(&self) -> Point {
        self.chunks.extent(())
    }

    pub fn max_point_utf16(&self) -> PointUtf16 {
        self.chunks.extent(())
    }

    pub fn cursor(&self, offset: usize) -> Cursor<'_> {
        Cursor::new(self, offset)
    }

    pub fn chars(&self) -> impl Iterator<Item = char> + '_ {
        self.chars_at(0)
    }

    pub fn chars_at(&self, start: usize) -> impl Iterator<Item = char> + '_ {
        self.chunks_in_range(start..self.len()).flat_map(str::chars)
    }

    pub fn chunks(&self) -> Chunks<'_> {
        self.chunks_in_range(0..self.len())
    }

    pub fn chunks_in_range(&self, range: Range<usize>) -> Chunks<'_> {
        Chunks::new(self, range, false)
    }

    pub fn reversed_chunks_in_range(&self, range: Range<usize>) -> Chunks<'_> {
        Chunks::new(self, range, true)
    }

    pub fn chars_in_range(&self, range: Range<usize>) -> impl Iterator<Item = char> + '_ {
        self.chunks_in_range(range).flat_map(str::chars)
    }

    pub fn offset_to_offset_utf16(&self, offset: usize) -> OffsetUtf16 {
        if offset >= self.summary().len {
            return self.summary().len_utf16;
        }
        let (start, _, item) =
            self.chunks
                .find::<Dimensions<usize, OffsetUtf16>, _>((), &offset, Bias::Left);
        let overshoot = offset - start.0;
        start.1
            + item.map_or(Default::default(), |chunk| {
                chunk.as_slice().offset_to_offset_utf16(overshoot)
            })
    }

    pub fn offset_utf16_to_offset(&self, offset: OffsetUtf16) -> usize {
        if offset >= self.summary().len_utf16 {
            return self.summary().len;
        }
        let (start, _, item) =
            self.chunks
                .find::<Dimensions<OffsetUtf16, usize>, _>((), &offset, Bias::Left);
        let overshoot = offset - start.0;
        start.1
            + item.map_or(Default::default(), |chunk| {
                chunk.as_slice().offset_utf16_to_offset(overshoot)
            })
    }

    pub fn offset_to_point(&self, offset: usize) -> Point {
        if offset >= self.summary().len {
            return self.summary().lines;
        }
        let (start, _, item) =
            self.chunks
                .find::<Dimensions<usize, Point>, _>((), &offset, Bias::Left);
        let overshoot = offset - start.0;
        start.1
            + item.map_or(Point::zero(), |chunk| {
                chunk.as_slice().offset_to_point(overshoot)
            })
    }

    pub fn offset_to_point_utf16(&self, offset: usize) -> PointUtf16 {
        if offset >= self.summary().len {
            return self.summary().lines_utf16();
        }
        let (start, _, item) =
            self.chunks
                .find::<Dimensions<usize, PointUtf16>, _>((), &offset, Bias::Left);
        let overshoot = offset - start.0;
        start.1
            + item.map_or(PointUtf16::zero(), |chunk| {
                chunk.as_slice().offset_to_point_utf16(overshoot)
            })
    }

    pub fn point_to_offset(&self, point: Point) -> usize {
        if point >= self.summary().lines {
            return self.summary().len;
        }
        let (start, _, item) =
            self.chunks
                .find::<Dimensions<Point, usize>, _>((), &point, Bias::Left);
        let overshoot = point - start.0;
        start.1 + item.map_or(0, |chunk| chunk.as_slice().point_to_offset(overshoot))
    }

    pub fn point_utf16_to_offset(&self, point: PointUtf16) -> usize {
        if point >= self.summary().lines_utf16() {
            return self.summary().len;
        }
        let (start, _, item) =
            self.chunks
                .find::<Dimensions<PointUtf16, usize>, _>((), &point, Bias::Left);
        let overshoot = point - start.0;
        start.1
            + item.map_or(0, |chunk| {
                chunk.as_slice().point_utf16_to_offset(overshoot, false)
            })
    }

    pub fn clip_offset(&self, offset: usize, bias: Bias) -> usize {
        match bias {
            Bias::Left => self.floor_char_boundary(offset),
            Bias::Right => self.ceil_char_boundary(offset),
        }
    }

    pub fn clip_point(&self, point: Point, bias: Bias) -> Point {
        let (start, _, item) = self.chunks.find::<Point, _>((), &point, Bias::Right);
        if let Some(chunk) = item {
            let overshoot = point - start;
            start + chunk.as_slice().clip_point(overshoot, bias)
        } else {
            self.summary().lines
        }
    }

    pub fn line_len(&self, row: u32) -> u32 {
        self.clip_point(Point::new(row, u32::MAX), Bias::Left).column
    }
}

impl<'a> From<&'a str> for Rope {
    fn from(text: &'a str) -> Self {
        let mut rope = Self::new();
        rope.push(text);
        rope
    }
}

impl<'a> FromIterator<&'a str> for Rope {
    fn from_iter<T: IntoIterator<Item = &'a str>>(iter: T) -> Self {
        let mut rope = Rope::new();
        for chunk in iter {
            rope.push(chunk);
        }
        rope
    }
}

impl From<String> for Rope {
    #[inline(always)]
    fn from(text: String) -> Self {
        Rope::from(text.as_str())
    }
}

impl fmt::Display for Rope {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        for chunk in self.chunks() {
            write!(f, "{}", chunk)?;
        }
        Ok(())
    }
}

impl fmt::Debug for Rope {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        use std::fmt::Write as _;

        write!(f, "\"")?;
        let mut format_string = String::new();
        for chunk in self.chunks() {
            write!(&mut format_string, "{:?}", chunk)?;
            write!(f, "{}", &format_string[1..format_string.len() - 1])?;
            format_string.clear();
        }
        write!(f, "\"")?;
        Ok(())
    }
}

pub struct Cursor<'a> {
    rope: &'a Rope,
    chunks: crate::zed_sum_tree::Cursor<'a, 'static, Chunk, usize>,
    offset: usize,
}

impl<'a> Cursor<'a> {
    pub fn new(rope: &'a Rope, offset: usize) -> Self {
        let mut chunks = rope.chunks.cursor(());
        chunks.seek(&offset, Bias::Right);
        Self {
            rope,
            chunks,
            offset,
        }
    }

    pub fn seek_forward(&mut self, end_offset: usize) {
        assert!(
            end_offset >= self.offset,
            "cannot seek backward from {} to {}",
            self.offset,
            end_offset
        );
        assert!(
            end_offset <= self.rope.len(),
            "cannot summarize past end of rope"
        );

        self.chunks.seek_forward(&end_offset, Bias::Right);
        self.offset = end_offset;
    }

    pub fn slice(&mut self, end_offset: usize) -> Rope {
        assert!(
            end_offset >= self.offset,
            "cannot slice backward from {} to {}",
            self.offset,
            end_offset
        );
        assert!(
            end_offset <= self.rope.len(),
            "cannot summarize past end of rope"
        );

        let mut slice = Rope::new();
        if let Some(start_chunk) = self.chunks.item() {
            let start_ix = self.offset - self.chunks.start();
            let end_ix = cmp::min(end_offset, self.chunks.end()) - self.chunks.start();
            slice.push_chunk(start_chunk.slice(start_ix..end_ix));
        }

        if end_offset > self.chunks.end() {
            self.chunks.next();
            slice.append(Rope {
                chunks: self.chunks.slice(&end_offset, Bias::Right),
            });
            if let Some(end_chunk) = self.chunks.item() {
                let end_ix = end_offset - self.chunks.start();
                slice.push_chunk(end_chunk.slice(0..end_ix));
            }
        }

        self.offset = end_offset;
        slice
    }

    pub fn summary<D: TextDimension>(&mut self, end_offset: usize) -> D {
        assert!(
            end_offset >= self.offset,
            "cannot summarize backward from {} to {}",
            self.offset,
            end_offset
        );
        assert!(
            end_offset <= self.rope.len(),
            "cannot summarize past end of rope"
        );

        let mut summary = D::zero(());
        if let Some(start_chunk) = self.chunks.item() {
            let start_ix = self.offset - self.chunks.start();
            let end_ix = cmp::min(end_offset, self.chunks.end()) - self.chunks.start();
            summary.add_assign(&D::from_chunk(start_chunk.slice(start_ix..end_ix)));
        }

        if end_offset > self.chunks.end() {
            self.chunks.next();
            summary.add_assign(&self.chunks.summary(&end_offset, Bias::Right));
            if let Some(end_chunk) = self.chunks.item() {
                let end_ix = end_offset - self.chunks.start();
                summary.add_assign(&D::from_chunk(end_chunk.slice(0..end_ix)));
            }
        }

        self.offset = end_offset;
        summary
    }

    pub fn suffix(mut self) -> Rope {
        self.slice(self.rope.chunks.extent(()))
    }

    pub fn offset(&self) -> usize {
        self.offset
    }
}

#[derive(Clone)]
pub struct Chunks<'a> {
    chunks: crate::zed_sum_tree::Cursor<'a, 'static, Chunk, usize>,
    range: Range<usize>,
    offset: usize,
    reversed: bool,
}

impl<'a> Chunks<'a> {
    pub fn new(rope: &'a Rope, range: Range<usize>, reversed: bool) -> Self {
        let mut chunks = rope.chunks.cursor(());
        let offset = if reversed {
            chunks.seek(&range.end, Bias::Left);
            range.end
        } else {
            chunks.seek(&range.start, Bias::Right);
            range.start
        };
        Self {
            chunks,
            range,
            offset,
            reversed,
        }
    }

    fn offset_is_valid(&self) -> bool {
        if self.reversed {
            if self.offset <= self.range.start || self.offset > self.range.end {
                return false;
            }
        } else if self.offset < self.range.start || self.offset >= self.range.end {
            return false;
        }

        true
    }

    pub fn offset(&self) -> usize {
        self.offset
    }

    pub fn seek(&mut self, mut offset: usize) {
        offset = offset.clamp(self.range.start, self.range.end);

        if self.reversed {
            if offset > self.chunks.end() {
                self.chunks.seek_forward(&offset, Bias::Left);
            } else if offset <= *self.chunks.start() {
                self.chunks.seek(&offset, Bias::Left);
            }
        } else {
            if offset >= self.chunks.end() {
                self.chunks.seek_forward(&offset, Bias::Right);
            } else if offset < *self.chunks.start() {
                self.chunks.seek(&offset, Bias::Right);
            }
        };

        self.offset = offset;
    }

    pub fn peek(&self) -> Option<&'a str> {
        if !self.offset_is_valid() {
            return None;
        }

        let chunk = self.chunks.item()?;
        let chunk_start = *self.chunks.start();
        let slice_range = if self.reversed {
            let slice_start = cmp::max(chunk_start, self.range.start) - chunk_start;
            let slice_end = self.offset - chunk_start;
            slice_start..slice_end
        } else {
            let slice_start = self.offset - chunk_start;
            let slice_end = cmp::min(self.chunks.end(), self.range.end) - chunk_start;
            slice_start..slice_end
        };

        Some(&chunk.text[slice_range])
    }
}

impl<'a> Iterator for Chunks<'a> {
    type Item = &'a str;

    fn next(&mut self) -> Option<Self::Item> {
        let chunk = self.peek()?;
        if self.reversed {
            self.offset -= chunk.len();
            if self.offset <= *self.chunks.start() {
                self.chunks.prev();
            }
        } else {
            self.offset += chunk.len();
            if self.offset >= self.chunks.end() {
                self.chunks.next();
            }
        }

        Some(chunk)
    }
}

impl crate::zed_sum_tree::Item for Chunk {
    type Summary = ChunkSummary;

    fn summary(&self, _cx: ()) -> Self::Summary {
        ChunkSummary {
            text: self.as_slice().text_summary(),
        }
    }
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct ChunkSummary {
    pub text: TextSummary,
}

impl crate::zed_sum_tree::ContextLessSummary for ChunkSummary {
    fn zero() -> Self {
        Default::default()
    }

    fn add_summary(&mut self, summary: &Self) {
        self.text += &summary.text;
    }
}

/// Summary of a string of text.
#[derive(Copy, Clone, Debug, Default, Eq, PartialEq)]
pub struct TextSummary {
    /// Length in bytes.
    pub len: usize,
    /// Length in UTF-8 chars.
    pub chars: usize,
    /// Length in UTF-16 code units
    pub len_utf16: OffsetUtf16,
    /// A point representing the number of lines and the length of the last line.
    pub lines: Point,
    /// How many `char`s are in the first line
    pub first_line_chars: u32,
    /// How many `char`s are in the last line
    pub last_line_chars: u32,
    /// How many UTF-16 code units are in the last line
    pub last_line_len_utf16: u32,
    /// The row idx of the longest row
    pub longest_row: u32,
    /// How many `char`s are in the longest row
    pub longest_row_chars: u32,
}

impl TextSummary {
    pub fn lines_utf16(&self) -> PointUtf16 {
        PointUtf16 {
            row: self.lines.row,
            column: self.last_line_len_utf16,
        }
    }
}

impl<'a> From<&'a str> for TextSummary {
    fn from(text: &'a str) -> Self {
        let mut len_utf16 = OffsetUtf16(0);
        let mut lines = Point::new(0, 0);
        let mut first_line_chars = 0;
        let mut last_line_chars = 0;
        let mut last_line_len_utf16 = 0;
        let mut longest_row = 0;
        let mut longest_row_chars = 0;
        let mut chars = 0;
        for c in text.chars() {
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
            len: text.len(),
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
}

impl crate::zed_sum_tree::ContextLessSummary for TextSummary {
    fn zero() -> Self {
        Default::default()
    }

    fn add_summary(&mut self, summary: &Self) {
        *self += summary;
    }
}

impl ops::Add<Self> for TextSummary {
    type Output = Self;

    fn add(mut self, rhs: Self) -> Self::Output {
        AddAssign::add_assign(&mut self, &rhs);
        self
    }
}

impl<'a> ops::AddAssign<&'a Self> for TextSummary {
    fn add_assign(&mut self, other: &'a Self) {
        let joined_chars = self.last_line_chars + other.first_line_chars;
        if joined_chars > self.longest_row_chars {
            self.longest_row = self.lines.row;
            self.longest_row_chars = joined_chars;
        }
        if other.longest_row_chars > self.longest_row_chars {
            self.longest_row = self.lines.row + other.longest_row;
            self.longest_row_chars = other.longest_row_chars;
        }

        if self.lines.row == 0 {
            self.first_line_chars += other.first_line_chars;
        }

        if other.lines.row == 0 {
            self.last_line_chars += other.first_line_chars;
            self.last_line_len_utf16 += other.last_line_len_utf16;
        } else {
            self.last_line_chars = other.last_line_chars;
            self.last_line_len_utf16 = other.last_line_len_utf16;
        }

        self.chars += other.chars;
        self.len += other.len;
        self.len_utf16 += other.len_utf16;
        self.lines += other.lines;
    }
}

impl ops::AddAssign<Self> for TextSummary {
    fn add_assign(&mut self, other: Self) {
        *self += &other;
    }
}

pub trait TextDimension:
    'static + Clone + Copy + Default + for<'a> Dimension<'a, ChunkSummary> + std::fmt::Debug
{
    fn from_text_summary(summary: &TextSummary) -> Self;
    fn from_chunk(chunk: ChunkSlice) -> Self;
    fn add_assign(&mut self, other: &Self);
}

impl<'a> crate::zed_sum_tree::Dimension<'a, ChunkSummary> for TextSummary {
    fn zero(_cx: ()) -> Self {
        Default::default()
    }

    fn add_summary(&mut self, summary: &'a ChunkSummary, _: ()) {
        *self += &summary.text;
    }
}

impl TextDimension for TextSummary {
    fn from_text_summary(summary: &TextSummary) -> Self {
        *summary
    }

    fn from_chunk(chunk: ChunkSlice) -> Self {
        chunk.text_summary()
    }

    fn add_assign(&mut self, other: &Self) {
        *self += *other;
    }
}

impl<'a> crate::zed_sum_tree::Dimension<'a, ChunkSummary> for usize {
    fn zero(_cx: ()) -> Self {
        Default::default()
    }

    fn add_summary(&mut self, summary: &'a ChunkSummary, _: ()) {
        *self += summary.text.len;
    }
}

impl TextDimension for usize {
    fn from_text_summary(summary: &TextSummary) -> Self {
        summary.len
    }

    fn from_chunk(chunk: ChunkSlice) -> Self {
        chunk.len()
    }

    fn add_assign(&mut self, other: &Self) {
        *self += *other;
    }
}

impl<'a> crate::zed_sum_tree::Dimension<'a, ChunkSummary> for OffsetUtf16 {
    fn zero(_cx: ()) -> Self {
        Default::default()
    }

    fn add_summary(&mut self, summary: &'a ChunkSummary, _: ()) {
        *self += summary.text.len_utf16;
    }
}

impl TextDimension for OffsetUtf16 {
    fn from_text_summary(summary: &TextSummary) -> Self {
        summary.len_utf16
    }

    fn from_chunk(chunk: ChunkSlice) -> Self {
        chunk.len_utf16()
    }

    fn add_assign(&mut self, other: &Self) {
        *self += *other;
    }
}

impl<'a> crate::zed_sum_tree::Dimension<'a, ChunkSummary> for Point {
    fn zero(_cx: ()) -> Self {
        Default::default()
    }

    fn add_summary(&mut self, summary: &'a ChunkSummary, _: ()) {
        *self += summary.text.lines;
    }
}

impl TextDimension for Point {
    fn from_text_summary(summary: &TextSummary) -> Self {
        summary.lines
    }

    fn from_chunk(chunk: ChunkSlice) -> Self {
        chunk.lines()
    }

    fn add_assign(&mut self, other: &Self) {
        *self += *other;
    }
}

impl<'a> crate::zed_sum_tree::Dimension<'a, ChunkSummary> for PointUtf16 {
    fn zero(_cx: ()) -> Self {
        Default::default()
    }

    fn add_summary(&mut self, summary: &'a ChunkSummary, _: ()) {
        *self += summary.text.lines_utf16();
    }
}

impl TextDimension for PointUtf16 {
    fn from_text_summary(summary: &TextSummary) -> Self {
        summary.lines_utf16()
    }

    fn from_chunk(chunk: ChunkSlice) -> Self {
        PointUtf16 {
            row: chunk.lines().row,
            column: chunk.last_line_len_utf16(),
        }
    }

    fn add_assign(&mut self, other: &Self) {
        *self += *other;
    }
}
