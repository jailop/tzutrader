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
    int64_t init_timestamp = 0;
    double init_cash;
    double cash;
    std::vector<Position> positions;
    std::vector<std::pair<int64_t, double>> equity_curve;
    double tx_cost_pct;
    double stop_loss_pct;
    double take_profit_pct;
    double last_price = std::nan("");
    double init_price = std::nan("");
    double total_costs = 0.0;
    uint16_t num_trades = 0;
    uint16_t num_stop_loss = 0;
    uint16_t num_take_profit = 0;
    int64_t last_timestamp = 0;

    void liquidate_position_at(size_t i, double price) {
        double proceeds = positions[i].quantity * price;
        double commission = proceeds * tx_cost_pct;
        total_costs += commission;
        cash += proceeds - commission;
        positions[i] = positions.back();
        positions.pop_back();
    }

    void liquidate_all_at_price(double price) {
        for (const auto& p : positions) {
            double proceeds = p.quantity * price;
            double commission = proceeds * tx_cost_pct;
            total_costs += commission;
            cash += proceeds - commission;
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

    void check_stop_loss_take_profit(double current_price) {
        for (size_t i = 0; i < positions.size();) {
            bool should_liquidate = false;
            const Position& p = positions[i];
            
            if (!std::isnan(stop_loss_pct)) {
                double stop_price = p.price * (1.0 - stop_loss_pct);
                if (current_price <= stop_price) {
                    should_liquidate = true;
                    ++num_stop_loss;
                }
            }
            
            if (!should_liquidate && !std::isnan(take_profit_pct)) {
                double tp_price = p.price * (1.0 + take_profit_pct);
                if (current_price >= tp_price) {
                    should_liquidate = true;
                    ++num_take_profit;
                }
            }
            
            if (should_liquidate) {
                liquidate_position_at(i, current_price);
                ++num_trades;
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
            total_costs += commission;
            cash -= cost + commission;
            ++num_trades;
            positions.push_back(Position{signal.timestamp, qty, signal.price});
        }
    }

    void execute_sell(const Signal& signal) {
        liquidate_all_at_price(signal.price);
        ++num_trades;
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
        last_timestamp = signal.timestamp;
        
        if (init_timestamp == 0) {
            init_timestamp = signal.timestamp;
            init_price = signal.price;
            equity_curve.emplace_back(init_timestamp, cash);
        }

        check_stop_loss_take_profit(signal.price);
        process_signal(signal);
        
        equity_curve.emplace_back(last_timestamp, compute_total_value());
    }

    friend std::ostream& operator<<(std::ostream& os,
            const BasicPortfolio& portfolio);
};

inline std::ostream& operator<<(std::ostream& os, const BasicPortfolio& portfolio) {
    double holdings = portfolio.get_holdings_value();
    double qty = portfolio.get_total_quantity();
    double total_value = portfolio.compute_total_value();
    double profit_loss = total_value - portfolio.init_cash;
    
    os << std::fixed << std::setprecision(4)
        << "init_time:" << portfolio.init_timestamp
        << " curr_time:" << portfolio.last_timestamp
        << " init_cash:" << portfolio.init_cash
        << " curr_cash:" << portfolio.cash
        << " num_trades:" << portfolio.num_trades
        << " num_stop_loss:" << portfolio.num_stop_loss
        << " num_take_profit:" << portfolio.num_take_profit
        << " quantity:" << qty
        << " holdings:" << holdings
        << " valuation:" << total_value
        << " total_costs:" << portfolio.total_costs
        << " profit:" << profit_loss;

    PerformanceMetrics perf = compute_performance_metrics(portfolio.equity_curve);
    os << " total_return:" << perf.total_return;
    
    if (perf.has_annual_return) {
        os << " annual_return:" << perf.annual_return;
    } else {
        os << " annual_return:N/A";
    }

    BuyAndHoldMetrics bh = compute_buy_and_hold_metrics(
        portfolio.init_cash, portfolio.init_price, portfolio.last_price, perf.years);
    
    if (bh.valid) {
        os << " buy_and_hold_return:" << bh.total_return;
        if (bh.has_annual_return) {
            os << " buy_and_hold_annual:" << bh.annual_return;
        }
    }

    os << " max_drawdown:" << perf.max_drawdown
       << " sharpe:" << perf.sharpe_ratio;
    
    return os;
}

} // namespace tzu

#endif // PORTFOLIOS_H
