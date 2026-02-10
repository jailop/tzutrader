//! Average True Range (ATR)
//!
//! ATR measures market volatility by decomposing the entire range of an asset
//! price for that period. It uses the true range, which is the greatest of:
//! - Current High minus Current Low
//! - Absolute value of Current High minus Previous Close
//! - Absolute value of Current Low minus Previous Close
//!
//! # Type Parameters
//! - `P`: Period for averaging true range (compile-time constant)
//! - `S`: Number of recent ATR values to store (compile-time constant, default 1)
//!
//! # Example
//!
//! ```rust
//! use tzutrader::indicators::{Indicator, ATR};
//! use tzutrader::types::Ohlcv;
//!
//! let mut atr = ATR::<14, 3>::new();
//!
//! // Warmup period - needs P values before producing results
//! for i in 0..14 {
//!     let bar = Ohlcv {
//!         timestamp: 0,
//!         open: 100.0,
//!         high: 105.0 + i as f64,
//!         low: 95.0,
//!         close: 100.0,
//!         volume: 1000.0,
//!     };
//!     let result = atr.update(bar);
//!     if i < 13 {
//!         assert!(result.is_none());
//!     }
//! }
//!
//! // After warmup, ATR provides volatility measurement
//! let bar = Ohlcv {
//!     timestamp: 0,
//!     open: 100.0,
//!     high: 110.0,
//!     low: 95.0,
//!     close: 105.0,
//!     volume: 1000.0,
//! };
//! let result = atr.update(bar).unwrap();
//! println!("ATR: {:.2}", result);
//! ```

use super::{base::BaseIndicator, ma::MA, Indicator};
use crate::types::Ohlcv;

#[derive(Debug, Clone)]
pub struct ATR<const P: usize, const S: usize = 1> {
    prev_close: f64,
    ma: MA<P, 1>,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> ATR<P, S> {
    pub fn new() -> Self {
        Self {
            prev_close: f64::NAN,
            ma: MA::new(),
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for ATR<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for ATR<P, S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) -> Option<f64> {
        let tr = if self.prev_close.is_nan() {
            value.high - value.low
        } else {
            let hl = value.high - value.low;
            let hc = (value.high - self.prev_close).abs();
            let lc = (value.low - self.prev_close).abs();
            hl.max(hc).max(lc)
        };

        self.prev_close = value.close;
        self.ma.update(tr);
        let atr_value = self.ma.get(0);
        
        if let Some(atr) = atr_value {
            self.data.update(atr);
        }
        
        atr_value
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.prev_close = f64::NAN;
        self.ma.reset();
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_atr_warmup_period() {
        // ATR needs P values before producing results (via MA)
        const P: usize = 5;
        let mut atr = ATR::<P, 1>::new();

        // During warmup: should return None
        for i in 0..(P - 1) {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0,
                low: 95.0,
                close: 100.0,
                volume: 1000.0,
            };
            assert!(atr.update(bar).is_none(), 
                "Update {} should return None during warmup", i + 1);
        }
        
        // Pth value should return Some
        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 100.0,
            volume: 1000.0,
        };
        assert!(atr.update(bar).is_some());
    }

    #[test]
    fn test_atr_first_bar_tr() {
        // First bar should use high - low as true range
        const P: usize = 3;
        let mut atr = ATR::<P, 1>::new();

        let bar1 = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 110.0,
            low: 90.0,
            close: 105.0,
            volume: 1000.0,
        };
        atr.update(bar1);

        // Second bar
        let bar2 = Ohlcv {
            timestamp: 0,
            open: 105.0,
            high: 115.0,
            low: 100.0,
            close: 110.0,
            volume: 1000.0,
        };
        atr.update(bar2);

        // Third bar - should return ATR
        let bar3 = Ohlcv {
            timestamp: 0,
            open: 110.0,
            high: 120.0,
            low: 105.0,
            close: 115.0,
            volume: 1000.0,
        };
        let result = atr.update(bar3);
        assert!(result.is_some());
        assert!(result.unwrap() > 0.0);
    }

