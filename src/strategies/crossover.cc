#include "strategies.h"

namespace Strat {

template <typename T>
Signal Crossover<T>::update(const SingleValue& data) {
    double short_value = short_sma.update(data.value);
    double long_value = long_sma.update(data.value);
    Signal signal = {data.timestamp, {{Side::NONE, data.value}}};
    if ((short_value > long_value * (1.0 + threshold))
            && (last_side != Side::BUY))
        last_side = signal.items[0].side = Side::BUY;
    else if ((short_value < long_value * (1.0 - threshold))
            && (last_side != Side::SELL))
        last_side = signal.items[0].side = Side::SELL;
    return signal;
}

} // namespace Strat
