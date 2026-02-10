//! Bollinger Bands
//!
//! Bollinger Bands consist of a middle band (SMA) and two outer bands
//! (standard deviations away from the middle). They are used to measure
//! volatility and identify overbought/oversold conditions.
//!
//! # Type Parameters
//! - `P`: Period for moving average and standard deviation (compile-time constant)
//! - `S`: Number of recent Bollinger Band values to store (compile-time constant, default 1)
//!
//! # Example
//!
//! ```rust
//! use tzutrader::indicators::{Indicator, bollinger::BollingerBands};
//!
//! let mut bb = BollingerBands::<20, 1>::with_std_dev(2.0);
//! for i in 1..=30 {
//!     bb.update(i as f64 + (i as f64 * 0.1).sin());
//! }
//! if let Some(middle) = bb.get(0) {
//!     let values = bb.get_values(0);
//!     println!("Upper: {:.2}", values.upper.unwrap_or(f64::NAN));
//!     println!("Middle: {:.2}", middle);
//!     println!("Lower: {:.2}", values.lower.unwrap_or(f64::NAN));
//! }
//! ```

use super::{base::BaseIndicator, ma::MA, stdev::STDEV, Indicator};

#[derive(Debug, Clone, Copy, Default)]
pub struct BollingerResult {
    pub upper: f64,
    pub middle: f64,
    pub lower: f64,
}

#[derive(Debug, Clone)]
pub struct BollingerBands<const P: usize, const S: usize = 1> {
    ma: MA<P, 1>,
    stdev: STDEV<P, 1>,
    num_std_dev: f64,
    upper: BaseIndicator<f64, S>,
    middle: BaseIndicator<f64, S>,
    lower: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> BollingerBands<P, S> {
    pub fn new() -> Self {
        Self::new_with_stddev(2.0)
    }

    pub fn new_with_stddev(num_std_dev: f64) -> Self {
        Self {
            ma: MA::new(),
            stdev: STDEV::new(),
            num_std_dev,
            upper: BaseIndicator::new(),
            middle: BaseIndicator::new(),
            lower: BaseIndicator::new(),
        }
    }

    pub fn get_values(&self, key: i32) -> BollingerResult {
        BollingerResult {
            upper: self.upper.get(key).unwrap_or(f64::NAN),
            middle: self.middle.get(key).unwrap_or(f64::NAN),
            lower: self.lower.get(key).unwrap_or(f64::NAN),
        }
    }
}

impl<const P: usize, const S: usize> Default for BollingerBands<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for BollingerBands<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) -> Option<BollingerResult> {
        self.ma.update(value);
        self.stdev.update(value);

        let middle = self.ma.get(0);
        let stddev = self.stdev.get(0);

        if middle.is_none() || stddev.is_none() {
            self.upper.update(f64::NAN);
            self.middle.update(f64::NAN);
            self.lower.update(f64::NAN);
            None
        } else {
            let m = middle.unwrap();
            let s = stddev.unwrap();
            let offset = s * self.num_std_dev;
            self.upper.update(m + offset);
            self.middle.update(m);
            self.lower.update(m - offset);
            Some(m)
        }
        Some(self.get_values(0))
    }

    fn get(&self, key: i32) -> Option<BollingerResult> {
        Some(self.get_values(key))
    }

    fn reset(&mut self) {
        self.ma.reset();
        self.stdev.reset();
        self.upper.reset();
        self.middle.reset();
        self.lower.reset();
    }
}
