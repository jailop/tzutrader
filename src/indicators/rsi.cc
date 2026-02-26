#include "indicators.h"
#include <cmath>

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
