//! Prompt assembly adapted from yoyo-evolve/src/prompt.rs and Dart AgentPrompt.

use super::dispatch::AgentIntent;
use super::file_index::{format_related_files_section, format_selection_section, is_file_context_mode};
use crate::api::{OrchestrateRequest, RangeContext};

const HELP_TEXT: &str = "IDE Agent:
  Chat naturally       Ask questions or request advice (no document edit)
  Describe a change    Edits the file when your message sounds like a change request
  /explain [topic]     Explain selected code
  /edit [instruction]  Explicitly edit (optional — natural phrasing also works)
  /refactor [hint]     Refactor the selection
  /fix [issue]         Fix the selection
  /compact             Drop older chat turns to free context (keeps recent 6)
  /help                Show this message

Examples: \"complete line 1 and add a second line\", \"how should I continue this story?\"";

fn format_memories_section(memories: &str) -> String {
    let trimmed = memories.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    format!("## Project memories (persistent)\n\n{trimmed}\n\n")
}

pub fn help_message() -> &'static str {
    HELP_TEXT
}

/// Build the model prompt for the resolved intent.
pub fn build_prompt(
    intent: &AgentIntent,
    request: &OrchestrateRequest,
    context: &RangeContext,
    project_context: Option<&str>,
) -> String {
    let related = format_related_files_section(&context.related_files);
    let project = project_context
        .map(|ctx| format!("## Project context\n\n{ctx}\n\n"))
        .unwrap_or_default();
    let memories = format_memories_section(&request.project_memories);
    let active_path = if request.filename.is_empty() {
        "untitled"
    } else {
        request.filename.as_str()
    };
    let file_context = is_file_context_mode(context, request, active_path);
    let selection_section = format_selection_section(context, file_context);
    match intent {
        AgentIntent::Help => HELP_TEXT.to_string(),
        AgentIntent::UnknownSlash { command } => {
            format!("The user entered an unknown slash command: {command}\n\
                     Reply briefly that the command is not supported in the IDE agent panel, \
                     and suggest /help or natural-language edit instructions.")
        }
        AgentIntent::Summarize { instruction } => format!(
            "You are a coding assistant in an IDE.\n\
             File: {}\n\
             Language: {}\n\
             Selection UTF-16 range: {}..{}\n\n\
             {project}{memories}\
             {}\n\
             ## Context\n\
             {}\n\n\
             ## Selected text\n\
             {}\n\n\
             ## Instruction\n\
             {}\n\n\
             Respond with a concise explanation using the file content above when available. \
             Do not claim you cannot see the file if Context or Open files sections contain it. \
             Do not propose code edits.",
            request.filename,
            request.language,
            context.start_utf16,
            context.end_utf16,
             related,
            context.context_lines,
            &selection_section,
            instruction,
        ),
        AgentIntent::Clarify { instruction } => format!(
            "You are a helpful IDE coding assistant in REPL mode.\n\
             Answer conversationally in the agent console. Do not edit the document.\n\
             File: {}\n\
             Language: {}\n\n\
             {project}{memories}\
             {}\n\
             ## Context\n\
             {}\n\n\
             ## Selected text\n\
             {}\n\n\
             ## User message\n\
             {}\n\n\
             Respond clearly using the file content above when it is available. \
             Do not claim you cannot see the file if Context or Open files sections contain it. \
             Do not return replacement code unless the user explicitly \
             asked you to rewrite the selection.",
            request.filename,
            request.language,
            related,
            context.context_lines,
            &selection_section,
            instruction,
        ),
        AgentIntent::Disambiguate { .. } => String::new(),
        AgentIntent::ApplyEdit { instruction } => {
            let selection_help = if file_context {
                "(no selection — active file is in scope; return ONLY the new or changed text \
                 to insert, not the whole file)"
            } else {
                &selection_section
            };
            let edit_instructions = if file_context {
                "Respond in two parts:\n\
                 1. A brief conversational reply for the agent console (what you will change and why).\n\
                 2. On its own line, write the sentinel <<EDIT>> followed by ONLY the text to add \
                 or the replacement snippet (no markdown fences or **bold** / __underline__ \
                 emphasis, not the full file unless rewriting \
                 the entire file)."
            } else {
                "Respond in two parts:\n\
                 1. A brief conversational reply for the agent console (what you will change and why).\n\
                 2. On its own line, write the sentinel <<EDIT>> followed by the replacement text \
                 for the selection only (no markdown fences or **bold** / __underline__ emphasis)."
            };
            format!(
            "You are a coding assistant editing a file in an IDE.\n\
             File: {}\n\
             Language: {}\n\
             Selection UTF-16 range: {}..{}\n\n\
             {project}{memories}\
             {}\n\
             ## Context\n\
             {}\n\n\
             ## Selected text\n\
             {}\n\n\
             ## Instruction\n\
             {}\n\n\
             {edit_instructions}\n\n\
             Example:\n\
             I'll rename this function for clarity.\n\
             <<EDIT>>\n\
             fn clearer_name() {{}}",
            request.filename,
            request.language,
            context.start_utf16,
            context.end_utf16,
            related,
            context.context_lines,
            selection_help,
            instruction,
        )},
    }
}
