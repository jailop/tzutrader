#include <gtest/gtest.h>
#include <fstream>
#include <vector>
#include "streamers.h"
#include "defs.h"

using namespace tzu;

TEST(CsvStreamer, ReadsOhlcv) {
    std::ifstream file("../data/btcusd.csv");
    ASSERT_TRUE(file.is_open());
    Csv<Ohlcv> csv(file);
    int count = 0;
    for (const auto& row : csv) {
        EXPECT_GT(row.timestamp, 0);
        EXPECT_GT(row.open, 0);
        EXPECT_GT(row.close, 0);
        ++count;
        if (count == 5) break;
    }
    EXPECT_EQ(count, 5);
}

TEST(CsvStreamer, ReadsTick) {
    std::ifstream file("../data/btcusd_tick.csv");
    ASSERT_TRUE(file.is_open());
    Csv<Tick> csv(file);
    int count = 0;
    for (const auto& row : csv) {
        EXPECT_GT(row.timestamp, 0);
        EXPECT_GT(row.price, 0);
        EXPECT_GE(row.side, Side::NONE);
        ++count;
        if (count == 5) break;
    }
    EXPECT_EQ(count, 5);
}

TEST(CsvStreamer, ReadsSingleValue) {
    std::ifstream file("../data/btcusd_singlevalue.csv");
    ASSERT_TRUE(file.is_open());
    Csv<SingleValue> csv(file);
    int count = 0;
    for (const auto& row : csv) {
        EXPECT_GT(row.timestamp, 0);
        EXPECT_GT(row.value, 0);
        ++count;
        if (count == 5) break;
    }
    EXPECT_EQ(count, 5);
}
