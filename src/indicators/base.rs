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
pub struct BaseIndicator<T, const N: usize = 1> {
    pos: i32,
    filled: bool,
    data: [T; N],
}

impl<T: Default + Copy, const N: usize> BaseIndicator<T, N> {
    /// Create a new indicator with default values
    pub fn new() -> Self {
        Self {
            pos: -1,
            filled: false,
            data: [T::default(); N],
        }
    }
}

impl<T: Default + Copy, const N: usize> Default for BaseIndicator<T, N> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T: Copy + Default, const N: usize> Indicator for BaseIndicator<T, N> {
    type Input = T;
    type Output = T;

    fn update(&mut self, value: T) -> Option<T> {
        if self.pos == -1 {
            self.pos = 0;
        } else {
            self.pos = (self.pos + 1) % N as i32;
            if self.pos == 0 {
                self.filled = true; // Buffer is now full
            }
        }
        self.data[self.pos as usize] = value;
        Some(value)
    }

    fn get(&self, key: i32) -> Option<T> {
        match self.pos {
            -1 => return None, // No data yet
            _ if key > 0 => return None, // Future values not available
            _ if key < -(N as i32) => return None, // Out of bounds
            _ if !self.filled && key < -self.pos => return None, // Not enough data yet
            _ => {
                let pos = ((self.pos + N as i32 + key) % N as i32) as usize;
                Some(self.data[pos])
            }
        }
    }

    fn reset(&mut self) {
        self.pos = -1;
        self.filled = false;
        // self.data = [T::default(); N];
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
        
        assert_eq!(ind.get(0), Some(3));
        assert_eq!(ind.get(-1), Some(2));
        assert_eq!(ind.get(-2), Some(1));
        
        // Test circular behavior
        ind.update(4);
        assert_eq!(ind.get(0), Some(4));
        assert_eq!(ind.get(-1), Some(3));
        assert_eq!(ind.get(-2), Some(2));
    }

    #[test]
    fn test_reset() {
        let mut ind = BaseIndicator::<i32, 3>::new();
        
        ind.update(1);
        ind.update(2);
        ind.reset();
        
        ind.update(10);
        let val = ind.get(0);
        assert!(val.is_some());
        assert_eq!(val, Some(10));
    }

    #[test]
    fn test_empty_access() {
        let ind = BaseIndicator::<i32, 3>::new();
        assert!(ind.get(0).is_none());
    }

    #[test]
    fn test_future_access() {
        let mut ind = BaseIndicator::<i32, 3>::new();
        ind.update(1);
        ind.get(1).is_none();
    }

    #[test]
    fn test_not_completly_filled() {
        let mut ind = BaseIndicator::<i32, 3>::new();
        ind.update(1);
        ind.update(2);
        assert!(ind.get(-2).is_none());
    }
}
