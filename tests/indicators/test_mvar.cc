#include <gtest/gtest.h>
#include "indicators.h"
#include <cmath>

TEST(MVar, ReturnsNaNDuringWarmup) {
    Ind::MVar<3> mvar(1);
    EXPECT_TRUE(std::isnan(mvar.update(1.0)));
    EXPECT_TRUE(std::isnan(mvar.update(2.0)));
    EXPECT_FALSE(std::isnan(mvar.update(3.0)));
}

TEST(MVar, CalculatesCorrectMovingVariance) {
    Ind::MVar<3> mvar(1);
    mvar.update(10.0);
    mvar.update(20.0);
    double result = mvar.update(30.0);
    EXPECT_NEAR(result, 100.0, 1e-10);
}

TEST(MVar, SlidingWindowUpdatesCorrectly) {
    Ind::MVar<3> mvar(1);
    mvar.update(10.0);
    mvar.update(20.0);
    mvar.update(30.0);
    double result = mvar.update(40.0);
    EXPECT_NEAR(result, 100.0, 1e-10);
}
