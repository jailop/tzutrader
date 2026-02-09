/// Relative Strength Index (RSI)
///
/// RSI measures the magnitude of recent price changes to evaluate
/// overbought or oversold conditions in the price of a stock or other asset.

use super::{base::BaseIndicator, ma::MA, Indicator, Ohlcv};

#[derive(Debug, Clone)]
pub struct RSI<const P: usize, const S: usize = 1> {
    gains: MA<P, 1>,
    losses: MA<P, 1>,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> RSI<P, S> {
    pub fn new() -> Self {
        Self {
            gains: MA::new(),
            losses: MA::new(),
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const P: usize, const S: usize> Default for RSI<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for RSI<P, S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) {
        let diff = value.close - value.open;
        self.gains.update(if diff >= 0.0 { diff } else { 0.0 });
        self.losses.update(if diff < 0.0 { -diff } else { 0.0 });
        
        let loss_avg = self.losses.get(0);
        if loss_avg.is_nan() {
            self.data.update(f64::NAN);
        } else {
            let gain_avg = self.gains.get(0);
            let rsi_value = 100.0 - 100.0 / (1.0 + gain_avg / loss_avg);
            self.data.update(rsi_value);
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.gains.reset();
        self.losses.reset();
        self.data.reset();
    }
}
