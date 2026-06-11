use flutter_rust_bridge::frb;
use parking_lot::RwLock;
use regex::RegexBuilder;
use crate::zed_rope::{self, Rope, OffsetUtf16, Point};
use std::sync::Arc;

pub struct RopeInstance {
    state: Arc<RwLock<EditorState>>,
}

impl RopeInstance {
    fn new(text: String) -> Self {
        let state = EditorState::new(text);
        Self {
            state: Arc::new(RwLock::new(state)),
        }
    }

    fn from_file(path: String, max_chars: Option<usize>) -> Result<Self, String> {
        use std::fs::File;
        use std::io::{BufReader, Read};

        let file = File::open(&path).map_err(|e| format!("Failed to open file: {}", e))?;
        let mut reader = BufReader::new(file);
        let content = if let Some(limit) = max_chars {
            let mut buffer = Vec::new();
            reader.take(limit as u64).read_to_end(&mut buffer)
                .map_err(|e| format!("Failed to read file: {}", e))?;
            String::from_utf8_lossy(&buffer).into_owned()
        } else {
            let mut s = String::new();
            reader.read_to_string(&mut s).map_err(|e| format!("Failed to read file: {}", e))?;
            s
        };

        let state = EditorState::new(content);
        Ok(Self {
            state: Arc::new(RwLock::new(state)),
        })
    }

    fn get_state(&self) -> &RwLock<EditorState> {
        &self.state
    }
}

struct EditorState {
    rope: Rope,
    // For viewport-based loading of very long single lines
    file_handle: Option<std::fs::File>,
    file_byte_offset: usize,
    total_file_size: usize,
}

impl EditorState {
    fn new(text: String) -> Self {
        Self {
            rope: Rope::from(text),
            file_handle: None,
            file_byte_offset: 0,
            total_file_size: 0,
        }
    }
}



/// Metrics returned in a single FFI call to minimize cross-language traffic.
pub struct RopeMetrics {
    pub byte_len: usize,
    pub char_len: usize,
    pub utf16_len: usize,
    pub line_count: usize,
    pub max_line_utf16_len: usize,
}

// ── Rope helper functions ────────────────────────────────────────────────────

/// Return the number of lines (same semantics as ropey::Rope::len_lines).
#[inline]
fn rope_len_lines(rope: &Rope) -> usize {
    rope.summary().lines.row as usize + 1
}

/// Iterate over the chars of the given 0-based line index.
fn line_chars<'a>(rope: &'a Rope, line_idx: usize) -> impl Iterator<Item = char> + 'a {
    let total_lines = rope_len_lines(rope);
    let start = rope.point_to_offset(Point::new(line_idx as u32, 0));
    let end = if line_idx + 1 < total_lines {
        rope.point_to_offset(Point::new(line_idx as u32 + 1, 0))
    } else {
        rope.summary().len
    };
    rope.chars_in_range(start..end)
}

/// Convert line index to byte offset (start of that line).
#[inline]
fn line_to_byte(rope: &Rope, line_idx: usize) -> usize {
    rope.point_to_offset(Point::new(line_idx as u32, 0))
}

/// Convert byte offset to line index.
#[inline]
fn byte_to_line(rope: &Rope, byte_offset: usize) -> usize {
    rope.offset_to_point(byte_offset).row as usize
}

/// Convert a UTF-16 offset to a byte offset.
#[inline]
fn utf16_to_byte(rope: &Rope, utf16: usize) -> usize {
    rope.offset_utf16_to_offset(OffsetUtf16(utf16))
}

/// Convert a byte offset to a UTF-16 offset.
#[inline]
fn byte_to_utf16(rope: &Rope, byte: usize) -> usize {
    rope.offset_to_offset_utf16(byte).0
}

/// Get char at byte offset.
#[inline]
fn char_at_byte(rope: &Rope, byte_offset: usize) -> char {
    rope.chars_at(byte_offset).next().unwrap_or('\0')
}

/// Get max UTF-16 length across all lines (for horizontal scroll).
fn max_line_utf16_len(rope: &Rope) -> usize {
    rope.summary().longest_row_chars as usize
}

// ── Public FFI functions ──────────────────────────────────────────────────────

#[frb(sync)]
pub fn get_metrics(instance: &RopeInstance) -> RopeMetrics {
    let state = instance.get_state().read();
    let summary = state.rope.summary();
    RopeMetrics {
        byte_len: summary.len,
        char_len: summary.chars,
        utf16_len: summary.len_utf16.0,
        line_count: summary.lines.row as usize + 1,
        max_line_utf16_len: summary.longest_row_chars as usize,
    }
}

/// Convert UTF-16 offset to byte offset (kept for legacy call sites).
#[inline]
fn utf16_to_char_offset(state: &EditorState, utf16_offset: usize) -> usize {
    utf16_to_byte(&state.rope, utf16_offset)
}

/// Convert byte offset to UTF-16 offset.
#[inline]
fn byte_to_utf16_offset(state: &EditorState, byte_offset: usize) -> usize {
    byte_to_utf16(&state.rope, byte_offset)
}

#[frb(sync)]
pub fn create_rope_instance(text: String) -> RopeInstance {
    RopeInstance::new(text)
}

#[frb(sync)]
pub fn insert(instance: &RopeInstance, offset_utf16: usize, text: String) {
    let mut state = instance.get_state().write();
    let byte_idx = utf16_to_char_offset(&state, offset_utf16);
    state.rope.replace(byte_idx..byte_idx, &text);
}

#[frb(sync)]
pub fn delete(instance: &RopeInstance, start_utf16: usize, end_utf16: usize) {
    let mut state = instance.get_state().write();
    let start_byte = utf16_to_char_offset(&state, start_utf16);
    let end_byte = utf16_to_char_offset(&state, end_utf16);
    if start_byte < end_byte {
        state.rope.replace(start_byte..end_byte, "");
    }
}

