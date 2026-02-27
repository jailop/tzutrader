#include <gtest/gtest.h>
#include <fstream>
#include <vector>
#include "streamers.h"
#include "strategies.h"
#include "defs.h"

static std::vector<OHLCV> load_ohlcv(const std::string& path) {
    std::ifstream file(path);
    std::vector<OHLCV> data;
    Csv<OHLCV> csv(file);
    for (const auto& row : csv) data.push_back(row);
    return data;
}

TEST(RSI, ReturnsHoldDuringWarmup) {
    using Strat::RSI;
    auto data = load_ohlcv("../data/btcusd.csv");
    RSI<> strat;
    for (size_t i = 0; i < 20; ++i) {
        auto sig = strat.update(data[i]);
        EXPECT_EQ(sig.side, Side::NONE);
    }
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
