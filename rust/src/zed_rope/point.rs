// Adapted from Zed's rope crate (GPL-3.0-or-later)

use std::{cmp, fmt, ops};

/// Represents a row and byte-column offset within a text buffer.
#[derive(Clone, Copy, Default, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct Point {
    pub row: u32,
    pub column: u32,
}

impl Point {
    pub fn new(row: u32, column: u32) -> Self {
        Self { row, column }
    }

    pub fn zero() -> Self {
        Self::default()
    }

    pub fn is_zero(&self) -> bool {
        self.row == 0 && self.column == 0
    }
}

impl ops::Add for Point {
    type Output = Self;

    fn add(self, rhs: Self) -> Self::Output {
        if rhs.row == 0 {
            Point::new(self.row, self.column + rhs.column)
        } else {
            Point::new(self.row + rhs.row, rhs.column)
        }
    }
}

impl ops::AddAssign for Point {
    fn add_assign(&mut self, rhs: Self) {
        *self = *self + rhs;
    }
}

impl ops::Sub for Point {
    type Output = Self;

    fn sub(self, rhs: Self) -> Self::Output {
        debug_assert!(self >= rhs);
        if self.row == rhs.row {
            Point::new(0, self.column - rhs.column)
        } else {
            Point::new(self.row - rhs.row, self.column)
        }
    }
}

impl ops::SubAssign for Point {
    fn sub_assign(&mut self, rhs: Self) {
        *self = *self - rhs;
    }
}

impl fmt::Debug for Point {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({}, {})", self.row, self.column)
    }
}

impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({}, {})", self.row, self.column)
    }
}
