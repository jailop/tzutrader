//! Return on Investment (ROI)
//!
//! ROI calculates the percentage change from the previous value.
//! It's a simple momentum indicator.
//!
//! # Type Parameters
//! - `S`: Number of recent ROI values to store (compile-time constant, default 1)

use super::{base::BaseIndicator, Indicator};

#[derive(Debug, Clone)]
pub struct ROI<const S: usize = 1> {
    prev: f64,
    data: BaseIndicator<f64, S>,
}

impl<const S: usize> ROI<S> {
    pub fn new() -> Self {
        Self {
            prev: f64::NAN,
            data: BaseIndicator::new(),
        }
    }
}

impl<const S: usize> Default for ROI<S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const S: usize> Indicator for ROI<S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) -> Option<f64> {
        if self.prev.is_nan() || self.prev == 0.0 {
            self.prev = value;
            return None;
        }
        
        let roi_value = value / self.prev - 1.0;
        self.data.update(roi_value);
        self.prev = value;
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.prev = f64::NAN;
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_roi_first_value() {
        // First value should return None (no previous value to compare)
        let mut roi = ROI::<1>::new();
        
        assert!(roi.update(100.0).is_none());
        assert!(roi.get(0).is_none());
    }

    #[test]
    fn test_roi_positive_return() {
        // Test positive return (price increase)
        let mut roi = ROI::<1>::new();
        
        roi.update(100.0);
        
        // Price increases to 110 -> ROI = 110/100 - 1 = 0.10 (10%)
        let result = roi.update(110.0).unwrap();
        assert!((result - 0.10).abs() < 0.0001);
    }

    #[test]
    fn test_roi_negative_return() {
        // Test negative return (price decrease)
        let mut roi = ROI::<1>::new();
        
        roi.update(100.0);
        
        // Price decreases to 90 -> ROI = 90/100 - 1 = -0.10 (-10%)
        let result = roi.update(90.0).unwrap();
        assert!((result - (-0.10)).abs() < 0.0001);
    }

    #[test]
    fn test_roi_zero_return() {
        // Test zero return (no change)
        let mut roi = ROI::<1>::new();
        
        roi.update(100.0);
        
        // Price stays at 100 -> ROI = 100/100 - 1 = 0.0 (0%)
        let result = roi.update(100.0);
        assert_eq!(result, Some(0.0));
    }

    #[test]
    fn test_roi_doubling() {
        // Test when price doubles
        let mut roi = ROI::<1>::new();
        
        roi.update(50.0);
        
        // Price doubles to 100 -> ROI = 100/50 - 1 = 1.0 (100%)
        let result = roi.update(100.0);
        assert_eq!(result, Some(1.0));
    }

    #[test]
    fn test_roi_halving() {
        // Test when price halves
        let mut roi = ROI::<1>::new();
        
        roi.update(100.0);
        
        // Price halves to 50 -> ROI = 50/100 - 1 = -0.5 (-50%)
        let result = roi.update(50.0);
        assert_eq!(result, Some(-0.5));
    }

    #[test]
    fn test_roi_sequence() {
        // Test ROI over a sequence of values
        let mut roi = ROI::<5>::new();
        
        roi.update(100.0);
        
        // 100 -> 105 (5% gain)
        let result = roi.update(105.0).unwrap();
        assert!((result - 0.05).abs() < 0.0001);
        
        // 105 -> 110 (4.76% gain)
        let result = roi.update(110.0).unwrap();
        assert!((result - (5.0 / 105.0)).abs() < 0.0001);
        
        // 110 -> 100 (-9.09% loss)
        let result = roi.update(100.0).unwrap();
        assert!((result - (-10.0 / 110.0)).abs() < 0.0001);
    }

    #[test]
    fn test_roi_zero_prev_value() {
        // Test handling of zero previous value (division by zero protection)
        let mut roi = ROI::<1>::new();
        
        // First value is 0
        roi.update(0.0);
        assert!(roi.get(0).is_none());
        
        // Next value should be skipped (prev is 0)
        assert!(roi.update(100.0).is_none());
        assert!(roi.get(0).is_none());
        
        // Now we have valid previous value
        let result = roi.update(110.0).unwrap();
        assert!((result - 0.10).abs() < 0.0001);
    }

