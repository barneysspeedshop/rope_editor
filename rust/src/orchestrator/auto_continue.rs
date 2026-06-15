//! Auto-continue heuristics adapted from yoyo-evolve/src/repl.rs.

const MAX_AUTO_CONTINUES: usize = 3;

pub fn max_auto_continues() -> usize {
    MAX_AUTO_CONTINUES
}

pub fn build_continue_prompt(partial: &str) -> String {
    format!(
        "Continue the previous response exactly where you left off.\n\
         Do not repeat any content already provided.\n\
         Output only the continuation text.\n\n\
         Partial output so far:\n\
         ---\n\
         {partial}\n\
         ---\n\n\
         Continue:"
    )
}

/// Returns true when model output likely stopped mid-work (repl.rs `looks_incomplete`).
pub fn looks_incomplete(text: &str) -> bool {
    let text = text.trim();
    if text.is_empty() || text.len() < 20 {
        return false;
    }

    // Unclosed markdown / code fences.
    if text.matches("```").count() % 2 == 1 {
        return true;
    }

    // Unbalanced braces in code-like output.
    if looks_like_truncated_code(text) {
        return true;
    }

    let tail_start = safe_byte_index(text, text.len().saturating_sub(300));
    let tail_lower = text[tail_start..].to_lowercase();

    let continuation_phrases = [
        "next, i'll",
        "next i'll",
        "i'll now ",
        "let me continue",
        "let me proceed",
        "i'll continue",
        "moving on to",
        "now i'll",
        "i still need to",
    ];
    for phrase in &continuation_phrases {
        if tail_lower.contains(phrase) {
            return true;
        }
    }

    if (text.ends_with("...") || text.ends_with('…'))
        && (tail_lower.contains("remaining")
            || tail_lower.contains("need to")
            || tail_lower.contains("let me ")
            || tail_lower.contains("continue"))
    {
        return true;
    }

    false
}

fn looks_like_truncated_code(text: &str) -> bool {
    let open = text.chars().filter(|&c| c == '{' || c == '(' || c == '[').count();
    let close = text.chars().filter(|&c| c == '}' || c == ')' || c == ']').count();
    if open > close && text.contains('{') {
        return true;
    }
    false
}

fn safe_byte_index(text: &str, byte_index: usize) -> usize {
    if byte_index >= text.len() {
        return text.len();
    }
    let mut index = byte_index;
    while index > 0 && !text.is_char_boundary(index) {
        index -= 1;
    }
    index
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_unclosed_fence() {
        assert!(looks_incomplete("fn main() {\n```rust\nfn foo() {"));
    }

    #[test]
    fn complete_block_is_not_incomplete() {
        assert!(!looks_incomplete("fn main() {\n  ok();\n}"));
    }
}