/// Combined replace operation: delete a range and insert text atomically.
#[frb(sync)]
pub fn replace(instance: &RopeInstance, start_utf16: usize, end_utf16: usize, text: String) {
    let mut state = instance.get_state().write();
    let start_byte = utf16_to_char_offset(&state, start_utf16);
    let end_byte = utf16_to_char_offset(&state, end_utf16);
    state.rope.replace(start_byte..end_byte, &text);
}

#[frb(sync)]
pub fn get_text(instance: &RopeInstance) -> String {
    instance.get_state().read().rope.to_string()
}

#[frb(sync)]
pub fn get_text_range(instance: &RopeInstance, start_utf16: usize, end_utf16: usize) -> String {
    let state = instance.get_state().read();
    let start_byte = utf16_to_char_offset(&state, start_utf16);
    let end_byte = utf16_to_char_offset(&state, end_utf16);
    if start_byte >= end_byte { return String::new(); }
    state.rope.slice(start_byte..end_byte.min(state.rope.summary().len)).to_string()
}

#[frb(sync)]
pub fn get_line_count(instance: &RopeInstance) -> usize {
    let state = instance.get_state().read();
    rope_len_lines(&state.rope)
}

/// Optimized function to get document length in UTF-16 code units
#[frb(sync)]
pub fn get_length_utf16(instance: &RopeInstance) -> usize {
    instance.get_state().read().rope.summary().len_utf16.0
}

#[frb(sync)]
pub fn get_line_start_offset_utf16(instance: &RopeInstance, line_index: usize) -> usize {
    let state = instance.get_state().read();
    let byte = line_to_byte(&state.rope, line_index);
    byte_to_utf16(&state.rope, byte)
}

/// Batch API: Returns UTF-16 start offsets for a contiguous range of lines.
#[frb(sync)]
pub fn get_line_start_offsets_batch(instance: &RopeInstance, start_line: usize, end_line: usize) -> Vec<usize> {
    let state = instance.get_state().read();
    let total_lines = rope_len_lines(&state.rope);
    let start = start_line.min(total_lines);
    let end = end_line.min(total_lines);
    if start >= end { return Vec::new(); }
    (start..end)
        .map(|l| byte_to_utf16(&state.rope, line_to_byte(&state.rope, l)))
        .collect()
}

/// Minimap density data for a single line.
/// Avoids serializing full line strings just to measure whitespace/content.
pub struct MinimapLineDensity {
    /// Number of leading whitespace characters (spaces/tabs).
    pub leading_whitespace: usize,
    /// Length of non-whitespace content (excluding leading/trailing whitespace).
    pub content_length: usize,
    /// Whether the line is empty or whitespace-only.
    pub is_empty: bool,
}

/// Batch API: Returns minimap density data for multiple lines.
/// Eliminates string serialization overhead for minimap rendering.
/// For each line, computes leading whitespace, content length, and emptiness
/// directly on the Rust side.
#[frb(sync)]
pub fn get_minimap_density_batch(instance: &RopeInstance, line_indices: Vec<usize>) -> Vec<MinimapLineDensity> {
    let state = instance.get_state().read();
    let total_lines = rope_len_lines(&state.rope);

    line_indices
        .into_iter()
        .map(|line_index| {
            if line_index >= total_lines {
                return MinimapLineDensity {
                    leading_whitespace: 0,
                    content_length: 0,
                    is_empty: true,
                };
            }

            let mut leading_whitespace: usize = 0;
            let mut trailing_whitespace: usize = 0;
            let mut total_chars: usize = 0;
            let mut in_leading = true;

            for ch in line_chars(&state.rope, line_index) {
                if ch == '\n' || ch == '\r' { continue; }
                total_chars += 1;
                if ch.is_whitespace() {
                    if in_leading { leading_whitespace += 1; }
                    trailing_whitespace += 1;
                } else {
                    in_leading = false;
                    trailing_whitespace = 0;
                }
            }

            let content_length = total_chars.saturating_sub(leading_whitespace + trailing_whitespace);
            MinimapLineDensity {
                leading_whitespace,
                content_length,
                is_empty: content_length == 0,
            }
        })
        .collect()
}

#[frb(sync)]
pub fn get_line_at_offset_utf16(instance: &RopeInstance, offset_utf16: usize) -> usize {
    let state = instance.get_state().read();
    let byte = utf16_to_byte(&state.rope, offset_utf16);
    byte_to_line(&state.rope, byte)
}

/// Returns only the requested line, avoiding a full document clone.
#[frb(sync)]
pub fn get_line_text(instance: &RopeInstance, line_index: usize) -> String {
    let state = instance.get_state().read();
    if line_index >= rope_len_lines(&state.rope) { return String::new(); }
    line_chars(&state.rope, line_index).collect()
}

#[frb(sync)]
pub fn get_lines_text_batch(instance: &RopeInstance, line_indices: Vec<usize>) -> Vec<String> {
    let state = instance.get_state().read();
    let total_lines = rope_len_lines(&state.rope);
    line_indices
        .into_iter()
        .filter_map(|line_index| {
            if line_index < total_lines {
                Some(line_chars(&state.rope, line_index).collect::<String>())
            } else {
                None
            }
        })
        .collect()
}

#[frb(sync)]
pub fn search(
    instance: &RopeInstance,
    pattern: String,
    case_sensitive: bool,
    is_regex: bool,
) -> Vec<usize> {
    let state = instance.get_state().read();
    let mut results = Vec::new();
    let full_text = state.rope.to_string();

    let regex_pattern = if is_regex { pattern } else { regex::escape(&pattern) };
    let re = RegexBuilder::new(&regex_pattern)
        .case_insensitive(!case_sensitive)
        .build();

    if let Ok(re) = re {
        for mat in re.find_iter(&full_text) {
            results.push(byte_to_utf16(&state.rope, mat.start()));
            results.push(byte_to_utf16(&state.rope, mat.end()));
        }
    }
    results
}

