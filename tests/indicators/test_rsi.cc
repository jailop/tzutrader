#include <gtest/gtest.h>
#include "indicators.h"
#include <cmath>

using namespace tzu;

TEST(RSI, ReturnsNaNDuringWarmup) {
    RSI rsi(3);
    Ohlcv d1{0, 100.0, 0, 0, 102.0, 0};
    Ohlcv d2{0, 102.0, 0, 0, 104.0, 0};
    EXPECT_TRUE(std::isnan(rsi.update(d1)));
    EXPECT_TRUE(std::isnan(rsi.update(d2)));
}

TEST(RSI, CalculatesRSIWithGainsOnly) {
    RSI rsi(3);
    rsi.update(Ohlcv{0, 100.0, 0, 0, 102.0, 0});
    rsi.update(Ohlcv{0, 102.0, 0, 0, 104.0, 0});
    double result = rsi.update(Ohlcv{0, 104.0, 0, 0, 106.0, 0});
    EXPECT_DOUBLE_EQ(result, 100.0);
}

TEST(RSI, CalculatesRSIWithLossesOnly) {
    RSI rsi(3);
    rsi.update(Ohlcv{0, 100.0, 0, 0, 98.0, 0});
    rsi.update(Ohlcv{0, 98.0, 0, 0, 96.0, 0});
    double result = rsi.update(Ohlcv{0, 96.0, 0, 0, 94.0, 0});
    EXPECT_DOUBLE_EQ(result, 0.0);
}
