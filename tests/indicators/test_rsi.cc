#include <gtest/gtest.h>
#include "indicators.h"
#include <cmath>

struct DummyOHLCV {
    double open, close;
};

TEST(RSI, ReturnsNaNDuringWarmup) {
    Ind::RSI<3> rsi;
    OHLCV d1{0, 100.0, 0, 0, 102.0, 0};
    OHLCV d2{0, 102.0, 0, 0, 104.0, 0};
    EXPECT_TRUE(std::isnan(rsi.update(d1)));
    EXPECT_TRUE(std::isnan(rsi.update(d2)));
}

TEST(RSI, CalculatesRSIWithGainsOnly) {
    Ind::RSI<3> rsi;
    rsi.update(OHLCV{0, 100.0, 0, 0, 102.0, 0});
    rsi.update(OHLCV{0, 102.0, 0, 0, 104.0, 0});
    double result = rsi.update(OHLCV{0, 104.0, 0, 0, 106.0, 0});
    EXPECT_DOUBLE_EQ(result, 100.0);
}

TEST(RSI, CalculatesRSIWithLossesOnly) {
    Ind::RSI<3> rsi;
    rsi.update(OHLCV{0, 100.0, 0, 0, 98.0, 0});
    rsi.update(OHLCV{0, 98.0, 0, 0, 96.0, 0});
    double result = rsi.update(OHLCV{0, 96.0, 0, 0, 94.0, 0});
    EXPECT_DOUBLE_EQ(result, 0.0);
}
