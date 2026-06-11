// Adapted from Zed's rope crate (GPL-3.0-or-later)

use std::{fmt, ops};

/// Represents a row and UTF-16 column offset within a text buffer.
#[derive(Clone, Copy, Default, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct PointUtf16 {
    pub row: u32,
    pub column: u32,
}

impl PointUtf16 {
    pub fn new(row: u32, column: u32) -> Self {
        Self { row, column }
    }

    pub fn zero() -> Self {
        Self::default()
    }
}

impl ops::Add for PointUtf16 {
    type Output = Self;

    fn add(self, rhs: Self) -> Self::Output {
        if rhs.row == 0 {
            PointUtf16::new(self.row, self.column + rhs.column)
        } else {
            PointUtf16::new(self.row + rhs.row, rhs.column)
        }
    }
}

impl ops::AddAssign for PointUtf16 {
    fn add_assign(&mut self, rhs: Self) {
        *self = *self + rhs;
    }
}

impl ops::Sub for PointUtf16 {
    type Output = Self;

    fn sub(self, rhs: Self) -> Self::Output {
        debug_assert!(self >= rhs);
        if self.row == rhs.row {
            PointUtf16::new(0, self.column - rhs.column)
        } else {
            PointUtf16::new(self.row - rhs.row, self.column)
        }
    }
}

impl fmt::Debug for PointUtf16 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "PointUtf16({}, {})", self.row, self.column)
    }
}

impl fmt::Display for PointUtf16 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({}, {})", self.row, self.column)
    }
}
