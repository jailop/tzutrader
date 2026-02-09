/// Average Directional Movement Index (ADX)
///
/// Measures the strength of a trend (not direction).
/// Includes +DI and -DI which show trend direction.
/// Uses Wilder's smoothing formula for TR, +DM, -DM, and ADX.

use super::{base::BaseIndicator, Indicator, Ohlcv};

#[derive(Debug, Clone, Copy, Default)]
pub struct ADXValues {
    pub adx: f64,
    pub plus_di: f64,
    pub minus_di: f64,
}

#[derive(Debug, Clone)]
pub struct ADX<const P: usize, const S: usize = 1> {
    prev_high: f64,
    prev_low: f64,
    prev_close: f64,
    smoothed_tr: f64,
    smoothed_plus_dm: f64,
    smoothed_minus_dm: f64,
    smoothed_dx: f64,
    length: usize,
    initialized: bool,
    adx_values: BaseIndicator<f64, S>,
    plus_di_values: BaseIndicator<f64, S>,
    minus_di_values: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> ADX<P, S> {
    pub fn new() -> Self {
        Self {
            prev_high: f64::NAN,
            prev_low: f64::NAN,
            prev_close: f64::NAN,
            smoothed_tr: 0.0,
            smoothed_plus_dm: 0.0,
            smoothed_minus_dm: 0.0,
            smoothed_dx: 0.0,
            length: 0,
            initialized: false,
            adx_values: BaseIndicator::new_float(),
            plus_di_values: BaseIndicator::new_float(),
            minus_di_values: BaseIndicator::new_float(),
        }
    }

    pub fn get_values(&self, key: i32) -> ADXValues {
        ADXValues {
            adx: self.adx_values.get(key),
            plus_di: self.plus_di_values.get(key),
            minus_di: self.minus_di_values.get(key),
        }
    }
}

impl<const P: usize, const S: usize> Default for ADX<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for ADX<P, S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) {
        if self.prev_high.is_nan() {
            self.prev_high = value.high;
            self.prev_low = value.low;
            self.prev_close = value.close;
            self.adx_values.update(f64::NAN);
            self.plus_di_values.update(f64::NAN);
            self.minus_di_values.update(f64::NAN);
        } else {
            let tr1 = value.high - value.low;
            let tr2 = (value.high - self.prev_close).abs();
            let tr3 = (value.low - self.prev_close).abs();
            let tr = tr1.max(tr2).max(tr3);
            
            let up_move = value.high - self.prev_high;
            let down_move = self.prev_low - value.low;
            
            let mut plus_dm = 0.0;
            let mut minus_dm = 0.0;
            
            if up_move > down_move && up_move > 0.0 {
                plus_dm = up_move;
            }
            if down_move > up_move && down_move > 0.0 {
                minus_dm = down_move;
            }
            
            self.length += 1;
            
            if self.length <= P {
                self.smoothed_tr += tr;
                self.smoothed_plus_dm += plus_dm;
                self.smoothed_minus_dm += minus_dm;
                
                if self.length == P {
                    self.smoothed_tr /= P as f64;
                    self.smoothed_plus_dm /= P as f64;
                    self.smoothed_minus_dm /= P as f64;
                    self.initialized = true;
                }
                
                self.adx_values.update(f64::NAN);
                self.plus_di_values.update(f64::NAN);
                self.minus_di_values.update(f64::NAN);
            } else {
                self.smoothed_tr = (self.smoothed_tr * (P - 1) as f64 + tr) / P as f64;
                self.smoothed_plus_dm = (self.smoothed_plus_dm * (P - 1) as f64 + plus_dm) / P as f64;
                self.smoothed_minus_dm = (self.smoothed_minus_dm * (P - 1) as f64 + minus_dm) / P as f64;
                
                let mut plus_di = 0.0;
                let mut minus_di = 0.0;
                
                if self.smoothed_tr > 0.0 {
                    plus_di = 100.0 * self.smoothed_plus_dm / self.smoothed_tr;
                    minus_di = 100.0 * self.smoothed_minus_dm / self.smoothed_tr;
                }
                
                let mut dx = 0.0;
                let di_sum = plus_di + minus_di;
                if di_sum > 0.0 {
                    dx = 100.0 * (plus_di - minus_di).abs() / di_sum;
                }
                
                if self.length == P + 1 {
                    self.smoothed_dx = dx;
                } else {
                    self.smoothed_dx = (self.smoothed_dx * (P - 1) as f64 + dx) / P as f64;
                }
                
                self.adx_values.update(self.smoothed_dx);
                self.plus_di_values.update(plus_di);
                self.minus_di_values.update(minus_di);
            }
            
            self.prev_high = value.high;
            self.prev_low = value.low;
            self.prev_close = value.close;
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.adx_values.get(key)
    }

    fn reset(&mut self) {
        self.prev_high = f64::NAN;
        self.prev_low = f64::NAN;
        self.prev_close = f64::NAN;
        self.smoothed_tr = 0.0;
        self.smoothed_plus_dm = 0.0;
        self.smoothed_minus_dm = 0.0;
        self.smoothed_dx = 0.0;
        self.length = 0;
        self.initialized = false;
        self.adx_values.reset();
        self.plus_di_values.reset();
        self.minus_di_values.reset();
    }
}
