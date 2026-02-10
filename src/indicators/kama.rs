//! Kaufman Adaptive Moving Average (KAMA)
//!
//! KAMA is an adaptive moving average that adjusts its smoothing constant based on
//! market volatility. In trending markets, it becomes more responsive (like EMA).
//! In choppy markets, it becomes smoother (like SMA).
//!
//! The calculation uses an Efficiency Ratio (ER) to measure market direction:
//! - ER = (absolute price change) / (sum of absolute bar-to-bar changes)
//! - ER near 1.0 = strong trend (more responsive)
//! - ER near 0.0 = choppy/sideways (more smoothing)
//!
//! # Type Parameters
//! - `P`: Period for calculating the efficiency ratio (compile-time constant)
//! - `S`: Number of recent KAMA values to store (compile-time constant, default 1)

use super::{base::BaseIndicator, Indicator};

#[derive(Debug, Clone)]
pub struct KAMA<const P: usize, const S: usize = 1> {
    prices: Vec<f64>,
    pos: usize,
    length: usize,
    prev_kama: f64,
    initialized: bool,
    fast_sc: f64,
    slow_sc: f64,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> KAMA<P, S> {
    pub fn new() -> Self {
        Self::with_periods(2, 30)
    }

    pub fn with_periods(fast_period: usize, slow_period: usize) -> Self {
        Self {
            prices: vec![f64::NAN; P + 1],
            pos: 0,
            length: 0,
            prev_kama: f64::NAN,
            initialized: false,
            fast_sc: 2.0 / (fast_period as f64 + 1.0),
            slow_sc: 2.0 / (slow_period as f64 + 1.0),
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for KAMA<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for KAMA<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) -> Option<f64> {
        self.prices[self.pos] = value;
        self.pos = (self.pos + 1) % (P + 1);

        if self.length < P + 1 {
            self.length += 1;
        }

        if self.length < P + 1 {
            self.data.update(f64::NAN);
            return None;
        }

        if !self.initialized {
            self.prev_kama = self.prices[(self.pos + P) % (P + 1)];
            self.initialized = true;
        }

        let oldest_idx = self.pos;
        let newest_idx = (self.pos + P) % (P + 1);

        let change = (self.prices[newest_idx] - self.prices[oldest_idx]).abs();

        let mut volatility = 0.0;
        for i in 0..P {
            let idx1 = (oldest_idx + i) % (P + 1);
            let idx2 = (oldest_idx + i + 1) % (P + 1);
            volatility += (self.prices[idx2] - self.prices[idx1]).abs();
        }

        let er = if volatility > 0.0 {
            change / volatility
        } else {
            0.0
        };

        let sc = er * (self.fast_sc - self.slow_sc) + self.slow_sc;
        let sc2 = sc * sc;

        let kama_value = self.prev_kama + sc2 * (value - self.prev_kama);
        self.prev_kama = kama_value;
        self.data.update(kama_value);
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.pos = 0;
        self.length = 0;
        self.prev_kama = f64::NAN;
        self.initialized = false;
        self.prices = vec![f64::NAN; P + 1];
        self.data.reset();
    }
}
