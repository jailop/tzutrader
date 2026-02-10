//! Money Flow Index (MFI)
//!
//! Volume-weighted RSI that measures buying and selling pressure.
//! Combines price and volume to identify overbought/oversold conditions.
//!
//! Formula: MFI = 100 - 100 / (1 + Money Flow Ratio)
//! Where Money Flow Ratio = Positive Money Flow / Negative Money Flow

use super::{base::BaseIndicator, Indicator};
use crate::types::Ohlcv;

#[derive(Debug, Clone)]
pub struct MFI<const P: usize, const S: usize = 1> {
    prev_typical_price: f64,
    pos_flow_window: [f64; P],
    neg_flow_window: [f64; P],
    length: usize,
    pos: usize,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> MFI<P, S> {
    pub fn new() -> Self {
        Self {
            prev_typical_price: f64::NAN,
            pos_flow_window: [0.0; P],
            neg_flow_window: [0.0; P],
            length: 0,
            pos: 0,
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for MFI<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for MFI<P, S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) -> Option<Self::Output> {
        let typical_price = (value.high + value.low + value.close) / 3.0;
        let money_flow = typical_price * value.volume;

        let mut pos_flow = 0.0;
        let mut neg_flow = 0.0;

        if !self.prev_typical_price.is_nan() {
            if typical_price > self.prev_typical_price {
                pos_flow = money_flow;
            } else if typical_price < self.prev_typical_price {
                neg_flow = money_flow;
            }
        }

        if self.length < P {
            self.length += 1;
        }

        self.pos_flow_window[self.pos] = pos_flow;
        self.neg_flow_window[self.pos] = neg_flow;
        self.pos = (self.pos + 1) % P;
        self.prev_typical_price = typical_price;

        if self.length < P {
            self.data.update(f64::NAN);
        } else {
            let sum_pos_flow: f64 = self.pos_flow_window.iter().sum();
            let sum_neg_flow: f64 = self.neg_flow_window.iter().sum();

            let mfi_value = if sum_neg_flow == 0.0 {
                if sum_pos_flow == 0.0 {
                    50.0
                } else {
                    100.0
                }
            } else {
                let money_flow_ratio = sum_pos_flow / sum_neg_flow;
                100.0 - 100.0 / (1.0 + money_flow_ratio)
            };

            self.data.update(mfi_value);
        }
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.prev_typical_price = f64::NAN;
        self.length = 0;
        self.pos = 0;
        self.pos_flow_window = [0.0; P];
        self.neg_flow_window = [0.0; P];
        self.data.reset();
    }
}
