#ifndef PORTFOLIOS_H
#define PORTFOLIOS_H

#include <cstdint>
#include <cmath>
#include <iostream>
#include <vector>
#include <iomanip>
#include "defs.h"
#include "stats.h"

namespace tzu {

template<class T>
class Portfolio {
public:
    void update(const T& signal) {
        static_cast<T*>(this)->update(signal);
    }
};


/**
 * BasicPortfolio implements transaction costs and simple stop-loss /
 * take-profit policies. Transaction costs are expressed as a fraction
 * of the transaction value (e.g. 0.001 == 0.1%).  This portfolio uses
 * all available cash to buy as many units as possible at each buy
 * signal, and liquidates all positions at each sell signal. Stop-loss
 * and take-profit are checked at each update and positions are
 * liquidated if the price breaches the stop-loss or take-profit
 * thresholds.  Stop-loss and take-profit are fractions relative to the
 * acquisition price (e.g. 0.1 == 10%). By default transaction costs are
 * 0 and stop-loss / take-profit are NaN (disabled).
 */
class BasicPortfolio: public Portfolio<BasicPortfolio> {
private:
    double init_cash;
    double cash;
    std::vector<Position> positions;
    double tx_cost_pct;
    double stop_loss_pct;
    double take_profit_pct;
    double last_price = std::nan("");
    PortfolioStats stats;

    void liquidate_position_at(size_t i, double price, int64_t timestamp, 
                              bool is_stop_loss = false, bool is_take_profit = false) {
        const Position& pos = positions[i];
        double proceeds = pos.quantity * price;
        double commission = proceeds * tx_cost_pct;
        stats.add_costs(commission);
        cash += proceeds - commission;
        
        double profit = (price - pos.price) * pos.quantity - commission;
        stats.record_trade_close(timestamp, pos.quantity, pos.price, price, profit,
                                is_stop_loss, is_take_profit);
        
        positions[i] = positions.back();
        positions.pop_back();
    }

    void liquidate_all_at_price(double price, int64_t timestamp) {
        for (const auto& p : positions) {
            double proceeds = p.quantity * price;
            double commission = proceeds * tx_cost_pct;
            stats.add_costs(commission);
            cash += proceeds - commission;
            
            double profit = (price - p.price) * p.quantity - commission;
            stats.record_trade_close(timestamp, p.quantity, p.price, price, profit, false, false);
        }
        positions.clear();
    }

    double compute_holdings_value() const {
        double holdings = 0.0;
        for (const auto& p : positions) {
            holdings += p.quantity * last_price;
        }
        return holdings;
    }

    double compute_total_quantity() const {
        double qty = 0.0;
        for (const auto& p : positions) {
            qty += p.quantity;
        }
        return qty;
    }

    double compute_total_value() const {
        return cash + compute_holdings_value();
    }

    void check_stop_loss_take_profit(double current_price, int64_t timestamp) {
        for (size_t i = 0; i < positions.size();) {
            bool should_liquidate = false;
            bool is_stop_loss = false;
            bool is_take_profit = false;
            const Position& p = positions[i];
            
            if (!std::isnan(stop_loss_pct)) {
                double stop_price = p.price * (1.0 - stop_loss_pct);
                if (current_price <= stop_price) {
                    should_liquidate = true;
                    is_stop_loss = true;
                }
            }
            
            if (!should_liquidate && !std::isnan(take_profit_pct)) {
                double tp_price = p.price * (1.0 + take_profit_pct);
                if (current_price >= tp_price) {
                    should_liquidate = true;
                    is_take_profit = true;
                }
            }
            
            if (should_liquidate) {
                stats.increment_trades();
                liquidate_position_at(i, current_price, timestamp, is_stop_loss, is_take_profit);
            } else {
                ++i;
            }
        }
    }

    void process_signal(const Signal& signal) {
        if (signal.side == Side::BUY) {
            execute_buy(signal);
        } else if (signal.side == Side::SELL) {
            execute_sell(signal);
        }
    }

    void execute_buy(const Signal& signal) {
        double unit_cost = signal.price * (1.0 + tx_cost_pct);
        double qty = std::floor(cash / unit_cost);
        if (qty > 0) {
            double cost = qty * signal.price;
            double commission = cost * tx_cost_pct;
            stats.add_costs(commission);
            cash -= cost + commission;
            stats.increment_trades();
            stats.record_trade_open(signal.timestamp, qty, signal.price);
            positions.push_back(Position{signal.timestamp, qty, signal.price});
        }
    }

    void execute_sell(const Signal& signal) {
        size_t num_positions = positions.size();
        if (num_positions > 0) {
            stats.increment_trades();
            liquidate_all_at_price(signal.price, signal.timestamp);
        }
    }

    double get_holdings_value() const {
        return compute_holdings_value();
    }

    double get_total_quantity() const {
        return compute_total_quantity();
    }

public:
    BasicPortfolio(double initCash = 100000.0,
                   double txCostPct = 0.0,
                   double stopLossPct = std::nan(""),
                   double takeProfitPct = std::nan(""))
        : init_cash(initCash), cash(initCash),
          tx_cost_pct(txCostPct), stop_loss_pct(stopLossPct),
          take_profit_pct(takeProfitPct) {}

    void update(const Signal& signal) {
        if (signal.price <= 0.0) return;
        last_price = signal.price;
        
        if (stats.is_initialized()) {
            stats.initialize(signal.timestamp, cash, signal.price);
        }

        check_stop_loss_take_profit(signal.price, signal.timestamp);
        process_signal(signal);
        
        stats.record_equity(signal.timestamp, compute_total_value(), signal.price);
    }

    friend std::ostream& operator<<(std::ostream& os,
            const BasicPortfolio& portfolio);
};

inline std::ostream& operator<<(std::ostream& os, const BasicPortfolio& portfolio) {
    double holdings = portfolio.get_holdings_value();
    double qty = portfolio.get_total_quantity();
    double total_value = portfolio.compute_total_value();
    
    portfolio.stats.print_summary(os, portfolio.cash, holdings, qty, total_value);
    
    return os;
}

} // namespace tzu

#endif // PORTFOLIOS_H
