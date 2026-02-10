//! Double Exponential Moving Average (DEMA)
//!
//! DEMA is designed to reduce the lag of traditional EMAs by using a combination
//! of a single EMA and a double EMA. It's more responsive to price changes than
//! both SMA and EMA.
//!
//! Formula: DEMA = 2 * EMA(price) - EMA(EMA(price))
//!
//! # Type Parameters
//! - `P`: Period for the exponential moving averages (compile-time constant)
//! - `S`: Number of recent DEMA values to store (compile-time constant, default 1)

use super::{base::BaseIndicator, ema::EMA, Indicator};

#[derive(Debug, Clone)]
pub struct DEMA<const P: usize, const S: usize = 1> {
    first_ema: EMA<P, 1>,
    second_ema: EMA<P, 1>,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> DEMA<P, S> {
    pub fn new() -> Self {
        Self {
            first_ema: EMA::new(),
            second_ema: EMA::new(),
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for DEMA<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for DEMA<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) -> Option<f64> {
        self.first_ema.update(value);
        let ema1 = self.first_ema.get(0);

        if ema1.is_none() {
            return None;
        }
        
        self.second_ema.update(ema1.unwrap());
        let ema2 = self.second_ema.get(0);
        
        if ema2.is_none() {
            return None;
        }
        
        self.data.update(2.0 * ema1.unwrap() - ema2.unwrap());
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.first_ema.reset();
        self.second_ema.reset();
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dema_warmup_period() {
        // DEMA needs P values for first EMA, then P-1 more for second EMA
        // Total warmup: 2*P-1 values
        const P: usize = 3;
        let mut dema = DEMA::<P, 1>::new();

        // During warmup: should return None (first 2*P-2 updates return None)
        for i in 0..(2 * P - 2) {
            assert!(dema.update(10.0 + i as f64).is_none(), 
                "Update {} should return None during warmup", i + 1);
        }
        
        // The (2*P-1)th update should return Some
        assert!(dema.update(20.0).is_some());
        assert!(dema.update(21.0).is_some());
    }

    #[test]
    fn test_dema_formula() {
        // Verify DEMA = 2 * EMA - EMA(EMA)
        let mut dema = DEMA::<3, 1>::new();
        let mut ema1 = EMA::<3, 5>::new();
        let mut ema2 = EMA::<3, 1>::new();

        let values = vec![10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0];

        for &val in &values {
            dema.update(val);
            ema1.update(val);
            
            if let Some(e1) = ema1.get(0) {
                ema2.update(e1);
            }
        }

        let dema_value = dema.get(0).unwrap();
        let ema1_value = ema1.get(0).unwrap();
        let ema2_value = ema2.get(0).unwrap();
        
        let expected = 2.0 * ema1_value - ema2_value;
        assert!((dema_value - expected).abs() < 0.0001);
    }

    #[test]
    fn test_dema_responsiveness() {
        // DEMA should be more responsive to changes than regular EMA
        let mut dema = DEMA::<5, 1>::new();
        let mut ema = EMA::<5, 1>::new();

        // Stable period
        for _ in 0..10 {
            dema.update(100.0);
            ema.update(100.0);
        }

        // Sharp upward move
        for _ in 0..5 {
            dema.update(110.0);
            ema.update(110.0);
        }

        let dema_value = dema.get(0).unwrap();
        let ema_value = ema.get(0).unwrap();

        // DEMA should be closer to 110.0 than EMA (more responsive)
        let dema_distance = (110.0 - dema_value).abs();
        let ema_distance = (110.0 - ema_value).abs();
        
        assert!(dema_distance < ema_distance, 
            "DEMA ({}) should be more responsive than EMA ({})", dema_value, ema_value);
    }

    #[test]
    fn test_dema_constant_values() {
        // When all values are the same, DEMA should equal that value
        let mut dema = DEMA::<3, 1>::new();

        for _ in 0..10 {
            dema.update(50.0);
        }

        let result = dema.get(0).unwrap();
        assert!((result - 50.0).abs() < 0.0001);
    }

    #[test]
    fn test_dema_uptrend() {
        // Test DEMA behavior in a consistent uptrend
        let mut dema = DEMA::<3, 5>::new();

        // Create uptrend: 10, 12, 14, 16, 18, 20, 22, 24
        for i in 0..8 {
            dema.update(10.0 + 2.0 * i as f64);
        }

        // In an uptrend, DEMA should be increasing
        let current = dema.get(0).unwrap();
        let prev1 = dema.get(-1).unwrap();
        let prev2 = dema.get(-2).unwrap();

        assert!(current > prev1, "DEMA should increase in uptrend");
        assert!(prev1 > prev2, "DEMA should consistently increase");
    }

    #[test]
    fn test_dema_downtrend() {
        // Test DEMA behavior in a consistent downtrend
        let mut dema = DEMA::<3, 5>::new();

        // Create downtrend: 100, 95, 90, 85, 80, 75, 70, 65
        for i in 0..8 {
            dema.update(100.0 - 5.0 * i as f64);
        }

        // In a downtrend, DEMA should be decreasing
        let current = dema.get(0).unwrap();
        let prev1 = dema.get(-1).unwrap();
        let prev2 = dema.get(-2).unwrap();

        assert!(current < prev1, "DEMA should decrease in downtrend");
        assert!(prev1 < prev2, "DEMA should consistently decrease");
    }

    #[test]
    fn test_dema_reset() {
        const P: usize = 3;
        let mut dema = DEMA::<P, 1>::new();

        // Add values
        for i in 1..=10 {
            dema.update(i as f64);
        }
        
        assert!(dema.get(0).is_some());

        // Reset
        dema.reset();

        // Should need warmup again (first 2*P-2 updates return None)
        for i in 0..(2 * P - 2) {
            assert!(dema.update(100.0 + i as f64).is_none(),
                "After reset, update {} should return None", i + 1);
        }
        // The (2*P-1)th update should return Some
        assert!(dema.update(200.0).is_some());
    }

    #[test]
    fn test_dema_historical_access() {
        // Test buffer storage with S=4
        const P: usize = 3;
        let mut dema = DEMA::<P, 4>::new();

        // Warmup (need 2*P-1 values)
        for i in 1..=(2 * P - 1) {
            dema.update(i as f64);
        }

        // Add more values to fill buffer
        for i in 0..3 {
            dema.update(10.0 + i as f64);
        }

        // Access current and historical values within buffer
        for i in 0..4 {
            assert!(dema.get(-i).is_some(), 
                "Should be able to access value at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(dema.get(-4).is_none());
    }

    #[test]
    fn test_dema_get_before_warmup() {
        // Test that get() returns None before warmup is complete
        const P: usize = 3;
        let mut dema = DEMA::<P, 1>::new();

        // Before any updates
        assert!(dema.get(0).is_none());

        // During warmup (first 2*P-2 updates return None, get also returns None)
        for i in 0..(2 * P - 2) {
            dema.update(10.0 + i as f64);
            assert!(dema.get(0).is_none(), 
                "get(0) should return None during warmup at update {}", i + 1);
        }

        // After warmup: the (2*P-1)th update produces valid data
        dema.update(20.0);
        assert!(dema.get(0).is_some());
    }

    #[test]
    fn test_dema_price_reversal() {
        // Test DEMA response to price reversal
        let mut dema = DEMA::<3, 1>::new();

        // Uptrend
        for i in 0..6 {
            dema.update(10.0 + 2.0 * i as f64);
        }
        
        let before_reversal = dema.get(0).unwrap();

        // Price reversal - sharp drop
        for _ in 0..3 {
            dema.update(15.0);
        }

        let after_reversal = dema.get(0).unwrap();

        // DEMA should respond by decreasing after reversal
        assert!(after_reversal < before_reversal, 
            "DEMA should decrease after price reversal from {} to {}", 
            before_reversal, after_reversal);
    }
}