// Async versions for non-blocking UI operations
pub fn create_rope_instance_async(text: String) -> RopeInstance {
    RopeInstance::new(text)
}

/// Load a rope directly from a file path without loading entire content into Dart first.
/// For single-line files, pass max_chars to limit how much is loaded (for viewport buffering).
/// Pass None for max_chars to load the entire file (for normal multi-line files).
pub fn create_rope_instance_from_file(path: String, max_chars: Option<usize>) -> Result<RopeInstance, String> {
    RopeInstance::from_file(path, max_chars)
}

pub fn get_text_async(instance: &RopeInstance) -> String {
    instance.get_state().read().rope.to_string()
}

#[frb(sync)]
pub fn get_content_hash(instance: &RopeInstance) -> i64 {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    let state = instance.get_state().read();
    let mut hasher = DefaultHasher::new();
    for chunk in state.rope.chunks() {
        chunk.hash(&mut hasher);
    }
    hasher.finish() as i64
}

// ============================================================================
// 4. Range-Based Text Access
// ============================================================================

/// Get text for a contiguous range of lines in a single FFI call.
#[frb(sync)]
pub fn get_lines_text_range(instance: &RopeInstance, start_line: usize, end_line: usize) -> String {
    let state = instance.get_state().read();
    let total_lines = rope_len_lines(&state.rope);
    let start = start_line.min(total_lines);
    let end = end_line.min(total_lines);
    if start >= end { return String::new(); }
    let start_byte = line_to_byte(&state.rope, start);
    let end_byte = if end >= total_lines {
        state.rope.summary().len
    } else {
        line_to_byte(&state.rope, end)
    };
    state.rope.slice(start_byte..end_byte).to_string()
}

/// Get a text chunk starting at a UTF-16 offset with a maximum length.
/// Useful for slicing wide lines for viewport rendering without copying
/// the entire line content.
#[frb(sync)]
pub fn get_text_chunk(instance: &RopeInstance, start_utf16: usize, max_length: usize) -> String {
    let state = instance.get_state().read();
    let start_byte = utf16_to_byte(&state.rope, start_utf16);
    let total_bytes = state.rope.summary().len;
    if start_byte >= total_bytes { return String::new(); }

    let mut end_byte = start_byte;
    let mut utf16_count = 0;
    for ch in state.rope.chars_at(start_byte) {
        utf16_count += ch.len_utf16();
        end_byte += ch.len_utf8();
        if utf16_count >= max_length { break; }
    }
    state.rope.slice(start_byte..end_byte.min(total_bytes)).to_string()
}

// ============================================================================
// 5. Indentation Analysis
// ============================================================================

/// Information about the indentation style detected in a document.
pub struct IndentInfo {
    /// Whether the document primarily uses tabs for indentation.
    pub uses_tabs: bool,
    /// The detected number of spaces per indent level (2, 4, 8, etc.).
    /// Only meaningful if uses_tabs is false.
    pub spaces_per_indent: usize,
    /// Whether the document has mixed indentation styles.
    pub mixed: bool,
}

/// Detect the dominant indentation style in the document by sampling lines.
#[frb(sync)]
pub fn detect_indentation(instance: &RopeInstance) -> IndentInfo {
    let state = instance.get_state().read();
    let total_lines = rope_len_lines(&state.rope);

    let mut tab_lines = 0;
    let mut space_lines = 0;
    let mut indent_sizes: [usize; 9] = [0; 9];

    let sample_count = total_lines.min(1000);
    let step = if sample_count > 0 { total_lines / sample_count } else { 1 };

    for i in (0..total_lines).step_by(step.max(1)) {
        let mut chars = line_chars(&state.rope, i);
        if let Some(first) = chars.next() {
            if first == '\t' {
                tab_lines += 1;
            } else if first == ' ' {
                let mut spaces = 1;
                for ch in chars {
                    if ch == ' ' { spaces += 1; } else { break; }
                }
                space_lines += 1;
                if spaces <= 8 { indent_sizes[spaces] += 1; }
            }
        }
    }

    let uses_tabs = tab_lines > space_lines;
    let mixed = tab_lines > 0 && space_lines > 0 &&
                (tab_lines as f64 / (tab_lines + space_lines) as f64) > 0.1 &&
                (space_lines as f64 / (tab_lines + space_lines) as f64) > 0.1;
    let spaces_per_indent = if indent_sizes[2] >= indent_sizes[4] && indent_sizes[2] > 0 {
        2
    } else if indent_sizes[4] > 0 {
        4
    } else {
        indent_sizes.iter().enumerate().skip(1).max_by_key(|(_, &count)| count).map(|(i, _)| i).unwrap_or(4)
    };
    IndentInfo { uses_tabs, spaces_per_indent, mixed }
}

#[frb(sync)]
pub fn get_line_indentation(instance: &RopeInstance, line_index: usize) -> usize {
    let state = instance.get_state().read();
    if line_index >= rope_len_lines(&state.rope) { return 0; }
    let mut indent = 0;
    for ch in line_chars(&state.rope, line_index) {
        if ch == ' ' || ch == '\t' { indent += 1; } else { break; }
    }
    indent
}

// ============================================================================
// 6. Range Search
// ============================================================================