    #[test]
    fn test_roi_historical_access() {
        // Test buffer storage with S=5
        let mut roi = ROI::<5>::new();
        
        // Add initial value
        roi.update(100.0);
        
        // Add more values to fill buffer
        for i in 1..=5 {
            roi.update(100.0 + i as f64 * 5.0);
        }
        
        // Access current and historical values
        for i in 0..5 {
            assert!(roi.get(-i).is_some(), 
                "Should be able to access value at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(roi.get(-5).is_none());
    }

    #[test]
    fn test_roi_get_before_first_update() {
        // Test that get() returns None before enough updates
        let mut roi = ROI::<1>::new();
        
        // Before any updates
        assert!(roi.get(0).is_none());
        
        // After first update (no previous value)
        roi.update(100.0);
        assert!(roi.get(0).is_none());
        
        // After second update
        roi.update(105.0);
        assert!(roi.get(0).is_some());
    }

    #[test]
    fn test_roi_reset() {
        let mut roi = ROI::<1>::new();
        
        // Add values
        roi.update(100.0);
        roi.update(110.0);
        
        assert!(roi.get(0).is_some());
        
        // Reset
        roi.reset();
        
        // Should need initial value again
        assert!(roi.update(200.0).is_none());
        assert!(roi.update(220.0).is_some());
    }

    #[test]
    fn test_roi_volatile_sequence() {
        // Test ROI with volatile price movements
        let mut roi = ROI::<3>::new();
        
        roi.update(100.0);
        
        // Sharp increase
        let roi1 = roi.update(150.0).unwrap();
        assert!((roi1 - 0.5).abs() < 0.0001); // 50% gain
        
        // Sharp decrease
        let roi2 = roi.update(120.0).unwrap();
        assert!((roi2 - (-0.2)).abs() < 0.0001); // 20% loss
        
        // Recovery
        let roi3 = roi.update(150.0).unwrap();
        assert!((roi3 - 0.25).abs() < 0.0001); // 25% gain
    }

    #[test]
    fn test_roi_cumulative_vs_periodic() {
        // ROI measures period-to-period, not cumulative from start
        let mut roi = ROI::<3>::new();
        
        // Start at 100
        roi.update(100.0);
        
        // Move to 110 (10% from 100)
        let result = roi.update(110.0).unwrap();
        assert!((result - 0.10).abs() < 0.0001);
        
        // Move to 121 (10% from 110, not 21% from 100)
        let result = roi.update(121.0).unwrap();
        assert!((result - 0.10).abs() < 0.0001);
        
        // Each ROI is calculated from immediate previous value
        let result = roi.update(133.1).unwrap();
        assert!((result - 0.10).abs() < 0.0001);
    }

    #[test]
    fn test_roi_negative_values() {
        // Test ROI with negative values
        let mut roi = ROI::<1>::new();
        
        roi.update(-100.0);
        
        // From -100 to -50: ROI = -50/-100 - 1 = 0.5 - 1 = -0.5
        // (mathematically correct, though may seem counterintuitive)
        let result = roi.update(-50.0).unwrap();
        assert!((result - (-0.5)).abs() < 0.0001);
        
        // From -50 to -100: ROI = -100/-50 - 1 = 2 - 1 = 1.0
        let result = roi.update(-100.0).unwrap();
        assert!((result - 1.0).abs() < 0.0001);
    }

    #[test]
    fn test_roi_small_changes() {
        // Test ROI with small percentage changes
        let mut roi = ROI::<1>::new();
        
        roi.update(10000.0);
        
        // Small increase (0.01%)
        let result = roi.update(10001.0).unwrap();
        assert!((result - 0.0001).abs() < 0.000001);
    }

    #[test]
    fn test_roi_percentage_conversion() {
        // Verify ROI can be easily converted to percentage
        let mut roi = ROI::<1>::new();
        
        roi.update(100.0);
        
        let roi_value = roi.update(125.0).unwrap();
        let percentage = roi_value * 100.0;
        
        assert_eq!(percentage, 25.0); // 25% gain
    }

    #[test]
    fn test_roi_crossing_zero() {
        // Test behavior when crossing zero
        let mut roi = ROI::<3>::new();
        
        roi.update(10.0);
        roi.update(5.0);   // -50%
        roi.update(0.0);   // -100%
        
        // After zero, next update should return None
        assert!(roi.update(5.0).is_none());
        
        // Now can calculate again
        assert!(roi.update(10.0).is_some());
    }
}
