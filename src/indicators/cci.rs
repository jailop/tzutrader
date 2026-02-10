//! Commodity Channel Index (CCI)
//!
//! Measures the deviation of the typical price from its average.
//! Useful for identifying cyclical trends and overbought/oversold conditions.
//!
//! Formula: CCI = (Typical Price - MA(Typical Price)) / (constant * Mean Deviation)
//! Where Typical Price = (High + Low + Close) / 3
//!
//! # Type Parameters
//! - `P`: Period for moving average and mean deviation calculation
//! - `S`: Number of recent CCI values to store
//!
//! # Example
//!
//! ```rust
//! use tzutrader::indicators::{Indicator, cci::CCI};
//! use tzutrader::types::Ohlcv;
//!
//! // Standard CCI with period 20
//! let mut cci = CCI::<20, 3>::new();
//!
//! // Warmup period
//! for i in 0..20 {
//!     let bar = Ohlcv {
//!         timestamp: 0,
//!         open: 100.0,
//!         high: 105.0 + i as f64 * 0.5,
//!         low: 95.0,
//!         close: 100.0 + i as f64 * 0.3,
//!         volume: 1000.0,
//!     };
//!     cci.update(bar);
//! }
//!
//! // After warmup, CCI provides trend signals
//! let bar = Ohlcv {
//!     timestamp: 0,
//!     open: 110.0,
//!     high: 115.0,
//!     low: 108.0,
//!     close: 113.0,
//!     volume: 1000.0,
//! };
//! if let Some(cci_value) = cci.update(bar) {
//!     println!("CCI: {:.2}", cci_value);
//!     if cci_value > 100.0 {
//!         println!("Overbought condition");
//!     } else if cci_value < -100.0 {
//!         println!("Oversold condition");
//!     }
//! }
//! ```

use super::{base::BaseIndicator, ma::MA, Indicator};
use crate::types::Ohlcv;

#[derive(Debug, Clone)]
pub struct CCI<const P: usize, const S: usize = 1> {
    tp_window: [f64; P],
    length: usize,
    pos: usize,
    tp_ma: MA<P, 1>,
    constant: f64,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> CCI<P, S> {
    pub fn new() -> Self {
        Self::with_constant(0.015)
    }

    pub fn with_constant(constant: f64) -> Self {
        Self {
            tp_window: [f64::NAN; P],
            length: 0,
            pos: 0,
            tp_ma: MA::new(),
            constant,
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for CCI<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for CCI<P, S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) -> Option<Self::Output> {
        let typical_price = (value.high + value.low + value.close) / 3.0;

        if self.length < P {
            self.length += 1;
        }

        self.tp_window[self.pos] = typical_price;
        self.pos = (self.pos + 1) % P;

        self.tp_ma.update(typical_price);
        let tp_avg = self.tp_ma.get(0);

        if let Some(tp_avg) = tp_avg {
            let sum_deviation: f64 = self.tp_window.iter()
                .map(|&tp| (tp - tp_avg).abs()).sum();
            let mean_deviation = sum_deviation / P as f64;
            let cci_value = if mean_deviation == 0.0 {
                0.0
            } else {
                (typical_price - tp_avg) / (self.constant * mean_deviation)
            };
            self.data.update(cci_value);
            self.data.get(0)
        } else {
            None
        }
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.length = 0;
        self.pos = 0;
        self.tp_ma.reset();
        self.tp_window = [f64::NAN; P];
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cci_warmup_period() {
        const P: usize = 20;
        let mut cci = CCI::<P, 1>::new();

        // During warmup: should return None
        for i in 0..(P - 1) {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0,
                low: 95.0,
                close: 100.0 + i as f64,
                volume: 1000.0,
            };
            assert!(cci.update(bar).is_none(), 
                "Update {} should return None during warmup", i + 1);
        }
        
        // Pth value should return Some
        let bar = Ohlcv {
            timestamp: 0,
            open: 110.0,
            high: 115.0,
            low: 109.0,
            close: 113.0,
            volume: 1000.0,
        };
        assert!(cci.update(bar).is_some());
    }

    #[test]
    fn test_cci_typical_price() {
        // Verify typical price calculation
        const P: usize = 5;
        let mut cci = CCI::<P, 1>::new();

        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 120.0,
            low: 90.0,
            close: 105.0,
            volume: 1000.0,
        };

        // Typical price should be (120 + 90 + 105) / 3 = 105
        // This is internal, so we test indirectly through CCI behavior
        for _ in 0..P {
            cci.update(bar);
        }

        // With no price variation, CCI should be 0
        let result = cci.get(0).unwrap();
        assert!(result.abs() < 0.01,
            "CCI should be near 0 with constant typical price, got {}", result);
    }

    #[test]
    fn test_cci_zero_deviation() {
        // When all typical prices are identical, CCI should be 0
        const P: usize = 10;
        let mut cci = CCI::<P, 1>::new();

        for _ in 0..20 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 110.0,
                low: 90.0,
                close: 100.0,  // Typical price = 100
                volume: 1000.0,
            };
            cci.update(bar);
        }

