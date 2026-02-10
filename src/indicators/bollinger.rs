//! Bollinger Bands
//!
//! Bollinger Bands consist of a middle band (SMA) and two outer bands
//! (standard deviations away from the middle). They are used to measure
//! volatility and identify overbought/oversold conditions.
//!
//! # Type Parameters
//! - `P`: Period for moving average and standard deviation (compile-time constant)
//! - `S`: Number of recent Bollinger Band values to store
//!
//! # Example
//!
//! ```rust
//! use tzutrader::indicators::{Indicator, bollinger::BollingerBands};
//!
//! // Standard Bollinger Bands with period 20, 2 standard deviations
//! let mut bb = BollingerBands::<20, 3>::new();
//!
//! // Warmup period
//! for i in 0..20 {
//!     bb.update(100.0 + i as f64 * 0.5);
//! }
//!
//! // After warmup, get all three bands
//! if let Some(bands) = bb.update(110.0) {
//!     println!("Upper Band: {:.2}", bands.upper);
//!     println!("Middle Band: {:.2}", bands.middle);
//!     println!("Lower Band: {:.2}", bands.lower);
//!     println!("Bandwidth: {:.2}", bands.upper - bands.lower);
//! }
//! ```

use super::{base::BaseIndicator, ma::MA, stdev::STDEV, Indicator};

#[derive(Debug, Clone, Copy, Default)]
pub struct BollingerResult {
    pub upper: f64,
    pub middle: f64,
    pub lower: f64,
}

#[derive(Debug, Clone)]
pub struct BollingerBands<const P: usize, const S: usize = 1> {
    ma: MA<P, 1>,
    stdev: STDEV<P, 1>,
    num_std_dev: f64,
    data: BaseIndicator<BollingerResult, S>,
}

impl<const P: usize, const S: usize> BollingerBands<P, S> {
    pub fn new() -> Self {
        Self::new_with_stddev(2.0)
    }

