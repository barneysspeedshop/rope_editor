//! LLM client with true Ollama streaming via reqwest.

use crate::api::AgentBackendConfig;
use serde::{Deserialize, Serialize};

#[derive(Serialize)]
struct OllamaGenerateRequest<'a> {
    model: &'a str,
    prompt: &'a str,
    stream: bool,
}

#[derive(Deserialize)]
struct OllamaStreamChunk {
    response: Option<String>,
    done: Option<bool>,
}

/// Stub backend for dev / tests without network.
pub fn call_stub(prompt: &str) -> Result<String, String> {
    if prompt.contains("REPL mode") || prompt.contains("Do not edit the document") {
        Ok("This is a stub REPL reply. The selected code is in context above. \
             Describe a change naturally to edit the document, or ask a question for advice."
            .into())
    } else if prompt.contains("Explain") || prompt.contains("explanation") {
        Ok("This is a stub summary of the selected code.".into())
    } else {
        Ok("I'll apply that change to the selection.\n<<EDIT>>\n// stub replacement\nedited_by_agent();".into())
    }
}

pub fn call_backend_streaming(
    config: &AgentBackendConfig,
    prompt: &str,
    on_token: impl FnMut(&str),
) -> Result<String, String> {
    match config.backend_id.as_str() {
        "stub" => call_stub_stream(prompt, on_token),
        "ollama" => call_ollama_stream(config, prompt, on_token),
        other => Err(format!("Unsupported agent backend: {other}")),
    }
}

fn call_stub_stream(
    prompt: &str,
    mut on_token: impl FnMut(&str),
) -> Result<String, String> {
    let text = call_stub(prompt)?;
    for ch in text.chars() {
        on_token(&ch.to_string());
    }
    Ok(text)
}

#[cfg(not(target_family = "wasm"))]
fn call_ollama_stream(
    config: &AgentBackendConfig,
    prompt: &str,
    mut on_token: impl FnMut(&str),
) -> Result<String, String> {
    use reqwest::blocking::Client;
    use std::io::{BufRead, BufReader};

    let base = config.base_url.trim_end_matches('/');
    let url = format!("{base}/api/generate");
    let body = OllamaGenerateRequest {
        model: &config.model,
        prompt,
        stream: true,
    };

    let client = Client::builder()
        .timeout(std::time::Duration::from_secs(600))
        .build()
        .map_err(|e| format!("Failed to build HTTP client: {e}"))?;

    let response = client
        .post(&url)
        .json(&body)
        .send()
        .map_err(|e| format!("Ollama request failed: {e}"))?;

    if !response.status().is_success() {
        return Err(format!(
            "Ollama HTTP {}: {}",
            response.status(),
            response.text().unwrap_or_default()
        ));
    }

    let reader = BufReader::new(response);
    let mut full = String::new();

    for line in reader.lines() {
        let line = line.map_err(|e| format!("Ollama stream read failed: {e}"))?;
        if line.trim().is_empty() {
            continue;
        }
        let chunk: OllamaStreamChunk =
            serde_json::from_str(&line).map_err(|e| format!("Invalid Ollama stream JSON: {e}"))?;
        if let Some(token) = chunk.response {
            if !token.is_empty() {
                full.push_str(&token);
                on_token(&token);
            }
        }
        if chunk.done == Some(true) {
            break;
        }
    }

    Ok(full)
}

#[cfg(target_family = "wasm")]
fn call_ollama_stream(
    _config: &AgentBackendConfig,
    _prompt: &str,
    _on_token: impl FnMut(&str),
) -> Result<String, String> {
    Err("Ollama orchestration is not available on web/WASM.".into())
}

/// Non-streaming fallback (sync tests).
#[allow(dead_code)]
pub fn call_backend(config: &AgentBackendConfig, prompt: &str) -> Result<String, String> {
    let mut out = String::new();
    call_backend_streaming(config, prompt, |token| out.push_str(token))?;
    Ok(out)
}
