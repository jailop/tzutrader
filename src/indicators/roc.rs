//! Rate of Change (ROC)
//!
//! ROC measures the percentage change in price from P periods ago.
//! It's a momentum indicator that oscillates around zero.
//!
//! # Type Parameters
//! - `P`: Lookback period (compile-time constant)
//! - `S`: Number of recent ROC values to store (compile-time constant, default 1)
//!
//! # Example
//!
//! ```rust
//! use tzutrader::indicators::{Indicator, roc::ROC};
//!
//! let mut roc = ROC::<5, 3>::new();
//!
//! // Warmup period - needs P values before producing results
//! for i in 1..=5 {
//!     assert!(roc.update(i as f64 * 20.0).is_none());
//! }
//!
//! // After warmup, ROC calculates percentage change from P periods ago
//! // Price goes from 20 (5 periods ago) to 140: ROC = ((140 - 20) / 20) * 100 = 600%
//! let result = roc.update(140.0).unwrap();
//! assert!((result - 600.0).abs() < 0.01);
//!
//! // Access current value
//! println!("Current ROC: {:.2}%", roc.get(0).unwrap());
//!
//! // Access previous value (if available)
//! if let Some(prev) = roc.get(-1) {
//!     println!("Previous ROC: {:.2}%", prev);
//! }
//! ```

use super::{base::BaseIndicator, Indicator};

