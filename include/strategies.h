#ifndef STRATEGIES_H
#define STRATEGIES_H

#include "indicators.h"

template <typename T>
class Crossover {
    T short_sma;
    T long_sma;
    double threshold;
    double smoothing;  // Smoothing factor for EMA
    Side last_side;
    Signal signal;
    static constexpr DataType required_data[1] = {DataType::SINGLE_VALUE};
    static constexpr size_t num_items = 1;
public:
    Crossover(size_t short_period, size_t long_period,
            double threshold = 0.0, double smoothing = 2.0)
        : threshold(threshold),
          smoothing(smoothing), last_side(Side::NONE),
          signal({0, {{Side::NONE, 0.0}}}) {
        if (std::is_same<T, EMA>::value) {
            short_sma = T(short_period, smoothing);
            long_sma = T(long_period, smoothing);
        } else {
            short_sma = T(short_period);
            long_sma = T(long_period);
        }
    }
    constexpr const DataType* requiredData() const { return required_data; }
    constexpr size_t numItems() const { return num_items; }
    Signal update(const SingleValue& data);
};

typedef Crossover<SMA> SmaCrossover;
typedef Crossover<EMA> EmaCrossover;

#endif // STRATEGIES_H
