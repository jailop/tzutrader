#include <gtest/gtest.h>
#include "tzu/indicators.h"

using namespace tzu;

TEST(MDD, ReturnsDuringWarmup) {
    MDD mdd;
    // No values has been added
    EXPECT_TRUE(mdd.get() == 0.0);
    // First value is added
    EXPECT_TRUE(mdd.update(100.0) == 0.0);
}

TEST(MDD, UpdatesPeakAndDrawdown) {
    MDD mdd;
    mdd.update(100.0);
    EXPECT_TRUE(mdd.update(120.0) == 0.0);
    EXPECT_TRUE(mdd.update(90.0) == -0.25);
    EXPECT_TRUE(mdd.update(130.0) == -0.25);
    EXPECT_TRUE(mdd.update(110.0) == -0.25);
    EXPECT_TRUE(mdd.update(65.0) == -0.5);
}
