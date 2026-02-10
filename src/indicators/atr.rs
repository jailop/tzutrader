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
//! use tzutrader::types::Ohlcv;
//! use tzutrader::indicators::{Indicator, ATR};
//!
//! let mut atr = ATR::<14, 1>::new();
//! let bar = Ohlcv {
//!     timestamp: 0,
//!     open: 100.0,
//!     high: 105.0,
//!     low: 99.0,
//!     close: 103.0,
//!     volume: 1000.0,
//! };
//! atr.update(bar);
//! if let Some(value) = atr.get(0) {
//!     println!("ATR: {:.2}", value);
//! }
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
        if atr_value.is_some() {
            self.data.update(atr_value.unwrap());
        } else {
            self.data.update(f64::NAN);
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
