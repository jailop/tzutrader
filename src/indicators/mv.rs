//! Moving Variance (MV)
//!
//! Calculates the variance of values over a rolling window.
//! Uses a moving average internally to calculate variance.
//!
//! # Type Parameters
//! - `P`: Period for variance calculation (compile-time constant)
//! - `S`: Number of recent variance values to store (compile-time constant, default 1)
//!
//! # Example
//!
//! ```rust
//! use tzutrader::indicators::{Indicator, mv::MV};
//!
//! let mut mv = MV::<5, 1>::new();
//! for i in 1..=10 {
//!     mv.update(i as f64);
//! }
//! if let Some(variance) = mv.get(0) {
//!     println!("Variance: {:.2}", variance);
//! }
//! ```

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
            data: BaseIndicator::new(),
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

    fn update(&mut self, value: f64) -> Option<f64> {
        if self.length < P {
            self.length += 1;
        }

        self.prevs[self.pos] = value;
        self.pos = (self.pos + 1) % P;
        self.ma.update(value);

        if self.length < P {
            self.data.update(f64::NAN);
            None
        } else {
            let mean = self.ma.get(0).unwrap();
            let mut accum = 0.0;
            for i in 0..P {
                let diff = self.prevs[i] - mean;
                accum += diff * diff;
            }
            self.data.update(accum / P as f64);
            self.data.get(0)
        }
    }

    fn get(&self, key: i32) -> Option<f64> {
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
