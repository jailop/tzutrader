#ifndef DEFS_H
#define DEFS_H

#include <cstdint>
#include <cmath>

enum class Side {
    BUY,
    SELL,
    NONE
};

struct SignalItem {
    Side side;
    double price;
    double volume;
    SignalItem(Side s = Side::NONE, double p = 0.0, double v = 0.0)
        : side(s), price(p), volume(v) {}
};

struct Signal {
    int64_t timestamp;
    SignalItem* items;
    Signal(int64_t ts = 0, SignalItem* i = nullptr)
        : timestamp(ts), items(i) {}
};


enum class OHLCVField {
    OPEN,
    HIGH,
    LOW,
    CLOSE,
    VOLUME
};

struct OHLCV {
    int64_t timestamp;
    double open;
    double high;
    double low;
    double close;
    double volume;
    OHLCV(int64_t ts = 0, double o = 0.0, double h = 0.0, double l = 0.0,
          double c = 0.0, double v = 0.0)
        : timestamp(ts), open(o), high(h), low(l), close(c), volume(v) {}
    double getFieldValue(OHLCVField field) const {
        switch (field) {
            case OHLCVField::OPEN: return open;
            case OHLCVField::HIGH: return high;
            case OHLCVField::LOW: return low;
            case OHLCVField::CLOSE: return close;
            case OHLCVField::VOLUME: return volume;
        }
        return std::nan(""); // Should never reach here
    }
};

struct Tick {
    int64_t timestamp;
    double price = 0.0;
    double volume = 0.0;
    Side side = Side::NONE;
};

struct SingleValue {
    int64_t timestamp;
    double value = 0.0;
};

enum class DataType {
    OHLCV,
    TICK,
    SINGLE_VALUE,
};

#endif // DEFS_H
