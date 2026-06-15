//! Token estimation and context budget (yoyo-evolve ~4 bytes/token heuristic).

use crate::api::AgentContextBudget;

/// Default context window when the caller does not specify one.
pub const DEFAULT_CONTEXT_WINDOW: u32 = 32_768;

/// Approximate tokens from text length (~4 bytes per token for code/English).
pub fn estimate_tokens(text: &str) -> u32 {
    (text.len() / 4) as u32
}

/// Warning tier from usage percentage.
pub fn warning_level(usage_percent: u32) -> String {
    match usage_percent {
        0..=59 => "ok".into(),
        60..=79 => "warn".into(),
        80..=89 => "high".into(),
        _ => "critical".into(),
    }
}

pub fn build_budget(
    prompt_text: &str,
    transcript_tokens: u32,
    context_window: u32,
) -> AgentContextBudget {
    let prompt_tokens = estimate_tokens(prompt_text);
    let total = prompt_tokens.saturating_add(transcript_tokens);
    let window = context_window.max(1);
    let usage_percent = ((total as u64 * 100) / window as u64).min(100) as u32;

    AgentContextBudget {
        prompt_tokens,
        transcript_tokens,
        total_tokens: total,
        context_window: window,
        usage_percent,
        warning_level: warning_level(usage_percent),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn estimate_empty_is_zero() {
        assert_eq!(estimate_tokens(""), 0);
    }

    #[test]
    fn warning_thresholds() {
        assert_eq!(warning_level(50), "ok");
        assert_eq!(warning_level(60), "warn");
        assert_eq!(warning_level(80), "high");
        assert_eq!(warning_level(95), "critical");
    }

    #[test]
    fn budget_sums_prompt_and_transcript() {
        let budget = build_budget(&"x".repeat(400), 100, 1000);
        assert_eq!(budget.prompt_tokens, 100);
        assert_eq!(budget.transcript_tokens, 100);
        assert_eq!(budget.total_tokens, 200);
        assert_eq!(budget.usage_percent, 20);
        assert_eq!(budget.warning_level, "ok");
    }
}