/// Search for a pattern only within a specific line range.
/// Returns UTF-16 offsets as pairs [start, end, start, end, ...].
/// More efficient than full document search when you only need results
/// for visible lines.
#[frb(sync)]
pub fn search_in_range(
    instance: &RopeInstance,
    pattern: String,
    start_line: usize,
    end_line: usize,
    case_sensitive: bool,
    is_regex: bool,
) -> Vec<usize> {
    let state = instance.get_state().read();
    let total_lines = rope_len_lines(&state.rope);
    let start_line = start_line.min(total_lines);
    let end_line = end_line.min(total_lines);
    if start_line >= end_line || pattern.is_empty() { return Vec::new(); }

    let start_byte = line_to_byte(&state.rope, start_line);
    let end_byte = if end_line >= total_lines {
        state.rope.summary().len
    } else {
        line_to_byte(&state.rope, end_line)
    };

    let range_text = state.rope.slice(start_byte..end_byte).to_string();
    let regex_pattern = if is_regex { pattern } else { regex::escape(&pattern) };
    let re = RegexBuilder::new(&regex_pattern)
        .case_insensitive(!case_sensitive)
        .build();
    let mut results = Vec::new();
    if let Ok(re) = re {
        for mat in re.find_iter(&range_text) {
            results.push(byte_to_utf16(&state.rope, start_byte + mat.start()));
            results.push(byte_to_utf16(&state.rope, start_byte + mat.end()));
        }
    }
    results
}

// ============================================================================
// 7. Character Class Queries (Word Navigation)
// ============================================================================

/// Character classification for word boundary detection.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CharClass {
    /// Whitespace characters (space, tab, newline, etc.)
    Whitespace,
    /// Word characters (letters, digits, underscore)
    Word,
    /// Punctuation and symbols
    Punctuation,
    /// Line ending (specifically \n or \r)
    LineEnding,
}

impl CharClass {
    fn from_char(c: char) -> Self {
        if c == '\n' || c == '\r' {
            CharClass::LineEnding
        } else if c.is_whitespace() {
            CharClass::Whitespace
        } else if c.is_alphanumeric() || c == '_' {
            CharClass::Word
        } else {
            CharClass::Punctuation
        }
    }
}

/// Get the character class at a UTF-16 offset.
/// Returns 0=Whitespace, 1=Word, 2=Punctuation, 3=LineEnding
#[frb(sync)]
pub fn char_class_at(instance: &RopeInstance, offset_utf16: usize) -> u8 {
    let state = instance.get_state().read();
    let byte_offset = utf16_to_byte(&state.rope, offset_utf16);
    if byte_offset >= state.rope.summary().len { return 0; }
    let ch = char_at_byte(&state.rope, byte_offset);
    match CharClass::from_char(ch) {
        CharClass::Whitespace => 0,
        CharClass::Word => 1,
        CharClass::Punctuation => 2,
        CharClass::LineEnding => 3,
    }
}

#[frb(sync)]
pub fn find_word_boundary(instance: &RopeInstance, offset_utf16: usize, forward: bool) -> usize {
    let state = instance.get_state().read();
    let total_bytes = state.rope.summary().len;
    let start_byte = utf16_to_byte(&state.rope, offset_utf16).min(total_bytes);
    if forward {
        find_word_boundary_forward(&state.rope, start_byte)
    } else {
        find_word_boundary_backward(&state.rope, start_byte)
    }
}

fn find_word_boundary_forward(rope: &Rope, start_byte: usize) -> usize {
    let total_bytes = rope.summary().len;
    if start_byte >= total_bytes {
        return rope.summary().len_utf16.0;
    }
    let start_class = CharClass::from_char(char_at_byte(rope, start_byte));
    let mut pos = start_byte;
    for ch in rope.chars_at(start_byte) {
        if CharClass::from_char(ch) != start_class || CharClass::from_char(ch) == CharClass::LineEnding {
            break;
        }
        pos += ch.len_utf8();
    }
    if pos < total_bytes {
        for ch in rope.chars_at(pos) {
            let class = CharClass::from_char(ch);
            if class == CharClass::Word || class == CharClass::LineEnding {
                break;
            }
            pos += ch.len_utf8();
        }
    }
    byte_to_utf16(rope, pos)
}

fn find_word_boundary_backward(rope: &Rope, start_byte: usize) -> usize {
    if start_byte == 0 { return 0; }
    let mut pos = start_byte.min(rope.summary().len);

    // Skip backward over whitespace and punctuation before the cursor.
    while pos > 0 {
        let window_start = rope.clip_offset(pos.saturating_sub(4), crate::zed_sum_tree::Bias::Right);
        let text: String = rope.chunks_in_range(window_start..pos).collect();
        let ch = text.chars().next_back().unwrap_or('\0');
        let class = CharClass::from_char(ch);
        if class == CharClass::Word || class == CharClass::LineEnding {
            break;
        }
        pos -= ch.len_utf8();
    }

    // Skip backward over word characters to find the start of the previous word.
    while pos > 0 {
        let window_start = rope.clip_offset(pos.saturating_sub(4), crate::zed_sum_tree::Bias::Right);
        let text: String = rope.chunks_in_range(window_start..pos).collect();
        let ch = text.chars().next_back().unwrap_or('\0');
        if CharClass::from_char(ch) != CharClass::Word {
            break;
        }
        pos -= ch.len_utf8();
    }

    byte_to_utf16(rope, pos)
}

/// Helper to convert byte offset to UTF-16 offset (replaces char_to_utf16_offset)
#[inline]
fn char_to_utf16_offset(state: &EditorState, byte_offset: usize) -> usize {
    byte_to_utf16(&state.rope, byte_offset)
}

// ============================================================================
// 8. Byte Offset Support (LSP Compatibility)
// ============================================================================

#[frb(sync)]
pub fn utf16_to_byte_offset(instance: &RopeInstance, offset_utf16: usize) -> usize {
    let state = instance.get_state().read();
    utf16_to_byte(&state.rope, offset_utf16)
}

#[frb(sync)]
pub fn byte_to_utf16_offset_pub(instance: &RopeInstance, byte_offset: usize) -> usize {
    let state = instance.get_state().read();
    byte_to_utf16(&state.rope, byte_offset)
}

