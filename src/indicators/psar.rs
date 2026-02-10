//! Parabolic SAR (Stop and Reverse)
//!
//! Provides dynamic trailing stop levels that follow price trends.
//! SAR dots appear below price during uptrends and above during downtrends.

use super::{base::BaseIndicator, Indicator};
use crate::types::Ohlcv;

#[derive(Debug, Clone, Copy, Default)]
pub struct PSARResult {
    pub sar: f64,
    pub is_uptrend: bool,
    pub af: f64,
}

#[derive(Debug, Clone)]
pub struct PSAR<const S: usize = 1> {
    sar: f64,
    extreme: f64,
    af: f64,
    is_uptrend: bool,
    initialized: bool,
    init_high: f64,
    init_low: f64,
    bar_count: usize,
    acceleration: f64,
    maximum: f64,
    data: BaseIndicator<PSARResult, S>,
}

impl<const S: usize> PSAR<S> {
    pub fn new() -> Self {
        Self::with_params(0.02, 0.20)
    }

    pub fn with_params(acceleration: f64, maximum: f64) -> Self {
        Self {
            sar: f64::NAN,
            extreme: f64::NAN,
            af: acceleration,
            is_uptrend: true,
            initialized: false,
            init_high: f64::NEG_INFINITY,
            init_low: f64::INFINITY,
            bar_count: 0,
            acceleration,
            maximum,
            data: BaseIndicator::new(),
        }
    }
}

impl<const S: usize> Default for PSAR<S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const S: usize> Indicator for PSAR<S> {
    type Input = Ohlcv;
    type Output = PSARResult;

    fn update(&mut self, value: Ohlcv) -> Option<PSARResult> {
        self.bar_count += 1;

        if self.bar_count == 1 {
            self.init_high = value.high;
            self.init_low = value.low;
            self.data.update(PSARResult {
                sar: f64::NAN,
                is_uptrend: true,
                af: self.acceleration,
            });
            return None;
        }

        if !self.initialized {
            if value.close > self.init_low {
                self.is_uptrend = true;
                self.sar = self.init_low;
                self.extreme = self.init_high.max(value.high);
            } else {
                self.is_uptrend = false;
                self.sar = self.init_high;
                self.extreme = self.init_low.min(value.low);
            }

            self.af = self.acceleration;
            self.initialized = true;

            self.data.update(PSARResult {
                sar: self.sar,
                is_uptrend: self.is_uptrend,
                af: self.af,
            });
            return None;
        }

        let prev_sar = self.sar;
        let prev_extreme = self.extreme;
        let prev_af = self.af;
        let was_uptrend = self.is_uptrend;

        self.sar = prev_sar + prev_af * (prev_extreme - prev_sar);

        if was_uptrend {
            if value.low < self.sar {
                self.is_uptrend = false;
                self.sar = prev_extreme;
                self.extreme = value.low;
                self.af = self.acceleration;
            } else {
                if value.high > prev_extreme {
                    self.extreme = value.high;
                    self.af = (self.af + self.acceleration).min(self.maximum);
                }
                if self.sar > value.low {
                    self.sar = value.low;
                }
            }
        } else {
            if value.high > self.sar {
                self.is_uptrend = true;
                self.sar = prev_extreme;
                self.extreme = value.high;
                self.af = self.acceleration;
            } else {
                if value.low < prev_extreme {
                    self.extreme = value.low;
                    self.af = (self.af + self.acceleration).min(self.maximum);
                }
                if self.sar < value.high {
                    self.sar = value.high;
                }
            }
        }

        self.data.update(PSARResult {
            sar: self.sar,
            is_uptrend: self.is_uptrend,
            af: self.af,
        });
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<PSARResult> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.sar = f64::NAN;
        self.extreme = f64::NAN;
        self.af = self.acceleration;
        self.is_uptrend = true;
        self.initialized = false;
        self.init_high = f64::NEG_INFINITY;
        self.init_low = f64::INFINITY;
        self.bar_count = 0;
        self.data.reset();
    }
}
