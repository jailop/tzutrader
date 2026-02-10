//! Triple Exponential Moving Average (TEMA)
//!
//! TEMA takes the DEMA concept further by using three EMAs to achieve even less lag.
//! It's highly responsive to price changes with minimal lag.
//!
//! Formula: TEMA = 3 * EMA - 3 * EMA(EMA) + EMA(EMA(EMA))
//!
//! # Type Parameters
//! - `P`: Period for the exponential moving averages (compile-time constant)
//! - `S`: Number of recent TEMA values to store (compile-time constant, default 1)
//!
//! # Example
//!
//! ```rust
//! use tzutrader::indicators::{Indicator, tema::TEMA};
//!
//! let mut tema = TEMA::<10, 1>::new();
//! for i in 1..=30 {
//!     tema.update(i as f64);
//! }
//! if let Some(value) = tema.get(0) {
//!     println!("TEMA: {:.2}", value);
//! }
//! ```

use super::{base::BaseIndicator, ema::EMA, Indicator};

#[derive(Debug, Clone)]
pub struct TEMA<const P: usize, const S: usize = 1> {
    first_ema: EMA<P, 1>,
    second_ema: EMA<P, 1>,
    third_ema: EMA<P, 1>,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> TEMA<P, S> {
    pub fn new() -> Self {
        Self {
            first_ema: EMA::new(),
            second_ema: EMA::new(),
            third_ema: EMA::new(),
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for TEMA<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for TEMA<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) -> Option<f64> {
        self.first_ema.update(value);
        let ema1 = self.first_ema.get(0);

        if ema1.is_none() {
            self.data.update(f64::NAN);
            None
        } else {
            self.second_ema.update(ema1.unwrap());
            let ema2 = self.second_ema.get(0);
            if ema2.is_none() {
                self.data.update(f64::NAN);
                None
            } else {
                self.third_ema.update(ema2.unwrap());
                let ema3 = self.third_ema.get(0);
                if ema3.is_none() {
                    self.data.update(f64::NAN);
                    None
                } else {
                    self.data
                        .update(3.0 * ema1.unwrap() - 3.0 * ema2.unwrap() + ema3.unwrap());
                    self.data.get(0)
                }
            }
        }
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.first_ema.reset();
        self.second_ema.reset();
        self.third_ema.reset();
        self.data.reset();
    }
}
