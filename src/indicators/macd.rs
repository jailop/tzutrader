//! Moving Average Convergence Divergence (MACD)
//!
//! MACD is a trend-following momentum indicator that shows the relationship
//! between two moving averages of prices. It consists of three components:
//! - MACD line: Difference between short and long EMAs
//! - Signal line: EMA of the MACD line
//! - Histogram: Difference between MACD and Signal lines
//!
//! # Type Parameters
//! - `SHORT`: Period for the short EMA (compile-time constant)
//! - `LONG`: Period for the long EMA (compile-time constant)
//! - `DIFF`: Period for the signal line EMA (compile-time constant)
//! - `S`: Number of recent values to store (compile-time constant, default 1)
//!
//! # Example
//!
//! ```rust
//! use tzutrader::indicators::{Indicator, macd::MACD};
//!
//! // Standard MACD(12, 26, 9)
//! let mut macd = MACD::<12, 26, 9, 3>::new();
//!
//! // Warmup period - needs LONG + DIFF - 1 values before signal line is ready
//! for i in 0..50 {
//!     macd.update(100.0 + i as f64 * 0.5);
//! }
//!
//! // After warmup, MACD provides all three components
//! let result = macd.update(125.0);
//! if result.is_some() {
//!     let values = macd.get_values(0);
//!     if let Some(macd_line) = values.macd {
//!         println!("MACD Line: {:.4}", macd_line);
//!     }
//!     if let Some(signal) = values.signal {
//!         println!("Signal Line: {:.4}", signal);
//!     }
//!     if let Some(hist) = values.hist {
//!         println!("Histogram: {:.4}", hist);
//!     }
//! }
//! ```

use super::{base::BaseIndicator, ema::EMA, Indicator};

#[derive(Debug, Clone, Copy, Default)]
pub struct MACDValues {
    pub macd: Option<f64>,
    pub signal: Option<f64>,
    pub hist: Option<f64>,
}

#[derive(Debug, Clone)]
pub struct MACD<const SHORT: usize, const LONG: usize, const DIFF: usize, const S: usize = 1> {
    short_ema: EMA<SHORT, 1>,
    long_ema: EMA<LONG, 1>,
    diff_ema: EMA<DIFF, 1>,
    counter: usize,
    macd: BaseIndicator<f64, S>,
    signal: BaseIndicator<f64, S>,
    hist: BaseIndicator<f64, S>,
}

impl<const SHORT: usize, const LONG: usize, const DIFF: usize, const S: usize>
    MACD<SHORT, LONG, DIFF, S>
{
    pub fn new() -> Self {
        Self {
            short_ema: EMA::new(),
            long_ema: EMA::new(),
            diff_ema: EMA::new(),
            counter: 0,
            macd: BaseIndicator::new(),
            signal: BaseIndicator::new(),
            hist: BaseIndicator::new(),
        }
    }

    pub fn get_values(&self, key: i32) -> MACDValues {
        MACDValues {
            macd: self.macd.get(key),
            signal: self.signal.get(key),
            hist: self.hist.get(key),
        }
    }
}

impl<const SHORT: usize, const LONG: usize, const DIFF: usize, const S: usize> Default
    for MACD<SHORT, LONG, DIFF, S>
{
    fn default() -> Self {
        Self::new()
    }
}

