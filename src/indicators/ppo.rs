/// Percentage Price Oscillator (PPO)
///
/// MACD expressed as percentage.
/// Better for cross-asset comparison than absolute MACD.
///
/// Formula: PPO = ((Fast EMA - Slow EMA) / Slow EMA) * 100

use super::{base::BaseIndicator, ema::EMA, Indicator};

#[derive(Debug, Clone, Copy, Default)]
pub struct PPOValues {
    pub ppo: f64,
    pub signal: f64,
    pub histogram: f64,
}

#[derive(Debug, Clone)]
pub struct PPO<const FAST: usize, const SLOW: usize, const SIGNAL: usize, const S: usize = 1> {
    fast_ema: EMA<FAST, 1>,
    slow_ema: EMA<SLOW, 1>,
    signal_ema: EMA<SIGNAL, 1>,
    length: usize,
    ppo: BaseIndicator<f64, S>,
    signal: BaseIndicator<f64, S>,
    histogram: BaseIndicator<f64, S>,
}

impl<const FAST: usize, const SLOW: usize, const SIGNAL: usize, const S: usize> PPO<FAST, SLOW, SIGNAL, S> {
    pub fn new() -> Self {
        Self {
            fast_ema: EMA::new(),
            slow_ema: EMA::new(),
            signal_ema: EMA::new(),
            length: 0,
            ppo: BaseIndicator::new_float(),
            signal: BaseIndicator::new_float(),
            histogram: BaseIndicator::new_float(),
        }
    }

    pub fn get_values(&self, key: i32) -> PPOValues {
        PPOValues {
            ppo: self.ppo.get(key),
            signal: self.signal.get(key),
            histogram: self.histogram.get(key),
        }
    }
}

impl<const FAST: usize, const SLOW: usize, const SIGNAL: usize, const S: usize> Default for PPO<FAST, SLOW, SIGNAL, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const FAST: usize, const SLOW: usize, const SIGNAL: usize, const S: usize> Indicator for PPO<FAST, SLOW, SIGNAL, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) {
        self.length += 1;
        
        self.fast_ema.update(value);
        self.slow_ema.update(value);
        
        let fast_value = self.fast_ema.get(0);
        let slow_value = self.slow_ema.get(0);
        
        if self.length < SLOW || slow_value.is_nan() || slow_value == 0.0 {
            self.ppo.update(f64::NAN);
            self.signal.update(f64::NAN);
            self.histogram.update(f64::NAN);
        } else {
            let ppo_value = ((fast_value - slow_value) / slow_value) * 100.0;
            
            self.signal_ema.update(ppo_value);
            let signal_value = self.signal_ema.get(0);
            
            let hist_value = if signal_value.is_nan() {
                f64::NAN
            } else {
                ppo_value - signal_value
            };
            
            self.ppo.update(ppo_value);
            self.signal.update(signal_value);
            self.histogram.update(hist_value);
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.ppo.get(key)
    }

    fn reset(&mut self) {
        self.fast_ema.reset();
        self.slow_ema.reset();
        self.signal_ema.reset();
        self.length = 0;
        self.ppo.reset();
        self.signal.reset();
        self.histogram.reset();
    }
}
