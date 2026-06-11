// Adapted from Zed's rope crate (GPL-3.0-or-later)

/// A wrapper around a dimension type that allows it to be used as
/// an unclipped dimension (i.e., no clamping to the valid range).
#[derive(Clone, Copy, Debug, Default, Eq, Ord, PartialEq, PartialOrd)]
pub struct Unclipped<T: Clone + Copy + Default>(pub T);

impl<T: Clone + Copy + Default> Unclipped<T> {
    pub fn new(value: T) -> Self {
        Self(value)
    }
}

impl<T: Clone + Copy + Default + std::ops::Add<Output = T>> std::ops::Add for Unclipped<T> {
    type Output = Self;
    fn add(self, rhs: Self) -> Self {
        Self(self.0 + rhs.0)
    }
}

impl<T: Clone + Copy + Default + std::ops::AddAssign> std::ops::AddAssign for Unclipped<T> {
    fn add_assign(&mut self, rhs: Self) {
        self.0 += rhs.0;
    }
}
