//! Intent routing adapted from yoyo-evolve/src/dispatch.rs.
//!
//! Natural language is classified as edit, question/advice, ambiguous, or chat.

/// High-level intent for the IDE agent orchestrator.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AgentIntent {
    /// Produce a replacement edit for the current selection.
    ApplyEdit { instruction: String },
    /// Explain or summarize without mutating the document.
    Summarize { instruction: String },
    /// REPL chat response for the agent console (default for natural language).
    Clarify { instruction: String },
    /// User intent is unclear — ask whether they want an edit or an answer.
    Disambiguate { instruction: String },
    /// Built-in help text (no LLM call).
    Help,
    /// Unknown slash command — surface an error to the user.
    UnknownSlash { command: String },
}

const EDIT_VERBS: &[&str] = &[
    "edit",
    "replace",
    "rewrite",
    "refactor",
    "fix",
    "change",
    "update",
    "modify",
    "implement",
    "patch",
    "convert",
    "rename",
    "insert",
    "delete",
    "remove",
    "apply",
    "add",
    "append",
    "complete",
    "finish",
    "continue",
    "extend",
    "expand",
    "create",
    "generate",
    "build",
    "shorten",
    "trim",
    "modernize",
    "simplify",
    "clean up",
    "clean this",
];

const EDIT_PHRASES: &[&str] = &[
    "turn this into",
    "make this",
    "make the",
    "make it",
    "write ",
    "new line",
    "another line",
    "second line",
    "third line",
    "first line",
    "line 1",
    "line 2",
    "line 3",
    "continue the story",
    "continue writing",
    "next line",
    "following line",
];

const POLITE_EDIT_PREFIXES: &[&str] = &[
    "can you ",
    "could you ",
    "would you ",
    "please ",
    "i need you to ",
    "i want you to ",
];

const ADVICE_QUESTION_STARTS: &[&str] = &[
    "what ",
    "why ",
    "how do i ",
    "how should i ",
    "how can i ",
    "how would i ",
    "when should i ",
    "where should i ",
    "should i ",
    "is it ",
    "is this ",
    "is there ",
    "are there ",
    "what is ",
    "what are ",
    "what does ",
    "what would ",
    "why is ",
    "why does ",
    "why would ",
    "do you think ",
    "any advice",
    "any suggestions",
    "any recommendations",
    "your thoughts",
    "your opinion",
    "help me understand",
    "help me decide",
    "tell me about",
    "tell me how",
    "pros and cons",
];

const ADVICE_PHRASES: &[&str] = &[
    "what do you think",
    "recommend ",
    "suggest whether",
    "explain ",
    "describe ",
    "compare ",
];

const AMBIGUOUS_EDIT_PHRASES: &[&str] = &[
    "improve ",
    "better ",
    "cleaner ",
    "nicer ",
    "optimize ",
    "polish ",
    "enhance ",
    "tweak ",
    "adjust ",
    "fix it",
    "change it",
    "update it",
];

fn contains_word(lower: &str, word: &str) -> bool {
    if word.contains(' ') {
        return lower.contains(word);
    }
    lower
        .split(|c: char| !c.is_alphanumeric() && c != '_')
        .any(|token| token == word)
}

fn contains_any(lower: &str, phrases: &[&str]) -> bool {
    phrases.iter().any(|phrase| {
        if phrase.contains(' ') {
            lower.contains(phrase)
        } else {
            contains_word(lower, phrase)
        }
    })
}

fn starts_with_any(lower: &str, prefixes: &[&str]) -> bool {
    prefixes.iter().any(|prefix| lower.starts_with(prefix))
}

/// Returns true when the user explicitly asked for a document edit.
fn looks_like_edit_request(input: &str) -> bool {
    let lower = input.to_lowercase();
    if contains_any(&lower, EDIT_VERBS) || contains_any(&lower, EDIT_PHRASES) {
        return true;
    }
    starts_with_any(&lower, &["make ", "write "])
        || lower.contains("please edit")
        || lower.contains("can you edit")
        || lower.contains("could you edit")
}

fn is_polite_edit_request(input: &str) -> bool {
    let lower = input.to_lowercase();
    if !starts_with_any(&lower, POLITE_EDIT_PREFIXES) {
        return false;
    }
    looks_like_edit_request(input)
}

/// Returns true when the user is asking a question or seeking advice (not an edit).
fn looks_like_question_or_advice(input: &str) -> bool {
    let trimmed = input.trim();
    let lower = trimmed.to_lowercase();

    if is_polite_edit_request(trimmed) {
        return false;
    }

    if trimmed.ends_with('?') {
        return true;
    }

    if starts_with_any(&lower, ADVICE_QUESTION_STARTS) {
        return true;
    }

    if contains_any(&lower, ADVICE_PHRASES) && !looks_like_edit_request(trimmed) {
        return true;
    }

    false
}

/// Weak edit signals where the user might want advice instead of a document change.
fn looks_like_ambiguous_edit(input: &str) -> bool {
    let lower = input.to_lowercase();
    contains_any(&lower, AMBIGUOUS_EDIT_PHRASES)
}