#[derive(Debug, Clone)]
pub struct ROC<const P: usize, const S: usize = 1> {
    prevs: [f64; P],
    length: usize,
    pos: usize,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> ROC<P, S> {
    pub fn new() -> Self {
        Self {
            prevs: [f64::NAN; P],
            length: 0,
            pos: 0,
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for ROC<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for ROC<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) -> Option<f64> {
        if self.length < P {
            self.length += 1;
            self.prevs[self.pos] = value;
            self.pos = (self.pos + 1) % P;
            return None;
        }
        
        let old_value = self.prevs[self.pos];
        self.prevs[self.pos] = value;
        self.pos = (self.pos + 1) % P;

        if old_value == 0.0 {
            return None;
        }
        
        self.data.update(((value - old_value) / old_value) * 100.0);
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.length = 0;
        self.pos = 0;
        self.prevs = [f64::NAN; P];
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_roc_warmup_period() {
        // ROC needs P values before calculating rate of change
        const P: usize = 5;
        let mut roc = ROC::<P, 1>::new();

        // During warmup: should return None
        for i in 0..P {
            assert!(roc.update(100.0 + i as f64).is_none(), 
                "Update {} should return None during warmup", i + 1);
        }
        
        // After warmup: should return Some
        assert!(roc.update(110.0).is_some());
    }

    #[test]
    fn test_roc_positive_change() {
        // Test positive rate of change
        const P: usize = 3;
        let mut roc = ROC::<P, 1>::new();

        // Warmup: 100, 105, 110
        roc.update(100.0);
        roc.update(105.0);
        roc.update(110.0);

        // Current: 120, P periods ago: 100
        // ROC = ((120 - 100) / 100) * 100 = 20%
        let result = roc.update(120.0).unwrap();
        assert!((result - 20.0).abs() < 0.0001);
    }

    #[test]
    fn test_roc_negative_change() {
        // Test negative rate of change
        const P: usize = 3;
        let mut roc = ROC::<P, 1>::new();

        // Warmup: 100, 95, 90
        roc.update(100.0);
        roc.update(95.0);
        roc.update(90.0);

        // Current: 80, P periods ago: 100
        // ROC = ((80 - 100) / 100) * 100 = -20%
        let result = roc.update(80.0).unwrap();
        assert!((result - (-20.0)).abs() < 0.0001);
    }

    #[test]
    fn test_roc_zero_change() {
        // Test zero rate of change
        const P: usize = 4;
        let mut roc = ROC::<P, 1>::new();

        // All values the same
        for _ in 0..P {
            roc.update(100.0);
        }

        // No change
        let result = roc.update(100.0).unwrap();
        assert_eq!(result, 0.0);
    }

    #[test]
    fn test_roc_formula_accuracy() {
        // Verify ROC formula: ((current - old) / old) * 100
        const P: usize = 3;
        let mut roc = ROC::<P, 1>::new();

        let prices = vec![10.0, 20.0, 30.0, 40.0, 50.0, 60.0];
        
        for (i, &price) in prices.iter().enumerate() {
            let result = roc.update(price);
            
            if i < P {
                assert!(result.is_none());
            } else {
                let old_price = prices[i - P];
                let expected = ((price - old_price) / old_price) * 100.0;
                assert!((result.unwrap() - expected).abs() < 0.0001,
                    "At index {}: expected {}, got {:?}", i, expected, result);
            }
        }
    }

    #[test]
    fn test_roc_circular_buffer() {
        // Test that circular buffer works correctly
        const P: usize = 3;
        let mut roc = ROC::<P, 1>::new();

        // Fill buffer: 100, 110, 120
        roc.update(100.0);
        roc.update(110.0);
        roc.update(120.0);

        // ROC vs 100: (130 - 100) / 100 * 100 = 30%
        let result = roc.update(130.0).unwrap();
        assert!((result - 30.0).abs() < 0.0001);
        
        // ROC vs 110: (143 - 110) / 110 * 100 = 30%
        let result = roc.update(143.0).unwrap();
        assert!((result - 30.0).abs() < 0.0001);
        
        // ROC vs 120: (156 - 120) / 120 * 100 = 30%
        let result = roc.update(156.0).unwrap();
        assert!((result - 30.0).abs() < 0.0001);
    }

    #[test]
    fn test_roc_zero_old_value() {
        // Test handling of zero old value (division by zero protection)
        const P: usize = 3;
        let mut roc = ROC::<P, 1>::new();

        // Include 0 in warmup
        roc.update(0.0);
        roc.update(50.0);
        roc.update(100.0);

        // Would divide by 0, so should return None
        assert!(roc.update(150.0).is_none());
        
        // Next value compares to 50, should work
        let result = roc.update(75.0).unwrap();
        assert!((result - 50.0).abs() < 0.0001); // (75-50)/50*100 = 50%
    }

    #[test]
    fn test_roc_doubling() {
        // Test when price doubles over P periods
        const P: usize = 3;
        let mut roc = ROC::<P, 1>::new();

        roc.update(50.0);
        roc.update(60.0);
        roc.update(70.0);

        // Doubles from 50 to 100
        let result = roc.update(100.0).unwrap();
        assert!((result - 100.0).abs() < 0.0001); // 100% increase
    }

    #[test]
    fn test_roc_halving() {
        // Test when price halves over P periods
        const P: usize = 3;
        let mut roc = ROC::<P, 1>::new();

        roc.update(100.0);
        roc.update(90.0);
        roc.update(80.0);

        // Halves from 100 to 50
        let result = roc.update(50.0).unwrap();
        assert!((result - (-50.0)).abs() < 0.0001); // 50% decrease
    }

    #[test]
    fn test_roc_reset() {
        const P: usize = 3;
        let mut roc = ROC::<P, 1>::new();

        // Add values
        for i in 1..=10 {
            roc.update(i as f64 * 10.0);
        }
        
        assert!(roc.get(0).is_some());

        // Reset
        roc.reset();

        // Should need warmup again
        for i in 0..P {
            assert!(roc.update(100.0 + i as f64).is_none(),
                "After reset, update {} should return None", i + 1);
        }
        assert!(roc.update(200.0).is_some());
    }

    #[test]
    fn test_roc_historical_access() {
        // Test buffer storage with S=4
        const P: usize = 3;
        let mut roc = ROC::<P, 4>::new();

        // Warmup (these don't store in data buffer)
        for i in 0..P {
            roc.update(10.0 + i as f64 * 10.0);
        }

        // Add values to fill buffer (only these get stored)
        for i in 0..4 {
            roc.update(100.0 + i as f64 * 10.0);
        }

        // Access current and historical values (only 4 stored values)
        for i in 0..4 {
            assert!(roc.get(-i).is_some(), 
                "Should be able to access value at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(roc.get(-4).is_none());
    }

    #[test]
    fn test_roc_get_before_warmup() {
        // Test that get() returns None before warmup is complete
        const P: usize = 4;
        let mut roc = ROC::<P, 1>::new();

        // Before any updates
        assert!(roc.get(0).is_none());

        // During warmup
        for i in 0..P {
            roc.update(100.0 + i as f64);
            assert!(roc.get(0).is_none(), 
                "get(0) should return None during warmup at update {}", i + 1);
        }

        // After warmup
        roc.update(200.0);
        assert!(roc.get(0).is_some());
    }

    #[test]
    fn test_roc_uptrend() {
        // Test ROC in consistent uptrend
        const P: usize = 5;
        let mut roc = ROC::<P, 1>::new();

        // Steady increase: 100, 110, 120, 130, 140, 150
        for i in 0..=P {
            roc.update(100.0 + i as f64 * 10.0);
        }

        // ROC should be positive
        let result = roc.get(0).unwrap();
        assert!(result > 0.0, "ROC should be positive in uptrend");
        assert!((result - 50.0).abs() < 0.0001); // (150-100)/100*100 = 50%
    }

    #[test]
    fn test_roc_downtrend() {
        // Test ROC in consistent downtrend
        const P: usize = 5;
        let mut roc = ROC::<P, 1>::new();

        // Steady decrease: 200, 190, 180, 170, 160, 150
        for i in 0..=P {
            roc.update(200.0 - i as f64 * 10.0);
        }

        // ROC should be negative
        let result = roc.get(0).unwrap();
        assert!(result < 0.0, "ROC should be negative in downtrend");
        assert!((result - (-25.0)).abs() < 0.0001); // (150-200)/200*100 = -25%
    }

    #[test]
    fn test_roc_volatile_sequence() {
        // Test ROC with volatile movements
        const P: usize = 3;
        let mut roc = ROC::<P, 1>::new();

        roc.update(100.0);
        roc.update(105.0);
        roc.update(110.0);

        // Sharp rise
        let result = roc.update(150.0).unwrap();
        assert!((result - 50.0).abs() < 0.0001); // vs 100

        // Sharp fall
        let result = roc.update(100.0).unwrap();
        assert!((result - (-4.761905)).abs() < 0.001); // vs 105

        // Recovery
        let result = roc.update(132.0).unwrap();
        assert!((result - 20.0).abs() < 0.0001); // vs 110
    }

    #[test]
    fn test_roc_negative_prices() {
        // Test ROC with negative prices
        const P: usize = 3;
        let mut roc = ROC::<P, 1>::new();

        roc.update(-100.0);
        roc.update(-90.0);
        roc.update(-80.0);

        // From -100 to -50: ROC = ((-50) - (-100)) / (-100) * 100 = -50%
        let result = roc.update(-50.0).unwrap();
        assert!((result - (-50.0)).abs() < 0.0001);
    }

    #[test]
    fn test_roc_small_changes() {
        // Test ROC with small percentage changes
        const P: usize = 3;
        let mut roc = ROC::<P, 1>::new();

        roc.update(10000.0);
        roc.update(10005.0);
        roc.update(10010.0);

        // Small change: (10015 - 10000) / 10000 * 100 = 0.15%
        let result = roc.update(10015.0).unwrap();
        assert!((result - 0.15).abs() < 0.001);
    }

    #[test]
    fn test_roc_with_period_one() {
        // Edge case: P=1 means ROC compares to previous value
        const P: usize = 1;
        let mut roc = ROC::<P, 1>::new();

        roc.update(100.0);
        
        // vs 100: (110-100)/100*100 = 10%
        let result = roc.update(110.0).unwrap();
        assert!((result - 10.0).abs() < 0.0001);
        
        // vs 110: (105-110)/110*100 = -4.545...%
        let result = roc.update(105.0).unwrap();
        assert!((result - (-4.545454545)).abs() < 0.001);
    }

    #[test]
    fn test_roc_momentum_indicator() {
        // ROC oscillates around zero as a momentum indicator
        const P: usize = 5;
        let mut roc = ROC::<P, 1>::new();

        // Rising prices
        for i in 0..=P {
            roc.update(100.0 + i as f64 * 5.0);
        }
        assert!(roc.get(0).unwrap() > 0.0);

        // Stabilizing at higher level
        for _ in 0..P {
            roc.update(150.0);
        }
        // Should approach zero as momentum fades
        let result = roc.get(0).unwrap();
        assert!(result.abs() < 50.0); // Much less momentum than before
    }
}
