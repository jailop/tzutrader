/// Moving Average Convergence Divergence (MACD)
///
/// MACD is a trend-following momentum indicator that shows the relationship
/// between two moving averages of prices.

use super::{base::BaseIndicator, ema::EMA, Indicator};

#[derive(Debug, Clone, Copy, Default)]
pub struct MACDValues {
    pub macd: f64,
    pub signal: f64,
    pub hist: f64,
}

#[derive(Debug, Clone)]
pub struct MACD<const SHORT: usize, const LONG: usize, const DIFF: usize, const S: usize = 1> {
    short_ema: EMA<SHORT, 1>,
    long_ema: EMA<LONG, 1>,
    diff_ema: EMA<DIFF, 1>,
    counter: usize,
    macd: BaseIndicator<f64, S>,
    signal: BaseIndicator<f64, S>,
    hist: BaseIndicator<f64, S>,
}

impl<const SHORT: usize, const LONG: usize, const DIFF: usize, const S: usize> MACD<SHORT, LONG, DIFF, S> {
    pub fn new() -> Self {
        Self {
            short_ema: EMA::new(),
            long_ema: EMA::new(),
            diff_ema: EMA::new(),
            counter: 0,
            macd: BaseIndicator::new_float(),
            signal: BaseIndicator::new_float(),
            hist: BaseIndicator::new_float(),
        }
    }

    pub fn get_values(&self, key: i32) -> MACDValues {
        MACDValues {
            macd: self.macd.get(key),
            signal: self.signal.get(key),
            hist: self.hist.get(key),
        }
    }
}

impl<const SHORT: usize, const LONG: usize, const DIFF: usize, const S: usize> Default for MACD<SHORT, LONG, DIFF, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const SHORT: usize, const LONG: usize, const DIFF: usize, const S: usize> Indicator for MACD<SHORT, LONG, DIFF, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) {
        self.counter += 1;
        self.short_ema.update(value);
        self.long_ema.update(value);
        
        let start = if LONG > SHORT { LONG } else { SHORT };
        if self.counter >= start {
            let diff = self.short_ema.get(0) - self.long_ema.get(0);
            self.diff_ema.update(diff);
            self.macd.update(diff);
            self.signal.update(self.diff_ema.get(0));
            self.hist.update(diff - self.diff_ema.get(0));
        } else {
            self.macd.update(f64::NAN);
            self.signal.update(f64::NAN);
            self.hist.update(f64::NAN);
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.macd.get(key)
    }

    fn reset(&mut self) {
        self.short_ema.reset();
        self.long_ema.reset();
        self.diff_ema.reset();
        self.counter = 0;
        self.macd.reset();
        self.signal.reset();
        self.hist.reset();
    }
}
