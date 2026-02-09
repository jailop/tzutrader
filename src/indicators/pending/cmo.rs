/// Chande Momentum Oscillator (CMO)
///
/// Alternative to RSI that uses sum of gains/losses instead of average.
/// Range: -100 to +100 (vs RSI 0 to 100).
///
/// Formula: CMO = ((sumGains - sumLosses) / (sumGains + sumLosses)) * 100

use super::{base::BaseIndicator, Indicator};

#[derive(Debug, Clone)]
pub struct CMO<const P: usize, const S: usize = 1> {
    gains: [f64; P],
    losses: [f64; P],
    pos: usize,
    length: usize,
    prev_close: f64,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> CMO<P, S> {
    pub fn new() -> Self {
        Self {
            gains: [0.0; P],
            losses: [0.0; P],
            pos: 0,
            length: 0,
            prev_close: f64::NAN,
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const P: usize, const S: usize> Default for CMO<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for CMO<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, close: f64) {
        let mut gain = 0.0;
        let mut loss = 0.0;
        
        if !self.prev_close.is_nan() {
            let change = close - self.prev_close;
            if change > 0.0 {
                gain = change;
            } else if change < 0.0 {
                loss = -change;
            }
        }
        
        self.prev_close = close;
        
        self.gains[self.pos] = gain;
        self.losses[self.pos] = loss;
        self.pos = (self.pos + 1) % P;
        if self.length < P {
            self.length += 1;
        }
        
        if self.length < P {
            self.data.update(f64::NAN);
        } else {
            let sum_gains: f64 = self.gains.iter().sum();
            let sum_losses: f64 = self.losses.iter().sum();
            
            let total_movement = sum_gains + sum_losses;
            let cmo_value = if total_movement == 0.0 {
                0.0
            } else {
                ((sum_gains - sum_losses) / total_movement) * 100.0
            };
            
            self.data.update(cmo_value);
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.pos = 0;
        self.length = 0;
        self.prev_close = f64::NAN;
        self.gains = [0.0; P];
        self.losses = [0.0; P];
        self.data.reset();
    }
}
