#include "strategies.h"
#include <cmath>

namespace Strat {

const Signal MACD::update(const SingleValue& data) {
    Ind::MACDResult macd_value = macd.update(data.value);
    signal.timestamp = data.timestamp;
    signal.items[0].price = data.value;
    if (std::isnan(macd_value.macd) || std::isnan(macd_value.signal))
        return signal;
    if ((macd_value.macd > macd_value.signal * (1.0 + threshold))
            && (last_side != Side::BUY))
        last_side = signal.items[0].side = Side::BUY;
    else if ((macd_value.macd < macd_value.signal * (1.0 - threshold))
            && (last_side != Side::SELL))
        last_side = signal.items[0].side = Side::SELL;
    return signal;
}

} // namespace Strat
