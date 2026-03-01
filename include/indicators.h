#ifndef INDICATORS_H
#define INDICATORS_H

#include <cstddef>
#include <vector>
#include "defs.h"

/**
 * This header defines several technical indicators commonly used in
 * financial analysis. Each indicator is implemented as a class that
 * maintains the necessary state to calculate the indicator values
 * efficiently as new data points are added. All the indicators follow a
 * similar interface, with a `get()` method to retrieve the current
 * value and an `update()` method to add a new data point and
 * recalculate the indicator.
 */

namespace tzu {

template <class T, typename In, typename Out>
class Indicator {
public:
    Out get() const noexcept {
        return static_cast<T*>(this)->get();
    }
    Out update(In value) {
        return static_cast<T*>(this)->update(value);
    }
};

/**
 * Simple Moving Average (SMA)
 *
 * Maintains a fixed-size window of the most recent values and
 * calculates the average. Returns NaN until enough values have been
 * added to fill the window. Once the window is full, it updates the
 * average efficiently by keeping a running sum and subtracting the
 * value that falls out of the window.
 *
 * Template parameter `window_size` specifies the size of the window.
 */
class SMA: public Indicator<SMA, double, double> {
    double data = std::nan("");
    std::vector<double> prev;
    size_t pos = 0;
    size_t len = 0;
    double sum = 0.0;
public:
    SMA(size_t window_size): prev(window_size, std::nan("")) {}
    double get() const noexcept { return data; }
    double update(double value) {
        if (len < prev.size())
            len++;
        else
            sum -= prev[pos];
        sum += value;
        prev[pos] = value;
        pos = (pos + 1) % prev.size();
        data = len < prev.size()
                ? std::nan("") 
                : sum / static_cast<double>(prev.size());
        return data;
    }
};

/**
 * Exponential Moving Average (EMA)
 *
 * Uses a smoothing factor to give more weight to recent values. Returns
 * NaN until enough values have been added to fill the initial period.
 * Once the initial period is filled, it calculates the EMA using the
 * formula:
 *
 * EMA_today = (Value_today * alpha) + (EMA_yesterday * (1 - alpha))
 *
 * where alpha is the smoothing factor calculated as:
 *
 * alpha = smoothing / (period + 1)
 *
 * The default smoothing factor is 2.0, which is commonly used in
 * financial applications.
 */
class EMA: public Indicator<EMA, double, double> {
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

/**
 * Moving Variance (MVar)
 * 
 * Calculates the variance of the most recent N values. Returns NaN
 * until enough values have been added to fill the window. Once the
 * window is full, it calculates the variance using the formula:
 *
 * Variance = (1 / (N - dof)) * sum((x_i - mean)^2)
 *
 * where dof is the degrees of freedom, which is typically 1 for sample
 * variance and 0 for population variance. The N template parameter
 * specifies the size of the window.
 *
 * The standard deviation can be obtained by taking the square root of
 * the variance.
 */
class MVar {
    double data = std::nan("");
    SMA sma;
    std::vector<double> prev;
    size_t pos = 0;
    size_t len = 0;
    double sum = 0.0;
    size_t dof;
public:
    MVar(size_t window_size, size_t dof)
        : sma(window_size), prev(window_size, std::nan("")), dof(dof) {}
    double get() const noexcept { return data; }
    double update(double value) {
        if (len < prev.size()) len++;
        prev[pos] = value;
        pos = (pos + 1) % prev.size();
        sma.update(value);
        if (len < prev.size())
            return std::nan("");
        double accum = 0.0;
        for (size_t prev_value : prev) {
            if (std::isnan(prev_value))
                return std::nan("");
            double diff = prev_value - sma.get();
            accum += diff * diff;
        }
        data = accum / (prev.size() - dof);
        return data;
    }
};

/**
 * Relative Strength Index (RSI)
 *
 * Calculates the RSI based on the average gains and losses over a
 * specified period. Returns NaN until enough values have been added to
 * fill the window. Once the window is full, it calculates the RSI using
 * the formula:
 *
 * RSI = 100 - (100 / (1 + (Average Gain / Average Loss)))
 *
 * where Average Gain and Average Loss are calculated using the SMA of
 * the gains and losses over the specified period. The N template
 * parameter specifies the size of the window for calculating the
 * average gains and losses.
 */
class RSI: public Indicator<RSI, Ohlcv, double> {
    double data = std::nan("");
    SMA gains;
    SMA losses;
public:
    RSI(size_t period): gains(period), losses(period) {}
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

/**
 * Moving Average Convergence Divergence Result (MACDResult)
 *
 * Holds the current values of the MACD line, signal line, and
 * histogram. The MACD line is the difference between the short-term EMA
 * and the long-term EMA. The signal line is the EMA of the MACD line,
 * and the histogram is the difference between the MACD line and the
 * signal line.
 */
struct MACDResult {
    double macd;
    double signal;
    double histogram;
};

/**
 * Moving Average Convergence Divergence (MACD)
 *
 * Combines multiple EMAs to calculate the MACD line, signal line, and
 * histogram. Returns NaN for all values until enough data has been
 * added to fill the initial periods for both EMAs. Once the initial
 * periods are filled, it calculates the MACD line as the difference
 * between the short-term EMA and the long-term EMA. The signal line is
 * calculated as the EMA of the MACD line, and the histogram is the
 * difference between the MACD line and the signal line.
 */
class MACD: public Indicator<MACD, double, MACDResult> {
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
