//! Return on Investment (ROI)
//!
//! ROI calculates the percentage change from the previous value.
//! It's a simple momentum indicator.
//!
//! # Type Parameters
//! - `S`: Number of recent ROI values to store (compile-time constant, default 1)
//!
//! # Example
//!
//! ```rust
//! use tzutrader::indicators::{Indicator, roi::ROI};
//!
//! let mut roi = ROI::<1>::new();
//! let prices = vec![100.0, 105.0, 103.0, 110.0];
//! for price in prices {
//!     roi.update(price);
//!     if let Some(value) = roi.get(0) {
//!         println!("ROI: {:.2}%", value * 100.0);
//!     }
//! }
//! ```

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
            data: BaseIndicator::new(),
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

    fn update(&mut self, value: f64) -> Option<f64> {
        if self.prev.is_nan() || self.prev == 0.0 {
            self.data.update(f64::NAN);
            self.prev = value;
            None
        } else {
            let roi_value = value / self.prev - 1.0;
            self.data.update(roi_value);
            self.prev = value;
            self.data.get(0)
        }
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.prev = f64::NAN;
        self.data.reset();
    }
}
