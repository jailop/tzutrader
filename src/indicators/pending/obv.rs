/// On-Balance Volume (OBV)
///
/// OBV is a momentum indicator that uses volume flow to predict changes in stock price.
/// It adds volume on up days and subtracts volume on down days.

use super::{base::BaseIndicator, Indicator, Ohlcv};

#[derive(Debug, Clone)]
pub struct OBV<const S: usize = 1> {
    prev_close: f64,
    obv_value: f64,
    initialized: bool,
    data: BaseIndicator<f64, S>,
}

impl<const S: usize> OBV<S> {
    pub fn new() -> Self {
        Self {
            prev_close: f64::NAN,
            obv_value: 0.0,
            initialized: false,
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const S: usize> Default for OBV<S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const S: usize> Indicator for OBV<S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) {
        if !self.initialized {
            self.obv_value = value.volume;
            self.prev_close = value.close;
            self.initialized = true;
        } else {
            if value.close > self.prev_close {
                self.obv_value += value.volume;
            } else if value.close < self.prev_close {
                self.obv_value -= value.volume;
            }
            self.prev_close = value.close;
        }
        
        self.data.update(self.obv_value);
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.prev_close = f64::NAN;
        self.obv_value = 0.0;
        self.initialized = false;
        self.data.reset();
    }
}
