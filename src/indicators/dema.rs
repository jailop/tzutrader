/// Double Exponential Moving Average (DEMA)
///
/// DEMA is designed to reduce the lag of traditional EMAs by using a combination
/// of a single EMA and a double EMA. It's more responsive to price changes than
/// both SMA and EMA.
///
/// Formula: DEMA = 2 * EMA(price) - EMA(EMA(price))

use super::{base::BaseIndicator, ema::EMA, Indicator};

#[derive(Debug, Clone)]
pub struct DEMA<const P: usize, const S: usize = 1> {
    first_ema: EMA<P, 1>,
    second_ema: EMA<P, 1>,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> DEMA<P, S> {
    pub fn new() -> Self {
        Self {
            first_ema: EMA::new(),
            second_ema: EMA::new(),
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const P: usize, const S: usize> Default for DEMA<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for DEMA<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) {
        self.first_ema.update(value);
        let ema1 = self.first_ema.get(0);
        
        if ema1.is_nan() {
            self.data.update(f64::NAN);
        } else {
            self.second_ema.update(ema1);
            let ema2 = self.second_ema.get(0);
            if ema2.is_nan() {
                self.data.update(f64::NAN);
            } else {
                self.data.update(2.0 * ema1 - ema2);
            }
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.first_ema.reset();
        self.second_ema.reset();
        self.data.reset();
    }
}
