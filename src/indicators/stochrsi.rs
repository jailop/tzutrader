/// Stochastic RSI (STOCHRSI)
///
/// Applies Stochastic oscillator to RSI values.
/// More sensitive than standard RSI, useful for overbought/oversold in trends.

use super::{base::BaseIndicator, ma::MA, rsi::RSI, Indicator, Ohlcv};

#[derive(Debug, Clone, Copy, Default)]
pub struct StochRSIValues {
    pub k: f64,
    pub d: f64,
}

#[derive(Debug, Clone)]
pub struct STOCHRSI<const RSIP: usize, const P: usize, const K: usize, const D: usize, const S: usize = 1> {
    rsi: RSI<RSIP, 1>,
    rsi_values: [f64; P],
    pos: usize,
    length: usize,
    k_ma: MA<K, 1>,
    d_ma: MA<D, 1>,
    k_values: BaseIndicator<f64, S>,
    d_values: BaseIndicator<f64, S>,
}

impl<const RSIP: usize, const P: usize, const K: usize, const D: usize, const S: usize> STOCHRSI<RSIP, P, K, D, S> {
    pub fn new() -> Self {
        Self {
            rsi: RSI::new(),
            rsi_values: [f64::NAN; P],
            pos: 0,
            length: 0,
            k_ma: MA::new(),
            d_ma: MA::new(),
            k_values: BaseIndicator::new_float(),
            d_values: BaseIndicator::new_float(),
        }
    }

    pub fn get_values(&self, key: i32) -> StochRSIValues {
        StochRSIValues {
            k: self.k_values.get(key),
            d: self.d_values.get(key),
        }
    }
}

impl<const RSIP: usize, const P: usize, const K: usize, const D: usize, const S: usize> Default for STOCHRSI<RSIP, P, K, D, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const RSIP: usize, const P: usize, const K: usize, const D: usize, const S: usize> Indicator for STOCHRSI<RSIP, P, K, D, S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) {
        self.rsi.update(value);
        let rsi_value = self.rsi.get(0);
        
        self.rsi_values[self.pos] = rsi_value;
        self.pos = (self.pos + 1) % P;
        if self.length < P {
            self.length += 1;
        }
        
        if self.length < P || rsi_value.is_nan() {
            self.k_values.update(f64::NAN);
            self.d_values.update(f64::NAN);
        } else {
            let mut highest_rsi = f64::NEG_INFINITY;
            let mut lowest_rsi = f64::INFINITY;
            
            for i in 0..P {
                let rsi = self.rsi_values[i];
                if !rsi.is_nan() {
                    if rsi > highest_rsi {
                        highest_rsi = rsi;
                    }
                    if rsi < lowest_rsi {
                        lowest_rsi = rsi;
                    }
                }
            }
            
            let raw_k = if highest_rsi == lowest_rsi {
                50.0
            } else {
                ((rsi_value - lowest_rsi) / (highest_rsi - lowest_rsi)) * 100.0
            };
            
            self.k_ma.update(raw_k);
            let smoothed_k = self.k_ma.get(0);
            self.d_ma.update(smoothed_k);
            let smoothed_d = self.d_ma.get(0);
            
            self.k_values.update(smoothed_k);
            self.d_values.update(smoothed_d);
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.k_values.get(key)
    }

    fn reset(&mut self) {
        self.rsi.reset();
        self.pos = 0;
        self.length = 0;
        self.k_ma.reset();
        self.d_ma.reset();
        self.rsi_values = [f64::NAN; P];
        self.k_values.reset();
        self.d_values.reset();
    }
}
