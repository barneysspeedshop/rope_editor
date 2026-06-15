//! Smart head+tail truncation for large file snippets (yoyo-evolve parity).

/// Default max lines before head+tail truncation kicks in.
pub const MAX_CONTEXT_LINES: usize = 500;

/// Returns `(truncated_text, was_truncated, original_line_count)`.
pub fn smart_truncate_for_context(content: &str, max_lines: usize) -> (String, bool, usize) {
    let lines: Vec<&str> = content.lines().collect();
    let total = lines.len();

    if total <= max_lines {
        return (content.to_string(), false, total);
    }

    // 40% head, 20% tail — more context at the top (imports, types, structs).
    let head_count = (max_lines * 2) / 5;
    let tail_count = (max_lines / 5).min(total.saturating_sub(head_count));
    let omitted = total.saturating_sub(head_count + tail_count);

    let mut result = String::new();
    for line in &lines[..head_count] {
        result.push_str(line);
        result.push('\n');
    }
    result.push_str(&format!(
        "\n[... {omitted} lines omitted ({total} total) — select a range or use @file:start-end ...]\n\n"
    ));
    if tail_count > 0 {
        for (i, line) in lines[total - tail_count..].iter().enumerate() {
            result.push_str(line);
            if i < tail_count - 1 {
                result.push('\n');
            }
        }
    }

    (result, true, total)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn small_content_unchanged() {
        let text = "line one\nline two\n";
        let (out, truncated, total) = smart_truncate_for_context(text, 500);
        assert!(!truncated);
        assert_eq!(total, 2);
        assert_eq!(out, text);
    }

    #[test]
    fn large_content_keeps_head_and_tail() {
        let lines: String = (0..800)
            .map(|i| format!("fn function_{i}() {{}}\n"))
            .collect();
        let (out, truncated, total) = smart_truncate_for_context(&lines, 500);
        assert!(truncated);
        assert_eq!(total, 800);
        assert!(out.contains("function_0"));
        assert!(out.contains("function_799"));
        assert!(out.contains("lines omitted"));
        assert!(!out.contains("function_400"));
    }
}
