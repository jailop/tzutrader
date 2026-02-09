/// Return on Investment (ROI)
///
/// ROI calculates the percentage change from the previous value.
/// It's a simple momentum indicator.

use super::{base::BaseIndicator, Indicator};

#[derive(Debug, Clone)]
pub struct ROI<const S: usize = 1> {
    prev: f64,
    data: BaseIndicator<f64, S>,
}

impl<const S: usize> ROI<S> {
    pub fn new() -> Self {
        Self {
            prev: f64::NAN,
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const S: usize> Default for ROI<S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const S: usize> Indicator for ROI<S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) {
        if self.prev.is_nan() || self.prev == 0.0 {
            self.data.update(f64::NAN);
        } else {
            self.data.update(value / self.prev - 1.0);
        }
        self.prev = value;
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.prev = f64::NAN;
        self.data.reset();
    }
}
