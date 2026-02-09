/// Triangular Moving Average (TRIMA)
///
/// TRIMA is calculated by taking a Simple Moving Average of a Simple Moving Average.
/// This double smoothing produces a smoother line with less lag than SMA, but more
/// lag than EMA. The result is a triangular weighting where the central values have
/// more influence than the edges.

use super::{base::BaseIndicator, ma::MA, Indicator};

#[derive(Debug, Clone)]
pub struct TRIMA<const P: usize, const S: usize = 1> {
    first_ma: MA<P, 1>,
    second_ma: MA<P, 1>,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> TRIMA<P, S> {
    pub fn new() -> Self {
        Self {
            first_ma: MA::new(),
            second_ma: MA::new(),
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const P: usize, const S: usize> Default for TRIMA<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for TRIMA<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) {
        self.first_ma.update(value);
        let first_ma_value = self.first_ma.get(0);
        
        if first_ma_value.is_nan() {
            self.data.update(f64::NAN);
        } else {
            self.second_ma.update(first_ma_value);
            self.data.update(self.second_ma.get(0));
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.first_ma.reset();
        self.second_ma.reset();
        self.data.reset();
    }
}
