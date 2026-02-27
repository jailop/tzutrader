#include <gtest/gtest.h>
#include "indicators.h"
#include <cmath>

TEST(EMA, ReturnsNaNDuringWarmup) {
    Ind::EMA ema(3);
    EXPECT_TRUE(std::isnan(ema.update(10.0)));
    EXPECT_TRUE(std::isnan(ema.update(20.0)));
    EXPECT_FALSE(std::isnan(ema.update(30.0)));
}

TEST(EMA, FirstValueIsSMAOfWarmupPeriod) {
    Ind::EMA ema(3);
    ema.update(10.0);
    ema.update(20.0);
    double result = ema.update(30.0);
    EXPECT_DOUBLE_EQ(result, (10.0 + 20.0 + 30.0) / 3.0); // 60/3 = 20.0
}

TEST(EMA, AppliesExponentialSmoothingAfterWarmup) {
    Ind::EMA ema(3, 2.0);
    ema.update(10.0);
    ema.update(20.0);
    double prevEMA = ema.update(30.0); // triggers SMA assignment
    double alpha = 2.0 / (3.0 + 1.0);
    double newPrice = 40.0;
    double expectedEMA = (newPrice * alpha) + (prevEMA * (1.0 - alpha));
    double result = ema.update(newPrice);
    EXPECT_NEAR(result, expectedEMA, 1e-10); // prevEMA is the first EMA value, as above
}
