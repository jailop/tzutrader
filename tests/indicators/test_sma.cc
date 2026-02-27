#include <gtest/gtest.h>
#include "indicators.h"
#include <cmath>

using namespace tzu;

TEST(SMA, ReturnsNaNDuringWarmup) {
    SMA<3> sma;
    EXPECT_TRUE(std::isnan(sma.update(1.0)));
    EXPECT_TRUE(std::isnan(sma.update(2.0)));
    EXPECT_FALSE(std::isnan(sma.update(3.0)));
}

TEST(SMA, CalculatesCorrectMovingAverage) {
    SMA<3> sma;
    sma.update(10.0);
    sma.update(20.0);
    double result = sma.update(30.0);
    EXPECT_DOUBLE_EQ(result, 20.0);
}

TEST(SMA, SlidingWindowUpdatesCorrectly) {
    SMA<3> sma;
    sma.update(10.0);
    sma.update(20.0);
    sma.update(30.0);
    double result = sma.update(40.0);
    EXPECT_DOUBLE_EQ(result, 30.0);
}
