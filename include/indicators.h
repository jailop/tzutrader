#ifndef INDICATORS_H
#define INDICATORS_H

#include <cstddef>
#include "defs.h"

namespace tzu {

template <size_t N=9>
class SMA {
    double data = std::nan("");
    double prev[N];
    size_t pos = 0;
    size_t len = 0;
    double sum = 0.0;
public:
    double get() const noexcept { return data; }
    double update(double value) {
        if (len < N)
            len++;
        else
            sum -= prev[pos];
        sum += value;
        prev[pos] = value;
        pos = (pos + 1) % N;
        data = len < N
                ? std::nan("") 
                : sum / N;
        return data;
    }
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
    double get() const noexcept { return data; }
    double update(double value) {
        len++;
        if (len < period) {
            prev += value;
            data = std::nan("");
        } else if (len == period) {
            prev += value;
            prev /= period;
            data = prev;
        } else {
            prev = (value * alpha) + (prev * (1.0 - alpha));
            data = prev;
        }
        return data;
    }
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
    double get() const noexcept { return data; }
    double update(double value) {
        if (len < size) len++;
        prev[pos] = value;
        pos = (pos + 1) % size;
        sma.update(value);
        if (len < size)
            return std::nan("");
        double accum = 0.0;
        for (size_t i = 0; i < size; i++) {
            double diff = prev[i] - sma.get();
            accum += diff * diff;
        }
        data = accum / (size - dof);
        return data;
    }
};


template <size_t N=14>
class RSI {
    double data = std::nan("");
    SMA<N> gains;
    SMA<N> losses;
public:
    double get() const noexcept { return data; }
    double update(Ohlcv value) {
        double diff = value.close - value.open;
        gains.update(diff >= 0.0 ? diff : 0.0);
        losses.update(diff < 0 ? -diff : 0.0);
        if (std::isnan(losses.get()))
            return std::nan("");
        data = 100.0 - 100.0 / (1.0 + gains.get() / losses.get());
        return data;
    }
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
          start(std::fmax(short_period, long_period)) {}
    MACDResult get() const noexcept { return data; }
    MACDResult update(double value) {
        len++;
        short_ema.update(value);
        long_ema.update(value);
        if (len <= start)
            return {std::nan(""), std::nan(""), std::nan("")};
        double diff = short_ema.get() - long_ema.get();
        signal_ema.update(diff);
        data = {diff, signal_ema.get(), diff - signal_ema.get()};
        return data;
    }
};

} // namespace tzu

#endif // INDICATORS_H