#[frb(sync)]
pub fn get_line_start_byte_offset(instance: &RopeInstance, line_index: usize) -> usize {
    let state = instance.get_state().read();
    let total_lines = rope_len_lines(&state.rope);
    let line_index = line_index.min(total_lines);
    line_to_byte(&state.rope, line_index)
}

#[frb(sync)]
pub fn line_column_to_byte_offset(instance: &RopeInstance, line: usize, column_utf16: usize) -> usize {
    let state = instance.get_state().read();
    let total_lines = rope_len_lines(&state.rope);
    if line >= total_lines { return state.rope.summary().len; }
    let line_start_byte = line_to_byte(&state.rope, line);
    let mut byte_in_line = 0usize;
    let mut utf16_count = 0;
    for ch in line_chars(&state.rope, line) {
        if utf16_count >= column_utf16 { break; }
        utf16_count += ch.len_utf16();
        byte_in_line += ch.len_utf8();
    }
    line_start_byte + byte_in_line
}

#[frb(sync)]
pub fn byte_offset_to_line_column(instance: &RopeInstance, byte_offset: usize) -> Vec<usize> {
    let state = instance.get_state().read();
    let byte_offset = byte_offset.min(state.rope.summary().len);
    let line = byte_to_line(&state.rope, byte_offset);
    let line_start_byte = line_to_byte(&state.rope, line);
    let mut utf16_column = 0;
    let mut pos = line_start_byte;
    for ch in state.rope.chars_at(line_start_byte) {
        if pos >= byte_offset { break; }
        pos += ch.len_utf8();
        utf16_column += ch.len_utf16();
    }
    vec![line, utf16_column]
}

// ============================================================================
// 9. Bidirectional Iteration
// ============================================================================

#[frb(sync)]
pub fn reversed_chars_at(instance: &RopeInstance, offset_utf16: usize, max_chars: usize) -> String {
    let state = instance.get_state().read();
    let end_byte = utf16_to_byte(&state.rope, offset_utf16);
    if end_byte == 0 { return String::new(); }
    // Conservative 4 bytes per char maximum
    let start_byte = state.rope.clip_offset(
        end_byte.saturating_sub(max_chars * 4),
        crate::zed_sum_tree::Bias::Right,
    );
    let text: String = state.rope.chunks_in_range(start_byte..end_byte).collect();
    text.chars().rev().collect()
}

#[frb(sync)]
pub fn reversed_text_in_range(instance: &RopeInstance, start_utf16: usize, end_utf16: usize) -> String {
    let state = instance.get_state().read();
    let start_byte = utf16_to_byte(&state.rope, start_utf16);
    let end_byte = utf16_to_byte(&state.rope, end_utf16);
    if start_byte >= end_byte { return String::new(); }
    let text: String = state.rope.chunks_in_range(start_byte..end_byte).collect();
    text.chars().rev().collect()
}

#[frb(sync)]
pub fn prev_line_start(instance: &RopeInstance, offset_utf16: usize) -> usize {
    let state = instance.get_state().read();
    let byte_offset = utf16_to_byte(&state.rope, offset_utf16);
    let current_line = byte_to_line(&state.rope, byte_offset);
    if current_line == 0 { return 0; }
    let prev_byte = line_to_byte(&state.rope, current_line - 1);
    byte_to_utf16(&state.rope, prev_byte)
}

#[frb(sync)]
pub fn next_line_start(instance: &RopeInstance, offset_utf16: usize) -> usize {
    let state = instance.get_state().read();
    let byte_offset = utf16_to_byte(&state.rope, offset_utf16);
    let current_line = byte_to_line(&state.rope, byte_offset);
    let total_lines = rope_len_lines(&state.rope);
    if current_line + 1 >= total_lines {
        return state.rope.summary().len_utf16.0;
    }
    let next_byte = line_to_byte(&state.rope, current_line + 1);
    byte_to_utf16(&state.rope, next_byte)
}

// ============================================================================
// 10. Batch Line Indent API
// ============================================================================

/// Line indent information.
pub struct LineIndentInfo {
    /// Number of leading tab characters.
    pub tabs: usize,
    /// Number of leading space characters.
    pub spaces: usize,
    /// Whether the line is blank (whitespace only).
    pub line_blank: bool,
}

/// Get line indentation info for a contiguous range of lines.
/// More efficient than calling getLineIndentation in a loop.
#[frb(sync)]
pub fn get_line_indents_range(instance: &RopeInstance, start_line: usize, end_line: usize) -> Vec<LineIndentInfo> {
    let state = instance.get_state().read();
    let total_lines = rope_len_lines(&state.rope);
    let start = start_line.min(total_lines);
    let end = end_line.min(total_lines);
    if start >= end { return Vec::new(); }
    (start..end).map(|line_idx| {
        let mut tabs = 0;
        let mut spaces = 0;
        let mut line_blank = true;
        for ch in line_chars(&state.rope, line_idx) {
            if ch == '\t' { tabs += 1; }
            else if ch == ' ' { spaces += 1; }
            else {
                if ch != '\n' && ch != '\r' { line_blank = false; }
                break;
            }
        }
        LineIndentInfo { tabs, spaces, line_blank }
    }).collect()
}

#[frb(sync)]
pub fn get_reversed_line_indents_range(instance: &RopeInstance, start_line: usize, end_line: usize) -> Vec<LineIndentInfo> {
    let state = instance.get_state().read();
    let total_lines = rope_len_lines(&state.rope);
    let start = start_line.min(total_lines);
    let end = end_line.min(total_lines);
    if start >= end { return Vec::new(); }
    (start..end).rev().map(|line_idx| {
        let mut tabs = 0;
        let mut spaces = 0;
        let mut line_blank = true;
        for ch in line_chars(&state.rope, line_idx) {
            if ch == '\t' { tabs += 1; }
            else if ch == ' ' { spaces += 1; }
            else {
                if ch != '\n' && ch != '\r' { line_blank = false; }
                break;
            }
        }
        LineIndentInfo { tabs, spaces, line_blank }
    }).collect()
}

