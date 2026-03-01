#ifndef PORTFOLIOS_H
#define PORTFOLIOS_H

#include <cstdint>
#include <cmath>
#include <iostream>
#include <vector>
#include <iomanip>
#include <algorithm>
#include <numeric>
#include "defs.h"

namespace tzu {

template<class T>
class Portfolio {
public:
    void update(const T& signal) {
        static_cast<T*>(this)->update(signal);
    }
};

inline void compute_holdings_qty(const std::vector<Position>& positions, double last_price,
                                 double &out_holdings, double &out_qty) {
    out_holdings = 0.0;
    out_qty = 0.0;
    for (const auto &p : positions) {
        out_holdings += p.quantity * last_price;
        out_qty += p.quantity;
    }
}

inline double compute_total_value(double cash, double holdings) {
    return cash + holdings;
}

// Compute basic performance metrics from an equity curve (timestamp, equity)
inline void compute_performance_metrics(const std::vector<std::pair<int64_t, double>>& eq,
                                        double &out_total_return, double &out_annual_return,
                                        double &out_max_drawdown, double &out_sharpe,
                                        double &out_years) {
    out_total_return = out_annual_return = out_max_drawdown = out_sharpe = 0.0;
    if (eq.size() < 1) return;
    double start = eq.front().second;
    double end = eq.back().second;
    out_total_return = (end / start) - 1.0;

    double years = 0.0;
    if (eq.size() >= 2) {
        double seconds = static_cast<double>(eq.back().first - eq.front().first);
        years = seconds / (365.0 * 24.0 * 3600.0);
    }
    // Only compute annualized return for periods longer than 30 days.
    if (years >= (30.0/365.0)) {
        out_annual_return = std::pow(end / start, 1.0 / years) - 1.0;
    } else {
        out_annual_return = std::nan("");
    }

    out_years = years;

    // max drawdown
    double peak = eq.front().second;
    double max_dd = 0.0;
    for (const auto &p : eq) {
        if (p.second > peak) peak = p.second;
        double dd = (peak - p.second) / peak;
        if (dd > max_dd) max_dd = dd;
    }
    out_max_drawdown = max_dd;

    // Sharpe (assume risk-free 0), compute periodic returns
    if (eq.size() >= 2) {
        std::vector<double> rets;
        rets.reserve(eq.size() - 1);
        for (size_t i = 1; i < eq.size(); ++i) {
            double r = (eq[i].second / eq[i-1].second) - 1.0;
            rets.push_back(r);
        }
        double mean = std::accumulate(rets.begin(), rets.end(), 0.0) / rets.size();
        double var = 0.0;
        for (double r : rets) var += (r - mean) * (r - mean);
        var /= rets.size();
        double stddev = std::sqrt(var);
        double samples_per_year = 1.0;
        if (years > 0.0) samples_per_year = static_cast<double>(rets.size()) / years;
        if (stddev > 0.0) out_sharpe = (mean * std::sqrt(samples_per_year)) / stddev;
    }
}


/**
 * BasicPortfolio implements transaction costs and simple stop-loss /
 * take-profit policies. Transaction costs are expressed as a fraction
 * of the transaction value (e.g. 0.001 == 0.1%).  This porfolio uses
 * all available cash to buy as many units as possible at each buy
 * signal, and liquidates all positions at each sell signal. Stop-loss
 * and take-profit are checked at each update and positions are
 * liquidated if the price breaches the stop-loss or take-profit
 * thresholds.  Stop-loss and take-profit are fractions relative to the
 * acquisition price (e.g. 0.1 == 10%). By default transaction costs are
 * 0 and stop-loss / take-profit are NaN (disabled).
 */
class BasicPortfolio: public Portfolio<BasicPortfolio> {
    int64_t init_timestamp = 0;
    double init_cash;
    double cash;
    std::vector<Position> positions;
    // equity curve stored as (timestamp, equity)
    std::vector<std::pair<int64_t,double>> equity_curve;
    double tx_cost_pct;
    double stop_loss_pct;
    double take_profit_pct;
    double last_price = std::nan("");
    double init_price = std::nan(""); // price at start for buy&hold comparison
    double total_costs = 0.0;
    uint16_t num_trades = 0;
    uint16_t num_stop_loss = 0;
    uint16_t num_take_profit = 0;
    int64_t last_timestamp = 0;

