#include "indicators.h"
#include <cmath>

RSI::RSI(size_t period, size_t size)
    : data(size), gains(period), losses(period) {}

double RSI::update(OHLCV value) {
    double diff = value.close - value.open;
    gains.update(diff >= 0.0 ? diff : 0.0);
    losses.update(diff < 0 ? -diff : 0.0);
    if (std::isnan(losses.get())) {
        return data.update(std::nan(""));
    } else {
        double rsi = 100.0 - 100.0 / (1.0 + gains.get() / losses.get());
        return data.update(rsi);
    }
}

double inline RSI::operator[](int index) {
    return data[index];
}

double inline RSI::get() {
    return data.get();
}

size_t inline RSI::size() {
    return data.size();
}