// ============================================================================
// 11. Enhanced Search with Whole Word and Include/Exclude
// ============================================================================

/// Search result with additional metadata.
pub struct SearchMatch {
    pub start_utf16: usize,
    pub end_utf16: usize,
    pub line: usize,
}

/// Enhanced search with whole word matching.
/// Returns UTF-16 offsets as pairs [start, end, start, end, ...].
#[frb(sync)]
pub fn search_whole_word(
    instance: &RopeInstance,
    pattern: String,
    case_sensitive: bool,
    whole_word: bool,
) -> Vec<usize> {
    let state = instance.get_state().read();
    if pattern.is_empty() { return Vec::new(); }
    let full_text = state.rope.to_string();
    
    // Build regex pattern
    let escaped = regex::escape(&pattern);
    let regex_pattern = if whole_word {
        // Add word boundary assertions, but only if the pattern starts/ends with word chars
        let starts_with_word = pattern.chars().next()
            .map(|c| c.is_alphanumeric() || c == '_')
            .unwrap_or(false);
        let ends_with_word = pattern.chars().last()
            .map(|c| c.is_alphanumeric() || c == '_')
            .unwrap_or(false);
        
        let mut p = String::new();
        if starts_with_word {
            p.push_str(r"\b");
        }
        p.push_str(&escaped);
        if ends_with_word {
            p.push_str(r"\b");
        }
        p
    } else {
        escaped
    };
    
    let re = RegexBuilder::new(&regex_pattern)
        .case_insensitive(!case_sensitive)
        .build();
    
    let mut results = Vec::new();
    
    if let Ok(re) = re {
        for mat in re.find_iter(&full_text) {
            results.push(byte_to_utf16(&state.rope, mat.start()));
            results.push(byte_to_utf16(&state.rope, mat.end()));
        }
    }

    results
}

/// Search with include/exclude path patterns.
/// This version accepts line ranges and can skip certain regions.
#[frb(sync)]
pub fn search_with_ranges(
    instance: &RopeInstance,
    pattern: String,
    case_sensitive: bool,
    is_regex: bool,
    whole_word: bool,
    include_lines: Option<Vec<(usize, usize)>>,
    exclude_lines: Option<Vec<(usize, usize)>>,
) -> Vec<usize> {
    let state = instance.get_state().read();
    if pattern.is_empty() { return Vec::new(); }
    let total_lines = rope_len_lines(&state.rope);
    let base_pattern = if is_regex { pattern.clone() } else { regex::escape(&pattern) };
    let regex_pattern = if whole_word && !is_regex {
        let sw = pattern.chars().next().map(|c| c.is_alphanumeric() || c == '_').unwrap_or(false);
        let ew = pattern.chars().last().map(|c| c.is_alphanumeric() || c == '_').unwrap_or(false);
        let mut p = String::new();
        if sw { p.push_str(r"\b"); }
        p.push_str(&base_pattern);
        if ew { p.push_str(r"\b"); }
        p
    } else { base_pattern };
    let re = match RegexBuilder::new(&regex_pattern).case_insensitive(!case_sensitive).build() {
        Ok(r) => r,
        Err(_) => return Vec::new(),
    };
    let mut results = Vec::new();
    let search_ranges: Vec<(usize, usize)> = if let Some(includes) = include_lines {
        includes.into_iter().map(|(s, e)| (s.min(total_lines), e.min(total_lines))).collect()
    } else { vec![(0, total_lines)] };
    let exclude_set: std::collections::HashSet<usize> = exclude_lines
        .map(|excludes| excludes.into_iter().flat_map(|(s, e)| s..e).collect())
        .unwrap_or_default();
    for (sl, el) in search_ranges {
        for line_idx in sl..el {
            if exclude_set.contains(&line_idx) { continue; }
            let line_start_byte = line_to_byte(&state.rope, line_idx);
            let line_text: String = line_chars(&state.rope, line_idx).collect();
            for mat in re.find_iter(&line_text) {
                results.push(byte_to_utf16(&state.rope, line_start_byte + mat.start()));
                results.push(byte_to_utf16(&state.rope, line_start_byte + mat.end()));
            }
        }
    }
    results
}

// ============================================================================
// 12. Enhanced Metrics with Additional TextSummary Fields
// ============================================================================

/// Comprehensive text metrics matching Zed's TextSummary.
/// Note: renamed to avoid collision with zed_rope::TextSummary.
pub struct DocumentTextSummary {
    pub len: usize,
    pub chars: usize,
    pub len_utf16: usize,
    pub lines: usize,
    pub last_line_column: usize,
    pub first_line_chars: usize,
    pub last_line_chars: usize,
    pub last_line_len_utf16: usize,
    pub longest_row: usize,
    pub longest_row_chars: usize,
}

#[frb(sync)]
pub fn get_text_summary(instance: &RopeInstance) -> DocumentTextSummary {
    let state = instance.get_state().read();
    let s = state.rope.summary();
    let total_lines = s.lines.row as usize + 1;
    // last_line_column: byte length of last line excluding newline
    let last_line_start = line_to_byte(&state.rope, s.lines.row as usize);
    let last_line_column = s.len.saturating_sub(last_line_start);
    DocumentTextSummary {
        len: s.len,
        chars: s.chars,
        len_utf16: s.len_utf16.0,
        lines: total_lines,
        last_line_column,
        first_line_chars: s.first_line_chars as usize,
        last_line_chars: s.last_line_chars as usize,
        last_line_len_utf16: s.last_line_len_utf16 as usize,
        longest_row: s.longest_row as usize,
        longest_row_chars: s.longest_row_chars as usize,
    }
}

