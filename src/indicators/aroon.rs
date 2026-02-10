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
use crate::types::Ohlcv;

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
    data: BaseIndicator<AroonValues, S>,
}

impl<const P: usize, const S: usize> AROON<P, S> {
    pub fn new() -> Self {
        Self {
            highs: [f64::NAN; P],
            lows: [f64::NAN; P],
            pos: 0,
            length: 0,
            data: BaseIndicator::new(),
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
    type Output = AroonValues;

    fn update(&mut self, value: Ohlcv) -> Option<AroonValues> {
        self.highs[self.pos] = value.high;
        self.lows[self.pos] = value.low;
        self.pos = (self.pos + 1) % P;

        if self.length < P {
            self.length += 1;
        }

        if self.length < P {
            self.data.update(AroonValues {
                up: f64::NAN,
                down: f64::NAN,
                oscillator: f64::NAN,
            });
            return None;
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

            self.data.update(AroonValues {
                up: aroon_up,
                down: aroon_down,
                oscillator: aroon_osc,
            });
        }
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<AroonValues> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.pos = 0;
        self.length = 0;
        self.highs = [f64::NAN; P];
        self.lows = [f64::NAN; P];
        self.data.reset();
    }
}