    void liquidate_position_at(size_t i, double price) {
        const Position p = positions[i];
        double proceeds = p.quantity * price;
        double commission = proceeds * tx_cost_pct;
        total_costs += commission;
        cash += proceeds - commission;
        // remove by swapping with last
        positions[i] = positions.back();
        positions.pop_back();
    }

    void liquidate_all_at_price(double price) {
        for (const auto &p : positions) {
            double proceeds = p.quantity * price;
            double commission = proceeds * tx_cost_pct;
            total_costs += commission;
            cash += proceeds - commission;
        }
        positions.clear();
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
            // record initial equity (before processing this row)
            equity_curve.emplace_back(init_timestamp, cash);
        }
        // Check stop-loss and take-profit for existing positions
        for (size_t i = 0; i < positions.size();) {
            bool liquidate = false;
            const Position &p = positions[i];
            if (!std::isnan(stop_loss_pct)) {
                double stop_price = p.price * (1.0 - stop_loss_pct);
                if (signal.price <= stop_price) {
                    liquidate = true;
                    ++num_stop_loss;
                }
            }
            if (!liquidate && !std::isnan(take_profit_pct)) {
                double tp_price = p.price * (1.0 + take_profit_pct);
                if (signal.price >= tp_price) {
                    liquidate = true;
                    ++num_take_profit;
                }
            }
            if (liquidate) {
                liquidate_position_at(i, signal.price);
                ++num_trades;
            } else {
                ++i;
            }
        }
        // Process new signal
        if (signal.side == Side::BUY) {
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
        } else if (signal.side == Side::SELL) {
                liquidate_all_at_price(signal.price);
            ++num_trades;
        }
        // record equity after processing the signal
        double holdings, qty;
        compute_holdings_qty(positions, last_price, holdings, qty);
        double total_value = compute_total_value(cash, holdings);
        equity_curve.emplace_back(last_timestamp, total_value);
    }

    friend std::ostream& operator<<(std::ostream& os,
            const BasicPortfolio& portfolio);
};

inline std::ostream& operator<<(std::ostream& os,
        const BasicPortfolio& portfolio) {
    double holdings, qty;
    compute_holdings_qty(portfolio.positions, portfolio.last_price, holdings, qty);
    double total_value = compute_total_value(portfolio.cash, holdings);
    double profit_loss = total_value - portfolio.init_cash;
    os << std::fixed << std::setprecision(4)
        << "init_time:" << portfolio.init_timestamp
        << " curr_time:" << portfolio.last_timestamp
        << " init_cash:" <<  portfolio.init_cash
        << " curr_cash:" << portfolio.cash
        << " num_trades:" << portfolio.num_trades
        << " num_stop_loss:" << portfolio.num_stop_loss
        << " num_take_profit:" << portfolio.num_take_profit
        << " quantity:" << qty
        << " holdings:" << holdings
        << " valuation:" << total_value
        << " total_costs:" << portfolio.total_costs
        << " profit:" << profit_loss;

    // compute and print performance metrics
    double total_ret=0.0, ann_ret=0.0, max_dd=0.0, sharpe=0.0, years=0.0;
    compute_performance_metrics(portfolio.equity_curve, total_ret, ann_ret, max_dd, sharpe, years);
    os << " total_return:" << total_ret * 100.0 << "%";
    // only show annualized return when it was computed
    if (!std::isnan(ann_ret)) {
        os << " annual_return:" << ann_ret * 100.0 << "%";
    } else {
        os << " annual_return:N/A";
    }

    // buy-and-hold comparison
    if (!std::isnan(portfolio.init_price) && portfolio.init_price > 0.0) {
        double bh_qty = std::floor(portfolio.init_cash / portfolio.init_price);
        double bh_cash_left = portfolio.init_cash - (bh_qty * portfolio.init_price);
        double bh_value = bh_qty * portfolio.last_price + bh_cash_left;
        double bh_total_ret = (bh_value / portfolio.init_cash) - 1.0;
        os << " buy_and_hold_return:" << bh_total_ret * 100.0 << "%";
        if (!std::isnan(ann_ret)) {
            // annualize buy&hold using same years
            double bh_ann = std::pow(bh_value / portfolio.init_cash, 1.0 / years) - 1.0;
            os << " bh_annual:" << bh_ann * 100.0 << "%";
        }
    }

    os << " max_drawdown:" << max_dd * 100.0 << "%"
       << " sharpe:" << sharpe;
    return os;
}

} // namespace tzu

#endif // PORTFOLIOS_H