// ============================================================================
// 13. Point Utilities
// ============================================================================

#[frb(sync)]
pub fn offset_to_point(instance: &RopeInstance, offset_utf16: usize) -> Vec<usize> {
    let state = instance.get_state().read();
    let byte_offset = utf16_to_byte(&state.rope, offset_utf16);
    let p = state.rope.offset_to_point(byte_offset);
    vec![p.row as usize, p.column as usize]
}

#[frb(sync)]
pub fn point_to_offset(instance: &RopeInstance, row: usize, column_bytes: usize) -> usize {
    let state = instance.get_state().read();
    let p = Point::new(row as u32, column_bytes as u32);
    let byte_offset = state.rope.point_to_offset(p);
    byte_to_utf16(&state.rope, byte_offset)
}

#[frb(sync)]
pub fn clip_point(instance: &RopeInstance, row: usize, column_bytes: usize, bias: u8) -> Vec<usize> {
    let state = instance.get_state().read();
    let total_lines = rope_len_lines(&state.rope);
    if total_lines == 0 { return vec![0, 0]; }
    let clipped_row = row.min(total_lines.saturating_sub(1));
    let rope_bias = if bias == 0 { crate::zed_sum_tree::Bias::Left } else { crate::zed_sum_tree::Bias::Right };
    let clipped = state.rope.clip_point(
        Point::new(clipped_row as u32, column_bytes as u32),
        rope_bias,
    );
    vec![clipped.row as usize, clipped.column as usize]
}

// ============================================================================
// 14. HIGH-PERFORMANCE BATCH EDIT API
// ============================================================================
// These APIs are designed to minimize FFI overhead by combining multiple
// operations that are always performed together during text editing.

/// Result of a replace operation with all context needed for undo/redo and UI updates.
/// This eliminates the need for separate FFI calls to get deleted text, cursor position, etc.
pub struct EditResult {
    /// The text that was deleted (for undo recording).
    /// This is computed on the Rust side to avoid a separate substring() call.
    pub deleted_text: String,
    /// The new document length in UTF-16 code units.
    pub new_length: usize,
    /// The new cursor position in UTF-16 code units (start + replacement.len()).
    pub new_cursor: usize,
    /// The line number where the cursor now sits.
    pub cursor_line: usize,
    /// The column within the line (in UTF-16 code units).
    pub cursor_column: usize,
    /// Start offset of the current line (for IME projection).
    pub line_start_offset: usize,
    /// Length of the current line (excluding newline).
    pub line_length: usize,
    /// Whether the edit changed the number of lines in the document.
    pub line_count_changed: bool,
    /// The new line count.
    pub new_line_count: usize,
}

/// Combined replace operation that returns all edit context in a single FFI call.
/// 
/// This is the HIGH-PERFORMANCE replacement for the pattern:
///   deletedText = rope.substring(start, end);  // FFI call 1 - EXPENSIVE
///   rope.replace(start, end, text);            // FFI call 2
///   line = rope.getLineAtOffset(newCursor);    // FFI call 3 - EXPENSIVE
///   
/// Now becomes:
///   result = rope.replaceAndCapture(start, end, text);  // Single FFI call
///
/// Performance impact: Eliminates ~82% of CPU time spent in FFI calls during typing.
#[frb(sync)]
pub fn replace_and_capture(
    instance: &RopeInstance,
    start_utf16: usize,
    end_utf16: usize,
    text: String
) -> EditResult {
    let mut state = instance.get_state().write();
    let old_line_count = rope_len_lines(&state.rope);
    let start_byte = utf16_to_byte(&state.rope, start_utf16);
    let end_byte = utf16_to_byte(&state.rope, end_utf16);

    // Capture deleted text BEFORE modifying the rope
    let deleted_text = if start_byte < end_byte {
        state.rope.slice(start_byte..end_byte).to_string()
    } else {
        String::new()
    };

    // Perform the edit atomically
    state.rope.replace(start_byte..end_byte, &text);

    // All metrics are now up-to-date automatically (no rebuild needed!)
    let new_cursor_byte = start_byte + text.len();
    let new_cursor = byte_to_utf16(&state.rope, new_cursor_byte);
    let cursor_point = state.rope.offset_to_point(new_cursor_byte);
    let cursor_line = cursor_point.row as usize;
    let line_start_byte = line_to_byte(&state.rope, cursor_line);
    let line_start_offset = byte_to_utf16(&state.rope, line_start_byte);
    let cursor_column = new_cursor.saturating_sub(line_start_offset);

    // Line length in UTF-16 (excluding newline)
    let line_length: usize = line_chars(&state.rope, cursor_line)
        .filter(|&c| c != '\n' && c != '\r')
        .map(|c| c.len_utf16())
        .sum();

    let new_line_count = rope_len_lines(&state.rope);
    let new_length = state.rope.summary().len_utf16.0;

    EditResult {
        deleted_text,
        new_length,
        new_cursor,
        cursor_line,
        cursor_column,
        line_start_offset,
        line_length,
        line_count_changed: old_line_count != new_line_count,
        new_line_count,
    }
}

/// Cursor context returned by get_cursor_context.
/// Provides all information needed for cursor positioning in a single FFI call.
pub struct CursorContext {
    /// The 0-based line index.
    pub line: usize,
    /// The column within the line in UTF-16 code units.
    pub column: usize,
    /// UTF-16 offset where the current line starts.
    pub line_start_offset: usize,
    /// UTF-16 offset where the current line ends (before newline).
    pub line_end_offset: usize,
    /// Length of the current line in UTF-16 code units (excluding newline).
    pub line_length: usize,
    /// Total number of lines in the document.
    pub total_lines: usize,
    /// Total document length in UTF-16 code units.
    pub total_length: usize,
}

