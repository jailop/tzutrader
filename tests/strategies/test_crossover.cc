#include <gtest/gtest.h>
#include <fstream>
#include <vector>
#include "streamers.h"
#include "strategies.h"
#include "defs.h"

using namespace tzu;

// Helper: Load OHLCV from CSV
static std::vector<SingleValue> load_singlevalue(const std::string& path) {
    std::ifstream file(path);
    std::vector<SingleValue> data;
    Csv<SingleValue> csv(file);
    for (const auto& row : csv) data.push_back(row);
    return data;
}

TEST(SMACrossover, ReturnsHoldDuringWarmup) {
    std::ifstream file("../data/btcusd_singlevalue.csv");
    Csv<SingleValue> csv(file);
    SMACrossover strat(7, 21, 0.0);
    int i = 0;
    for (const auto& row : csv) {
        if (i++ >= 20) break;
        auto sig = strat.update(row);
        EXPECT_EQ(sig.side, Side::NONE);
    }
}

TEST(SMACrossover, GeneratesBuySellSignals) {
    std::ifstream file("../data/btcusd_singlevalue.csv");
    Csv<SingleValue> csv(file);
    SMACrossover strat(7, 21, 0.0);
    Side last = Side::NONE;
    bool buy = false, sell = false;
    for (const auto& row : csv) {
        auto sig = strat.update(row);
        if (sig.side == Side::BUY) buy = true;
        if (sig.side == Side::SELL) sell = true;
        last = sig.side;
    }
    EXPECT_TRUE(buy);
    EXPECT_TRUE(sell);
}

TEST(SMACrossover, AvoidsRepeatedSignals) {
    std::ifstream file("../data/btcusd_singlevalue.csv");
    Csv<SingleValue> csv(file);
    SMACrossover strat(7, 21, 0.0);
    Side last = Side::NONE;
    for (const auto& row : csv) {
        auto sig = strat.update(row);
        if (sig.side != Side::NONE) {
            EXPECT_NE(sig.side, last);
            last = sig.side;
        }
    }
}
