//! Relative Strength Index (RSI)
//!
//! RSI measures the magnitude of recent price changes to evaluate
//! overbought or oversold conditions in the price of a stock or other asset.
//! RSI values range from 0 to 100, with values above 70 typically considered
//! overbought and values below 30 considered oversold.
//!
//! # Type Parameters
//! - `P`: Period for calculating average gains and losses (compile-time constant)
//! - `S`: Number of recent RSI values to store (compile-time constant, default 1)
//!
//! # Example
//!
//! ```rust
//! use tzutrader::indicators::{Indicator, RSI};
//! use tzutrader::types::Ohlcv;
//!
//! let mut rsi = RSI::<14, 3>::new();
//!
//! // Warmup period - needs P values
//! for i in 0..14 {
//!     let bar = Ohlcv {
//!         timestamp: 0,
//!         open: 100.0,
//!         high: 105.0,
//!         low: 95.0,
//!         close: 100.0 + i as f64,
//!         volume: 1000.0,
//!     };
//!     rsi.update(bar);
//! }
//!
//! // After warmup, RSI provides overbought/oversold signals
//! let bar = Ohlcv {
//!     timestamp: 0,
//!     open: 115.0,
//!     high: 120.0,
//!     low: 114.0,
//!     close: 118.0,
//!     volume: 1000.0,
//! };
//! if let Some(rsi_value) = rsi.update(bar) {
//!     println!("RSI: {:.2}", rsi_value);
//!     if rsi_value > 70.0 {
//!         println!("Overbought condition");
//!     } else if rsi_value < 30.0 {
//!         println!("Oversold condition");
//!     }
//! }
//! ```

use super::{base::BaseIndicator, ma::MA, Indicator};
use crate::types::Ohlcv;

#[derive(Debug, Clone)]
pub struct RSI<const P: usize, const S: usize = 1> {
    gains: MA<P, 1>,
    losses: MA<P, 1>,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> RSI<P, S> {
    pub fn new() -> Self {
        Self {
            gains: MA::new(),
            losses: MA::new(),
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for RSI<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for RSI<P, S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) -> Option<f64> {
        let diff = value.close - value.open;
        self.gains.update(if diff >= 0.0 { diff } else { 0.0 });
        self.losses.update(if diff < 0.0 { -diff } else { 0.0 });

        let loss_avg = self.losses.get(0);
        if loss_avg.is_none() {
            return None;
        }
        
        let gain_avg = self.gains.get(0).unwrap();
        let loss_val = loss_avg.unwrap();
        
        let rsi_value = if loss_val == 0.0 {
            100.0  // No losses means RSI = 100
        } else {
            100.0 - 100.0 / (1.0 + gain_avg / loss_val)
        };
        
        self.data.update(rsi_value);
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.gains.reset();
        self.losses.reset();
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rsi_warmup_period() {
        const P: usize = 14;
        let mut rsi = RSI::<P, 1>::new();

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
            assert!(rsi.update(bar).is_none(), 
                "Update {} should return None during warmup", i + 1);
        }
        
        // Pth value should return Some
        let bar = Ohlcv {
            timestamp: 0,
            open: 110.0,
            high: 115.0,
            low: 109.0,
            close: 114.0,
            volume: 1000.0,
        };
        assert!(rsi.update(bar).is_some());
    }

    #[test]
    fn test_rsi_range() {
        // RSI should always be between 0 and 100
        const P: usize = 10;
        let mut rsi = RSI::<P, 1>::new();

        // Various price movements
        for i in 0..50 {
            let close = if i % 3 == 0 {
                100.0 + i as f64
            } else if i % 3 == 1 {
                100.0 - i as f64 * 0.5
            } else {
                100.0
            };
            
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 110.0,
                low: 90.0,
                close,
                volume: 1000.0,
            };
            
            if let Some(rsi_val) = rsi.update(bar) {
                assert!(rsi_val >= 0.0 && rsi_val <= 100.0,
                    "RSI must be between 0 and 100, got {}", rsi_val);
            }
        }
    }

    #[test]
    fn test_rsi_uptrend() {
        // Strong uptrend should produce high RSI (overbought)
        const P: usize = 14;
        let mut rsi = RSI::<P, 1>::new();

        // Consistent gains
        for i in 0..30 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0 + i as f64,
                high: 105.0 + i as f64,
                low: 99.0 + i as f64,
                close: 103.0 + i as f64,
                volume: 1000.0,
            };
            rsi.update(bar);
        }