/// Get complete cursor context in a single FFI call.
/// Replaces multiple calls to getLineAtOffset(), getLineStartOffset(), etc.
/// 
/// This is the HIGH-PERFORMANCE replacement for the pattern:
///   line = rope.getLineAtOffset(offset);       // FFI call 1
///   lineStart = rope.getLineStartOffset(line); // FFI call 2
///   column = offset - lineStart;               // computation
///   
/// Now becomes:
///   ctx = rope.getCursorContext(offset);       // Single FFI call
#[frb(sync)]
pub fn get_cursor_context(instance: &RopeInstance, offset_utf16: usize) -> CursorContext {
    let state = instance.get_state().read();
    let byte_offset = utf16_to_byte(&state.rope, offset_utf16);
    let p = state.rope.offset_to_point(byte_offset);
    let line = p.row as usize;
    let line_start_byte = line_to_byte(&state.rope, line);
    let line_start_offset = byte_to_utf16(&state.rope, line_start_byte);
    let column = offset_utf16.saturating_sub(line_start_offset);
    let total_lines = rope_len_lines(&state.rope);
    let line_end_offset = if line + 1 < total_lines {
        let next_byte = line_to_byte(&state.rope, line + 1);
        byte_to_utf16(&state.rope, next_byte).saturating_sub(1)
    } else {
        state.rope.summary().len_utf16.0
    };
    let line_length = line_end_offset.saturating_sub(line_start_offset);
    let total_length = state.rope.summary().len_utf16.0;
    CursorContext {
        line,
        column,
        line_start_offset,
        line_end_offset,
        line_length,
        total_lines,
        total_length,
    }
}

// ============================================================================
// 15. IME PROJECTION CACHE
// ============================================================================
// IME systems require a "window" of text around the cursor. Instead of 
// copying this text on every keystroke, we cache it in Rust and only
// return new text when the window actually needs to shift.

/// IME projection window state.
pub struct ImeProjection {
    /// Whether a new window was computed (false means use cached).
    pub window_changed: bool,
    /// Start offset of the window in the document (UTF-16).
    pub window_start: usize,
    /// The text content of the window (empty if window_changed is false).
    pub text: String,
    /// Selection base offset relative to window_start.
    pub selection_base: usize,
    /// Selection extent offset relative to window_start.
    pub selection_extent: usize,
}

/// Get or update the IME projection window.
/// 
/// This is a SMART API that:
/// 1. Checks if the cursor is still within the cached window
/// 2. Only extracts text if the window needs to shift
/// 3. Returns an empty string if the cached window is still valid
///
/// Parameters:
/// - caret_offset: Current cursor position in UTF-16
/// - selection_base: Selection start in UTF-16  
/// - selection_extent: Selection end in UTF-16
/// - max_window_size: Maximum window size (typically 4000 chars)
/// - cached_window_start: The start of the previously cached window
/// - cached_window_end: The end of the previously cached window
///
/// Returns ImeProjection with window_changed=false if cache is still valid.
#[frb(sync)]
pub fn get_ime_projection(
    instance: &RopeInstance,
    caret_offset: usize,
    selection_base: usize,
    selection_extent: usize,
    max_window_size: usize,
    cached_window_start: usize,
    cached_window_end: usize,
) -> ImeProjection {
    let state = instance.get_state().read();
    let doc_length = state.rope.summary().len_utf16.0;
    let caret = caret_offset.min(doc_length);

    let margin = max_window_size / 4;
    let in_safe_zone = caret >= cached_window_start.saturating_add(margin)
        && caret + margin <= cached_window_end
        && cached_window_end <= doc_length;

    if in_safe_zone && cached_window_end > cached_window_start {
        return ImeProjection {
            window_changed: false,
            window_start: cached_window_start,
            text: String::new(),
            selection_base: selection_base.saturating_sub(cached_window_start),
            selection_extent: selection_extent.saturating_sub(cached_window_start),
        };
    }

    let half_window = max_window_size / 2;
    let new_start = caret.saturating_sub(half_window);
    let new_end = (new_start + max_window_size).min(doc_length);

    // O(log n) byte offset lookup — this is the fix!
    let start_byte = utf16_to_byte(&state.rope, new_start);
    let end_byte = utf16_to_byte(&state.rope, new_end);
    let text = state.rope.slice(start_byte..end_byte).to_string();

    ImeProjection {
        window_changed: true,
        window_start: new_start,
        text,
        selection_base: selection_base.saturating_sub(new_start).min(new_end - new_start),
        selection_extent: selection_extent.saturating_sub(new_start).min(new_end - new_start),
    }
}

#[frb(sync)]
pub fn is_ime_window_valid(
    instance: &RopeInstance,
    caret_offset: usize,
    max_window_size: usize,
    cached_window_start: usize,
    cached_window_end: usize,
) -> bool {
    let state = instance.get_state().read();
    let doc_length = state.rope.summary().len_utf16.0;
    let margin = max_window_size / 4;
    caret_offset >= cached_window_start.saturating_add(margin)
        && caret_offset + margin <= cached_window_end
        && cached_window_end <= doc_length
}

#[cfg(test)]
mod word_boundary_tests {
    use super::*;

    #[test]
    fn forward_skips_punctuation_between_words() {
        let instance = RopeInstance::new("one two_three, four".to_string());
        assert_eq!(find_word_boundary(&instance, 0, true), 4);
        assert_eq!(find_word_boundary(&instance, 4, true), 15);
        assert_eq!(find_word_boundary(&instance, 15, true), 19);
    }

    #[test]
    fn backward_finds_previous_word_starts() {
        let instance = RopeInstance::new("one two_three, four".to_string());
        assert_eq!(find_word_boundary(&instance, 19, false), 15);
        assert_eq!(find_word_boundary(&instance, 15, false), 4);
        assert_eq!(find_word_boundary(&instance, 4, false), 0);
    }
}