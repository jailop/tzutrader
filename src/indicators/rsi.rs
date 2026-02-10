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
//!
//! let mut rsi = RSI::<14, 1>::new();
//! let bar = Ohlcv {
//!     timestamp: 0,
//!     open: 100.0,
//!     high: 105.0,
//!     low: 99.0,
//!     close: 103.0,
//!     volume: 1000.0,
//! };
//! rsi.update(bar);
//! // Access current RSI value
//! if let Some(value) = rsi.get(0) {
//!     println!("RSI: {:.2}", value);
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
            self.data.update(f64::NAN);
            None
        } else {
            let gain_avg = self.gains.get(0).unwrap();
            let rsi_value = 100.0 - 100.0 / (1.0 + gain_avg / loss_avg.unwrap());
            self.data.update(rsi_value);
            self.data.get(0)
        }
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