        let rsi_val = rsi.get(0).unwrap();
        assert!(rsi_val > 70.0, 
            "RSI should be > 70 (overbought) in strong uptrend, got {}", rsi_val);
    }

    #[test]
    fn test_rsi_downtrend() {
        // Strong downtrend should produce low RSI (oversold)
        const P: usize = 14;
        let mut rsi = RSI::<P, 1>::new();

        // Consistent losses
        for i in 0..30 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 200.0 - i as f64,
                high: 201.0 - i as f64,
                low: 195.0 - i as f64,
                close: 197.0 - i as f64,
                volume: 1000.0,
            };
            rsi.update(bar);
        }

        let rsi_val = rsi.get(0).unwrap();
        assert!(rsi_val < 30.0, 
            "RSI should be < 30 (oversold) in strong downtrend, got {}", rsi_val);
    }

    #[test]
    fn test_rsi_neutral() {
        // Flat market should produce neutral RSI around 50
        const P: usize = 14;
        let mut rsi = RSI::<P, 1>::new();

        // No net change (equal gains and losses)
        for i in 0..30 {
            let close = if i % 2 == 0 { 101.0 } else { 99.0 };
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 102.0,
                low: 98.0,
                close,
                volume: 1000.0,
            };
            rsi.update(bar);
        }

        let rsi_val = rsi.get(0).unwrap();
        assert!((rsi_val - 50.0).abs() < 20.0,
            "RSI should be near 50 in neutral market, got {}", rsi_val);
    }

    #[test]
    fn test_rsi_no_losses() {
        // All gains, no losses should give RSI = 100
        const P: usize = 5;
        let mut rsi = RSI::<P, 1>::new();

        for i in 0..10 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0 + i as f64,
                high: 105.0 + i as f64,
                low: 99.0 + i as f64,
                close: 103.0 + i as f64,
                volume: 1000.0,
            };
            rsi.update(bar);
        }

        let rsi_val = rsi.get(0).unwrap();
        assert!((rsi_val - 100.0).abs() < 0.01,
            "RSI should be 100 with no losses, got {}", rsi_val);
    }

    #[test]
    fn test_rsi_no_gains() {
        // All losses, no gains should give RSI = 0
        const P: usize = 5;
        let mut rsi = RSI::<P, 1>::new();

        for i in 0..10 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 200.0 - i as f64,
                high: 201.0 - i as f64,
                low: 195.0 - i as f64,
                close: 197.0 - i as f64,
                volume: 1000.0,
            };
            rsi.update(bar);
        }

        let rsi_val = rsi.get(0).unwrap();
        assert!(rsi_val < 0.01,
            "RSI should be 0 with no gains, got {}", rsi_val);
    }

    #[test]
    fn test_rsi_formula() {
        // Verify RSI formula: RSI = 100 - (100 / (1 + RS)), where RS = Avg Gain / Avg Loss
        const P: usize = 3;
        let mut rsi = RSI::<P, 1>::new();

        // Known sequence
        let bars = vec![
            (100.0, 105.0),  // +5 gain
            (105.0, 103.0),  // -2 loss
            (103.0, 108.0),  // +5 gain
        ];

        for (open, close) in bars {
            let bar = Ohlcv {
                timestamp: 0,
                open,
                high: open.max(close) + 1.0,
                low: open.min(close) - 1.0,
                close,
                volume: 1000.0,
            };
            rsi.update(bar);
        }

        // Avg gain = (5 + 0 + 5) / 3 = 3.333
        // Avg loss = (0 + 2 + 0) / 3 = 0.667
        // RS = 3.333 / 0.667 = 5
        // RSI = 100 - (100 / (1 + 5)) = 100 - 16.667 = 83.333
        let rsi_val = rsi.get(0).unwrap();
        assert!((rsi_val - 83.333).abs() < 0.1,
            "RSI calculation mismatch, expected ~83.3, got {}", rsi_val);
    }

    #[test]
    fn test_rsi_divergence() {
        // Test RSI's ability to detect momentum changes
        const P: usize = 10;
        let mut rsi = RSI::<P, 1>::new();

        // Strong uptrend with large consistent gains
        for i in 0..25 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0 + i as f64 * 2.0,
                high: 105.0 + i as f64 * 2.0,
                low: 99.0 + i as f64 * 2.0,
                close: 104.0 + i as f64 * 2.0,  // +4 gain each bar
                volume: 1000.0,
            };
            rsi.update(bar);
        }

        let strong_rsi = rsi.get(0).unwrap();

        // Mixed trend: smaller gains with occasional small losses
        let moves = vec![0.3, -0.1, 0.4, -0.2, 0.3, -0.1, 0.2, -0.1, 0.3, -0.2];
        let mut price = 150.0;
        for gain in moves {
            let bar = Ohlcv {
                timestamp: 0,
                open: price,
                high: price + 2.0,
                low: price - 1.0,
                close: price + gain,
                volume: 1000.0,
            };
            rsi.update(bar);
            price += gain;
        }

        let weak_rsi = rsi.get(0).unwrap();
        
        // RSI should decrease when gains become much smaller and mixed with losses
        assert!(weak_rsi < strong_rsi,
            "RSI should decrease when momentum weakens (was {:.2}, now {:.2})", strong_rsi, weak_rsi);
    }

    #[test]
    fn test_rsi_reset() {
        const P: usize = 14;
        let mut rsi = RSI::<P, 1>::new();

        // Add values
        for i in 0..30 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0,
                low: 95.0,
                close: 100.0 + i as f64,
                volume: 1000.0,
            };
            rsi.update(bar);
        }
        
        assert!(rsi.get(0).is_some());

        // Reset
        rsi.reset();

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
            assert!(rsi.update(bar).is_none(),
                "After reset, update {} should return None", i + 1);
        }
        
        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 105.0,
            volume: 1000.0,
        };
        assert!(rsi.update(bar).is_some());
    }

    #[test]
    fn test_rsi_historical_access() {
        const P: usize = 10;
        let mut rsi = RSI::<P, 4>::new();

        // Add warmup + enough to fill buffer (10 warmup + 3 more = 13 total, stores 4)
        for i in 0..13 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0,
                low: 95.0,
                close: 100.0 + (i % 3) as f64,
                volume: 1000.0,
            };
            rsi.update(bar);
        }

        // Access current and historical values (only 4 stored)
        for i in 0..4 {
            assert!(rsi.get(-i).is_some(), 
                "Should be able to access RSI at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(rsi.get(-4).is_none());
    }

    #[test]
    fn test_rsi_sensitivity() {
        // Shorter period should be more sensitive to recent changes
        let mut rsi_short = RSI::<5, 1>::new();
        let mut rsi_long = RSI::<20, 1>::new();

        // Mixed period with gains and losses
        for i in 0..30 {
            let gain = if i % 3 == 0 { 1.0 } else if i % 3 == 1 { -0.5 } else { 0.5 };
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 103.0,
                low: 97.0,
                close: 100.0 + gain,
                volume: 1000.0,
            };
            rsi_short.update(bar);
            rsi_long.update(bar);
        }

        // Sudden strong upward moves (large gains)
        for _ in 0..5 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 115.0,
                low: 99.0,
                close: 112.0,  // Large +12 gain
                volume: 1000.0,
            };
            rsi_short.update(bar);
            rsi_long.update(bar);
        }

        let rsi_short_val = rsi_short.get(0).unwrap();
        let rsi_long_val = rsi_long.get(0).unwrap();

        // Shorter period should react more strongly to recent sharp moves
        // The short period "forgets" the earlier mixed period faster
        assert!(rsi_short_val > rsi_long_val,
            "Shorter period RSI ({:.2}) should be more responsive than longer period ({:.2})", 
            rsi_short_val, rsi_long_val);
    }

    #[test]
    fn test_rsi_get_before_warmup() {
        const P: usize = 10;
        let mut rsi = RSI::<P, 1>::new();

        // Before any updates
        assert!(rsi.get(0).is_none());

        // During warmup
        for i in 0..(P - 1) {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0,
                low: 95.0,
                close: 102.0,
                volume: 1000.0,
            };
            rsi.update(bar);
            assert!(rsi.get(0).is_none(), 
                "get(0) should return None during warmup at update {}", i + 1);
        }

        // After warmup
        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 105.0,
            low: 95.0,
            close: 103.0,
            volume: 1000.0,
        };
        rsi.update(bar);
        assert!(rsi.get(0).is_some());
    }
}
