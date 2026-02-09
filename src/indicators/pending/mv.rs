/// Moving Variance (MV)
///
/// Calculates the variance of values over a rolling window.
/// Uses a moving average internally to calculate variance.

use super::{base::BaseIndicator, ma::MA, Indicator};

#[derive(Debug, Clone)]
pub struct MV<const P: usize, const S: usize = 1> {
    ma: MA<P, 1>,
    prevs: [f64; P],
    length: usize,
    pos: usize,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> MV<P, S> {
    pub fn new() -> Self {
        Self {
            ma: MA::new(),
            prevs: [f64::NAN; P],
            length: 0,
            pos: 0,
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const P: usize, const S: usize> Default for MV<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for MV<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) {
        if self.length < P {
            self.length += 1;
        }
        
        self.prevs[self.pos] = value;
        self.pos = (self.pos + 1) % P;
        self.ma.update(value);
        
        if self.length < P {
            self.data.update(f64::NAN);
        } else {
            let mean = self.ma.get(0);
            let mut accum = 0.0;
            for i in 0..P {
                let diff = self.prevs[i] - mean;
                accum += diff * diff;
            }
            self.data.update(accum / P as f64);
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.length = 0;
        self.pos = 0;
        self.ma.reset();
        self.prevs = [f64::NAN; P];
        self.data.reset();
    }
}
