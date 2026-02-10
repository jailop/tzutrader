//! Moving Variance (MV)
//!
//! Calculates the variance of values over a rolling window.
//! Uses a moving average internally to calculate variance.
//!
//! # Type Parameters
//! - `P`: Period for variance calculation (compile-time constant)
//! - `S`: Number of recent variance values to store (compile-time constant, default 1)

use super::{base::BaseIndicator, ma::MA, Indicator};

#[derive(Debug, Clone)]
pub struct MV<const P: usize, const S: usize = 1> {
    ma: MA<P, 1>,
    prevs: [f64; P],
    length: usize,
    pos: usize,
    data: BaseIndicator<f64, S>,
}

impl<const P: usize, const S: usize> MV<P, S> {
    pub fn new() -> Self {
        Self {
            ma: MA::new(),
            prevs: [f64::NAN; P],
            length: 0,
            pos: 0,
            data: BaseIndicator::new(),
        }
    }
}

impl<const P: usize, const S: usize> Default for MV<P, S> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const P: usize, const S: usize> Indicator for MV<P, S> {
    type Input = f64;
    type Output = f64;

    fn update(&mut self, value: f64) -> Option<f64> {
        if self.length < P {
            self.length += 1;
        }

        self.prevs[self.pos] = value;
        self.pos = (self.pos + 1) % P;
        self.ma.update(value);

        if self.length < P {
            return None;
        }
        
        let mean = self.ma.get(0).unwrap();
        let mut accum = 0.0;
        for i in 0..P {
            let diff = self.prevs[i] - mean;
            accum += diff * diff;
        }
        self.data.update(accum / P as f64);
        self.data.get(0)
    }

    fn get(&self, key: i32) -> Option<f64> {
        self.data.get(key)
    }

