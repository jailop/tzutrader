#ifndef INDICATORS_H
#define INDICATORS_H

#include <cstddef>
#include "defs.h"

namespace Ind {

template <size_t N=9>
class SMA {
    double data = std::nan("");
    double prev[N];
    size_t pos = 0;
    size_t len = 0;
    double sum = 0.0;
public:
    double update(double value);
    double get() const noexcept { return data; }
};

class EMA {
    double data = std::nan("");
    double alpha;
    double prev = 0.0;
    size_t len = 0;
    size_t period;
public:
    EMA(size_t period, double smoothing = 2.0)
        : alpha(smoothing / (period + 1.0)), period(period) {}
    double update(double value);
    double get() const noexcept { return data; }
};

template <size_t N=9>
class MVar {
    double data = std::nan("");
    SMA<N> sma;
    double prev[N];
    size_t size = N;
    size_t pos = 0;
    size_t len = 0;
    double sum = 0.0;
    size_t dof;
public:
    MVar(size_t dof)
        : dof(dof) {}
    double update(double value);
    double get() const noexcept { return data; }
};


template <size_t N=14>
class RSI {
    double data = std::nan("");
    SMA<N> gains;
    SMA<N> losses;
public:
    double update(OHLCV value);
    double get() const noexcept { return data; }
};

struct MACDResult {
    double macd;
    double signal;
    double histogram;
};

class MACD {
    MACDResult data;
    EMA short_ema;
    EMA long_ema;
    EMA signal_ema;
    size_t len = 0;
    size_t start;
public:
    MACD(size_t short_period, size_t long_period, size_t signal_period,
            double smoothing = 2.0)
        : short_ema(short_period, smoothing),
          long_ema(long_period, smoothing),
          signal_ema(signal_period, smoothing),
          start(std::max(short_period, long_period)) {}
    MACDResult update(double value);
    MACDResult get() const noexcept { return data; }
};

} // namespace Ind

#endif // INDICATORS_H
