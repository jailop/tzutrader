//! Percentage Price Oscillator (PPO)
//!
//! MACD expressed as percentage.
//! Better for cross-asset comparison than absolute MACD.
//!
//! Formula: PPO = ((Fast EMA - Slow EMA) / Slow EMA) * 100

use super::{base::BaseIndicator, ema::EMA, Indicator};

#[derive(Debug, Clone, Copy, Default)]
pub struct PPOResult {
    pub ppo: f64,
    pub signal: f64,
    pub histogram: f64,
}

#[derive(Debug, Clone)]
pub struct PPO<const FAST: usize, const SLOW: usize, const SIGNAL: usize,
        const S: usize = 1> {
    fast_ema: EMA<FAST, 1>,
    slow_ema: EMA<SLOW, 1>,
    signal_ema: EMA<SIGNAL, 1>,
    length: usize,
    data: BaseIndicator<PPOResult, S>,
    // ppo: BaseIndicator<f64, S>,
    // signal: BaseIndicator<f64, S>,
    // histogram: BaseIndicator<f64, S>,
}

impl<const FAST: usize, const SLOW: usize, const SIGNAL: usize,
        const S: usize> PPO<FAST, SLOW, SIGNAL, S> {

    pub fn new() -> Self {
        Self {
            fast_ema: EMA::new(),
            slow_ema: EMA::new(),
            signal_ema: EMA::new(),
            length: 0,
            data: BaseIndicator::new(),
        }
    }
}

impl<const FAST: usize, const SLOW: usize, const SIGNAL: usize,
        const S: usize> Default for PPO<FAST, SLOW, SIGNAL, S> {

    fn default() -> Self {
        Self::new()
    }
}

impl<const FAST: usize, const SLOW: usize, const SIGNAL: usize,
        const S: usize> Indicator for PPO<FAST, SLOW, SIGNAL, S> {
    type Input = f64;
    type Output = PPOResult;

    fn update(&mut self, value: f64) -> Option<PPOResult> {
        self.length += 1;
        let fast_value = self.fast_ema.update(value).unwrap_or(f64::NAN);
        let slow_value = self.slow_ema.update(value).unwrap_or(f64::NAN);
        if self.length < SLOW || slow_value.is_nan() || slow_value == 0.0 {
            self.data.update(PPOResult {
                ppo: f64::NAN,
                signal: f64::NAN,
                histogram: f64::NAN,
            });
        } else {
            let ppo_value = ((fast_value - slow_value) / slow_value) * 100.0;
            let signal_value = self.signal_ema.update(ppo_value).unwrap_or(f64::NAN);
            let hist_value = if signal_value.is_nan() {
                f64::NAN
            } else {
                ppo_value - signal_value
            };
            self.data.update(PPOResult {
                ppo: ppo_value,
                signal: signal_value,
                histogram: hist_value,
            });
        }
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<PPOResult> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.fast_ema.reset();
        self.slow_ema.reset();
        self.signal_ema.reset();
        self.length = 0;
        self.data.reset();
    }
}
