#include <gtest/gtest.h>
#include <cassert>
#include <fstream>
#include <vector>
#include "streamers.h"
#include "strategies.h"
#include "defs.h"

static std::vector<OHLCV> load_ohlcv(const std::string& path) {
    std::ifstream file(path);
    assert(file.is_open());
    std::vector<OHLCV> data;
    Csv<OHLCV> csv(file);
    for (const auto& row : csv) data.push_back(row);
    assert(!data.empty());
    return data;
}

constexpr char OHLCV_PATH[] = "../data/btcusd.csv";

TEST(RSI, ReturnsHoldDuringWarmup) {
    using Strat::RSI;
    std::ifstream file(OHLCV_PATH);
    assert(file.is_open());
    Csv<OHLCV> csv(file);
    RSI<> strat;
    size_t count = 0;
    for (auto& row : csv) {
        auto sig = strat.update(row);
        EXPECT_EQ(sig.side, Side::NONE);
        count++;
    }
    EXPECT_GT(count, 0);
}

TEST(RSI, GeneratesBuySellSignals) {
    using Strat::RSI;
    auto data = load_ohlcv("../data/btcusd.csv");
    RSI<> strat;
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
    using Strat::RSI;
    auto data = load_ohlcv("../data/btcusd.csv");
    RSI<> strat;
    Side last = Side::NONE;
    for (size_t i = 0; i < data.size(); ++i) {
        auto sig = strat.update(data[i]);
        if (sig.side != Side::NONE) {
            EXPECT_NE(sig.side, last);
            last = sig.side;
        }
    }
}
