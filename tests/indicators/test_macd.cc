#include <gtest/gtest.h>
#include "indicators.h"
#include <cmath>

using namespace tzu;

TEST(MACD, ReturnsNaNDuringWarmup) {
    MACD macd(3, 5, 2);
    auto result = macd.update(100.0);
    EXPECT_TRUE(std::isnan(result.macd));
    EXPECT_TRUE(std::isnan(result.signal));
    EXPECT_TRUE(std::isnan(result.histogram));
}

TEST(MACD, CalculatesMACDLineAfterWarmup) {
    MACD macd(2, 4, 2);
    macd.update(100.0);
    macd.update(102.0);
    macd.update(104.0);
    macd.update(106.0);
    auto result = macd.update(108.0);
    EXPECT_FALSE(std::isnan(result.macd));
}

TEST(MACD, HistogramEqualsMACDMinusSignal) {
    MACD macd(3, 6, 2);
    for (int i = 0; i < 10; ++i) macd.update(100.0 + i * 2.0);
    auto result = macd.update(120.0);
    if (!std::isnan(result.macd) && !std::isnan(result.signal))
        EXPECT_NEAR(result.histogram, result.macd - result.signal, 1e-10);
}
