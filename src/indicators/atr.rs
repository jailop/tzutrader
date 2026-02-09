/// Average True Range (ATR)
///
/// ATR measures market volatility by decomposing the entire range of an asset
/// price for that period. It uses the true range, which is the greatest of:
/// - Current High minus Current Low
/// - Absolute value of Current High minus Previous Close
/// - Absolute value of Current Low minus Previous Close

use super::{base::BaseIndicator, ma::MA, Indicator, Ohlcv};

#[derive(Debug, Clone)]
pub struct ATR<const P: usize, const S: usize = 1> {
    prev_close: f64,
    ma: MA<P, 1>,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> ATR<P, S> {
    pub fn new() -> Self {
        Self {
            prev_close: f64::NAN,
            ma: MA::new(),
            data: BaseIndicator::new_float(),
        }
    }
}

impl<const P: usize, const S: usize> Default for ATR<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for ATR<P, S> {
    type Input = Ohlcv;
    type Output = f64;

    fn update(&mut self, value: Ohlcv) {
        let tr = if self.prev_close.is_nan() {
            value.high - value.low
        } else {
            let hl = value.high - value.low;
            let hc = (value.high - self.prev_close).abs();
            let lc = (value.low - self.prev_close).abs();
            hl.max(hc).max(lc)
        };
        
        self.prev_close = value.close;
        self.ma.update(tr);
        self.data.update(self.ma.get(0));
    }

    fn get(&self, key: i32) -> f64 {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.prev_close = f64::NAN;
        self.ma.reset();
        self.data.reset();
    }
}
