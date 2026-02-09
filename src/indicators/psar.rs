/// Parabolic SAR (Stop and Reverse)
///
/// Provides dynamic trailing stop levels that follow price trends.
/// SAR dots appear below price during uptrends and above during downtrends.

use super::{base::BaseIndicator, Indicator, Ohlcv};

#[derive(Debug, Clone, Copy, Default)]
pub struct PSARValues {
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
    sar_values: BaseIndicator<f64, S>,
    uptrend_values: BaseIndicator<bool, S>,
    af_values: BaseIndicator<f64, S>,
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
            sar_values: BaseIndicator::new_float(),
            uptrend_values: BaseIndicator::new(),
            af_values: BaseIndicator::new_float(),
        }
    }

    pub fn get_values(&self, key: i32) -> PSARValues {
        PSARValues {
            sar: self.sar_values.get(key),
            is_uptrend: self.uptrend_values.get(key),
            af: self.af_values.get(key),
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
    type Output = f64;

    fn update(&mut self, value: Ohlcv) {
        self.bar_count += 1;
        
        if self.bar_count == 1 {
            self.init_high = value.high;
            self.init_low = value.low;
            self.sar_values.update(f64::NAN);
            self.uptrend_values.update(true);
            self.af_values.update(self.acceleration);
            return;
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
            
            self.sar_values.update(self.sar);
            self.uptrend_values.update(self.is_uptrend);
            self.af_values.update(self.af);
            return;
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
        
        self.sar_values.update(self.sar);
        self.uptrend_values.update(self.is_uptrend);
        self.af_values.update(self.af);
    }

    fn get(&self, key: i32) -> f64 {
        self.sar_values.get(key)
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
        self.sar_values.reset();
        self.uptrend_values.reset();
        self.af_values.reset();
    }
}
