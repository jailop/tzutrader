//! Stochastic Oscillator (STOCH)
//!
//! Measures momentum by comparing closing price to the price range over a period.
//! %K shows where the close is relative to the high-low range.
//! %D is a moving average of %K, providing a smoother signal line.

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
    k_values: BaseIndicator<f64, S>,
    d_values: BaseIndicator<f64, S>,
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
            k_values: BaseIndicator::new(),
            d_values: BaseIndicator::new(),
        }
    }

    pub fn get_values(&self, key: i32) -> StochResult {
        StochResult {
            k: self.k_values.get(key).unwrap_or(f64::NAN),
            d: self.d_values.get(key).unwrap_or(f64::NAN),
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
    type Output = f64;

    fn update(&mut self, value: Ohlcv) -> Option<StochResult> {
        if self.length < K {
            self.length += 1;
        }

        self.high_window[self.pos] = value.high;
        self.low_window[self.pos] = value.low;
        self.close_window[self.pos] = value.close;
        self.pos = (self.pos + 1) % K;

        if self.length < K {
            self.k_values.update(f64::NAN);
            self.d_values.update(f64::NAN);
        } else {
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
            self.k_values.update(k);
            self.d_values.update(self.k_ma.get(0).unwrap_or(f64::NAN));
        }
        Some(self.get_values(0))
    }

    fn get(&self, key: i32) -> Option<StochResult> {
        Some(self.get_values(key))
    }

    fn reset(&mut self) {
        self.length = 0;
        self.pos = 0;
        self.k_ma.reset();
        self.k_values.reset();
        self.d_values.reset();
        self.high_window = [f64::NAN; K];
        self.low_window = [f64::NAN; K];
        self.close_window = [f64::NAN; K];
    }
}