    fn reset(&mut self) {
        self.length = 0;
        self.pos = 0;
        self.ma.reset();
        self.prevs = [f64::NAN; P];
        self.data.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mv_warmup_period() {
        // MV needs P values before calculating variance
        const P: usize = 5;
        let mut mv = MV::<P, 1>::new();

        // During warmup: should return None
        for i in 0..(P - 1) {
            assert!(mv.update(100.0 + i as f64).is_none(), 
                "Update {} should return None during warmup", i + 1);
        }
        
        // Pth value should return Some
        assert!(mv.update(110.0).is_some());
    }

    #[test]
    fn test_mv_zero_variance() {
        // When all values are identical, variance should be zero
        const P: usize = 5;
        let mut mv = MV::<P, 1>::new();

        for _ in 0..10 {
            mv.update(100.0);
        }

        let result = mv.get(0).unwrap();
        assert_eq!(result, 0.0, "Variance of constant values should be 0");
    }

    #[test]
    fn test_mv_simple_calculation() {
        // Test variance with known values
        const P: usize = 5;
        let mut mv = MV::<P, 1>::new();

        // Values: 2, 4, 6, 8, 10
        // Mean = 6
        // Variance = ((2-6)² + (4-6)² + (6-6)² + (8-6)² + (10-6)²) / 5
        //          = (16 + 4 + 0 + 4 + 16) / 5 = 40 / 5 = 8
        mv.update(2.0);
        mv.update(4.0);
        mv.update(6.0);
        mv.update(8.0);
        mv.update(10.0);

        let result = mv.get(0).unwrap();
        assert_eq!(result, 8.0);
    }

    #[test]
    fn test_mv_rolling_window() {
        // Test that variance updates with rolling window
        const P: usize = 3;
        let mut mv = MV::<P, 1>::new();

        // Initial: 1, 2, 3 -> mean=2, variance=((1-2)²+(2-2)²+(3-2)²)/3 = 2/3
        mv.update(1.0);
        mv.update(2.0);
        mv.update(3.0);
        let var1 = mv.get(0).unwrap();
        assert!((var1 - 2.0/3.0).abs() < 0.0001);

        // After 4: 2, 3, 4 -> mean=3, variance=((2-3)²+(3-3)²+(4-3)²)/3 = 2/3
        mv.update(4.0);
        let var2 = mv.get(0).unwrap();
        assert!((var2 - 2.0/3.0).abs() < 0.0001);

        // After 10: 3, 4, 10 -> mean=17/3, variance=...
        mv.update(10.0);
        let var3 = mv.get(0).unwrap();
        // Variance should increase significantly due to outlier
        assert!(var3 > var2, "Variance should increase with outlier");
    }

    #[test]
    fn test_mv_low_vs_high_variance() {
        // Compare low variance vs high variance data
        const P: usize = 5;
        let mut mv_low = MV::<P, 1>::new();
        let mut mv_high = MV::<P, 1>::new();

        // Low variance: values close together
        for i in 0..P {
            mv_low.update(100.0 + i as f64 * 0.1);
        }

        // High variance: values spread apart
        for i in 0..P {
            mv_high.update(100.0 + i as f64 * 10.0);
        }

        let low_var = mv_low.get(0).unwrap();
        let high_var = mv_high.get(0).unwrap();

        assert!(high_var > low_var, 
            "High variance data should have higher variance than low variance data");
    }

    #[test]
    fn test_mv_symmetry() {
        // Variance should be same for symmetric distribution
        const P: usize = 5;
        let mut mv1 = MV::<P, 1>::new();
        let mut mv2 = MV::<P, 1>::new();

        // Symmetric around 50: 40, 45, 50, 55, 60
        mv1.update(40.0);
        mv1.update(45.0);
        mv1.update(50.0);
        mv1.update(55.0);
        mv1.update(60.0);

        // Same values, different order: 60, 40, 55, 45, 50
        mv2.update(60.0);
        mv2.update(40.0);
        mv2.update(55.0);
        mv2.update(45.0);
        mv2.update(50.0);

        let var1 = mv1.get(0).unwrap();
        let var2 = mv2.get(0).unwrap();

        assert_eq!(var1, var2, "Variance should be independent of value order");
    }

    #[test]
    fn test_mv_positive_definiteness() {
        // Variance is always non-negative
        const P: usize = 4;
        let mut mv = MV::<P, 1>::new();

        // Random-ish values
        let values = vec![5.3, 2.1, 8.7, 3.9, 6.4, 9.2];

        for &val in &values {
            if let Some(var) = mv.update(val) {
                assert!(var >= 0.0, "Variance must be non-negative, got {}", var);
            }
        }
    }

    #[test]
    fn test_mv_reset() {
        const P: usize = 3;
        let mut mv = MV::<P, 1>::new();

        // Add values
        for i in 1..=10 {
            mv.update(i as f64 * 10.0);
        }
        
        assert!(mv.get(0).is_some());

        // Reset
        mv.reset();

        // Should need warmup again
        for i in 0..(P - 1) {
            assert!(mv.update(100.0 + i as f64).is_none(),
                "After reset, update {} should return None", i + 1);
        }
        assert!(mv.update(200.0).is_some());
    }

    #[test]
    fn test_mv_historical_access() {
        // Test buffer storage with S=4
        const P: usize = 3;
        let mut mv = MV::<P, 4>::new();

        // Warmup and add values
        for i in 0..P {
            mv.update(10.0 * i as f64);
        }

        // Add more values to fill buffer
        for i in 0..3 {
            mv.update(100.0 + i as f64 * 10.0);
        }

        // Access current and historical values
        for i in 0..4 {
            assert!(mv.get(-i).is_some(), 
                "Should be able to access value at index -{}", i);
        }
        
        // Beyond buffer should be None
        assert!(mv.get(-4).is_none());
    }

    #[test]
    fn test_mv_get_before_warmup() {
        // Test that get() returns None before warmup is complete
        const P: usize = 4;
        let mut mv = MV::<P, 1>::new();

        // Before any updates
        assert!(mv.get(0).is_none());

        // During warmup
        for i in 0..(P - 1) {
            mv.update(100.0 + i as f64);
            assert!(mv.get(0).is_none(), 
                "get(0) should return None during warmup at update {}", i + 1);
        }

        // After warmup
        mv.update(200.0);
        assert!(mv.get(0).is_some());
    }

    #[test]
    fn test_mv_increase_with_spread() {
        // Variance should increase as data spreads out
        const P: usize = 5;
        let mut mv = MV::<P, 1>::new();

        // Start with tight values
        for i in 0..P {
            mv.update(100.0 + i as f64);
        }
        let var1 = mv.get(0).unwrap();

        // Continue with more spread out values
        for i in 0..P {
            mv.update(100.0 + i as f64 * 5.0);
        }
        let var2 = mv.get(0).unwrap();

        assert!(var2 > var1, 
            "Variance should increase when data becomes more spread out");
    }

    #[test]
    fn test_mv_with_outlier() {
        // Test variance response to outlier
        const P: usize = 5;
        let mut mv = MV::<P, 1>::new();

        // Stable values
        for _ in 0..P {
            mv.update(100.0);
        }
        let stable_var = mv.get(0).unwrap();
        assert_eq!(stable_var, 0.0);

        // Introduce outlier
        mv.update(200.0);
        let outlier_var = mv.get(0).unwrap();

        assert!(outlier_var > stable_var, 
            "Variance should increase dramatically with outlier");
    }

    #[test]
    fn test_mv_scale_invariance() {
        // Variance scales with the square of the scaling factor
        const P: usize = 4;
        let mut mv1 = MV::<P, 1>::new();
        let mut mv2 = MV::<P, 1>::new();

        let base_values = vec![1.0, 2.0, 3.0, 4.0];
        let scale = 10.0;

        for &val in &base_values {
            mv1.update(val);
            mv2.update(val * scale);
        }

        let var1 = mv1.get(0).unwrap();
        let var2 = mv2.get(0).unwrap();

        // var2 should be scale² times var1
        let expected = var1 * scale * scale;
        assert!((var2 - expected).abs() < 0.001,
            "Variance should scale with square of scaling factor");
    }

    #[test]
    fn test_mv_with_period_one() {
        // Edge case: P=1 means variance is always 0 (single value)
        const P: usize = 1;
        let mut mv = MV::<P, 1>::new();

        mv.update(100.0);
        assert_eq!(mv.get(0), Some(0.0));
        
        mv.update(105.0);
        assert_eq!(mv.get(0), Some(0.0));
        
        mv.update(200.0);
        assert_eq!(mv.get(0), Some(0.0));
    }
}
