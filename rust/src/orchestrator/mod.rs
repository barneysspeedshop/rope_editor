//! yoyo-evolve-inspired orchestration bridge for the IDE agent.

mod auto_continue;
mod dispatch;
mod edit_stream;
mod file_index;
mod llm;
mod project_context;
mod prompt;
mod smart_edit;
mod token_budget;
mod truncate;

pub use dispatch::{route_intent, AgentIntent};
pub use file_index::{active_file_in_scope, context_window_message, prepare_context_files};
pub use llm::call_backend_streaming;
pub use prompt::{build_prompt, help_message};
pub use smart_edit::{
    build_replace_actions, extract_edit_replacement, extract_repl_message,
};

use auto_continue::{build_continue_prompt, looks_incomplete, max_auto_continues};
use edit_stream::EditStreamSplitter;
use std::sync::atomic::{AtomicU64, Ordering};
use token_budget::{build_budget, DEFAULT_CONTEXT_WINDOW};
use crate::api::{
    get_context_for_range, AgentBackendConfig, AgentResponse, OrchestrateEvent, OrchestrateRequest,
    RangeContext, RopeInstance,
};
use crate::frb_generated::StreamSink;
use project_context::{load_project_context, normalize_project_root};

static ORCHESTRATE_EPOCH: AtomicU64 = AtomicU64::new(0);

const CANCELLED: &str = "__orchestrate_cancelled__";

/// Invalidates in-flight orchestrate threads (e.g. after Flutter hot restart).
pub fn orchestrate_cancel_stale() {
    ORCHESTRATE_EPOCH.fetch_add(1, Ordering::SeqCst);
}

fn push_event(
    sink: Option<&StreamSink<OrchestrateEvent>>,
    epoch: u64,
    event: OrchestrateEvent,
) -> Result<(), String> {
    if epoch != ORCHESTRATE_EPOCH.load(Ordering::SeqCst) {
        return Err(CANCELLED.into());
    }
    if let Some(s) = sink {
        if s.add(event).is_err() {
            return Err(CANCELLED.into());
        }
    }
    Ok(())
}

fn resolve_response(
    intent: &AgentIntent,
    request: &OrchestrateRequest,
    context: &RangeContext,
    model_text: &str,
) -> AgentResponse {
    match intent {
        AgentIntent::Help => AgentResponse::Clarify {
            message: help_message().to_string(),
        },
        AgentIntent::UnknownSlash { command } => AgentResponse::Clarify {
            message: format!(
                "Unknown command: {command}. Type /help for supported IDE agent commands."
            ),
        },
        AgentIntent::Summarize { .. } => AgentResponse::Summarize {
            summary: model_text.trim().to_string(),
        },
        AgentIntent::Clarify { .. } => AgentResponse::Clarify {
            message: model_text.trim().to_string(),
        },
        AgentIntent::Disambiguate { instruction } => AgentResponse::Clarify {
            message: dispatch::disambiguation_message(instruction),
        },
        AgentIntent::ApplyEdit { .. } => {
            let active_path = if request.filename.is_empty() {
                "untitled".to_string()
            } else {
                request.filename.clone()
            };
            let empty_collapsed_selection = context.selected_text.is_empty()
                && request.end_utf16 <= request.start_utf16;
            let file_context_edit =
                empty_collapsed_selection && active_file_in_scope(&request.open_files, &active_path);

            if empty_collapsed_selection && !file_context_edit {
                return AgentResponse::Clarify {
                    message: "Include the active file in scope (or select text in the editor) \
                              before requesting an edit."
                        .into(),
                };
            }
            let replacement =
                extract_edit_replacement(model_text, &context.selected_text);
            let edits = if file_context_edit {
                let trimmed = replacement.trim();
                if trimmed.is_empty() {
                    Vec::new()
                } else {
                    vec![crate::api::EditorAction {
                        kind: crate::api::EditorActionKind::Replace,
                        start_utf16: request.start_utf16,
                        end_utf16: request.end_utf16,
                        text: trimmed.to_string(),
                    }]
                }
            } else {
                build_replace_actions(context, &replacement)
            };
            if edits.is_empty() {
                AgentResponse::Clarify {
                    message: format!(
                        "Could not extract a replacement edit from the model response. \
                         Try /edit with a clearer instruction.\n\nModel output:\n{model_text}"
                    ),
                }
            } else {
                let message = extract_repl_message(model_text);
                AgentResponse::ApplyEdits { edits, message }
            }
        }
    }
}

fn stream_llm_response(
    config: &AgentBackendConfig,
    prompt: &str,
    emit_edit_deltas: bool,
    sink: Option<&StreamSink<OrchestrateEvent>>,
    epoch: u64,
) -> Result<String, String> {
    if emit_edit_deltas {
        return stream_edit_llm_response(config, prompt, sink, epoch);
    }

    call_backend_streaming(config, prompt, |token| {
        let _ = push_event(
            sink,
            epoch,
            OrchestrateEvent::Thinking {
                text: token.to_string(),
            },
        );
    })
}

fn stream_edit_llm_response(
    config: &AgentBackendConfig,
    prompt: &str,
    sink: Option<&StreamSink<OrchestrateEvent>>,
    epoch: u64,
) -> Result<String, String> {
    let mut splitter = EditStreamSplitter::new();
    let full = call_backend_streaming(config, prompt, |token| {
        splitter.push(
            token,
            |repl| {
                let _ = push_event(
                    sink,
                    epoch,
                    OrchestrateEvent::Thinking {
                        text: repl.to_string(),
                    },
                );
            },
            |edit| {
                let _ = push_event(
                    sink,
                    epoch,
                    OrchestrateEvent::EditDelta {
                        delta: edit.to_string(),
                    },
                );
            },
        );
    })?;
    splitter.finish(
        |repl| {
            let _ = push_event(
                sink,
                epoch,
                OrchestrateEvent::Thinking {
                    text: repl.to_string(),
                },
            );
        },
        |edit| {
            let _ = push_event(
                sink,
                epoch,
                OrchestrateEvent::EditDelta {
                    delta: edit.to_string(),
                },
            );
        },
    );
    Ok(full)
}

