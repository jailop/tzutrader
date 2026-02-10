//! Momentum (MOM)
//!
//! Simple Momentum - Current price minus price N periods ago.
//! Foundation for many other indicators.
//! Positive = upward momentum, Negative = downward momentum.
//!
//! # Type Parameters
//! - `P`: Lookback period (compile-time constant)
//! - `S`: Number of recent momentum values to store (compile-time constant, default 1)

use super::{base::BaseIndicator, Indicator};

#[derive(Debug, Clone)]
pub struct MOM<const P: usize, const S: usize = 1> {
    prices: [f64; P],
    pos: usize,
    length: usize,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> MOM<P, S> {
    pub fn new() -> Self {
        Self {
            prices: [f64::NAN; P],
            pos: 0,
            length: 0,
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for MOM<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for MOM<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, price: f64) -> Option<f64> {
        if self.length < P {
            self.prices[self.pos] = price;
            self.pos = (self.pos + 1) % P;
            self.length += 1;
            return None;
        }
        
        let old_price = self.prices[self.pos];
        let momentum = price - old_price;

        self.prices[self.pos] = price;
        self.pos = (self.pos + 1) % P;

        self.data.update(momentum);
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.pos = 0;
        self.length = 0;
        self.prices = [f64::NAN; P];
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mom_warmup_period() {
        // MOM needs P values before calculating momentum
        const P: usize = 5;
        let mut mom = MOM::<P, 1>::new();

        // During warmup: should return None
        for i in 0..P {
            assert!(mom.update(100.0 + i as f64).is_none(), 
                "Update {} should return None during warmup", i + 1);
        }
        
        // After warmup: should return Some
        assert!(mom.update(110.0).is_some());
    }

    #[test]
    fn test_mom_positive_momentum() {
        // Test upward momentum (current price > old price)
        const P: usize = 3;
        let mut mom = MOM::<P, 1>::new();

        // Warmup with prices: 100, 105, 110
        mom.update(100.0);
        mom.update(105.0);
        mom.update(110.0);

        // Current: 115, P periods ago: 100
        // Momentum = 115 - 100 = 15
        let result = mom.update(115.0);
        assert_eq!(result, Some(15.0));
    }

    #[test]
    fn test_mom_negative_momentum() {
        // Test downward momentum (current price < old price)
        const P: usize = 3;
        let mut mom = MOM::<P, 1>::new();

        // Warmup with prices: 100, 95, 90
        mom.update(100.0);
        mom.update(95.0);
        mom.update(90.0);

        // Current: 85, P periods ago: 100
        // Momentum = 85 - 100 = -15
        let result = mom.update(85.0);
        assert_eq!(result, Some(-15.0));
    }

    #[test]
    fn test_mom_zero_momentum() {
        // Test no momentum (current price == old price)
        const P: usize = 4;
        let mut mom = MOM::<P, 1>::new();

        // Warmup with constant price
        for _ in 0..P {
            mom.update(100.0);
        }

        // Current price same as P periods ago
        // Momentum = 100 - 100 = 0
        let result = mom.update(100.0);
        assert_eq!(result, Some(0.0));
    }

    #[test]
    fn test_mom_calculation_accuracy() {
        // Verify momentum calculation over a series
        const P: usize = 3;
        let mut mom = MOM::<P, 1>::new();

        // Prices: 10, 20, 30, 40, 50, 60
        let prices = vec![10.0, 20.0, 30.0, 40.0, 50.0, 60.0];
        
        for (i, &price) in prices.iter().enumerate() {
            let result = mom.update(price);
            
            if i < P {
                assert!(result.is_none());
            } else {
                // Momentum = current - price_P_periods_ago
                let expected = price - prices[i - P];
                assert_eq!(result, Some(expected),
                    "At index {}: expected {}, got {:?}", i, expected, result);
            }
        }
    }

    #[test]
    fn test_mom_circular_buffer() {
        // Test that circular buffer works correctly
        const P: usize = 3;
        let mut mom = MOM::<P, 1>::new();

        // Fill buffer: 100, 110, 120
        mom.update(100.0);
        mom.update(110.0);
        mom.update(120.0);

        // Update 130 (momentum vs 100) = 30
        assert_eq!(mom.update(130.0), Some(30.0));
        
        // Update 140 (momentum vs 110) = 30
        assert_eq!(mom.update(140.0), Some(30.0));
        
        // Update 150 (momentum vs 120) = 30
        assert_eq!(mom.update(150.0), Some(30.0));
        
        // Update 160 (momentum vs 130 - buffer wrapped) = 30
        assert_eq!(mom.update(160.0), Some(30.0));
    }

    #[test]
    fn test_mom_trend_detection() {
        // Test momentum in different trend scenarios
        const P: usize = 5;
        let mut mom = MOM::<P, 1>::new();

        // Uptrend: steadily increasing prices
        // Prices: 100, 110, 120, 130, 140, 150
        for i in 0..=P {
            mom.update(100.0 + i as f64 * 10.0);
        }
        
        let uptrend_mom = mom.get(0).unwrap();
        // Momentum = 150 - 100 = 50
        assert!(uptrend_mom > 0.0, "Momentum should be positive in uptrend");
        assert_eq!(uptrend_mom, 50.0);

        // Continue with flat prices at 150
        for _ in 0..P {
            mom.update(150.0);
        }
        
        let flat_mom = mom.get(0).unwrap();
        // Now comparing 150 vs price from P periods ago (which is also 150)
        // Momentum = 150 - 150 = 0
        assert_eq!(flat_mom, 0.0, "Momentum should be zero when prices are flat");
    }

    #[test]
    fn test_mom_reset() {
        const P: usize = 3;
        let mut mom = MOM::<P, 1>::new();

        // Add values
        for i in 1..=10 {
            mom.update(i as f64 * 10.0);
        }
        
        assert!(mom.get(0).is_some());

        // Reset
        mom.reset();

        // Should need warmup again
        for i in 0..P {
            assert!(mom.update(100.0 + i as f64).is_none(),
                "After reset, update {} should return None", i + 1);
        }
        assert!(mom.update(200.0).is_some());
    }

    #[test]
    fn test_mom_historical_access() {
        // Test buffer storage with S=5
        const P: usize = 3;
        let mut mom = MOM::<P, 5>::new();

        // Warmup
        for i in 0..P {
            mom.update(10.0 * i as f64);
        }

        // Add more values to fill buffer
        for i in 0..5 {
            mom.update(100.0 + i as f64 * 10.0);
        }

        // Access current and historical values
        for i in 0..5 {
            assert!(mom.get(-i).is_some(), 
                "Should be able to access value at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(mom.get(-5).is_none());
    }

    #[test]
    fn test_mom_get_before_warmup() {
        // Test that get() returns None before warmup is complete
        const P: usize = 4;
        let mut mom = MOM::<P, 1>::new();

        // Before any updates
        assert!(mom.get(0).is_none());

        // During warmup
        for i in 0..P {
            mom.update(100.0 + i as f64);
            assert!(mom.get(0).is_none(), 
                "get(0) should return None during warmup at update {}", i + 1);
        }

        // After warmup
        mom.update(200.0);
        assert!(mom.get(0).is_some());
    }

    #[test]
    fn test_mom_price_reversal() {
        // Test momentum during price reversal
        const P: usize = 5;
        let mut mom = MOM::<P, 1>::new();

        // Strong uptrend: 100, 110, 120, 130, 140
        for i in 0..=P {
            mom.update(100.0 + i as f64 * 10.0);
        }
        
        let peak_momentum = mom.get(0).unwrap();
        assert!(peak_momentum > 0.0, "Should have positive momentum in uptrend");

        // Price reversal - start declining
        for i in 1..=P {
            mom.update(150.0 - i as f64 * 10.0);
        }

        let reversal_momentum = mom.get(0).unwrap();
        assert!(reversal_momentum < peak_momentum, 
            "Momentum should decrease after reversal");
    }

    #[test]
    fn test_mom_with_period_one() {
        // Edge case: P=1 means momentum = current - previous
        const P: usize = 1;
        let mut mom = MOM::<P, 1>::new();

        mom.update(100.0);
        
        // Momentum = 105 - 100 = 5
        assert_eq!(mom.update(105.0), Some(5.0));
        
        // Momentum = 103 - 105 = -2
        assert_eq!(mom.update(103.0), Some(-2.0));
        
        // Momentum = 110 - 103 = 7
        assert_eq!(mom.update(110.0), Some(7.0));
    }
}
