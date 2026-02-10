//! Accumulation/Distribution Line (AD)
//!
//! AD is a volume-based indicator that measures the cumulative flow of money
//! into and out of a security. It uses the close location value (CLV) to
//! determine the money flow multiplier.

use super::{base::BaseIndicator, Indicator};
use crate::types::Ohlcv;

#[derive(Debug, Clone)]
pub struct AD<const S: usize = 1> {
    ad_value: f64,
    data: BaseIndicator<f64, S>,
}

impl<const S: usize> AD<S> {
    pub fn new() -> Self {
        Self {
            ad_value: 0.0,
            data: BaseIndicator::new(),
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

    fn update(&mut self, value: Ohlcv) -> Option<Self::Output> {
        let range = value.high - value.low;
        if range == 0.0 {
            self.data.update(self.ad_value);
        } else {
            let clv = ((value.close - value.low) - (value.high - value.close)) / range;
            self.ad_value += clv * value.volume;
            self.data.update(self.ad_value);
        }
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.ad_value = 0.0;
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ad_accumulation_phase() {
        // Test when close is near high (buying pressure)
        let mut ad = AD::<3>::new();
        
        let bar = Ohlcv {
            timestamp: 0,
            open: 50.0,
            high: 100.0,
            low: 50.0,
            close: 90.0, // Close near high
            volume: 1000.0,
        };
        
        // CLV = ((90-50) - (100-90)) / (100-50) = (40 - 10) / 50 = 0.6
        // AD = 0.6 * 1000 = 600
        let result = ad.update(bar);
        assert_eq!(result, Some(600.0));
    }

    #[test]
    fn test_ad_distribution_phase() {
        // Test when close is near low (selling pressure)
        let mut ad = AD::<3>::new();
        
        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 100.0,
            low: 50.0,
            close: 60.0, // Close near low
            volume: 1000.0,
        };
        
        // CLV = ((60-50) - (100-60)) / (100-50) = (10 - 40) / 50 = -0.6
        // AD = -0.6 * 1000 = -600
        let result = ad.update(bar);
        assert_eq!(result, Some(-600.0));
    }

    #[test]
    fn test_ad_neutral_close() {
        // Test when close is exactly at midpoint
        let mut ad = AD::<3>::new();
        
        let bar = Ohlcv {
            timestamp: 0,
            open: 50.0,
            high: 100.0,
            low: 50.0,
            close: 75.0, // Midpoint
            volume: 1000.0,
        };
        
        // CLV = ((75-50) - (100-75)) / (100-50) = (25 - 25) / 50 = 0
        // AD = 0 * 1000 = 0
        let result = ad.update(bar);
        assert_eq!(result, Some(0.0));
    }

    #[test]
    fn test_ad_cumulative_behavior() {
        // Test that AD accumulates over multiple bars
        let mut ad = AD::<5>::new();
        
        // First bar: positive flow
        let bar1 = Ohlcv {
            timestamp: 0,
            open: 50.0,
            high: 100.0,
            low: 50.0,
            close: 90.0,
            volume: 1000.0,
        };
        ad.update(bar1);
        assert_eq!(ad.get(0), Some(600.0));
        
        // Second bar: more positive flow
        let bar2 = Ohlcv {
            timestamp: 0,
            open: 90.0,
            high: 110.0,
            low: 80.0,
            close: 100.0,
            volume: 500.0,
        };
        // CLV = ((100-80) - (110-100)) / (110-80) = 10/30 = 0.333...
        // AD += 0.333... * 500 = 166.666...
        // Total AD = 600 + 166.666... = 766.666...
        let result = ad.update(bar2);
        assert!((result.unwrap() - 766.666667).abs() < 0.001);
        
        // Third bar: negative flow
        let bar3 = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 110.0,
            low: 70.0,
            close: 75.0,
            volume: 1000.0,
        };
        // CLV = ((75-70) - (110-75)) / (110-70) = (5-35)/40 = -0.75
        // AD += -0.75 * 1000 = -750
        // Total AD = 766.666... - 750 = 16.666...
        let result = ad.update(bar3);
        assert!((result.unwrap() - 16.666667).abs() < 0.001);
    }

    #[test]
    fn test_ad_zero_range() {
        // Test edge case where high == low (zero range)
        let mut ad = AD::<3>::new();
        
        // First update with normal range
        let bar1 = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 110.0,
            low: 90.0,
            close: 100.0,
            volume: 1000.0,
        };
        ad.update(bar1);
        let prev_value = ad.get(0).unwrap();
        
        // Second update with zero range
        let bar2 = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 100.0,
            low: 100.0,
            close: 100.0,
            volume: 1000.0,
        };
        let result = ad.update(bar2);
        
