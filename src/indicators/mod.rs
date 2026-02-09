/// Technical indicators for financial data analysis.
///
/// This module defines a common interface for indicators using traits,
/// allowing them to be used interchangeably in algorithms that process
/// financial data. Indicators are designed to work with zero dynamic memory
/// allocation (using const generics), implement circular buffers for
/// processing historical data, and are designed for streaming data scenarios
/// where new data points are continuously added.

pub mod ad;
pub mod adx;
pub mod aroon;
pub mod atr;
pub mod base;
pub mod bollinger;
pub mod cci;
pub mod cmo;
pub mod dema;
pub mod ema;
pub mod kama;
pub mod ma;
pub mod macd;
pub mod mfi;
pub mod mom;
pub mod mv;
pub mod natr;
pub mod obv;
pub mod ppo;
pub mod psar;
pub mod roc;
pub mod roi;
pub mod rsi;
pub mod stdev;
pub mod stoch;
pub mod stochrsi;
pub mod tema;
pub mod trange;
pub mod trima;

/// OHLCV bar data structure
#[derive(Debug, Clone, Copy, Default)]
#[allow(dead_code)]
pub struct Ohlcv {
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub volume: f64,
}

/// Trait that all indicators must implement.
///
/// This trait uses associated types to allow indicators to accept
/// different input types (T) and produce different output types (U).
///
/// # Type Parameters
/// - `T`: The input value type (e.g., f64, Ohlcv)
/// - `U`: The output value type (e.g., f64)
#[allow(unused)]
pub trait Indicator {
    /// Input value type
    type Input;
    /// Output value type
    type Output;

    /// Update the indicator with a new value.
    ///
    /// In a streaming scenario, this would be called each time
    /// a new data point is available.
    fn update(&mut self, value: Self::Input);

    /// Access a value in time series style.
    ///
    /// - `key = 0`: current time step value
    /// - `key = -1`: previous time step value
    /// - `key = -2`: two time steps ago
    ///
    /// # Panics
    /// - Panics if a positive index is accessed (future values)
    /// - Panics if the index is out of bounds
    fn get(&self, key: i32) -> Self::Output;

    /// Reset the state of the indicator.
    ///
    /// This clears all stored data and returns the indicator
    /// to its initial state.
    fn reset(&mut self);
}
