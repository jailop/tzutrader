//! True Range (TRANGE)
//!
//! True Range is the greatest of:
//! - Current High minus Current Low
//! - Absolute value of Current High minus Previous Close
//! - Absolute value of Current Low minus Previous Close
//!
//! # Type Parameters
//! - `S`: Number of recent TRANGE values to store (compile-time constant, default 1)

use super::{base::BaseIndicator, Indicator};
use crate::types::Ohlcv;

#[derive(Debug, Clone)]
pub struct TRANGE<const S: usize = 1> {
    prev_close: f64,
    data: BaseIndicator<f64, S>,
}

impl<const S: usize> TRANGE<S> {
    pub fn new() -> Self {
        Self {
            prev_close: f64::NAN,
            data: BaseIndicator::new(),
        }
    }
}

impl<const S: usize> Default for TRANGE<S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const S: usize> Indicator for TRANGE<S> {
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
        self.data.update(tr);
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.prev_close = f64::NAN;
        self.data.reset();
    }
}
