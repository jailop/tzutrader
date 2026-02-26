#include "strategies.h"

namespace Strat {

Signal RSI::update(const OHLCV& data) {
    double rsi_value = rsi.update(data.close);
    Signal signal = {
        data.timestamp,
        {{Side::NONE, data.close, 0.0}}
    };
    if (std::isnan(rsi_value))
        return signal;
    if ((rsi_value < oversold) && (last_side != Side::BUY))
        last_side = signal.items[0].side = Side::BUY;
    else if ((rsi_value > overbought) && (last_side != Side::SELL))
        last_side = signal.items[0].side = Side::SELL;
    return signal;
}
