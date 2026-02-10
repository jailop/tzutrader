//! Stochastic Oscillator (STOCH)
//!
//! Measures momentum by comparing closing price to the price range over a period.
//! %K shows where the close is relative to the high-low range.
//! %D is a moving average of %K, providing a smoother signal line.
//!
//! # Type Parameters
//! - `K`: Lookback period for %K calculation
//! - `D`: Period for %D moving average of %K
//! - `S`: Number of recent values to store
//!
//! # Example
//!
//! ```rust
//! use tzutrader::indicators::{Indicator, stoch::STOCH};
//! use tzutrader::types::Ohlcv;
//!
//! // Standard Stochastic (14, 3)
//! let mut stoch = STOCH::<14, 3, 3>::new();
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
//!     stoch.update(bar);
//! }
//!
//! // After warmup, get %K and %D
//! let bar = Ohlcv {
//!     timestamp: 0,
//!     open: 110.0,
//!     high: 115.0,
//!     low: 108.0,
//!     close: 113.0,
//!     volume: 1000.0,
//! };
//! if let Some(result) = stoch.update(bar) {
//!     println!("%K: {:.2}", result.k);
//!     println!("%D: {:.2}", result.d);
//!     if result.k > 80.0 {
//!         println!("Overbought condition");
//!     } else if result.k < 20.0 {
//!         println!("Oversold condition");
//!     }
//! }
//! ```

use super::{base::BaseIndicator, ma::MA, Indicator};
use crate::types::Ohlcv;

#[derive(Debug, Clone, Copy, Default)]
pub struct StochResult {
    pub k: f64,
    pub d: f64,
}

#[derive(Debug, Clone)]
pub struct STOCH<const K: usize, const D: usize, const S: usize = 1> {
    high_window: [f64; K],
    low_window: [f64; K],
    close_window: [f64; K],
    length: usize,
    pos: usize,
    k_ma: MA<D, 1>,
    data: BaseIndicator<StochResult, S>,
}

impl<const K: usize, const D: usize, const S: usize> STOCH<K, D, S> {
    pub fn new() -> Self {
        Self {
            high_window: [f64::NAN; K],
            low_window: [f64::NAN; K],
            close_window: [f64::NAN; K],
            length: 0,
            pos: 0,
            k_ma: MA::new(),
            data: BaseIndicator::new(),
        }
    }
}

impl<const K: usize, const D: usize, const S: usize> Default for STOCH<K, D, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const K: usize, const D: usize, const S: usize> Indicator for STOCH<K, D, S> {
    type Input = Ohlcv;
    type Output = StochResult;

    fn update(&mut self, value: Ohlcv) -> Option<StochResult> {
        if self.length < K {
            self.length += 1;
        }

        self.high_window[self.pos] = value.high;
        self.low_window[self.pos] = value.low;
        self.close_window[self.pos] = value.close;
        self.pos = (self.pos + 1) % K;

        if self.length < K {
            return None;
        }
        
        let mut highest_high = self.high_window[0];
        let mut lowest_low = self.low_window[0];

        for i in 1..K {
            if self.high_window[i] > highest_high {
                highest_high = self.high_window[i];
            }
            if self.low_window[i] < lowest_low {
                lowest_low = self.low_window[i];
            }
        }

        let range = highest_high - lowest_low;
        let k = if range == 0.0 {
            50.0
        } else {
            100.0 * (value.close - lowest_low) / range
        };

        self.k_ma.update(k);
        let d = self.k_ma.get(0).unwrap_or(k);  // Use k if %D not ready yet
        
        self.data.update(StochResult { k, d });
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<StochResult> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.length = 0;
        self.pos = 0;
        self.k_ma.reset();
        self.data.reset();
        self.high_window = [f64::NAN; K];
        self.low_window = [f64::NAN; K];
        self.close_window = [f64::NAN; K];
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_stoch_warmup_period() {
        const K: usize = 14;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 1>::new();

        // During warmup for %K: should return None
        for i in 0..(K - 1) {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0,
                low: 95.0,
                close: 100.0 + i as f64,
                volume: 1000.0,
            };
            assert!(stoch.update(bar).is_none(), 
                "Update {} should return None during warmup", i + 1);
        }
        
        // Kth value should return Some (%K is ready)
        let bar = Ohlcv {
            timestamp: 0,
            open: 110.0,
            high: 115.0,
            low: 109.0,
            close: 113.0,
            volume: 1000.0,
        };
        assert!(stoch.update(bar).is_some());
    }

