#ifndef PORTFOLIOS_H
#define PORTFOLIOS_H

#include <cstdint>
#include <cmath>
#include <iostream>
#include "defs.h"

namespace tzu {

/**
 * A simple portfolio that invests all available cash into the asset
 * when a BUY signal is received, and sells all holdings when a SELL
 * signal is received. It tracks the initial cash, current cash,
 * quantity held, last price, and last timestamp for performance
 * evaluation. Of course, this is a very naive and unrealistic
 * portfolio, but it serves as a basic example for testing and
 * demonstration purposes.
 */
class SimplePortfolio {
    double initial_cash;
    double cash;
    double quantity = 0.0;
    double last_price = std::nan("");
    int64_t last_timestamp = 0;
public:
    SimplePortfolio(double initialCash = 100000.0)
        : initial_cash(initialCash), cash(initialCash) {}
    void update(const Signal& signal) {
        if (signal.price <= 0.0) return;
        if (signal.side == Side::BUY) {
            double qty = std::floor(cash / signal.price);
            quantity += qty;
            cash -= qty * signal.price;
        } else if (signal.side == Side::SELL) {
            cash += quantity * signal.price;
            quantity = 0.0;
        }
        last_price = signal.price;
        last_timestamp = signal.timestamp;
    }
    friend std::ostream& operator<<(std::ostream& os,
            const SimplePortfolio& portfolio);
};


inline std::ostream& operator<<(std::ostream& os, const SimplePortfolio& portfolio) {
    double total_value = portfolio.cash + portfolio.quantity * portfolio.last_price;
    double profit_loss = total_value - portfolio.initial_cash;
    double return_pct = (total_value - portfolio.initial_cash)
        / portfolio.initial_cash;
    os 
        << "timestamp: " << portfolio.last_timestamp
        << " init_cash: " << portfolio.initial_cash
        << " curr_cash: " << portfolio.cash
        << " quantity: " << portfolio.quantity
        << " invested: " << portfolio.quantity * portfolio.last_price
        << " valuation: " << total_value
        << " profit: " << profit_loss
        << " return: " << return_pct;
    return os;
}
} // namespace tzu

#endif // PORTFOLIOS_H
