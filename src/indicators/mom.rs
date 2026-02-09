/// Momentum (MOM)
///
/// Simple Momentum - Current price minus price N periods ago.
/// Foundation for many other indicators.
/// Positive = upward momentum, Negative = downward momentum.

use super::{base::BaseIndicator, Indicator};

#[derive(Debug, Clone)]
pub struct MOM<const P: usize, const S: usize = 1> {
    prices: [f64; P],
    pos: usize,
    length: usize,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> MOM<P, S> {
    pub fn new() -> Self {
        Self {
            prices: [f64::NAN; P],
            pos: 0,
            length: 0,
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const P: usize, const S: usize> Default for MOM<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for MOM<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, price: f64) {
        if self.length < P {
            self.prices[self.pos] = price;
            self.pos = (self.pos + 1) % P;
            self.length += 1;
            self.data.update(f64::NAN);
        } else {
            let old_price = self.prices[self.pos];
            let momentum = price - old_price;
            
            self.prices[self.pos] = price;
            self.pos = (self.pos + 1) % P;
            
            self.data.update(momentum);
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.pos = 0;
        self.length = 0;
        self.prices = [f64::NAN; P];
        self.data.reset();
    }
}
