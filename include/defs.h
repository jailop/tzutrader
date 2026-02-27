#ifndef DEFS_H
#define DEFS_H

#include <cstdint>
#include <cmath>
#include <ostream>

namespace tzu {

enum class Side {
    BUY,
    SELL,
    NONE
};

struct Signal {
    int64_t timestamp;
    Side side;
    double price;
    double volume;
    Signal(int64_t ts = 0, Side s = Side::NONE, double p = 0.0, double v = 1.0)
        : timestamp(ts), side(s), price(p), volume(v) {}
};

enum class OhlcvField {
    OPEN,
    HIGH,
    LOW,
    CLOSE,
    VOLUME
};

struct Ohlcv {
    int64_t timestamp;
    double open;
    double high;
    double low;
    double close;
    double volume;
    Ohlcv(int64_t ts = 0, double o = 0.0, double h = 0.0, double l = 0.0,
          double c = 0.0, double v = 0.0)
        : timestamp(ts), open(o), high(h), low(l), close(c), volume(v) {}
    double getFieldValue(OhlcvField field) const {
        switch (field) {
            case OhlcvField::OPEN: return open;
            case OhlcvField::HIGH: return high;
            case OhlcvField::LOW: return low;
            case OhlcvField::CLOSE: return close;
            case OhlcvField::VOLUME: return volume;
        }
        return std::nan(""); // Should never reach here
    }
};

struct Tick {
    int64_t timestamp;
    double price = 0.0;
    double volume = 0.0;
    Side side = Side::NONE;
    Tick() = default;
    Tick(int64_t ts, double p, double v, Side s)
        : timestamp(ts), price(p), volume(v), side(s) {}
};

struct SingleValue {
    int64_t timestamp;
    double value = 0.0;
    SingleValue() = default;
    SingleValue(int64_t ts, double v) : timestamp(ts), value(v) {}
};

enum class DataType {
    OHLCV,
    TICK,
    SINGLE_VALUE,
};

} // namespace tzu

inline std::ostream& operator<<(std::ostream& os, const tzu::Signal& signal) {
    os << "Signal(timestamp=" << signal.timestamp
       << ", side=" 
       << (signal.side == tzu::Side::BUY 
               ? "BUY" 
               : signal.side == tzu::Side::SELL 
                ? "SELL" : "NONE")
       << ", price=" << signal.price
       << ", volume=" << signal.volume << ")";
    return os;
}


#endif // DEFS_H
