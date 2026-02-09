/// Normalized Average True Range (NATR)
///
/// NATR expresses the ATR as a percentage of the close price,
/// making it comparable across different price levels.
///
/// Formula: NATR = (ATR / Close) * 100

use super::{atr::ATR, base::BaseIndicator, Indicator, Ohlcv};

#[derive(Debug, Clone)]
pub struct NATR<const P: usize, const S: usize = 1> {
    atr: ATR<P, 1>,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> NATR<P, S> {
    pub fn new() -> Self {
        Self {
            atr: ATR::new(),
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const P: usize, const S: usize> Default for NATR<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for NATR<P, S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) {
        self.atr.update(value);
        let atr_value = self.atr.get(0);
        
        if atr_value.is_nan() || value.close == 0.0 {
            self.data.update(f64::NAN);
        } else {
            self.data.update((atr_value / value.close) * 100.0);
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.atr.reset();
        self.data.reset();
    }
}
