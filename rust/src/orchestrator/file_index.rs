//! Open-file indexing adapted from yoyo-evolve/src/context.rs patterns.
//!
//! Summarizes in-scope files for prompt injection without loading whole projects.

use crate::api::FileReference;

use super::truncate::{smart_truncate_for_context, MAX_CONTEXT_LINES};

/// Maximum open files included in agent context (yoyo `MAX_RECENT_FILES` analogue).
pub const MAX_CONTEXT_FILES: usize = 12;

/// Maximum snippet length per non-active file reference.
pub const MAX_SNIPPET_CHARS: usize = 512;

/// Maximum snippet length for the active in-scope file (file-context mode).
pub const MAX_ACTIVE_SNIPPET_CHARS: usize = 32768;

/// Prepares and caps the file list from the IDE request (active file first).
pub fn prepare_context_files(
    open_files: &[FileReference],
    active_path: &str,
) -> Vec<FileReference> {
    let mut files: Vec<FileReference> = open_files
        .iter()
        .cloned()
        .map(|mut f| {
            f.snippet = trim_snippet(&f.snippet, f.is_active);
            f
        })
        .collect();

    files.sort_by(|a, b| {
        b.is_active
            .cmp(&a.is_active)
            .then_with(|| a.path.cmp(&b.path))
    });
    files.dedup_by(|a, b| a.path == b.path);
    files.truncate(MAX_CONTEXT_FILES);

    // Ensure active file appears even if Dart omitted the flag.
    if !active_path.is_empty()
        && !files.iter().any(|f| f.path == active_path && f.is_active)
    {
        if let Some(pos) = files.iter().position(|f| f.path == active_path) {
            files[pos].is_active = true;
            files.sort_by(|a, b| b.is_active.cmp(&a.is_active));
        }
    }

    files
}

fn trim_snippet(snippet: &str, is_active: bool) -> String {
    if is_active {
        return trim_active_snippet(snippet);
    }
    let max_chars = MAX_SNIPPET_CHARS;
    let trimmed: String = snippet.chars().take(max_chars).collect();
    if snippet.chars().count() > max_chars {
        format!("{trimmed}…")
    } else {
        trimmed
    }
}

/// Active file: line-based head+tail truncation, then char cap as a safety net.
fn trim_active_snippet(snippet: &str) -> String {
    let (mut text, _, _) = smart_truncate_for_context(snippet, MAX_CONTEXT_LINES);
    if text.chars().count() > MAX_ACTIVE_SNIPPET_CHARS {
        let trimmed: String = text.chars().take(MAX_ACTIVE_SNIPPET_CHARS).collect();
        text = format!("{trimmed}…");
    }
    text
}

/// Human-readable message for the agent console (Context Window Update).
pub fn context_window_message(files: &[FileReference]) -> String {
    if files.is_empty() {
        return "Context window: active file only.".into();
    }
    let mut lines = vec!["Context window — reading:".to_string()];
    for file in files {
        let marker = if file.is_active { " (active)" } else { "" };
        lines.push(format!(
            "  • {}{} [hash {}]",
            file.path, marker, file.content_hash
        ));
    }
    lines.join("\n")
}

/// True when the active editor file is listed in the scoped open-file set.
pub fn active_file_in_scope(open_files: &[FileReference], active_path: &str) -> bool {
    if open_files.is_empty() {
        return false;
    }
    open_files
        .iter()
        .any(|file| file.is_active || file.path == active_path)
}

/// Collapsed selection with the active file explicitly in scope.
pub fn is_file_context_mode(
    context: &crate::api::RangeContext,
    request: &crate::api::OrchestrateRequest,
    active_path: &str,
) -> bool {
    context.selected_text.is_empty()
        && request.end_utf16 <= request.start_utf16
        && active_file_in_scope(&request.open_files, active_path)
}

pub(crate) fn format_selection_section(context: &crate::api::RangeContext, file_context: bool) -> String {
    if !context.selected_text.is_empty() {
        return context.selected_text.clone();
    }
    if file_context {
        return "(no text selected — active file content is provided in the sections below)"
            .into();
    }
    if !context.context_lines.trim().is_empty() {
        return "(no text selected — surrounding file context is provided below)".into();
    }
    "(empty selection)".into()
}

/// Prompt section listing related open files and snippets.
pub fn format_related_files_section(files: &[FileReference]) -> String {
    if files.is_empty() {
        return String::new();
    }
    let mut out = String::from("## Open files in scope\n\n");
    for file in files {
        out.push_str(&format!(
            "### {}{}\nContent hash: {}\n```\n{}\n```\n\n",
            file.path,
            if file.is_active { " (active)" } else { "" },
            file.content_hash,
            file.snippet,
        ));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn caps_and_dedupes_files() {
        let mut files = Vec::new();
        for i in 0..20 {
            files.push(FileReference {
                path: format!("file_{i}.rs"),
                snippet: "fn main() {}".into(),
                content_hash: i as i64,
                is_active: i == 0,
            });
        }
        files.push(FileReference {
            path: "file_0.rs".into(),
            snippet: "dup".into(),
            content_hash: 99,
            is_active: true,
        });
        let prepared = prepare_context_files(&files, "file_0.rs");
        assert!(prepared.len() <= MAX_CONTEXT_FILES);
        assert!(!prepared.iter().any(|f| f.path == "file_0.rs" && f.content_hash == 99));
    }
}
