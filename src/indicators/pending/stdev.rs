/// Standard Deviation (STDEV)
///
/// Calculates the standard deviation of values over a rolling window.
/// Standard deviation is the square root of the variance.

use super::{base::BaseIndicator, mv::MV, Indicator};

#[derive(Debug, Clone)]
pub struct STDEV<const P: usize, const S: usize = 1> {
    mv: MV<P, 1>,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> STDEV<P, S> {
    pub fn new() -> Self {
        Self {
            mv: MV::new(),
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const P: usize, const S: usize> Default for STDEV<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for STDEV<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) {
        self.mv.update(value);
        let variance = self.mv.get(0);
        if variance.is_nan() {
            self.data.update(f64::NAN);
        } else {
            self.data.update(variance.sqrt());
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.mv.reset();
        self.data.reset();
    }
}
