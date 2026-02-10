//! Aroon Indicator
//!
//! Aroon identifies when trends are likely to change by measuring
//! the time since the highest high and lowest low over a period.
//!
//! Formulas:
//!   Aroon Up = ((period - periods since period high) / period) * 100
//!   Aroon Down = ((period - periods since period low) / period) * 100
//!   Aroon Oscillator = Aroon Up - Aroon Down

use super::{base::BaseIndicator, Indicator};
use crate::Ohlcv;

#[derive(Debug, Clone, Copy, Default)]
pub struct AroonValues {
    pub up: f64,
    pub down: f64,
    pub oscillator: f64,
}

#[derive(Debug, Clone)]
pub struct AROON<const P: usize, const S: usize = 1> {
    highs: [f64; P],
    lows: [f64; P],
    pos: usize,
    length: usize,
    up_values: BaseIndicator<f64, S>,
    down_values: BaseIndicator<f64, S>,
    oscillator_values: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> AROON<P, S> {
    pub fn new() -> Self {
        Self {
            highs: [f64::NAN; P],
            lows: [f64::NAN; P],
            pos: 0,
            length: 0,
            up_values: BaseIndicator::new(),
            down_values: BaseIndicator::new(),
            oscillator_values: BaseIndicator::new(),
        }
    }

    pub fn get_values(&self, key: i32) -> AroonValues {
        AroonValues {
            up: self.up_values.get(key),
            down: self.down_values.get(key),
            oscillator: self.oscillator_values.get(key),
        }
    }
}

impl<const P: usize, const S: usize> Default for AROON<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for AROON<P, S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) -> Option<Self::Output> {
        self.highs[self.pos] = value.high;
        self.lows[self.pos] = value.low;
        self.pos = (self.pos + 1) % P;

        if self.length < P {
            self.length += 1;
        }

        if self.length < P {
            self.up_values.update(f64::NAN);
            self.down_values.update(f64::NAN);
            self.oscillator_values.update(f64::NAN);
        } else {
            let mut highest_high = f64::NEG_INFINITY;
            let mut lowest_low = f64::INFINITY;
            let mut periods_since_high = P - 1;
            let mut periods_since_low = P - 1;

            for periods_ago in 0..P {
                let idx = (self.pos + P - 1 - periods_ago) % P;

                if self.highs[idx] >= highest_high {
                    highest_high = self.highs[idx];
                    periods_since_high = periods_ago;
                }

                if self.lows[idx] <= lowest_low {
                    lowest_low = self.lows[idx];
                    periods_since_low = periods_ago;
                }
            }

            let aroon_up = ((P as f64 - periods_since_high as f64) / P as f64) * 100.0;
            let aroon_down = ((P as f64 - periods_since_low as f64) / P as f64) * 100.0;
            let aroon_osc = aroon_up - aroon_down;

            self.up_values.update(aroon_up);
            self.down_values.update(aroon_down);
            self.oscillator_values.update(aroon_osc);
        }
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.up_values.get(key)
    }

    fn reset(&mut self) {
        self.pos = 0;
        self.length = 0;
        self.highs = [f64::NAN; P];
        self.lows = [f64::NAN; P];
        self.up_values.reset();
        self.down_values.reset();
        self.oscillator_values.reset();
    }
}