        // AD should remain unchanged when range is zero
        assert_eq!(result, Some(prev_value));
    }

    #[test]
    fn test_ad_reset() {
        let mut ad = AD::<3>::new();
        
        // Add some values
        let bar = Ohlcv {
            timestamp: 0,
            open: 50.0,
            high: 100.0,
            low: 50.0,
            close: 90.0,
            volume: 1000.0,
        };
        ad.update(bar);
        assert_eq!(ad.get(0), Some(600.0));
        
        // Reset
        ad.reset();
        
        // Should be back to initial state
        let bar2 = Ohlcv {
            timestamp: 0,
            open: 50.0,
            high: 100.0,
            low: 50.0,
            close: 75.0,
            volume: 1000.0,
        };
        let result = ad.update(bar2);
        assert_eq!(result, Some(0.0)); // Neutral close after reset
    }

    #[test]
    fn test_ad_historical_access() {
        // Test buffer storage with S=3
        let mut ad = AD::<3>::new();
        
        let bar1 = Ohlcv {
            timestamp: 0,
            open: 50.0,
            high: 100.0,
            low: 50.0,
            close: 90.0,
            volume: 1000.0,
        };
        ad.update(bar1); // AD = 600
        
        let bar2 = Ohlcv {
            timestamp: 0,
            open: 90.0,
            high: 110.0,
            low: 80.0,
            close: 85.0,
            volume: 500.0,
        };
        ad.update(bar2); // AD = 600 + (5-25)/30*500 = 266.666...
        
        let bar3 = Ohlcv {
            timestamp: 0,
            open: 85.0,
            high: 95.0,
            low: 75.0,
            close: 90.0,
            volume: 800.0,
        };
        ad.update(bar3); // AD increases further
        
        // Access current value
        assert!(ad.get(0).is_some());
        
        // Access previous values
        assert!(ad.get(-1).is_some());
        assert!(ad.get(-2).is_some());
        
        // Beyond buffer size should be None
        assert!(ad.get(-3).is_none());
    }

    #[test]
    fn test_ad_close_at_extreme_high() {
        // Test when close equals high (maximum buying pressure)
        let mut ad = AD::<3>::new();
        
        let bar = Ohlcv {
            timestamp: 0,
            open: 50.0,
            high: 100.0,
            low: 50.0,
            close: 100.0,
            volume: 1000.0,
        };
        
        // CLV = ((100-50) - (100-100)) / (100-50) = 50/50 = 1.0
        // AD = 1.0 * 1000 = 1000
        let result = ad.update(bar);
        assert_eq!(result, Some(1000.0));
    }

    #[test]
    fn test_ad_close_at_extreme_low() {
        // Test when close equals low (maximum selling pressure)
        let mut ad = AD::<3>::new();
        
        let bar = Ohlcv {
            timestamp: 0,
            open: 100.0,
            high: 100.0,
            low: 50.0,
            close: 50.0,
            volume: 1000.0,
        };
        
        // CLV = ((50-50) - (100-50)) / (100-50) = -50/50 = -1.0
        // AD = -1.0 * 1000 = -1000
        let result = ad.update(bar);
        assert_eq!(result, Some(-1000.0));
    }
}
