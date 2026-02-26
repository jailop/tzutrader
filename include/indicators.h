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
    BaseIndicator(size_t size = 1);
    T update(T value);
    T operator[](int index);
    T get();
    size_t size();
};

class SMA {
    BaseIndicator<double> data;
    std::vector<double> prev;
    size_t pos;
    size_t len;
    double sum;
public:
    SMA(size_t period, size_t size = 1);
    double update(double value);
    double operator[](int index);
    double get();
    size_t size();
};

class EMA {
    BaseIndicator<double> data;
    double alpha;
    double prev;
    size_t len;
    size_t period;
public:
    EMA(size_t period, double smoothing = 2.0, size_t size = 1);
    double update(double value);
    double operator[](int index);
    double get();
    size_t size();
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
    MVar(size_t period, size_t dof, size_t size = 1);
    double update(double value);
    double operator[](int index);
    double get();
    size_t size();
};

class RSI {
    BaseIndicator<double> data;
    SMA gains;
    SMA losses;
public:
    RSI(size_t period, size_t size = 1);
    double update(OHLCV value);
    double operator[](int index);
    double get();
    size_t size();
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
            double smoothing = 2.0, size_t size = 1);
    MACDResult update(double value);
    MACDResult operator[](int index);
    MACDResult get();
    size_t size();
};

#endif // INDICATORS_H
