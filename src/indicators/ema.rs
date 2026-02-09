/// Exponential Moving Average (EMA)
///
/// EMA gives more weight to recent prices, making it more responsive
/// to price changes than SMA. Uses a smoothing factor based on the period.

use super::{base::BaseIndicator, Indicator};

#[derive(Debug, Clone)]
pub struct EMA<const P: usize, const S: usize = 1> {
    alpha: f64,
    length: usize,
    prev: f64,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> EMA<P, S> {
    pub fn new() -> Self {
        Self::with_smoothing(2.0)
    }

    pub fn with_smoothing(smoothing: f64) -> Self {
        Self {
            alpha: smoothing / (1.0 + P as f64),
            length: 0,
            prev: 0.0,
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const P: usize, const S: usize> Default for EMA<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for EMA<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) {
        self.length += 1;
        if self.length < P {
            self.prev += value;
            self.data.update(f64::NAN);
        } else if self.length == P {
            self.prev += value;
            self.prev /= P as f64;
            self.data.update(self.prev);
        } else {
            self.prev = (value * self.alpha) + self.prev * (1.0 - self.alpha);
            self.data.update(self.prev);
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.length = 0;
        self.prev = 0.0;
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ema_basic() {
        let mut ema = EMA::<3, 1>::new();
        
        ema.update(5.0);
        assert!(ema.get(0).is_nan());
        
        ema.update(4.0);
        assert!(ema.get(0).is_nan());
        
        ema.update(3.0);
        assert_eq!(ema.get(0), 4.0); // Initial mean
    }
}
