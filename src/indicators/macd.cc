#include "indicators.h"
#include <cmath>

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
