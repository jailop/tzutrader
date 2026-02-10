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
//! let mut macd = MACD::<12, 26, 9, 1>::new();
//! for i in 1..=50 {
//!     macd.update(i as f64);
//! }
//! if let Some(value) = macd.get(0) {
//!     println!("MACD: {:.2}", value);
//!     let values = macd.get_values(0);
//!     println!("Signal: {:.2}", values.signal.unwrap_or(f64::NAN));
//!     println!("Histogram: {:.2}", values.hist.unwrap_or(f64::NAN));
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
        if self.counter >= start {
            let short_val = self.short_ema.get(0);
            let long_val = self.long_ema.get(0);

            if short_val.is_some() && long_val.is_some() {
                let diff = short_val.unwrap() - long_val.unwrap();
                self.diff_ema.update(diff);
                let signal_val = self.diff_ema.get(0);

                self.macd.update(diff);
                if signal_val.is_some() {
                    self.signal.update(signal_val.unwrap());
                    self.hist.update(diff - signal_val.unwrap());
                } else {
                    self.signal.update(f64::NAN);
                    self.hist.update(f64::NAN);
                }
                self.macd.get(0)
            } else {
                self.macd.update(f64::NAN);
                self.signal.update(f64::NAN);
                self.hist.update(f64::NAN);
                None
            }
        } else {
            self.macd.update(f64::NAN);
            self.signal.update(f64::NAN);
            self.hist.update(f64::NAN);
            None
        }
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
