#ifndef STRATEGIES_H
#define STRATEGIES_H

#include "indicators.h"

namespace Strat {

template <size_t ShortPeriod, size_t LongPeriod>
class SMACrossover {
    Ind::SMA<ShortPeriod> short_sma;
    Ind::SMA<LongPeriod> long_sma;
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

template <size_t N=14>
class RSI {
    double oversold;
    double overbought;
    Ind::RSI<N> rsi;
    Side last_side;
    static constexpr DataType required_data[1] = {DataType::OHLCV};
    OHLCVField field;
public:
    RSI(double oversold = 30.0, double overbought = 70.0,
            OHLCVField field = OHLCVField::CLOSE)
        : oversold(oversold), overbought(overbought),
          last_side(Side::NONE), field(field) {}
    const DataType* requiredData() const { return required_data; }
    size_t numItems() const { return 1; }
    Signal update(const OHLCV& data) {
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

class MACD {
    Ind::MACD macd;
    double threshold;
    Side last_side;
    static constexpr DataType required_data[1] = {DataType::SINGLE_VALUE};
public:
    MACD(size_t short_period, size_t long_period, size_t signal_period,
            double smoothing = 0.0, double threshold = 0.0)
        : macd(short_period, long_period, signal_period, smoothing),
          threshold(threshold), last_side(Side::NONE) {}
    const DataType* requiredData() const { return required_data; }
    size_t numItems() const { return 1; }
    Signal update(const SingleValue& data) {
        Ind::MACDResult macd_value = macd.update(data.value);
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

} // namespace Strat

#endif // STRATEGIES_H
