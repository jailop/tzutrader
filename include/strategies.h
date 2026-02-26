#ifndef STRATEGIES_H
#define STRATEGIES_H

#include "indicators.h"

namespace Strat {

template <typename T>
class Crossover {
    T short_sma;
    T long_sma;
    double threshold;
    double smoothing;  // Smoothing factor for EMA
    Side last_side;
    static constexpr DataType required_data[1] = {DataType::SINGLE_VALUE};
    static constexpr size_t num_items = 1;
public:
    Crossover(size_t short_period, size_t long_period,
            double threshold = 0.0, double smoothing = 2.0)
        : threshold(threshold),
          smoothing(smoothing), last_side(Side::NONE) {
        if (std::is_same<T, Ind::EMA>::value) {
            short_sma = T(short_period, smoothing);
            long_sma = T(long_period, smoothing);
        } else {
            short_sma = T(short_period);
            long_sma = T(long_period);
        }
    }
    const DataType* requiredData() const { return required_data; }
    size_t numItems() const { return num_items; }
    Signal update(const SingleValue& data);
};

typedef Crossover<Ind::SMA> SmaCrossover;
typedef Crossover<Ind::EMA> EmaCrossover;

class RSI {
    double oversold;
    double overbought;
    Ind::RSI rsi;
    Side last_side;
    static constexpr DataType required_data[1] = {DataType::OHLCV};
    static constexpr size_t num_items = 1;
public:
    RSI(size_t period, double oversold = 30.0, double overbought = 70.0)
        : oversold(oversold), overbought(overbought), rsi(period),
          last_side(Side::NONE) {}
    const DataType* requiredData() const { return required_data; }
    size_t numItems() const { return num_items; }
    Signal update(const OHLCV& data);
};

} // namespace Strat

#endif // STRATEGIES_H
