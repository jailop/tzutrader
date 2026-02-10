//! Simple Moving Average (MA) indicator.
//!
//! The MA is calculated by taking the average of the last P values.
//! This implementation uses a circular buffer to store the last P input values
//! and an accumulator to keep track of their sum. When a new value is added,
//! the oldest value is subtracted from the accumulator and the new value is
//! added, allowing for efficient O(1) updates.
//!
//! # Type Parameters
//! - `P`: Period of the moving average (compile-time constant)
//! - `S`: Number of recent MA values to store (compile-time constant)
//!
//! # Example
//!
//! ```rust
//! use tzutrader_rs::{Indicator, MA};
//!
//! let mut ma = MA::<5, 3>::new();
//! for i in 1..=10 {
//!    ma.update(i as f64);
//! }
//! // access current value: 8.00
//! println!("Current: {:.2}", ma.get(0).unwrap_or(f64::NAN));
//! // access previous value: 7.00
//! println!("Previous: {:.2}", ma.get(-1).unwrap_or(f64::NAN));
//! // access two bars ago: 6.00
//! println!("Two bars ago: {:.2}\n", ma.get(-2).unwrap_or(f64::NAN));
//! ```

use super::{base::BaseIndicator, Indicator};

/// Moving Average indicator
#[derive(Debug, Clone)]
pub struct MA<const P: usize, const N: usize = 1> {
    accum: f64,
    length: usize,
    data: BaseIndicator<f64, N>,
    prevs: [f64; P],
    pos: usize,
}

impl<const P: usize, const N: usize> MA<P, N> {
    /// Create a new MA indicator
    pub fn new() -> Self {
        Self {
            accum: 0.0,
            length: 0,
            data: BaseIndicator::new(),
            prevs: [f64::NAN; P],
            pos: 0,
        }
    }
}

impl<const P: usize, const N: usize> Default for MA<P, N> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const N: usize> Indicator for MA<P, N> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) -> Option<f64> {
        if self.length < P {
            self.length += 1;
        } else {
            self.accum -= self.prevs[self.pos];
        }

        self.prevs[self.pos] = value;
        self.accum += value;
        self.pos = (self.pos + 1) % P;

        if self.length < P {
            None
        } else {
            self.data.update(self.accum / P as f64);
            self.data.get(0)
        }
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.length = 0;
        self.accum = 0.0;
        self.data.reset();
        self.pos = 0;
        // self.prevs = [f64::NAN; P];
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ma_basic() {
        let mut ma = MA::<3, 1>::new();

        // First two values should produce NaN
        ma.update(5.0);
        assert!(ma.get(0).is_none());

        ma.update(4.0);
        assert!(ma.get(0).is_none());

        // Third value completes the period
        ma.update(3.0);
        assert_eq!(ma.get(0), Some(4.0)); // (5 + 4 + 3) / 3 = 4

        // Fourth value (rolling window)
        ma.update(6.0);
        assert_eq!(ma.get(0), Some(4.333333333333333)); // (4 + 3 + 6) / 3
    }

    #[test]
    fn test_ma_history() {
        let mut ma = MA::<3, 3>::new();

        ma.update(5.0);
        ma.update(4.0);
        ma.update(3.0);
        let first = ma.get(0);

        ma.update(6.0);
        let second = ma.get(0);

        ma.update(9.0);
        let third = ma.get(0);

        assert_eq!(ma.get(0), third);
        assert_eq!(ma.get(-1), second);
        assert_eq!(ma.get(-2), first);
    }

    #[test]
    fn test_ma_reset() {
        let mut ma = MA::<3, 1>::new();

        ma.update(5.0);
        ma.update(4.0);
        ma.update(3.0);

        ma.reset();

        ma.update(10.0);
        assert!(ma.get(0).is_none());
    }

    #[test]
    fn test_ma_period_5() {
        let mut ma = MA::<5, 1>::new();

        for i in 1..=5 {
            ma.update(i as f64);
        }

        assert_eq!(ma.get(0), Some(3.0)); // (1 + 2 + 3 + 4 + 5) / 5 = 3
    }
}
