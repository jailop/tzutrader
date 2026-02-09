/// Base indicator implementation using a circular buffer.
///
/// This is a generic circular buffer that stores the last N values
/// of a time series. More elaborate indicators use this as support
/// for storing results.
///
/// # Type Parameters
/// - `N`: Size of the circular buffer (compile-time constant)
/// - `T`: Type of values stored in the buffer

use super::Indicator;

/// Generic indicator with circular buffer storage
#[derive(Debug, Clone)]
pub struct BaseIndicator<T, const N: usize> {
    pos: i32,
    data: [T; N],
}

impl<T: Default + Copy, const N: usize> BaseIndicator<T, N> {
    /// Create a new indicator with default values
    pub fn new() -> Self {
        Self {
            pos: -1,
            data: [T::default(); N],
        }
    }
}

impl<T: Default + Copy, const N: usize> Default for BaseIndicator<T, N> {
    fn default() -> Self {
        Self::new()
    }
}

// Special initialization for f64 to use NaN as default
impl<const N: usize> BaseIndicator<f64, N> {
    /// Create a new f64 indicator with NaN as initial values
    pub fn new_float() -> Self {
        Self {
            pos: -1,
            data: [f64::NAN; N],
        }
    }
}

impl<T: Copy + Default, const N: usize> Indicator for BaseIndicator<T, N> {
    type Input = T;
    type Output = T;

    fn update(&mut self, value: T) {
        if self.pos == -1 {
            self.pos = 0;
        } else {
            self.pos = (self.pos + 1) % N as i32;
        }
        self.data[self.pos as usize] = value;
    }

    fn get(&self, key: i32) -> T {
        assert!(self.pos != -1, "indicator is empty");
        assert!(key <= 0, "cannot access future values (positive index)");
        assert!(-key < N as i32, "index out of bounds");
        
        let pos = ((self.pos + N as i32 + key) % N as i32) as usize;
        self.data[pos]
    }

    fn reset(&mut self) {
        self.pos = -1;
        self.data = [T::default(); N];
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_base_indicator() {
        let mut ind = BaseIndicator::<i32, 3>::new();
        
        ind.update(1);
        ind.update(2);
        ind.update(3);
        
        assert_eq!(ind.get(0), 3);
        assert_eq!(ind.get(-1), 2);
        assert_eq!(ind.get(-2), 1);
        
        // Test circular behavior
        ind.update(4);
        assert_eq!(ind.get(0), 4);
        assert_eq!(ind.get(-1), 3);
        assert_eq!(ind.get(-2), 2);
    }

    #[test]
    fn test_reset() {
        let mut ind = BaseIndicator::<i32, 3>::new();
        
        ind.update(1);
        ind.update(2);
        ind.reset();
        
        ind.update(10);
        assert_eq!(ind.get(0), 10);
    }

    #[test]
    #[should_panic(expected = "indicator is empty")]
    fn test_empty_access() {
        let ind = BaseIndicator::<i32, 3>::new();
        ind.get(0);
    }

    #[test]
    #[should_panic(expected = "cannot access future values")]
    fn test_future_access() {
        let mut ind = BaseIndicator::<i32, 3>::new();
        ind.update(1);
        ind.get(1);
    }
}
