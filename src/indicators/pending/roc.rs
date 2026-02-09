/// Rate of Change (ROC)
///
/// ROC measures the percentage change in price from P periods ago.
/// It's a momentum indicator that oscillates around zero.

use super::{base::BaseIndicator, Indicator};

#[derive(Debug, Clone)]
pub struct ROC<const P: usize, const S: usize = 1> {
    prevs: [f64; P],
    length: usize,
    pos: usize,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> ROC<P, S> {
    pub fn new() -> Self {
        Self {
            prevs: [f64::NAN; P],
            length: 0,
            pos: 0,
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const P: usize, const S: usize> Default for ROC<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for ROC<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) {
        if self.length < P {
            self.length += 1;
            self.prevs[self.pos] = value;
            self.pos = (self.pos + 1) % P;
            self.data.update(f64::NAN);
        } else {
            let old_value = self.prevs[self.pos];
            self.prevs[self.pos] = value;
            self.pos = (self.pos + 1) % P;
            
            if old_value == 0.0 {
                self.data.update(f64::NAN);
            } else {
                self.data.update(((value - old_value) / old_value) * 100.0);
            }
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.length = 0;
        self.pos = 0;
        self.prevs = [f64::NAN; P];
        self.data.reset();
    }
}