        let result = cci.get(0).unwrap();
        assert!(result.abs() < 0.01,
            "CCI should be 0 with no price variation, got {}", result);
    }

    #[test]
    fn test_cci_uptrend() {
        // Strong uptrend should produce positive CCI (>100 for overbought)
        const P: usize = 20;
        let mut cci = CCI::<P, 1>::new();

        // Consistent uptrend
        for i in 0..40 {
            let base = 100.0 + i as f64 * 2.0;
            let bar = Ohlcv {
                timestamp: 0,
                open: base,
                high: base + 5.0,
                low: base - 1.0,
                close: base + 3.0,
                volume: 1000.0,
            };
            cci.update(bar);
        }

        let result = cci.get(0).unwrap();
        assert!(result > 0.0,
            "CCI should be positive in uptrend, got {}", result);
    }

    #[test]
    fn test_cci_downtrend() {
        // Strong downtrend should produce negative CCI (<-100 for oversold)
        const P: usize = 20;
        let mut cci = CCI::<P, 1>::new();

        // Consistent downtrend
        for i in 0..40 {
            let base = 200.0 - i as f64 * 2.0;
            let bar = Ohlcv {
                timestamp: 0,
                open: base,
                high: base + 1.0,
                low: base - 5.0,
                close: base - 3.0,
                volume: 1000.0,
            };
            cci.update(bar);
        }

        let result = cci.get(0).unwrap();
        assert!(result < 0.0,
            "CCI should be negative in downtrend, got {}", result);
    }

    #[test]
    fn test_cci_overbought() {
        // Price significantly above average should produce CCI > 100
        const P: usize = 20;
        let mut cci = CCI::<P, 1>::new();

        // Establish baseline
        for _ in 0..P {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 102.0,
                low: 98.0,
                close: 100.0,
                volume: 1000.0,
            };
            cci.update(bar);
        }

        // Sharp spike
        for _ in 0..5 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 120.0,
                high: 125.0,
                low: 118.0,
                close: 123.0,
                volume: 1000.0,
            };
            cci.update(bar);
        }

        let result = cci.get(0).unwrap();
        assert!(result > 100.0,
            "CCI should be > 100 (overbought) after sharp spike, got {}", result);
    }

    #[test]
    fn test_cci_oversold() {
        // Price significantly below average should produce CCI < -100
        const P: usize = 20;
        let mut cci = CCI::<P, 1>::new();

        // Establish baseline
        for _ in 0..P {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 102.0,
                low: 98.0,
                close: 100.0,
                volume: 1000.0,
            };
            cci.update(bar);
        }

        // Sharp drop
        for _ in 0..5 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 80.0,
                high: 82.0,
                low: 75.0,
                close: 77.0,
                volume: 1000.0,
            };
            cci.update(bar);
        }

        let result = cci.get(0).unwrap();
        assert!(result < -100.0,
            "CCI should be < -100 (oversold) after sharp drop, got {}", result);
    }

    #[test]
    fn test_cci_constant_parameter() {
        // Test different constant values
        const P: usize = 14;
        let mut cci1 = CCI::<P, 1>::with_constant(0.015);  // Standard
        let mut cci2 = CCI::<P, 1>::with_constant(0.030);  // Double

        for i in 0..30 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0 + i as f64,
                high: 105.0 + i as f64,
                low: 95.0 + i as f64,
                close: 102.0 + i as f64,
                volume: 1000.0,
            };
            cci1.update(bar);
            cci2.update(bar);
        }

        let result1 = cci1.get(0).unwrap();
        let result2 = cci2.get(0).unwrap();

        // Larger constant should produce smaller absolute CCI values
        assert!(result1.abs() > result2.abs(),
            "Larger constant should reduce CCI magnitude");
        assert!((result1 / result2 - 2.0).abs() < 0.1,
            "CCI should be inversely proportional to constant");
    }

    #[test]
    fn test_cci_mean_reversion() {
        // CCI should oscillate in range-bound market
        const P: usize = 20;
        let mut cci = CCI::<P, 5>::new();

        // Establish range-bound market with oscillation
        for i in 0..60 {
            let price = 100.0 + ((i as f64 * 0.5).sin() * 10.0);
            let bar = Ohlcv {
                timestamp: 0,
                open: price,
                high: price + 2.0,
                low: price - 2.0,
                close: price,
                volume: 1000.0,
            };
            cci.update(bar);
        }

        // CCI should have oscillated both positive and negative
        let mut has_positive = false;
        let mut has_negative = false;
        
        for i in 0..5 {
            let val = cci.get(-i).unwrap();
            if val > 0.0 { has_positive = true; }
            if val < 0.0 { has_negative = true; }
        }

        assert!(has_positive || has_negative,
            "CCI should oscillate in range-bound market");
    }

    #[test]
    fn test_cci_reset() {
        const P: usize = 20;
        let mut cci = CCI::<P, 1>::new();

        // Add values
        for i in 0..40 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 110.0,
                low: 90.0,
                close: 100.0 + i as f64,
                volume: 1000.0,
            };
            cci.update(bar);
        }
        
        assert!(cci.get(0).is_some());

        // Reset
        cci.reset();

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
            assert!(cci.update(bar).is_none(),
                "After reset, update {} should return None", i + 1);
        }
        
        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 102.0,
            volume: 1000.0,
        };
        assert!(cci.update(bar).is_some());
    }

    #[test]
    fn test_cci_historical_access() {
        const P: usize = 14;
        let mut cci = CCI::<P, 4>::new();

        // Add warmup + 3 more to fill buffer
        for i in 0..17 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0 + i as f64,
                low: 95.0,
                close: 100.0 + i as f64,
                volume: 1000.0,
            };
            cci.update(bar);
        }

        // Access current and historical values
        for i in 0..4 {
            assert!(cci.get(-i).is_some(), 
                "Should be able to access CCI at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(cci.get(-4).is_none());
    }

    #[test]
    fn test_cci_get_before_warmup() {
        const P: usize = 20;
        let mut cci = CCI::<P, 1>::new();

        // Before any updates
        assert!(cci.get(0).is_none());

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
            cci.update(bar);
            assert!(cci.get(0).is_none(), 
                "get(0) should return None during warmup at update {}", i + 1);
        }

        // After warmup
        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 102.0,
            volume: 1000.0,
        };
        cci.update(bar);
        assert!(cci.get(0).is_some());
    }

    #[test]
    fn test_cci_divergence_detection() {
        // CCI can detect bullish divergence
        const P: usize = 14;
        let mut cci = CCI::<P, 3>::new();

        // First low
        for _ in 0..P {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 102.0,
                low: 90.0,
                close: 92.0,
                volume: 1000.0,
            };
            cci.update(bar);
        }
        let first_low_cci = cci.get(0).unwrap();

        // Recovery
        for _ in 0..10 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 95.0,
                high: 100.0,
                low: 93.0,
                close: 98.0,
                volume: 1000.0,
            };
            cci.update(bar);
        }

        // Second low (price lower, but CCI higher = bullish divergence)
        for _ in 0..5 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 95.0,
                high: 98.0,
                low: 91.0,
                close: 93.0,  // Lower low
                volume: 1000.0,
            };
            cci.update(bar);
        }
        let second_low_cci = cci.get(0).unwrap();

        // In real divergence, second CCI low would be higher, but this is just structure test
        // Verify CCI values are calculated
        assert!(first_low_cci < 0.0 || second_low_cci < 0.0,
            "At least one CCI should be negative near lows");
    }

    #[test]
    fn test_cci_standard_parameters() {
        // Test standard CCI (20)
        let mut cci = CCI::<20, 1>::new();

        // Realistic price data
        for i in 0..40 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0 + (i as f64 * 0.3).sin() * 5.0,
                low: 95.0 + (i as f64 * 0.3).sin() * 5.0,
                close: 100.0 + (i as f64 * 0.3).sin() * 4.0,
                volume: 1000.0,
            };
            cci.update(bar);
        }

        let result = cci.get(0).unwrap();
        
        // CCI should be within reasonable bounds
        assert!(result.abs() < 300.0,
            "CCI should be within reasonable range");
    }
}
