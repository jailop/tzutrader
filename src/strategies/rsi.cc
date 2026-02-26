#include "strategies.h"
#include <cmath>

namespace Strat {

const Signal RSI::update(const OHLCV& data) {
    double rsi_value = rsi.update(data);
    signal.timestamp = data.timestamp;
    signal.items[0].price = data.getFieldValue(field);
    if (std::isnan(rsi_value))
        return signal;
    if ((rsi_value < oversold) && (last_side != Side::BUY))
        last_side = signal.items[0].side = Side::BUY;
    else if ((rsi_value > overbought) && (last_side != Side::SELL))
        last_side = signal.items[0].side = Side::SELL;
    return signal;
}

} // namespace Strat