    pub fn new_with_stddev(num_std_dev: f64) -> Self {
        Self {
            ma: MA::new(),
            stdev: STDEV::new(),
            num_std_dev,
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for BollingerBands<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for BollingerBands<P, S> {
    type Input = f64;
    type Output = BollingerResult;

    fn update(&mut self, value: f64) -> Option<BollingerResult> {
        self.ma.update(value);
        self.stdev.update(value);

        let middle = self.ma.get(0);
        let stddev = self.stdev.get(0);

        if middle.is_none() || stddev.is_none() {
            return None;
        }
        
        let m = middle.unwrap();
        let s = stddev.unwrap();
        let offset = s * self.num_std_dev;
        self.data.update(BollingerResult {
            upper: m + offset,
            middle: m,
            lower: m - offset,
        });
        
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<BollingerResult> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.ma.reset();
        self.stdev.reset();
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bollinger_warmup_period() {
        const P: usize = 20;
        let mut bb = BollingerBands::<P, 1>::new();

        // During warmup: should return None
        for i in 0..(P - 1) {
            assert!(bb.update(100.0 + i as f64).is_none(), 
                "Update {} should return None during warmup", i + 1);
        }
        
        // Pth value should return Some
        assert!(bb.update(110.0).is_some());
    }

    #[test]
    fn test_bollinger_middle_band() {
        // Middle band should equal the SMA
        const P: usize = 10;
        let mut bb = BollingerBands::<P, 1>::new();

        let values = vec![100.0, 102.0, 104.0, 103.0, 105.0, 107.0, 106.0, 108.0, 110.0, 109.0];
        for &val in &values {
            bb.update(val);
        }

        let result = bb.get(0).unwrap();
        let expected_sma: f64 = values.iter().sum::<f64>() / P as f64;
        
        assert!((result.middle - expected_sma).abs() < 0.01,
            "Middle band should equal SMA");
    }

    #[test]
    fn test_bollinger_band_symmetry() {
        // Upper and lower bands should be equidistant from middle
        const P: usize = 10;
        let mut bb = BollingerBands::<P, 1>::new();

        for i in 0..20 {
            bb.update(100.0 + i as f64);
        }

        let result = bb.get(0).unwrap();
        let upper_distance = result.upper - result.middle;
        let lower_distance = result.middle - result.lower;
        
        assert!((upper_distance - lower_distance).abs() < 0.001,
            "Bands should be symmetric around middle");
    }

    #[test]
    fn test_bollinger_stddev_parameter() {
        // Test different standard deviation multipliers
        const P: usize = 10;
        let mut bb2 = BollingerBands::<P, 1>::new_with_stddev(2.0);
        let mut bb3 = BollingerBands::<P, 1>::new_with_stddev(3.0);

        for i in 0..20 {
            bb2.update(100.0 + i as f64);
            bb3.update(100.0 + i as f64);
        }

        let result2 = bb2.get(0).unwrap();
        let result3 = bb3.get(0).unwrap();
        
        // 3-stddev bands should be wider than 2-stddev bands
        let width2 = result2.upper - result2.lower;
        let width3 = result3.upper - result3.lower;
        
        assert!(width3 > width2,
            "3-stddev bands should be wider than 2-stddev bands");
        assert!((width3 / width2 - 1.5).abs() < 0.001,
            "Width ratio should be 3/2 = 1.5");
    }

    #[test]
    fn test_bollinger_volatility_expansion() {
        // Bands should widen during high volatility
        const P: usize = 10;
        let mut bb = BollingerBands::<P, 1>::new();

        // Low volatility period
        for _ in 0..P {
            bb.update(100.0);
        }
        let low_vol = bb.get(0).unwrap();
        let low_bandwidth = low_vol.upper - low_vol.lower;

        // High volatility period
        for i in 0..P {
            let value = if i % 2 == 0 { 90.0 } else { 110.0 };
            bb.update(value);
        }
        let high_vol = bb.get(0).unwrap();
        let high_bandwidth = high_vol.upper - high_vol.lower;

        assert!(high_bandwidth > low_bandwidth,
            "Bandwidth should increase with higher volatility");
    }

    #[test]
    fn test_bollinger_squeeze() {
        // Bands should contract during low volatility (squeeze)
        const P: usize = 10;
        let mut bb = BollingerBands::<P, 1>::new();

        // Volatile period
        for i in 0..P {
            let value = 100.0 + (i % 3) as f64 * 10.0;
            bb.update(value);
        }
        let volatile = bb.get(0).unwrap();
        let wide_bandwidth = volatile.upper - volatile.lower;

        // Consolidation period
        for _ in 0..P {
            bb.update(100.0);
        }
        let consolidated = bb.get(0).unwrap();
        let narrow_bandwidth = consolidated.upper - consolidated.lower;

        assert!(narrow_bandwidth < wide_bandwidth,
            "Bands should squeeze during low volatility");
        assert!(narrow_bandwidth < 0.1,
            "Bandwidth should be near zero with no variation");
    }

    #[test]
    fn test_bollinger_price_touch() {
        // Test price touching/exceeding bands
        const P: usize = 20;
        let mut bb = BollingerBands::<P, 1>::new();

        // Establish baseline
        for _ in 0..P {
            bb.update(100.0);
        }

        // Price spike above upper band
        bb.update(150.0);
        let result = bb.get(0).unwrap();
        
        // After the spike, the bands will have widened
        // Just verify the structure is valid
        assert!(result.upper > result.middle);
        assert!(result.middle > result.lower);
    }

    #[test]
    fn test_bollinger_trend_following() {
        // In strong uptrend, all bands should trend upward
        const P: usize = 10;
        let mut bb = BollingerBands::<P, 3>::new();

        // Uptrend
        for i in 0..25 {
            bb.update(100.0 + i as f64 * 2.0);
        }

        let older = bb.get(-2).unwrap();
        let newer = bb.get(0).unwrap();

        assert!(newer.middle > older.middle,
            "Middle band should trend upward");
        assert!(newer.upper > older.upper,
            "Upper band should trend upward");
        assert!(newer.lower > older.lower,
            "Lower band should trend upward");
    }

    #[test]
    fn test_bollinger_reset() {
        const P: usize = 20;
        let mut bb = BollingerBands::<P, 1>::new();

        // Add values
        for i in 0..30 {
            bb.update(100.0 + i as f64);
        }
        
        assert!(bb.get(0).is_some());

        // Reset
        bb.reset();

        // Should need warmup again
        for i in 0..(P - 1) {
            assert!(bb.update(100.0 + i as f64).is_none(),
                "After reset, update {} should return None", i + 1);
        }
        assert!(bb.update(200.0).is_some());
    }

    #[test]
    fn test_bollinger_historical_access() {
        const P: usize = 10;
        let mut bb = BollingerBands::<P, 4>::new();

        // Add warmup + 3 more to fill buffer (10 + 3 = 13)
        for i in 0..13 {
            bb.update(100.0 + i as f64);
        }

        // Access current and historical values (only 4 stored)
        for i in 0..4 {
            assert!(bb.get(-i).is_some(), 
                "Should be able to access Bollinger at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(bb.get(-4).is_none());
    }

    #[test]
    fn test_bollinger_get_before_warmup() {
        const P: usize = 20;
        let mut bb = BollingerBands::<P, 1>::new();

        // Before any updates
        assert!(bb.get(0).is_none());

        // During warmup
        for i in 0..(P - 1) {
            bb.update(100.0 + i as f64);
            assert!(bb.get(0).is_none(), 
                "get(0) should return None during warmup at update {}", i + 1);
        }

        // After warmup
        bb.update(200.0);
        assert!(bb.get(0).is_some());
    }

    #[test]
    fn test_bollinger_percentage_b() {
        // %B = (Price - Lower Band) / (Upper Band - Lower Band)
        // When price is at middle band, %B should be 0.5
        const P: usize = 10;
        let mut bb = BollingerBands::<P, 1>::new();

        for i in 0..20 {
            bb.update(100.0);
        }

        let result = bb.get(0).unwrap();
        let price = 100.0;
        let percent_b = (price - result.lower) / (result.upper - result.lower);
        
        // When price equals middle band and there's no volatility,
        // %B should be around 0.5 (or undefined if bandwidth is 0)
        if result.upper - result.lower > 0.0001 {
            assert!((percent_b - 0.5).abs() < 0.1,
                "%B should be around 0.5 when price is at middle band");
        }
    }

    #[test]
    fn test_bollinger_standard_parameters() {
        // Test standard Bollinger Bands (20, 2)
        let mut bb = BollingerBands::<20, 1>::new();

        // Feed realistic price data
        for i in 0..30 {
            let price = 100.0 + (i as f64 * 0.5).sin() * 5.0;
            bb.update(price);
        }

        let result = bb.get(0).unwrap();
        
        // Verify structure
        assert!(result.upper > result.middle);
        assert!(result.middle > result.lower);
        assert!((result.upper - result.middle - (result.middle - result.lower)).abs() < 0.001);
    }

    #[test]
    fn test_bollinger_mean_reversion() {
        // Bollinger Bands can identify mean reversion opportunities
        const P: usize = 20;
        let mut bb = BollingerBands::<P, 1>::new();

        // Establish stable range
        for _ in 0..P {
            bb.update(100.0);
        }

        let baseline = bb.get(0).unwrap();
        
        // Price should be at middle when stable
        assert!((baseline.middle - 100.0).abs() < 0.01);
        
        // Bandwidth should be small with no volatility
        assert!(baseline.upper - baseline.lower < 1.0);
    }
}
