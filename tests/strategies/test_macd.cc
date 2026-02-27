#include <gtest/gtest.h>
#include <fstream>
#include <vector>
#include "streamers.h"
#include "strategies.h"
#include "defs.h"

// Use Csv<SingleValue> directly for iteration

using namespace tzu;

TEST(MACD, ReturnsHoldDuringWarmup) {
    std::ifstream file("../data/btcusd_singlevalue.csv");
    Csv<SingleValue> csv(file);
    MACDStrat strat(12, 26, 9, 0.0); // typical MACD params
    int i = 0;
    for (const auto& row : csv) {
        if (i++ >= 30) break;
        auto sig = strat.update(row);
        EXPECT_EQ(sig.side, Side::NONE);
    }
}

TEST(MACD, GeneratesBuySellSignals) {
    std::ifstream file("../data/btcusd_singlevalue.csv");
    Csv<SingleValue> csv(file);
    MACDStrat strat(12, 26, 9);
    bool buy = false, sell = false;
    for (const auto& row : csv) {
        auto sig = strat.update(row);
        if (sig.side == Side::BUY) buy = true;
        if (sig.side == Side::SELL) sell = true;
    }
    EXPECT_TRUE(buy);
    EXPECT_TRUE(sell);
}

TEST(MACD, AvoidsRepeatedSignals) {
    std::ifstream file("../data/btcusd_singlevalue.csv");
    Csv<SingleValue> csv(file);
    MACDStrat strat(12, 26, 9, 0.0);
    Side last = Side::NONE;
    for (const auto& row : csv) {
        auto sig = strat.update(row);
        if (sig.side != Side::NONE) {
            EXPECT_NE(sig.side, last);
            last = sig.side;
        }
    }
}
