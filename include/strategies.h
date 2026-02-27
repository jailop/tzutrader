#ifndef STRATEGIES_H
#define STRATEGIES_H

#include "indicators.h"

/**
 * This header file defines various trading strategies that utilize
 * technical indicators to generate buy and sell signals. Each strategy
 * is implemented as a class that shares a common interface for updating
 * with new market data and generating signals. The strategies include
 * methods to inform the required data types and the number of items
 * they need to process. This is designed to allow strategies that
 * require multiple inputs, for example prices and macroeconomic
 * indicators.
 */

namespace tzu {

/**
 * The cross-over strategy using two Simple Moving Averages (SMA).
 * Generates a buy signal when the short SMA crosses above the long SMA,
 * and a sell signal when the short SMA crosses below the long SMA. The
 * threshold parameter allows for a percentage-based buffer to avoid
 * false signals in choppy markets.
 */
template <size_t ShortPeriod, size_t LongPeriod>
class SMACrossover {
    SMA<ShortPeriod> short_sma;
    SMA<LongPeriod> long_sma;
    double threshold;
    Side last_side = Side::NONE;
    static constexpr DataType required_data[1] = {DataType::SINGLE_VALUE};
public:
    SMACrossover(double threshold = 0.0)
        : threshold(threshold) {}

    const DataType* requiredData() const { return required_data; }

    size_t numItems() const { return 1; }

    Signal update(const SingleValue& data) {
        double short_value = short_sma.update(data.value);
        double long_value = long_sma.update(data.value);
        Signal signal = {data.timestamp, Side::NONE, data.value};
        if ((short_value > long_value * (1.0 + threshold))
                && (last_side != Side::BUY))
            last_side = signal.side = Side::BUY;
        else if ((short_value < long_value * (1.0 - threshold))
                && (last_side != Side::SELL))
            last_side = signal.side = Side::SELL;
        return signal;
    }
};

/**
 * The RSI strategy generates buy signals when the RSI value falls below
 * the oversold threshold and sell signals when it rises above the
 * overbought threshold. The strategy keeps track of the last signal to
 * avoid generating multiple buy or sell signals in a row without an
 * intervening signal of the opposite type. The field parameter allows
 * the strategy to be applied to different price fields (e.g., close,
 * high, low) in the OHLCV data. The default period for the RSI is set
 * to 14, which is a common choice for this indicator.
 */
template <size_t N=14>
class RSIStrat {
    double oversold;
    double overbought;
    RSI<N> rsi;
    Side last_side;
    static constexpr DataType required_data[1] = {DataType::OHLCV};
    OhlcvField field;
public:
    RSIStrat(double oversold = 30.0, double overbought = 70.0,
            OhlcvField field = OhlcvField::CLOSE)
        : oversold(oversold), overbought(overbought),
          last_side(Side::NONE), field(field) {}
    const DataType* requiredData() const { return required_data; }
    size_t numItems() const { return 1; }
    Signal update(const Ohlcv& data) {
        double rsi_value = rsi.update(data);
        Signal signal = {data.timestamp, Side::NONE, data.getFieldValue(field)};
        if (std::isnan(rsi_value))
            return signal;
        if ((rsi_value < oversold) && (last_side != Side::BUY))
            last_side = signal.side = Side::BUY;
        else if ((rsi_value > overbought) && (last_side != Side::SELL))
            last_side = signal.side = Side::SELL;
        return signal;
    }
};

/**
 * The MACD strategy generates buy signals when the MACD line crosses above
 * the signal line and sell signals when it crosses below. The threshold
 * parameter allows for a percentage-based buffer to avoid false signals in
 * choppy markets. The strategy keeps track of the last signal to avoid
 * generating multiple buy or sell signals in a row without an intervening
 * signal of the opposite type. The threshold is applied as a percentage
 * difference between the MACD line and the signal line to determine
 * when a crossover is significant enough to generate a signal, helping
 * to filter out noise in volatile markets.
 */
class MACDStrat {
    MACD macd;
    double threshold;
    Side last_side;
    static constexpr DataType required_data[1] = {DataType::SINGLE_VALUE};
public:
    MACDStrat(size_t short_period, size_t long_period, size_t signal_period,
            double smoothing = 2.0, double threshold = 0.0)
        : macd(short_period, long_period, signal_period, smoothing),
          threshold(threshold), last_side(Side::NONE) {}
    const DataType* requiredData() const { return required_data; }
    size_t numItems() const { return 1; }
    Signal update(const SingleValue& data) {
        MACDResult macd_value = macd.update(data.value);
        Signal signal = {data.timestamp, Side::NONE, data.value};
        if (std::isnan(macd_value.macd) || std::isnan(macd_value.signal))
            return signal;
        if ((macd_value.macd > macd_value.signal * (1.0 + threshold))
                && (last_side != Side::BUY))
            last_side = signal.side = Side::BUY;
        else if ((macd_value.macd < macd_value.signal * (1.0 - threshold))
                && (last_side != Side::SELL))
            last_side = signal.side = Side::SELL;
        return signal;
    }
};

} // namespace tzu

#endif // STRATEGIES_H
