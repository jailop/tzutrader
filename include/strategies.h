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
    static constexpr size_t num_items = 1;
    SignalItem item[1] = {{Side::NONE, 0.0, 0.0}};
    Signal signal = {0, item};
public:
    SMACrossover(double threshold = 0.0, double smoothing = 2.0)
        : threshold(threshold) {}
    const DataType* requiredData() const { return required_data; }
    size_t numItems() const { return num_items; }
    const Signal update(const SingleValue& data);
};

template <size_t N=14>
class RSI {
    double oversold;
    double overbought;
    Ind::RSI<N> rsi;
    Side last_side;
    static constexpr DataType required_data[1] = {DataType::OHLCV};
    static constexpr size_t num_items = 1;
    SignalItem item[1] = {{Side::NONE, 0.0, 0.0}};
    Signal signal = {0, item};
    OHLCVField field;
public:
    RSI(double oversold = 30.0, double overbought = 70.0,
            OHLCVField field = OHLCVField::CLOSE)
        : oversold(oversold), overbought(overbought),
          last_side(Side::NONE), field(field) {}
    const DataType* requiredData() const { return required_data; }
    size_t numItems() const { return num_items; }
    const Signal update(const OHLCV& data);
};

class MACD {
    Ind::MACD macd;
    double threshold;
    Side last_side;
    static constexpr DataType required_data[1] = {DataType::SINGLE_VALUE};
    static constexpr size_t num_items = 1;
    SignalItem item[1] = {{Side::NONE, 0.0, 0.0}};
    Signal signal = {0, item};
public:
    MACD(size_t short_period, size_t long_period, size_t signal_period,
            double smoothing = 0.0, double threshold = 0.0)
        : macd(short_period, long_period, signal_period, smoothing),
          threshold(threshold), last_side(Side::NONE) {}
    const DataType* requiredData() const { return required_data; }
    size_t numItems() const { return num_items; }
    const Signal update(const SingleValue& data);
};

} // namespace Strat

#endif // STRATEGIES_H
