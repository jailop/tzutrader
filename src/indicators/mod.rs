//! Technical indicators for trading strategies
//!
//! This module defines a common interface for indicators using traits,
//! allowing them to be used interchangeably in algorithms that process
//! trading stragegies. Indicators are designed to work with zero dynamic memory
//! allocation (using const generics), implement circular buffers for
//! processing historical data, and are designed for streaming data scenarios
//! where new data points are continuously added.

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

pub use ad::AD;
pub use adx::ADX;
pub use aroon::AROON;
pub use atr::ATR;
pub use base::BaseIndicator;
pub use bollinger::BollingerBands;
pub use cci::CCI;
pub use cmo::CMO;
pub use dema::DEMA;
pub use ema::EMA;
pub use kama::KAMA;
pub use ma::MA;
pub use macd::MACD;
pub use mfi::MFI;
pub use mom::MOM;
pub use mv::MV;
pub use natr::NATR;
pub use obv::OBV;
pub use ppo::PPO;
pub use psar::PSAR;
pub use roc::ROC;
pub use roi::ROI;
pub use rsi::RSI;
pub use stdev::STDEV;
pub use stoch::STOCH;
pub use stochrsi::STOCHRSI;
pub use tema::TEMA;
pub use trange::TRANGE;
pub use trima::TRIMA;

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
    /// a new data point is available. It processes the input
    /// updating the internal state and returns the current
    /// output value.
    fn update(&mut self, value: Self::Input) -> Option<Self::Output>;

    /// Access a value in time series style.
    ///
    /// - `key = 0`: current time step value
    /// - `key = -1`: previous time step value
    /// - `key = -2`: two time steps ago
    ///
    /// It returns an optional value, which is `None` if the requested
    /// time step is out of bounds:
    /// - If the indicator has not yet received enough data points
    ///   to produce a valid output for the requested time step.
    /// - If the `key` is positive (future time steps are not available).
    /// - If the `key` is less than the negative size of the internal buffer.
    fn get(&self, key: i32) -> Option<Self::Output>;

    /// Reset the state of the indicator.
    ///
    /// This clears all stored data and returns the indicator
    /// to its initial state.
    fn reset(&mut self);
}
