#ifndef INDICATORS_H
#define INDICATORS_H

#include <vector>
#include <cstddef>
#include "defs.h"

template <typename T>
class BaseIndicator {
    std::vector<T> data;
    size_t pos;
public:
    BaseIndicator(size_t size = 1) : data(size), pos(0) {}
    T update(T value);
    T operator[](int index) const;
    T get() const noexcept;
    size_t size() const noexcept { return data.size(); }
};

class SMA {
    BaseIndicator<double> data;
    std::vector<double> prev;
    size_t pos;
    size_t len;
    double sum;
public:
    SMA(size_t period, size_t size = 1)
        : data(size), prev(period), pos(0), len(0), sum(0.0) {}
    double update(double value);
    double operator[](int index) const { return data[index]; }
    double get() const noexcept { return data.get(); }
    size_t size() const noexcept { return data.size(); }
};

class EMA {
    BaseIndicator<double> data;
    double alpha;
    double prev;
    size_t len;
    size_t period;
public:
    EMA(size_t period, double smoothing = 2.0, size_t size = 1)
        : data(size), alpha(smoothing / (period + 1.0)), prev(0.0), len(0),
          period(period) {}
    double update(double value);
    double operator[](int index) const { return data[index]; }
    double get() const noexcept { return data.get(); }
    size_t size() const noexcept { return data.size(); }
};

class MVar {
    BaseIndicator<double> data;
    SMA sma;
    std::vector<double> prev;
    size_t pos;
    size_t len;
    double sum;
    size_t dof;
public:
    MVar(size_t period, size_t dof, size_t size = 1)
        : data(size), sma(period), prev(period), pos(0), len(0), sum(0.0),
          dof(dof) {}
    double update(double value);
    double operator[](int index) const { return data[index]; }
    double get() const noexcept { return data.get(); }
    size_t size() const noexcept { return data.size(); }
};

class RSI {
    BaseIndicator<double> data;
    SMA gains;
    SMA losses;
public:
    RSI(size_t period, size_t size = 1)
        : data(size), gains(period), losses(period) {}
    double update(OHLCV value);
    double operator[](int index) const { return data[index]; }
    double get() const noexcept { return data.get(); }
    size_t size() const noexcept { return data.size(); }
};

struct MACDResult {
    double macd;
    double signal;
    double histogram;
};

class MACD {
    BaseIndicator<MACDResult> data;
    EMA short_ema;
    EMA long_ema;
    EMA signal_ema;
    size_t len;
    size_t start;
public:
    MACD(size_t short_period, size_t long_period, size_t signal_period,
            double smoothing = 2.0, size_t size = 1)
        : data(size), short_ema(short_period, smoothing),
          long_ema(long_period, smoothing),
          signal_ema(signal_period, smoothing),
          len(0), start(std::max(short_period, long_period)) {}
    MACDResult update(double value);
    MACDResult operator[](int index) const { return data[index]; }
    MACDResult get() const noexcept { return data.get(); }
    size_t size() const noexcept { return data.size(); }
};

#endif // INDICATORS_H
