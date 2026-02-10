//! Data types and structures for trading indicators
//!
//! This module defines common data structures used across indicators and other
//! trading modules. These types represent market data in various formats that
//! can be consumed by technical indicators and trading strategies.

/// OHLCV bar data structure
///
/// Represents a single candlestick/bar of market data with open, high, low, close prices
/// and volume information. This is the most common data format used in technical analysis.
///
/// # Fields
/// - `timestamp`: Unix timestamp in milliseconds
/// - `open`: Opening price for the period
/// - `high`: Highest price during the period
/// - `low`: Lowest price during the period
/// - `close`: Closing price for the period
/// - `volume`: Trading volume during the period
///
/// # Example
///
/// ```rust
/// use tzutrader::types::Ohlcv;
///
/// let bar = Ohlcv {
///     timestamp: 1609459200000, // 2021-01-01 00:00:00 UTC
///     open: 100.0,
///     high: 105.0,
///     low: 99.0,
///     close: 103.0,
///     volume: 10000.0,
/// };
///
/// println!("Close: {}, Volume: {}", bar.close, bar.volume);
/// ```
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct Ohlcv {
    pub timestamp: i64,
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub volume: f64,
}

impl Ohlcv {
    /// Create a new OHLCV bar
    pub fn new(timestamp: i64, open: f64, high: f64, low: f64, close: f64, volume: f64) -> Self {
        Self {
            timestamp,
            open,
            high,
            low,
            close,
            volume,
        }
    }

    /// Get the typical price: (high + low + close) / 3
    pub fn typical_price(&self) -> f64 {
        (self.high + self.low + self.close) / 3.0
    }

    /// Get the median price: (high + low) / 2
    pub fn median_price(&self) -> f64 {
        (self.high + self.low) / 2.0
    }

    /// Get the weighted close: (high + low + 2*close) / 4
    pub fn weighted_close(&self) -> f64 {
        (self.high + self.low + 2.0 * self.close) / 4.0
    }

    /// Check if this is a bullish (green) candle
    pub fn is_bullish(&self) -> bool {
        self.close > self.open
    }

    /// Check if this is a bearish (red) candle
    pub fn is_bearish(&self) -> bool {
        self.close < self.open
    }

    /// Get the body size (absolute difference between open and close)
    pub fn body_size(&self) -> f64 {
        (self.close - self.open).abs()
    }

    /// Get the range (high - low)
    pub fn range(&self) -> f64 {
        self.high - self.low
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ohlcv_creation() {
        let bar = Ohlcv::new(0, 100.0, 105.0, 99.0, 103.0, 10000.0);
        assert_eq!(bar.open, 100.0);
        assert_eq!(bar.high, 105.0);
        assert_eq!(bar.low, 99.0);
        assert_eq!(bar.close, 103.0);
        assert_eq!(bar.volume, 10000.0);
    }

    #[test]
    fn test_typical_price() {
        let bar = Ohlcv::new(0, 100.0, 105.0, 99.0, 102.0, 10000.0);
        assert_eq!(bar.typical_price(), (105.0 + 99.0 + 102.0) / 3.0);
    }

    #[test]
    fn test_median_price() {
        let bar = Ohlcv::new(0, 100.0, 110.0, 90.0, 105.0, 10000.0);
        assert_eq!(bar.median_price(), 100.0);
    }

    #[test]
    fn test_bullish_bearish() {
        let bullish = Ohlcv::new(0, 100.0, 105.0, 99.0, 103.0, 10000.0);
        assert!(bullish.is_bullish());
        assert!(!bullish.is_bearish());

        let bearish = Ohlcv::new(0, 100.0, 105.0, 99.0, 98.0, 10000.0);
        assert!(!bearish.is_bullish());
        assert!(bearish.is_bearish());
    }

    #[test]
    fn test_body_size() {
        let bar = Ohlcv::new(0, 100.0, 105.0, 99.0, 103.0, 10000.0);
        assert_eq!(bar.body_size(), 3.0);
    }

    #[test]
    fn test_range() {
        let bar = Ohlcv::new(0, 100.0, 110.0, 90.0, 105.0, 10000.0);
        assert_eq!(bar.range(), 20.0);
    }
}
