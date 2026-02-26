#include "indicators.h"
#include <cmath>

MACD::MACD(size_t short_period, size_t long_period, size_t signal_period,
        double smoothing, size_t size)
    : data(size), short_ema(short_period, smoothing),
      long_ema(long_period, smoothing), signal_ema(signal_period, smoothing),
      len(0), start(std::max(short_period, long_period)) {}

MACDResult MACD::update(double value) {
    len++;
    short_ema.update(value);
    long_ema.update(value);
    MACDResult result;
    if (len >= start) {
        double diff = short_ema.get() - long_ema.get();
        signal_ema.update(diff);
        return data.update({diff, signal_ema.get(), diff - signal_ema.get()});
    } else {
        return data.update({std::nan(""), std::nan(""), std::nan("")});
    }
}

MACDResult inline MACD::operator[](int index) {
    return data[index];
}

MACDResult inline MACD::get() {
    return data.get();
}

size_t inline MACD::size() {
    return data.size();
}
