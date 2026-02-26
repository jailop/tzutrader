#ifndef DEFS_H
#define DEFS_H

#include <cstdint>

enum class Side {
    BUY,
    SELL,
    NONE
};

struct SignalItem {
    Side side = Side::NONE;
    double price = 0.0;
    double volume = 0.0;
};

struct Signal {
    int64_t timestamp;
    SignalItem *items;
};

struct OHLCV {
    int64_t timestamp;
    double open = 0.0;
    double high = 0.0;
    double low = 0.0;
    double close = 0.0;
    double volume = 0.0;
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
