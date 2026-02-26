#include "indicators.h"
#include <cmath>

Ind::MACDResult Ind::MACD::update(double value) {
    len++;
    short_ema.update(value);
    long_ema.update(value);
    if (len < start)
        return {std::nan(""), std::nan(""), std::nan("")};
    double diff = short_ema.get() - long_ema.get();
    signal_ema.update(diff);
    data = {diff, signal_ema.get(), diff - signal_ema.get()};
    return data;
}
