// Adapted from Zed's rope crate (GPL-3.0-or-later)

use std::{fmt, ops};

/// The byte offset in a UTF-16 encoding of text.
#[derive(Clone, Copy, Default, Eq, Ord, PartialEq, PartialOrd)]
pub struct OffsetUtf16(pub usize);

impl OffsetUtf16 {
    pub fn new(n: usize) -> Self {
        Self(n)
    }
}

impl ops::Add for OffsetUtf16 {
    type Output = Self;

    fn add(self, rhs: Self) -> Self::Output {
        Self(self.0 + rhs.0)
    }
}

impl ops::AddAssign for OffsetUtf16 {
    fn add_assign(&mut self, rhs: Self) {
        self.0 += rhs.0;
    }
}

impl ops::Sub for OffsetUtf16 {
    type Output = Self;

    fn sub(self, rhs: Self) -> Self::Output {
        debug_assert!(self >= rhs, "OffsetUtf16 subtraction underflow");
        Self(self.0.saturating_sub(rhs.0))
    }
}

impl ops::SubAssign for OffsetUtf16 {
    fn sub_assign(&mut self, rhs: Self) {
        self.0 = self.0.saturating_sub(rhs.0);
    }
}

impl fmt::Debug for OffsetUtf16 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "OffsetUtf16({})", self.0)
    }
}

impl fmt::Display for OffsetUtf16 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}
