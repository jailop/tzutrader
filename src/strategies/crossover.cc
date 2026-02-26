#include "strategies.h"

template <typename T>
Signal Crossover<T>::update(const SingleValue& data) {
    double short_value = short_sma.update(data.value);
    double long_value = long_sma.update(data.value);
    signal.timestamp = data.timestamp;
    signal.items[0].price = data.value;
    signal.items[0].side = Side::NONE;
    if ((short_value > long_value * (1.0 + threshold))
            && (last_side != Side::BUY))
        last_side = signal.items[0].side = Side::BUY;
    else if ((short_value < long_value * (1.0 - threshold))
            && (last_side != Side::SELL))
        last_side = signal.items[0].side = Side::SELL;
    return signal;
}

