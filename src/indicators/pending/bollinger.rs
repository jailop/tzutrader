/// Bollinger Bands
///
/// Bollinger Bands consist of a middle band (SMA) and two outer bands
/// (standard deviations away from the middle). They are used to measure
/// volatility and identify overbought/oversold conditions.

use super::{base::BaseIndicator, ma::MA, stdev::STDEV, Indicator};

#[derive(Debug, Clone, Copy, Default)]
pub struct BollingerValues {
    pub upper: f64,
    pub middle: f64,
    pub lower: f64,
}

#[derive(Debug, Clone)]
pub struct BollingerBands<const P: usize, const S: usize = 1> {
    ma: MA<P, 1>,
    stdev: STDEV<P, 1>,
    num_std_dev: f64,
    upper: BaseIndicator<f64, S>,
    middle: BaseIndicator<f64, S>,
    lower: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> BollingerBands<P, S> {
    pub fn new() -> Self {
        Self::with_std_dev(2.0)
    }

    pub fn with_std_dev(num_std_dev: f64) -> Self {
        Self {
            ma: MA::new(),
            stdev: STDEV::new(),
            num_std_dev,
            upper: BaseIndicator::new_float(),
            middle: BaseIndicator::new_float(),
            lower: BaseIndicator::new_float(),
        }
    }

    pub fn get_values(&self, key: i32) -> BollingerValues {
        BollingerValues {
            upper: self.upper.get(key),
            middle: self.middle.get(key),
            lower: self.lower.get(key),
        }
    }
}

impl<const P: usize, const S: usize> Default for BollingerBands<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for BollingerBands<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) {
        self.ma.update(value);
        self.stdev.update(value);
        
        let middle = self.ma.get(0);
        let stddev = self.stdev.get(0);
        
        if middle.is_nan() || stddev.is_nan() {
            self.upper.update(f64::NAN);
            self.middle.update(f64::NAN);
            self.lower.update(f64::NAN);
        } else {
            let offset = stddev * self.num_std_dev;
            self.upper.update(middle + offset);
            self.middle.update(middle);
            self.lower.update(middle - offset);
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.middle.get(key)
    }

    fn reset(&mut self) {
        self.ma.reset();
        self.stdev.reset();
        self.upper.reset();
        self.middle.reset();
        self.lower.reset();
    }
}
