//! Edit translation adapted from yoyo-evolve/src/smart_edit.rs.
//!
//! Parses model output into rope [EditorAction] batches.

use crate::api::{EditorAction, EditorActionKind, RangeContext};

/// Strip markdown code fences and optional <<EDIT>> sentinel from model output.
pub fn parse_model_output(raw: &str) -> String {
    let mut text = raw.trim().to_string();
    if let Some(idx) = text.find("<<EDIT>>") {
        text = text[idx + "<<EDIT>>".len()..].trim().to_string();
    }
    if let Some(block) = extract_first_fenced_block(&text) {
        return strip_markdown_emphasis(&block);
    }
    strip_markdown_emphasis(&strip_markdown_fences(&text))
}

fn strip_markdown_emphasis(text: &str) -> String {
    let mut result = text.to_string();
    for delimiter in ["**", "__"] {
        result = strip_delimited_pairs(&result, delimiter);
    }
    result
}

fn strip_delimited_pairs(text: &str, delimiter: &str) -> String {
    if delimiter.is_empty() || !text.contains(delimiter) {
        return text.to_string();
    }

    let mut buffer = String::new();
    let mut index = 0;
    let delim_len = delimiter.len();

    while index < text.len() {
        let Some(start) = text[index..].find(delimiter) else {
            buffer.push_str(&text[index..]);
            break;
        };
        let start = index + start;
        buffer.push_str(&text[index..start]);

        let content_start = start + delim_len;
        let Some(rel_end) = text[content_start..].find(delimiter) else {
            buffer.push_str(&text[start..]);
            break;
        };
        let end = content_start + rel_end;
        buffer.push_str(&text[content_start..end]);
        index = end + delim_len;
    }

    buffer
}

/// Pull the first fenced code block from anywhere in the model output.
fn extract_first_fenced_block(text: &str) -> Option<String> {
    let start = text.find("```")?;
    let after_open = &text[start + 3..];
    let body_start = after_open.find('\n').map(|i| i + 1).unwrap_or(0);
    let body = &after_open[body_start..];
    let end = body.find("```")?;
    Some(body[..end].trim().to_string())
}

/// Conversational text before an edit marker or code fence.
pub fn extract_repl_message(raw: &str) -> String {
    if let Some(idx) = raw.find("<<EDIT>>") {
        return raw[..idx].trim().to_string();
    }
    if let Some(idx) = raw.find("```") {
        return raw[..idx].trim().to_string();
    }
    String::new()
}

/// Best-effort replacement text for an explicit edit request.
pub fn extract_edit_replacement(raw: &str, selected: &str) -> String {
    let parsed = parse_model_output(raw);
    if !parsed.trim().is_empty()
        && normalize_whitespace(&parsed) != normalize_whitespace(selected)
    {
        return parsed;
    }
    raw.trim().to_string()
}

fn strip_markdown_fences(text: &str) -> String {
    let trimmed = text.trim();
    if !trimmed.starts_with("```") {
        return trimmed.to_string();
    }
    let without_open = trimmed
        .strip_prefix("```")
        .unwrap_or(trimmed)
        .trim_start();
    let language_split = without_open.find('\n').unwrap_or(0);
    let body = if language_split > 0 && language_split < 20 {
        &without_open[language_split + 1..]
    } else {
        without_open
    };
    body.trim_end()
        .strip_suffix("```")
        .unwrap_or(body)
        .trim()
        .to_string()
}

/// Normalize whitespace for fuzzy comparison (smart_edit analogue).
pub fn normalize_whitespace(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Build a single replace action for the current selection.
pub fn build_replace_action(context: &RangeContext, replacement: &str) -> EditorAction {
    EditorAction {
        kind: EditorActionKind::Replace,
        start_utf16: context.start_utf16,
        end_utf16: context.end_utf16,
        text: replacement.to_string(),
    }
}

pub fn build_replace_actions(context: &RangeContext, replacement: &str) -> Vec<EditorAction> {
    let trimmed = replacement.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }
    if normalize_whitespace(trimmed) == normalize_whitespace(&context.selected_text) {
        return Vec::new();
    }
    vec![build_replace_action(context, trimmed)]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_fences_and_sentinel() {
        let raw = "thinking...\n<<EDIT>>\n```rust\nfn main() {}\n```";
        assert_eq!(parse_model_output(raw), "fn main() {}");
    }

    #[test]
    fn strips_markdown_emphasis_from_replacement() {
        let raw = "<<EDIT>>\nThe **bar** also celebrated";
        assert_eq!(parse_model_output(raw), "The bar also celebrated");
    }

    #[test]
    fn unchanged_selection_yields_no_actions() {
        let ctx = RangeContext {
            start_utf16: 0,
            end_utf16: 3,
            selected_text: "foo".into(),
            context_before: String::new(),
            context_after: String::new(),
            context_lines: String::new(),
            start_line: 0,
            end_line: 0,
            total_lines: 1,
            total_length: 3,
            related_files: Vec::new(),
        };
        assert!(build_replace_actions(&ctx, "foo").is_empty());
    }
}
