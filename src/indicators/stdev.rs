//! Standard Deviation (STDEV)
//!
//! Calculates the standard deviation of values over a rolling window.
//! Standard deviation is the square root of the variance.
//!
//! # Type Parameters
//! - `P`: Period for standard deviation calculation (compile-time constant)
//! - `S`: Number of recent stdev values to store (compile-time constant, default 1)

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
            data: BaseIndicator::new(),
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

    fn update(&mut self, value: f64) -> Option<f64> {
        self.mv.update(value);
        let variance = self.mv.get(0);
        if variance.is_none() {
            self.data.update(f64::NAN);
            None
        } else {
            self.data.update(variance.unwrap().sqrt());
            self.data.get(0)
        }
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.mv.reset();
        self.data.reset();
    }
}