impl<const SHORT: usize, const LONG: usize, const DIFF: usize, const S: usize> Indicator
    for MACD<SHORT, LONG, DIFF, S>
{
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) -> Option<f64> {
        self.counter += 1;
        self.short_ema.update(value);
        self.long_ema.update(value);

        let start = if LONG > SHORT { LONG } else { SHORT };
        if self.counter < start {
            return None;
        }
        
        let short_val = self.short_ema.get(0);
        let long_val = self.long_ema.get(0);

        if short_val.is_none() || long_val.is_none() {
            return None;
        }
        
        let diff = short_val.unwrap() - long_val.unwrap();
        self.diff_ema.update(diff);
        let signal_val = self.diff_ema.get(0);

        self.macd.update(diff);
        
        if let Some(sig) = signal_val {
            self.signal.update(sig);
            self.hist.update(diff - sig);
        }
        
        self.macd.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.macd.get(key)
    }

    fn reset(&mut self) {
        self.short_ema.reset();
        self.long_ema.reset();
        self.diff_ema.reset();
        self.counter = 0;
        self.macd.reset();
        self.signal.reset();
        self.hist.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_macd_warmup_period() {
        // MACD needs LONG values before MACD line is available
        const SHORT: usize = 3;
        const LONG: usize = 5;
        const DIFF: usize = 3;
        let mut macd = MACD::<SHORT, LONG, DIFF, 1>::new();

        // During warmup for MACD line: should return None
        for i in 0..(LONG - 1) {
            assert!(macd.update(100.0 + i as f64).is_none(), 
                "Update {} should return None during MACD warmup", i + 1);
        }
        
        // LONG-th value should return Some (MACD line available)
        assert!(macd.update(110.0).is_some());
    }

    #[test]
    fn test_macd_line_calculation() {
        // MACD line = short EMA - long EMA
        const SHORT: usize = 3;
        const LONG: usize = 5;
        const DIFF: usize = 2;
        let mut macd = MACD::<SHORT, LONG, DIFF, 1>::new();

        // Add values
        for i in 0..10 {
            macd.update(100.0 + i as f64 * 2.0);
        }

        let values = macd.get_values(0);
        assert!(values.macd.is_some());
        
        // MACD should be positive in uptrend (short EMA > long EMA)
        assert!(values.macd.unwrap() > 0.0);
    }

    #[test]
    fn test_macd_signal_line() {
        // Signal line is EMA of MACD line, needs additional DIFF periods
        const SHORT: usize = 3;
        const LONG: usize = 5;
        const DIFF: usize = 3;
        let mut macd = MACD::<SHORT, LONG, DIFF, 1>::new();

        // Warmup for MACD line
        for i in 0..LONG {
            macd.update(100.0 + i as f64);
        }

        // Signal line should be None initially
        let values_before = macd.get_values(0);
        assert!(values_before.macd.is_some());
        assert!(values_before.signal.is_none());

        // After DIFF more periods, signal should be available
        for i in 0..(DIFF - 1) {
            macd.update(110.0 + i as f64);
        }

        let values_after = macd.get_values(0);
        assert!(values_after.signal.is_some());
    }

    #[test]
    fn test_macd_histogram() {
        // Histogram = MACD line - Signal line
        const SHORT: usize = 3;
        const LONG: usize = 5;
        const DIFF: usize = 3;
        let mut macd = MACD::<SHORT, LONG, DIFF, 1>::new();

        // Full warmup
        for i in 0..20 {
            macd.update(100.0 + i as f64);
        }

        let values = macd.get_values(0);
        assert!(values.hist.is_some());
        
        // Histogram should equal MACD - Signal
        let expected_hist = values.macd.unwrap() - values.signal.unwrap();
        assert!((values.hist.unwrap() - expected_hist).abs() < 0.0001);
    }

    #[test]
    fn test_macd_uptrend() {
        // In uptrend, MACD should be positive and histogram expanding
        const SHORT: usize = 5;
        const LONG: usize = 10;
        const DIFF: usize = 5;
        let mut macd = MACD::<SHORT, LONG, DIFF, 3>::new();

        // Create uptrend
        for i in 0..30 {
            macd.update(100.0 + i as f64 * 2.0);
        }

        let values = macd.get_values(0);
        
        // MACD should be positive in uptrend
        assert!(values.macd.unwrap() > 0.0,
            "MACD should be positive in uptrend");
    }

    #[test]
    fn test_macd_downtrend() {
        // In downtrend, MACD should be negative
        const SHORT: usize = 5;
        const LONG: usize = 10;
        const DIFF: usize = 5;
        let mut macd = MACD::<SHORT, LONG, DIFF, 1>::new();

        // Create downtrend
        for i in 0..30 {
            macd.update(200.0 - i as f64 * 2.0);
        }

        let values = macd.get_values(0);
        
        // MACD should be negative in downtrend
        assert!(values.macd.unwrap() < 0.0,
            "MACD should be negative in downtrend");
    }

    #[test]
    fn test_macd_crossover() {
        // Test MACD/Signal crossover detection
        const SHORT: usize = 3;
        const LONG: usize = 6;
        const DIFF: usize = 3;
        let mut macd = MACD::<SHORT, LONG, DIFF, 2>::new();

        // Establish baseline
        for i in 0..15 {
            macd.update(100.0);
        }

        // Sharp uptrend to create bullish crossover
        for i in 0..10 {
            macd.update(100.0 + i as f64 * 5.0);
        }

        let current = macd.get_values(0);
        
        // In strong uptrend, histogram should be positive (MACD > Signal)
        if current.hist.is_some() {
            assert!(current.hist.unwrap() > 0.0,
                "Histogram should be positive after bullish crossover");
        }
    }

    #[test]
    fn test_macd_flat_market() {
        // In flat market, MACD should converge to zero
        const SHORT: usize = 5;
        const LONG: usize = 10;
        const DIFF: usize = 5;
        let mut macd = MACD::<SHORT, LONG, DIFF, 1>::new();

        // Flat prices
        for _ in 0..50 {
            macd.update(100.0);
        }

        let values = macd.get_values(0);
        
        // MACD should be near zero in flat market
        assert!(values.macd.unwrap().abs() < 0.01,
            "MACD should converge to zero in flat market");
    }

    #[test]
    fn test_macd_reset() {
        const SHORT: usize = 3;
        const LONG: usize = 5;
        const DIFF: usize = 3;
        let mut macd = MACD::<SHORT, LONG, DIFF, 1>::new();

        // Add values
        for i in 0..20 {
            macd.update(100.0 + i as f64);
        }
        
        assert!(macd.get(0).is_some());

        // Reset
        macd.reset();

        // Should need warmup again
        for i in 0..(LONG - 1) {
            assert!(macd.update(100.0 + i as f64).is_none(),
                "After reset, update {} should return None", i + 1);
        }
        assert!(macd.update(200.0).is_some());
    }

    #[test]
    fn test_macd_historical_access() {
        // Test buffer storage with S=4
        const SHORT: usize = 3;
        const LONG: usize = 5;
        const DIFF: usize = 3;
        let mut macd = MACD::<SHORT, LONG, DIFF, 4>::new();

        // Add enough values - warmup (LONG-1) plus 4 to fill buffer = 8 total
        for i in 0..8 {
            macd.update(100.0 + i as f64);
        }

        // Access current and historical MACD values (only 4 stored after warmup)
        for i in 0..4 {
            assert!(macd.get(-i).is_some(), 
                "Should be able to access MACD at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(macd.get(-4).is_none());

        // Also test get_values for historical access
        let hist_values = macd.get_values(-1);
        assert!(hist_values.macd.is_some());
    }

    #[test]
    fn test_macd_get_before_warmup() {
        // Test that get() returns None before warmup is complete
        const SHORT: usize = 3;
        const LONG: usize = 5;
        const DIFF: usize = 3;
        let mut macd = MACD::<SHORT, LONG, DIFF, 1>::new();

        // Before any updates
        assert!(macd.get(0).is_none());

        // During warmup
        for i in 0..(LONG - 1) {
            macd.update(100.0 + i as f64);
            assert!(macd.get(0).is_none(), 
                "get(0) should return None during warmup at update {}", i + 1);
        }

        // After warmup
        macd.update(200.0);
        assert!(macd.get(0).is_some());
    }

    #[test]
    fn test_macd_standard_parameters() {
        // Test with standard MACD(12, 26, 9) parameters
        let mut macd = MACD::<12, 26, 9, 1>::new();

        // Warmup
        for i in 0..50 {
            macd.update(100.0 + i as f64 * 0.5);
        }

        let values = macd.get_values(0);
        
        // All components should be available
        assert!(values.macd.is_some());
        assert!(values.signal.is_some());
        assert!(values.hist.is_some());
    }

    #[test]
    fn test_macd_divergence() {
        // Test MACD sensitivity to price changes
        const SHORT: usize = 5;
        const LONG: usize = 10;
        const DIFF: usize = 5;
        let mut macd = MACD::<SHORT, LONG, DIFF, 1>::new();

        // Stable period
        for _ in 0..20 {
            macd.update(100.0);
        }
        let stable_macd = macd.get_values(0).macd.unwrap();

        // Price increase
        for i in 0..10 {
            macd.update(100.0 + i as f64);
        }
        let rising_macd = macd.get_values(0).macd.unwrap();

        // MACD should increase with rising prices
        assert!(rising_macd > stable_macd,
            "MACD should increase with rising prices");
    }

    #[test]
    fn test_macd_components_relationship() {
        // Verify the relationships between MACD components
        const SHORT: usize = 4;
        const LONG: usize = 8;
        const DIFF: usize = 4;
        let mut macd = MACD::<SHORT, LONG, DIFF, 1>::new();

        // Full warmup
        for i in 0..25 {
            macd.update(100.0 + i as f64 * 0.5);
        }

        let values = macd.get_values(0);
        
        // When all are available, histogram = MACD - Signal
        if values.macd.is_some() && values.signal.is_some() && values.hist.is_some() {
            let calculated_hist = values.macd.unwrap() - values.signal.unwrap();
            assert!((values.hist.unwrap() - calculated_hist).abs() < 0.0001,
                "Histogram should equal MACD minus Signal");
        }
    }
}
