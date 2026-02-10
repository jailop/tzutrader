//! Commodity Channel Index (CCI)
//!
//! Measures the deviation of the typical price from its average.
//! Useful for identifying cyclical trends and overbought/oversold conditions.
//!
//! Formula: CCI = (Typical Price - MA(Typical Price)) / (constant * Mean Deviation)
//! Where Typical Price = (High + Low + Close) / 3

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

        if tp_avg.is_none() {
            self.data.update(f64::NAN);
        } else {
            let sum_deviation: f64 = self.tp_window.iter().map(|&tp| (tp - tp_avg).abs()).sum();
            let mean_deviation = sum_deviation / P as f64;

            let cci_value = if mean_deviation == 0.0 {
                0.0
            } else {
                (typical_price - tp_avg) / (self.constant * mean_deviation)
            };

            self.data.update(cci_value);
        }
        self.data.get(0)
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
