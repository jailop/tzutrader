#include <gtest/gtest.h>
#include <cassert>
#include <fstream>
#include <vector>
#include "streamers.h"
#include "strategies.h"
#include "defs.h"

using namespace tzu;

static std::vector<Ohlcv> load_ohlcv(const std::string& path) {
    std::ifstream file(path);
    assert(file.is_open());
    std::vector<Ohlcv> data;
    Csv<Ohlcv> csv(file);
    for (const auto& row : csv) data.push_back(row);
    assert(!data.empty());
    return data;
}

constexpr char Ohlcv_PATH[] = "../data/btcusd.csv";

TEST(RSI, ReturnsHoldDuringWarmup) {
    std::ifstream file(Ohlcv_PATH);
    assert(file.is_open());
    Csv<Ohlcv> csv(file);
    RSIStrat strat;
    int i = 0;
    for (const auto& row : csv) {
        if (i++ >= 13) break; // only check warmup period
        auto sig = strat.update(row);
        EXPECT_EQ(sig.side, Side::NONE);
    }
    EXPECT_GT(i, 0);
}

TEST(RSI, GeneratesBuySellSignals) {
    auto data = load_ohlcv("../data/btcusd.csv");
    RSIStrat strat;
    bool buy = false, sell = false;
    for (size_t i = 0; i < data.size(); ++i) {
        auto sig = strat.update(data[i]);
        if (sig.side == Side::BUY) buy = true;
        if (sig.side == Side::SELL) sell = true;
    }
    EXPECT_TRUE(buy);
    EXPECT_TRUE(sell);
}

TEST(RSI, AvoidsRepeatedSignals) {
    auto data = load_ohlcv("../data/btcusd.csv");
    RSIStrat strat;
    Side last = Side::NONE;
    for (size_t i = 0; i < data.size(); ++i) {
        auto sig = strat.update(data[i]);
        if (sig.side != Side::NONE) {
            EXPECT_NE(sig.side, last);
            last = sig.side;
        }
    }
}