fn has_strong_advice_signal(input: &str) -> bool {
    let trimmed = input.trim();
    let lower = trimmed.to_lowercase();
    if trimmed.ends_with('?') && !is_polite_edit_request(trimmed) {
        return true;
    }
    starts_with_any(
        &lower,
        &[
            "how do i ",
            "how should i ",
            "how can i ",
            "how would i ",
            "what should i ",
            "when should i ",
            "where should i ",
            "should i ",
            "is it better ",
            "would it be ",
            "do you think ",
            "what do you think",
        ],
    )
}

fn route_natural_language(input: &str) -> AgentIntent {
    let trimmed = input.trim();
    if has_strong_advice_signal(trimmed) {
        return AgentIntent::Clarify {
            instruction: trimmed.to_string(),
        };
    }
    if is_polite_edit_request(trimmed) {
        return AgentIntent::ApplyEdit {
            instruction: trimmed.to_string(),
        };
    }

    let edit = looks_like_edit_request(trimmed);
    let question = looks_like_question_or_advice(trimmed);

    if edit && question {
        return AgentIntent::Disambiguate {
            instruction: trimmed.to_string(),
        };
    }
    if edit {
        return AgentIntent::ApplyEdit {
            instruction: trimmed.to_string(),
        };
    }
    if question {
        return AgentIntent::Clarify {
            instruction: trimmed.to_string(),
        };
    }
    if looks_like_ambiguous_edit(trimmed) {
        return AgentIntent::Disambiguate {
            instruction: trimmed.to_string(),
        };
    }
    AgentIntent::Clarify {
        instruction: trimmed.to_string(),
    }
}

pub fn disambiguation_message(instruction: &str) -> String {
    format!(
        "I'm not sure whether you want me to edit the document or answer in chat.\n\n\
         • To edit: describe the change (e.g. \"complete line 1 and add a second line\").\n\
         • To ask: phrase it as a question (e.g. \"how should I continue this story?\").\n\n\
         Your message: \"{instruction}\""
    )
}

/// Pure routing layer (yoyo-evolve [`route_command`] analogue).
pub fn route_intent(input: &str) -> AgentIntent {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        return AgentIntent::Clarify {
            instruction: "Enter a message or slash command.".into(),
        };
    }

    if !trimmed.starts_with('/') {
        return route_natural_language(trimmed);
    }

    let rest = trimmed.strip_prefix('/').unwrap_or(trimmed);
    let cmd = rest.split_whitespace().next().unwrap_or(rest);
    let tail = rest.strip_prefix(cmd).unwrap_or("").trim();

    match cmd {
        "help" => AgentIntent::Help,
        "explain" | "summarize" | "summary" => AgentIntent::Summarize {
            instruction: if tail.is_empty() {
                "Explain the selected code.".into()
            } else {
                tail.to_string()
            },
        },
        "edit" | "refactor" | "fix" | "rename" | "extract" | "move" | "apply" | "quick" => {
            AgentIntent::ApplyEdit {
                instruction: if tail.is_empty() {
                    format!("{cmd} the selected code")
                } else {
                    format!("{cmd}: {tail}")
                },
            }
        }
        "clear" | "quit" | "exit" | "status" | "model" | "version" => AgentIntent::Clarify {
            instruction: format!(
                "Slash command '/{cmd}' is not available in the IDE agent panel. \
                 Chat naturally to ask questions, or describe the change you want in the file."
            ),
        },
        _ => AgentIntent::UnknownSlash {
            command: trimmed.to_string(),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn natural_language_question_defaults_to_repl() {
        assert!(matches!(
            route_intent("What does this function do?"),
            AgentIntent::Clarify { .. }
        ));
    }

    #[test]
    fn advice_question_routes_to_repl() {
        assert!(matches!(
            route_intent("How should I continue this story?"),
            AgentIntent::Clarify { .. }
        ));
    }

    #[test]
    fn story_edit_without_slash_routes_to_edit() {
        assert!(matches!(
            route_intent("complete line 1 and add a second line continuing the story"),
            AgentIntent::ApplyEdit { .. }
        ));
    }

    #[test]
    fn explicit_edit_phrase_routes_to_edit() {
        assert!(matches!(
            route_intent("refactor this function"),
            AgentIntent::ApplyEdit { .. }
        ));
    }

    #[test]
    fn polite_edit_routes_to_edit() {
        assert!(matches!(
            route_intent("can you add a second line continuing the story"),
            AgentIntent::ApplyEdit { .. }
        ));
    }

    #[test]
    fn ambiguous_improve_prompts_user() {
        assert!(matches!(
            route_intent("improve this"),
            AgentIntent::Disambiguate { .. }
        ));
    }

    #[test]
    fn explain_routes_to_summarize() {
        assert!(matches!(
            route_intent("/explain this function"),
            AgentIntent::Summarize { .. }
        ));
    }

    #[test]
    fn edit_slash_still_routes_to_edit() {
        assert!(matches!(
            route_intent("/edit modernize this"),
            AgentIntent::ApplyEdit { .. }
        ));
    }

    #[test]
    fn help_is_builtin() {
        assert_eq!(route_intent("/help"), AgentIntent::Help);
    }
}
