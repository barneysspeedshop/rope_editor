//! Incrementally splits model output into REPL prose vs edit deltas while streaming.

const EDIT_SENTINEL: &str = "<<EDIT>>";
const FENCE: &str = "```";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Phase {
    Repl,
    Edit,
}

pub struct EditStreamSplitter {
    accumulated: String,
    emitted: usize,
    phase: Phase,
}

impl EditStreamSplitter {
    pub fn new() -> Self {
        Self {
            accumulated: String::new(),
            emitted: 0,
            phase: Phase::Repl,
        }
    }

    pub fn push(
        &mut self,
        token: &str,
        mut on_repl: impl FnMut(&str),
        mut on_edit: impl FnMut(&str),
    ) {
        self.accumulated.push_str(token);
        loop {
            match self.phase {
                Phase::Repl => {
                    let slice = &self.accumulated[self.emitted..];
                    if let Some((start, end)) = find_edit_marker(slice) {
                        let repl = slice[..start].trim_end();
                        if !repl.is_empty() {
                            on_repl(repl);
                        }
                        self.emitted += end;
                        if self.accumulated[self.emitted..].starts_with('\n') {
                            self.emitted += 1;
                        }
                        self.phase = Phase::Edit;
                        continue;
                    }

                    let safe_end = safe_repl_emit_end(&self.accumulated, self.emitted);
                    if safe_end > self.emitted {
                        on_repl(&self.accumulated[self.emitted..safe_end]);
                        self.emitted = safe_end;
                    }
                    break;
                }
                Phase::Edit => {
                    if self.emitted < self.accumulated.len() {
                        on_edit(&self.accumulated[self.emitted..]);
                        self.emitted = self.accumulated.len();
                    }
                    break;
                }
            }
        }
    }

    pub fn finish(self, mut on_repl: impl FnMut(&str), mut on_edit: impl FnMut(&str)) {
        match self.phase {
            Phase::Repl => {
                if self.emitted < self.accumulated.len() {
                    on_repl(&self.accumulated[self.emitted..]);
                }
            }
            Phase::Edit => {
                if self.emitted < self.accumulated.len() {
                    on_edit(&self.accumulated[self.emitted..]);
                }
            }
        }
    }
}

fn find_edit_marker(slice: &str) -> Option<(usize, usize)> {
    if let Some(idx) = slice.find(EDIT_SENTINEL) {
        return Some((idx, idx + EDIT_SENTINEL.len()));
    }
    slice.find(FENCE).map(|idx| (idx, idx))
}

fn safe_repl_emit_end(text: &str, from: usize) -> usize {
    let tail = &text[from..];
    let mut hold_back = 0usize;
    for marker in [EDIT_SENTINEL, FENCE, "<<EDIT>", "<<EDI", "<<ED", "<<E", "<<", "<"] {
        for prefix in marker_suffixes(marker) {
            if tail.ends_with(prefix) && prefix.len() > hold_back {
                hold_back = prefix.len();
            }
        }
    }
    text.len().saturating_sub(hold_back)
}

fn marker_suffixes(marker: &str) -> Vec<&str> {
    (1..=marker.len()).map(|n| &marker[..n]).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_repl_and_edit_at_sentinel() {
        let mut splitter = EditStreamSplitter::new();
        let mut repl = String::new();
        let mut edit = String::new();
        splitter.push(
            "Here is the fix.\n<<EDIT>>\nnew code",
            |r| repl.push_str(r),
            |e| edit.push_str(e),
        );
        assert!(repl.contains("Here is the fix"));
        assert_eq!(edit, "new code");
    }
}
