/// Accumulation/Distribution Line (AD)
///
/// AD is a volume-based indicator that measures the cumulative flow of money
/// into and out of a security. It uses the close location value (CLV) to
/// determine the money flow multiplier.

use super::{base::BaseIndicator, Indicator, Ohlcv};

#[derive(Debug, Clone)]
pub struct AD<const S: usize = 1> {
    ad_value: f64,
    data: BaseIndicator<f64, S>,
}

impl<const S: usize> AD<S> {
    pub fn new() -> Self {
        Self {
            ad_value: 0.0,
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const S: usize> Default for AD<S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const S: usize> Indicator for AD<S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) {
        let range = value.high - value.low;
        if range == 0.0 {
            self.data.update(self.ad_value);
        } else {
            let clv = ((value.close - value.low) - (value.high - value.close)) / range;
            self.ad_value += clv * value.volume;
            self.data.update(self.ad_value);
        }
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.ad_value = 0.0;
        self.data.reset();
    }
}
