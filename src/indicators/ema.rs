//! Exponential Moving Average (EMA)
//!
//! EMA gives more weight to recent prices, making it more responsive
//! to price changes than SMA. Uses a smoothing factor based on the period.
//!
//! # Type Parameters
//! - `P`: Period for the exponential moving average (compile-time constant)
//! - `S`: Number of recent EMA values to store (compile-time constant, default 1)

use super::{base::BaseIndicator, Indicator};

#[derive(Debug, Clone)]
pub struct EMA<const P: usize, const S: usize = 1> {
    alpha: f64,
    length: usize,
    prev: f64,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> EMA<P, S> {
    pub fn new() -> Self {
        Self::with_smoothing(2.0)
    }

    pub fn with_smoothing(smoothing: f64) -> Self {
        Self {
            alpha: smoothing / (1.0 + P as f64),
            length: 0,
            prev: 0.0,
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for EMA<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for EMA<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) -> Option<f64> {
        self.length += 1;
        if self.length < P {
            self.prev += value;
            return None;
        } else if self.length == P {
            self.prev += value;
            self.prev /= P as f64;
            self.data.update(self.prev);
            self.data.get(0)
        } else {
            self.prev = (value * self.alpha) + self.prev * (1.0 - self.alpha);
            self.data.update(self.prev);
            self.data.get(0)
        }
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.length = 0;
        self.prev = 0.0;
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ema_basic() {
        let mut ema = EMA::<3, 1>::new();

        ema.update(5.0);
        assert!(ema.get(0).is_none());

        ema.update(4.0);
        assert!(ema.get(0).is_none());

        ema.update(3.0);
        assert_eq!(ema.get(0), Some(4.0)); // Initial mean
    }

    #[test]
    fn test_ema_warmup_period() {
        // EMA needs P values before producing results
        const P: usize = 5;
        let mut ema = EMA::<P, 1>::new();

        // During warmup: should return None
        for i in 0..(P - 1) {
            assert!(ema.update(100.0 + i as f64).is_none(), 
                "Update {} should return None during warmup", i + 1);
        }
        
        // Pth value should return Some (initial SMA)
        assert!(ema.update(110.0).is_some());
    }

    #[test]
    fn test_ema_initial_value() {
        // First value after warmup should be SMA of first P values
        const P: usize = 4;
        let mut ema = EMA::<P, 1>::new();

        let values = vec![10.0, 20.0, 30.0, 40.0];
        
        for &val in &values {
            ema.update(val);
        }

        // Initial EMA = SMA of first P values = (10+20+30+40)/4 = 25
        assert_eq!(ema.get(0), Some(25.0));
    }

    #[test]
    fn test_ema_smoothing() {
        // Test EMA smoothing formula: EMA = price * alpha + prev_ema * (1 - alpha)
        const P: usize = 3;
        let mut ema = EMA::<P, 1>::new();

        // Warmup: 10, 20, 30 -> SMA = 20
        ema.update(10.0);
        ema.update(20.0);
        ema.update(30.0);
        assert_eq!(ema.get(0), Some(20.0));

        // alpha = 2 / (P + 1) = 2 / 4 = 0.5
        // Next EMA = 40 * 0.5 + 20 * 0.5 = 30
        ema.update(40.0);
        assert_eq!(ema.get(0), Some(30.0));

        // EMA = 50 * 0.5 + 30 * 0.5 = 40
        ema.update(50.0);
        assert_eq!(ema.get(0), Some(40.0));
    }

    #[test]
    fn test_ema_responsiveness() {
        // EMA should respond to new prices, weighted toward recent values
        const P: usize = 5;
        let mut ema = EMA::<P, 1>::new();

        // Establish baseline at 100
        for _ in 0..10 {
            ema.update(100.0);
        }

        let baseline = ema.get(0).unwrap();
        assert!((baseline - 100.0).abs() < 0.01);

        // Sharp move to 120
        ema.update(120.0);
        let after_spike = ema.get(0).unwrap();

        // EMA should move toward 120 but not reach it in one update
        assert!(after_spike > baseline, "EMA should increase");
        assert!(after_spike < 120.0, "EMA shouldn't reach new price immediately");
    }

    #[test]
    fn test_ema_constant_values() {
        // When all values are constant, EMA should converge to that value
        const P: usize = 4;
        let mut ema = EMA::<P, 1>::new();

        for _ in 0..20 {
            ema.update(50.0);
        }

        let result = ema.get(0).unwrap();
        assert_eq!(result, 50.0);
    }

    #[test]
    fn test_ema_uptrend() {
        // Test EMA behavior in uptrend
        const P: usize = 5;
        let mut ema = EMA::<P, 5>::new();

        // Create steady uptrend
        for i in 0..10 {
            ema.update(100.0 + i as f64 * 5.0);
        }

        // EMA should be increasing
        let current = ema.get(0).unwrap();
        let prev1 = ema.get(-1).unwrap();
        let prev2 = ema.get(-2).unwrap();

        assert!(current > prev1, "EMA should increase in uptrend");
        assert!(prev1 > prev2, "EMA should consistently increase");
    }

    #[test]
    fn test_ema_downtrend() {
        // Test EMA behavior in downtrend
        const P: usize = 5;
        let mut ema = EMA::<P, 5>::new();

        // Create steady downtrend
        for i in 0..10 {
            ema.update(200.0 - i as f64 * 5.0);
        }

        // EMA should be decreasing
        let current = ema.get(0).unwrap();
        let prev1 = ema.get(-1).unwrap();
        let prev2 = ema.get(-2).unwrap();

        assert!(current < prev1, "EMA should decrease in downtrend");
        assert!(prev1 < prev2, "EMA should consistently decrease");
    }

    #[test]
    fn test_ema_custom_smoothing() {
        // Test custom smoothing factor
        const P: usize = 3;
        let mut ema_default = EMA::<P, 1>::new();
        let mut ema_custom = EMA::<P, 1>::with_smoothing(3.0);

        let values = vec![10.0, 20.0, 30.0, 40.0, 50.0];

        for &val in &values {
            ema_default.update(val);
            ema_custom.update(val);
        }

        let default_value = ema_default.get(0).unwrap();
        let custom_value = ema_custom.get(0).unwrap();

        // Different smoothing factors should produce different results
        assert_ne!(default_value, custom_value);
    }

    #[test]
    fn test_ema_reset() {
        const P: usize = 3;
        let mut ema = EMA::<P, 1>::new();

        // Add values
        for i in 1..=10 {
            ema.update(i as f64 * 10.0);
        }
        
        assert!(ema.get(0).is_some());

        // Reset
        ema.reset();

        // Should need warmup again
        for i in 0..(P - 1) {
            assert!(ema.update(100.0 + i as f64).is_none(),
                "After reset, update {} should return None", i + 1);
        }
        assert!(ema.update(200.0).is_some());
    }

    #[test]
    fn test_ema_historical_access() {
        // Test buffer storage with S=4
        const P: usize = 3;
        let mut ema = EMA::<P, 4>::new();

        // Need to add enough values so buffer has 4 entries
        // Warmup: P values (but only last one stored)
        for i in 0..P {
            ema.update(10.0 * i as f64);
        }

        // Add 3 more values to fill buffer to 4 entries
        for i in 0..3 {
            ema.update(100.0 + i as f64 * 10.0);
        }

        // Access current and historical values within buffer size
        for i in 0..4 {
            assert!(ema.get(-i).is_some(), 
                "Should be able to access value at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(ema.get(-4).is_none());
    }

    #[test]
    fn test_ema_get_before_warmup() {
        // Test that get() returns None before warmup is complete
        const P: usize = 4;
        let mut ema = EMA::<P, 1>::new();

        // Before any updates
        assert!(ema.get(0).is_none());

        // During warmup
        for i in 0..(P - 1) {
            ema.update(100.0 + i as f64);
            assert!(ema.get(0).is_none(), 
                "get(0) should return None during warmup at update {}", i + 1);
        }

        // After warmup (Pth value)
        ema.update(200.0);
        assert!(ema.get(0).is_some());
    }

    #[test]
    fn test_ema_lag_vs_sma() {
        // EMA should lag less than SMA
        const P: usize = 5;
        let mut ema = EMA::<P, 1>::new();

        // Stable at 100
        for _ in 0..10 {
            ema.update(100.0);
        }

        // Sudden jump to 150
        ema.update(150.0);
        let ema_value = ema.get(0).unwrap();

        // EMA should move more than halfway toward 150
        // With alpha = 2/(5+1) = 1/3, EMA = 150 * 1/3 + 100 * 2/3 = 116.67
        let expected = 150.0 * (1.0/3.0) + 100.0 * (2.0/3.0);
        assert!((ema_value - expected).abs() < 0.01);
    }

    #[test]
    fn test_ema_price_spike() {
        // Test EMA response to price spike
        const P: usize = 5;
        let mut ema = EMA::<P, 1>::new();

        // Stable period
        for _ in 0..10 {
            ema.update(100.0);
        }
        
        let before_spike = ema.get(0).unwrap();

        // Price spike
        ema.update(200.0);
        let during_spike = ema.get(0).unwrap();

        // Return to normal
        for _ in 0..5 {
            ema.update(100.0);
        }
        let after_spike = ema.get(0).unwrap();

        assert!(during_spike > before_spike, "EMA should react to spike");
        assert!(after_spike < during_spike, "EMA should decrease after spike");
        assert!(after_spike > before_spike, "EMA should still show residual effect");
    }

    #[test]
    fn test_ema_with_period_one() {
        // Edge case: P=1 means EMA = current price
        const P: usize = 1;
        let mut ema = EMA::<P, 1>::new();

        ema.update(100.0);
        assert_eq!(ema.get(0), Some(100.0));
        
        ema.update(105.0);
        assert_eq!(ema.get(0), Some(105.0));
        
        ema.update(103.0);
        assert_eq!(ema.get(0), Some(103.0));
    }
}