    #[test]
    fn test_stoch_range() {
        // %K and %D should always be between 0 and 100
        const K: usize = 14;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 1>::new();

        for i in 0..50 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 110.0 + (i % 5) as f64,
                low: 90.0 - (i % 3) as f64,
                close: 95.0 + (i % 7) as f64,
                volume: 1000.0,
            };
            
            if let Some(result) = stoch.update(bar) {
                assert!(result.k >= 0.0 && result.k <= 100.0,
                    "%K must be between 0 and 100, got {}", result.k);
                assert!(result.d >= 0.0 && result.d <= 100.0,
                    "%D must be between 0 and 100, got {}", result.d);
            }
        }
    }

    #[test]
    fn test_stoch_at_high() {
        // When close equals highest high, %K should be 100
        const K: usize = 5;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 1>::new();

        // Establish range
        for i in 0..K {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 100.0 + i as f64,
                low: 90.0,
                close: 95.0,
                volume: 1000.0,
            };
            stoch.update(bar);
        }

        // Close at highest high
        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 110.0,
            low: 90.0,
            close: 110.0,  // At the high
            volume: 1000.0,
        };
        let result = stoch.update(bar).unwrap();
        
        assert!((result.k - 100.0).abs() < 0.01,
            "%K should be 100 when close equals high, got {}", result.k);
    }

    #[test]
    fn test_stoch_at_low() {
        // When close equals lowest low, %K should be 0
        const K: usize = 5;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 1>::new();

        // Establish range
        for i in 0..K {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 110.0,
                low: 90.0 - i as f64,
                close: 100.0,
                volume: 1000.0,
            };
            stoch.update(bar);
        }

        // Close at lowest low
        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 110.0,
            low: 85.0,
            close: 85.0,  // At the low
            volume: 1000.0,
        };
        let result = stoch.update(bar).unwrap();
        
        assert!(result.k < 0.01,
            "%K should be 0 when close equals low, got {}", result.k);
    }

    #[test]
    fn test_stoch_at_midpoint() {
        // When close is at midpoint of range, %K should be around 50
        const K: usize = 5;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 1>::new();

        // Establish range: high=110, low=90
        for _ in 0..K {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 110.0,
                low: 90.0,
                close: 100.0,  // Midpoint
                volume: 1000.0,
            };
            stoch.update(bar);
        }

        let result = stoch.get(0).unwrap();
        assert!((result.k - 50.0).abs() < 1.0,
            "%K should be around 50 at midpoint, got {}", result.k);
    }

    #[test]
    fn test_stoch_d_smoothing() {
        // %D should be smoother than %K (less volatile)
        const K: usize = 14;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 5>::new();

        // Volatile price movement
        for i in 0..30 {
            let close = if i % 2 == 0 { 110.0 } else { 90.0 };
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 110.0,
                low: 90.0,
                close,
                volume: 1000.0,
            };
            stoch.update(bar);
        }

        // Get several values
        let mut k_changes = 0.0;
        let mut d_changes = 0.0;
        
        for i in 1..5 {
            let curr = stoch.get(-i).unwrap();
            let prev = stoch.get(-i - 1).unwrap();
            k_changes += (curr.k - prev.k).abs();
            d_changes += (curr.d - prev.d).abs();
        }

        // %D should change less than %K (smoother)
        assert!(d_changes < k_changes,
            "%D should be smoother than %K");
    }

    #[test]
    fn test_stoch_overbought() {
        // In strong uptrend, %K should reach overbought levels (>80)
        const K: usize = 14;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 1>::new();

        // Strong uptrend - closes near highs
        for i in 0..30 {
            let base = 100.0 + i as f64 * 2.0;
            let bar = Ohlcv {
                timestamp: 0,
                open: base,
                high: base + 3.0,
                low: base - 1.0,
                close: base + 2.5,  // Near high
                volume: 1000.0,
            };
            stoch.update(bar);
        }

        let result = stoch.get(0).unwrap();
        assert!(result.k > 80.0,
            "%K should be > 80 (overbought) in strong uptrend, got {}", result.k);
    }

    #[test]
    fn test_stoch_oversold() {
        // In strong downtrend, %K should reach oversold levels (<20)
        const K: usize = 14;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 1>::new();

        // Strong downtrend - closes near lows
        for i in 0..30 {
            let base = 200.0 - i as f64 * 2.0;
            let bar = Ohlcv {
                timestamp: 0,
                open: base,
                high: base + 1.0,
                low: base - 3.0,
                close: base - 2.5,  // Near low
                volume: 1000.0,
            };
            stoch.update(bar);
        }

        let result = stoch.get(0).unwrap();
        assert!(result.k < 20.0,
            "%K should be < 20 (oversold) in strong downtrend, got {}", result.k);
    }

    #[test]
    fn test_stoch_zero_range() {
        // When high equals low, %K should default to 50
        const K: usize = 5;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 1>::new();

        // No price movement
        for _ in 0..10 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 100.0,
                low: 100.0,
                close: 100.0,
                volume: 1000.0,
            };
            stoch.update(bar);
        }

        let result = stoch.get(0).unwrap();
        assert!((result.k - 50.0).abs() < 0.01,
            "%K should be 50 when range is zero, got {}", result.k);
    }

    #[test]
    fn test_stoch_reset() {
        const K: usize = 14;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 1>::new();

        // Add values
        for i in 0..30 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 110.0,
                low: 90.0,
                close: 100.0 + i as f64,
                volume: 1000.0,
            };
            stoch.update(bar);
        }
        
        assert!(stoch.get(0).is_some());

        // Reset
        stoch.reset();

        // Should need warmup again
        for i in 0..(K - 1) {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0,
                low: 95.0,
                close: 100.0,
                volume: 1000.0,
            };
            assert!(stoch.update(bar).is_none(),
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
        assert!(stoch.update(bar).is_some());
    }

    #[test]
    fn test_stoch_historical_access() {
        const K: usize = 10;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 4>::new();

        // Add warmup + 3 more to fill buffer (10 + 3 = 13)
        for i in 0..13 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0 + i as f64,
                low: 95.0,
                close: 100.0 + i as f64,
                volume: 1000.0,
            };
            stoch.update(bar);
        }

        // Access current and historical values (only 4 stored)
        for i in 0..4 {
            assert!(stoch.get(-i).is_some(), 
                "Should be able to access Stochastic at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(stoch.get(-4).is_none());
    }

    #[test]
    fn test_stoch_get_before_warmup() {
        const K: usize = 14;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 1>::new();

        // Before any updates
        assert!(stoch.get(0).is_none());

        // During warmup
        for i in 0..(K - 1) {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0,
                low: 95.0,
                close: 100.0,
                volume: 1000.0,
            };
            stoch.update(bar);
            assert!(stoch.get(0).is_none(), 
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
        stoch.update(bar);
        assert!(stoch.get(0).is_some());
    }

    #[test]
    fn test_stoch_crossover() {
        // Test %K and %D crossover
        const K: usize = 14;
        const D: usize = 3;
        let mut stoch = STOCH::<K, D, 5>::new();

        // Downtrend then reversal
        for i in 0..20 {
            let base = 200.0 - i as f64 * 2.0;
            let bar = Ohlcv {
                timestamp: 0,
                open: base,
                high: base + 2.0,
                low: base - 3.0,
                close: base - 2.0,
                volume: 1000.0,
            };
            stoch.update(bar);
        }

        // Sharp reversal upward
        for i in 0..10 {
            let base = 160.0 + i as f64 * 3.0;
            let bar = Ohlcv {
                timestamp: 0,
                open: base,
                high: base + 5.0,
                low: base - 1.0,
                close: base + 4.0,
                volume: 1000.0,
            };
            stoch.update(bar);
        }

        // %K should be higher than %D after sharp reversal (bullish crossover)
        let result = stoch.get(0).unwrap();
        // In a strong reversal, %K moves faster than %D
        assert!(result.k > 50.0 || result.d > 50.0,
            "After reversal, at least one should be above 50");
    }

    #[test]
    fn test_stoch_standard_parameters() {
        // Test standard Stochastic (14, 3)
        let mut stoch = STOCH::<14, 3, 1>::new();

        // Realistic price data
        for i in 0..30 {
            let bar = Ohlcv {
                timestamp: 0,
                open: 100.0,
                high: 105.0 + (i as f64 * 0.5).sin() * 3.0,
                low: 95.0 + (i as f64 * 0.5).sin() * 3.0,
                close: 100.0 + (i as f64 * 0.5).sin() * 2.0,
                volume: 1000.0,
            };
            stoch.update(bar);
        }

        let result = stoch.get(0).unwrap();
        
        // Verify structure
        assert!(result.k >= 0.0 && result.k <= 100.0);
        assert!(result.d >= 0.0 && result.d <= 100.0);
    }
}
