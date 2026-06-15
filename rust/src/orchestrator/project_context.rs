//! Project context loading adapted from yoyo-evolve/src/context.rs.

use std::path::{Path, PathBuf};
use std::process::Command;

const PROJECT_CONTEXT_FILES: &[&str] = &[
    "YOYO.md",
    "CLAUDE.md",
    ".yoyo/instructions.md",
    "AGENTS.md",
    ".cursorrules",
    ".github/copilot-instructions.md",
];

const MAX_PROJECT_FILES: usize = 200;

/// Loads git status, instruction files, and project type hints for prompt injection.
pub fn load_project_context(project_root: &str) -> Option<String> {
    if project_root.is_empty() {
        return None;
    }
    let root = Path::new(project_root);
    if !root.is_dir() {
        return None;
    }

    let mut context = String::new();
    let mut found_any = false;

    for name in PROJECT_CONTEXT_FILES {
        let path = root.join(name);
        if let Ok(content) = std::fs::read_to_string(&path) {
            let content = content.trim();
            if content.is_empty() {
                continue;
            }
            if !context.is_empty() {
                context.push_str("\n\n");
            }
            context.push_str(&format!("--- From {name} ---\n{content}"));
            found_any = true;
        }
    }

    if let Some(listing) = git_file_listing(root) {
        if !context.is_empty() {
            context.push_str("\n\n");
        }
        context.push_str("## Project Files\n\n");
        context.push_str(&listing);
        found_any = true;
    }

    if let Some(status) = git_status_summary(root) {
        if !context.is_empty() {
            context.push_str("\n\n");
        }
        context.push_str(&status);
        found_any = true;
    }

    if let Some(hints) = project_type_hints(root) {
        if !context.is_empty() {
            context.push_str("\n\n");
        }
        context.push_str("## Development Conventions\n\n");
        context.push_str(hints);
        found_any = true;
    }

    if found_any { Some(context) } else { None }
}

fn project_type_hints(root: &Path) -> Option<&'static str> {
    if root.join("pubspec.yaml").exists() {
        return Some(
            "This is a Flutter/Dart project. Prefer idiomatic Dart, follow Material \
             patterns, and respect the existing widget/viewmodel structure.",
        );
    }
    if root.join("Cargo.toml").exists() {
        return Some(
            "This is a Rust project. Prefer idiomatic Rust, minimize allocations in hot \
             paths, and respect existing module boundaries.",
        );
    }
    if root.join("package.json").exists() {
        return Some(
            "This is a JavaScript/TypeScript project. Match existing module and \
             formatting conventions.",
        );
    }
    None
}

fn run_git(root: &Path, args: &[&str]) -> Option<String> {
    let output = Command::new("git")
        .args(args)
        .current_dir(root)
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn git_file_listing(root: &Path) -> Option<String> {
    let stdout = run_git(root, &["ls-files"])?;
    if stdout.is_empty() {
        return None;
    }
    let files: Vec<&str> = stdout.lines().filter(|l| !l.is_empty()).collect();
    let total = files.len();
    let capped: Vec<&str> = files.into_iter().take(MAX_PROJECT_FILES).collect();
    let mut listing = capped.join("\n");
    if total > MAX_PROJECT_FILES {
        listing.push_str(&format!("\n... and {} more files", total - MAX_PROJECT_FILES));
    }
    Some(listing)
}

fn git_status_summary(root: &Path) -> Option<String> {
    let branch = run_git(root, &["rev-parse", "--abbrev-ref", "HEAD"])?;
    let porcelain = run_git(root, &["status", "--porcelain"]).unwrap_or_default();
    let uncommitted = porcelain.lines().filter(|l| !l.is_empty()).count();
    let mut result = String::from("## Git Status\n\n");
    result.push_str(&format!("Branch: {branch}\n"));
    if uncommitted > 0 {
        result.push_str(&format!(
            "Uncommitted changes: {} file{}\n",
            uncommitted,
            if uncommitted == 1 { "" } else { "s" }
        ));
    }
    Some(result)
}

/// Normalizes a project root path from Dart (may be file URI or plain path).
pub fn normalize_project_root(raw: &str) -> PathBuf {
    let trimmed = raw.trim();
    if trimmed.starts_with("file://") {
        PathBuf::from(trimmed.trim_start_matches("file://"))
    } else {
        PathBuf::from(trimmed)
    }
}