    #[test]
    fn test_atr_true_range_calculation() {
        // Test all three components of true range
        const P: usize = 3;
        let mut atr = ATR::<P, 1>::new();

        // First bar: TR = high - low = 110 - 90 = 20
        let bar1 = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 110.0,
            low: 90.0,
            close: 100.0,
            volume: 1000.0,
        };
        atr.update(bar1);

        // Second bar: high-low=10, high-prevClose=5, low-prevClose=5 -> TR=10
        let bar2 = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 102.0,
            volume: 1000.0,
        };
        atr.update(bar2);

        // Third bar: high-low=20, high-prevClose=8, low-prevClose=12 -> TR=20
        let bar3 = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 110.0,
            low: 90.0,
            close: 105.0,
            volume: 1000.0,
        };
        
        // ATR should be average of [20, 10, 20] = 16.666...
        let result = atr.update(bar3).unwrap();
        assert!((result - 16.666667).abs() < 0.01);
    }

    #[test]
    fn test_atr_gap_up() {
        // Test ATR when there's a gap up (high - prev_close larger than high - low)
        const P: usize = 3;
        let mut atr = ATR::<P, 1>::new();

        let bar1 = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 100.0,
            volume: 1000.0,
        };
        atr.update(bar1);

        let bar2 = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 100.0,
            volume: 1000.0,
        };
        atr.update(bar2);

        // Gap up: opens and stays above previous close
        let bar3 = Ohlcv {
            timestamp: 0,
            open: 120.0,
            high: 125.0,
            low: 115.0,
            close: 120.0,
            volume: 1000.0,
        };
        
        // TR should use high - prev_close = 125 - 100 = 25
        let result = atr.update(bar3).unwrap();
        // ATR = average of [10, 10, 25] = 15
        assert!((result - 15.0).abs() < 0.01);
    }

    #[test]
    fn test_atr_gap_down() {
        // Test ATR when there's a gap down (prev_close - low larger than high - low)
        const P: usize = 3;
        let mut atr = ATR::<P, 1>::new();

        let bar1 = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 100.0,
            volume: 1000.0,
        };
        atr.update(bar1);

        let bar2 = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 100.0,
            volume: 1000.0,
        };
        atr.update(bar2);

        // Gap down: opens and stays below previous close
        let bar3 = Ohlcv {
            timestamp: 0,
            open: 80.0,
            high: 85.0,
            low: 75.0,
            close: 80.0,
            volume: 1000.0,
        };
        
        // TR should use prev_close - low = 100 - 75 = 25
        let result = atr.update(bar3).unwrap();
        // ATR = average of [10, 10, 25] = 15
        assert!((result - 15.0).abs() < 0.01);
    }

    #[test]
    fn test_atr_increasing_volatility() {
        // Test that ATR increases with increasing volatility
        const P: usize = 5;
        let mut atr = ATR::<P, 1>::new();

        // Low volatility period
        for _ in 0..P {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 102.0,
                low: 98.0,
                close: 100.0,
                volume: 1000.0,
            };
            atr.update(bar);
        }
        let low_vol_atr = atr.get(0).unwrap();

        // High volatility period
        for _ in 0..P {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 120.0,
                low: 80.0,
                close: 100.0,
                volume: 1000.0,
            };
            atr.update(bar);
        }
        let high_vol_atr = atr.get(0).unwrap();

        assert!(high_vol_atr > low_vol_atr,
            "ATR should increase with higher volatility");
    }

    #[test]
    fn test_atr_constant_range() {
        // Test ATR with constant range
        const P: usize = 4;
        let mut atr = ATR::<P, 1>::new();

        // All bars have same range of 10
        for _ in 0..10 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0,
                low: 95.0,
                close: 100.0,
                volume: 1000.0,
            };
            atr.update(bar);
        }

        let result = atr.get(0).unwrap();
        assert!((result - 10.0).abs() < 0.01,
            "ATR should converge to constant range");
    }

    #[test]
    fn test_atr_reset() {
        const P: usize = 3;
        let mut atr = ATR::<P, 1>::new();

        // Add values
        for i in 0..10 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 110.0 + i as f64,
                low: 90.0,
                close: 100.0,
                volume: 1000.0,
            };
            atr.update(bar);
        }
        
        assert!(atr.get(0).is_some());

        // Reset
        atr.reset();

        // Should need warmup again
        for i in 0..(P - 1) {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0,
                low: 95.0,
                close: 100.0,
                volume: 1000.0,
            };
            assert!(atr.update(bar).is_none(),
                "After reset, update {} should return None", i + 1);
        }
        
        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 100.0,
            volume: 1000.0,
        };
        assert!(atr.update(bar).is_some());
    }

    #[test]
    fn test_atr_historical_access() {
        // Test buffer storage with S=4
        const P: usize = 3;
        let mut atr = ATR::<P, 4>::new();

        // Add enough values - first P-1 don't store, then 4 more to fill buffer
        for i in 0..6 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0 + i as f64,
                low: 95.0,
                close: 100.0,
                volume: 1000.0,
            };
            atr.update(bar);
        }

        // Access current and historical values (only 4 stored)
        for i in 0..4 {
            assert!(atr.get(-i).is_some(), 
                "Should be able to access value at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(atr.get(-4).is_none());
    }

    #[test]
    fn test_atr_get_before_warmup() {
        // Test that get() returns None before warmup is complete
        const P: usize = 4;
        let mut atr = ATR::<P, 1>::new();

        // Before any updates
        assert!(atr.get(0).is_none());

        // During warmup
        for i in 0..(P - 1) {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0,
                low: 95.0,
                close: 100.0,
                volume: 1000.0,
            };
            atr.update(bar);
            assert!(atr.get(0).is_none(), 
                "get(0) should return None during warmup at update {}", i + 1);
        }

        // After warmup
        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 100.0,
            volume: 1000.0,
        };
        atr.update(bar);
        assert!(atr.get(0).is_some());
    }

    #[test]
    fn test_atr_always_positive() {
        // ATR should always be non-negative
        const P: usize = 5;
        let mut atr = ATR::<P, 1>::new();

        // Various scenarios
        for i in 0..20 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0 + (i as f64 * 2.0),
                high: 110.0 + (i as f64 * 2.0),
                low: 90.0 + (i as f64 * 2.0),
                close: 105.0 + (i as f64 * 2.0),
                volume: 1000.0,
            };
            if let Some(atr_val) = atr.update(bar) {
                assert!(atr_val >= 0.0, "ATR must be non-negative, got {}", atr_val);
            }
        }
    }

    #[test]
    fn test_atr_volatility_measure() {
        // ATR should capture volatility regardless of direction
        const P: usize = 5;
        let mut atr1 = ATR::<P, 1>::new();
        let mut atr2 = ATR::<P, 1>::new();

        // Uptrend with volatility
        for i in 0..=P {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0 + i as f64 * 10.0,
                high: 120.0 + i as f64 * 10.0,
                low: 80.0 + i as f64 * 10.0,
                close: 110.0 + i as f64 * 10.0,
                volume: 1000.0,
            };
            atr1.update(bar);
        }

        // Downtrend with same volatility
        for i in 0..=P {
            let bar = Ohlcv {
                timestamp: 0,
                open: 200.0 - i as f64 * 10.0,
                high: 220.0 - i as f64 * 10.0,
                low: 180.0 - i as f64 * 10.0,
                close: 210.0 - i as f64 * 10.0,
                volume: 1000.0,
            };
            atr2.update(bar);
        }

        let atr1_val = atr1.get(0).unwrap();
        let atr2_val = atr2.get(0).unwrap();

        // Both should have similar ATR (volatility independent of direction)
        assert!((atr1_val - atr2_val).abs() < 5.0,
            "ATR should measure volatility independent of trend direction");
    }
}