fn orchestrate_inner(
    instance: &RopeInstance,
    request: OrchestrateRequest,
    sink: Option<&StreamSink<OrchestrateEvent>>,
    epoch: u64,
) -> Result<AgentResponse, String> {
    let intent = route_intent(&request.user_input);
    let active_path = if request.filename.is_empty() {
        "untitled".to_string()
    } else {
        request.filename.clone()
    };
    let context_files = prepare_context_files(&request.open_files, &active_path);

    push_event(
        sink,
        epoch,
        OrchestrateEvent::ContextWindowUpdate {
            files: context_files.clone(),
            message: context_window_message(&context_files),
        },
    )?;

    let project_root = normalize_project_root(&request.project_root);
    let project_context = load_project_context(
        project_root
            .to_str()
            .unwrap_or(&request.project_root),
    );

    let context = get_context_for_range(
        instance,
        request.start_utf16,
        request.end_utf16,
        5,
        context_files,
    );

    push_event(
        sink,
        epoch,
        OrchestrateEvent::Thinking {
            text: format!("Routing intent: {intent:?}\n"),
        },
    )?;

    if matches!(intent, AgentIntent::Help | AgentIntent::Disambiguate { .. }) {
        let response = resolve_response(&intent, &request, &context, "");
        push_event(
            sink,
            epoch,
            OrchestrateEvent::Complete {
                response: response.clone(),
            },
        )?;
        return Ok(response);
    }

    let prompt = build_prompt(&intent, &request, &context, project_context.as_deref());

    let context_window = if request.context_window_tokens == 0 {
        DEFAULT_CONTEXT_WINDOW
    } else {
        request.context_window_tokens
    };
    push_event(
        sink,
        epoch,
        OrchestrateEvent::ContextBudgetUpdate {
            budget: build_budget(
                &prompt,
                request.conversation_transcript_tokens,
                context_window,
            ),
        },
    )?;

    push_event(
        sink,
        epoch,
        OrchestrateEvent::Thinking {
            text: format!("Contacting {} (streaming)…\n", request.backend.backend_id),
        },
    )?;

    let is_edit = matches!(intent, AgentIntent::ApplyEdit { .. });
    let mut model_text = stream_llm_response(&request.backend, &prompt, is_edit, sink, epoch)?;

    if epoch != ORCHESTRATE_EPOCH.load(Ordering::SeqCst) {
        return Err(CANCELLED.into());
    }

    if is_edit {
        let mut continues = 0usize;
        while looks_incomplete(&model_text) && continues < max_auto_continues() {
            continues += 1;
            push_event(
                sink,
                epoch,
                OrchestrateEvent::Thinking {
                    text: format!("Auto-continuing generation ({continues})…\n"),
                },
            )?;
            let continue_prompt = build_continue_prompt(&model_text);
            let continuation =
                stream_llm_response(&request.backend, &continue_prompt, true, sink, epoch)?;
            model_text.push_str(&continuation);
            if epoch != ORCHESTRATE_EPOCH.load(Ordering::SeqCst) {
                return Err(CANCELLED.into());
            }
        }
    }

    let response = resolve_response(&intent, &request, &context, &model_text);

    push_event(
        sink,
        epoch,
        OrchestrateEvent::Complete {
            response: response.clone(),
        },
    )?;

    Ok(response)
}

pub fn orchestrate_request_sync(
    instance: &RopeInstance,
    request: OrchestrateRequest,
) -> Result<AgentResponse, String> {
    orchestrate_inner(instance, request, None, ORCHESTRATE_EPOCH.load(Ordering::SeqCst))
}

pub fn orchestrate_request(
    instance: &RopeInstance,
    request: OrchestrateRequest,
    sink: StreamSink<OrchestrateEvent>,
) {
    let epoch = ORCHESTRATE_EPOCH.fetch_add(1, Ordering::SeqCst) + 1;
    let instance = instance.clone_handle();
    std::thread::spawn(move || {
        match orchestrate_inner(&instance, request, Some(&sink), epoch) {
            Err(ref message) if message == CANCELLED => {}
            Err(message) => {
                let _ = push_event(
                    Some(&sink),
                    epoch,
                    OrchestrateEvent::Error { message },
                );
            }
            Ok(_) => {}
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::create_rope_instance;

    #[test]
    fn stub_edit_orchestration() {
        let instance = create_rope_instance("fn old() {}".into());
        let request = OrchestrateRequest {
            user_input: "/edit modernize this".into(),
            filename: "main.rs".into(),
            language: "rust".into(),
            start_utf16: 0,
            end_utf16: 14,
            project_root: String::new(),
            conversation_transcript_tokens: 0,
            context_window_tokens: 0,
            project_memories: String::new(),
            backend: AgentBackendConfig {
                backend_id: "stub".into(),
                base_url: String::new(),
                model: String::new(),
                api_key: String::new(),
            },
            open_files: Vec::new(),
        };
        let response = orchestrate_request_sync(&instance, request).unwrap();
        assert!(matches!(response, AgentResponse::ApplyEdits { .. }));
    }
}
