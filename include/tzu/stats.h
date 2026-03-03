#ifndef STATS_H
#define STATS_H

#include <cstdint>
#include <cmath>
#include <vector>
#include <algorithm>
#include <numeric>

namespace tzu {

/**
 * Trade record for tracking individual trades.
 */
struct Trade {
    int64_t open_time = 0;
    int64_t close_time = 0;
    double open_price = 0.0;
    double close_price = 0.0;
    double quantity = 0.0;
    double profit = 0.0;
    bool closed = false;
    
    Trade() = default;
    Trade(int64_t ot, int64_t ct, double op, double cp, double q, double p, bool c)
        : open_time(ot), close_time(ct), open_price(op), close_price(cp),
          quantity(q), profit(p), closed(c) {}
};

/**
 * Portfolio performance metrics computed from equity curve and trade history.
 */
struct PerformanceMetrics {
    double total_return = 0.0;
    double annual_return = 0.0;
    double max_drawdown = 0.0;
    double sharpe_ratio = 0.0;
    double years = 0.0;
    bool has_annual_return = false;
};

/**
 * Buy-and-hold benchmark metrics for comparison.
 */
struct BuyAndHoldMetrics {
    double quantity = 0.0;
    double cash_left = 0.0;
    double final_value = 0.0;
    double total_return = 0.0;
    double annual_return = 0.0;
    bool has_annual_return = false;
    bool valid = false;
};

/**
 * Portfolio statistics tracker.
 */
class PortfolioStats {
private:
    int64_t init_timestamp = 0;
    int64_t last_timestamp = 0;
    double init_cash = 0.0;
    double init_price = std::nan("");
    double last_price = std::nan("");
    std::vector<std::pair<int64_t, double>> equity_curve;
    std::vector<Trade> trades;
    uint16_t num_trades = 0;
    uint16_t num_stop_loss = 0;
    uint16_t num_take_profit = 0;
    double total_costs = 0.0;

public:
    void initialize(int64_t timestamp, double cash, double price) {
        init_timestamp = timestamp;
        last_timestamp = timestamp;
        init_cash = cash;
        init_price = price;
        last_price = price;
        equity_curve.emplace_back(timestamp, cash);
    }

    bool is_initialized() const {
        return init_timestamp == 0;
    }

    void record_equity(int64_t timestamp, double total_value, double price) {
        last_timestamp = timestamp;
        last_price = price;
        equity_curve.emplace_back(timestamp, total_value);
    }

    void record_trade_open(int64_t timestamp, double quantity, double price) {
        trades.push_back(Trade{timestamp, 0, price, 0.0, quantity, 0.0, false});
    }

    void record_trade_close(int64_t timestamp, double quantity, double open_price, 
                           double close_price, double profit, bool is_stop_loss, 
                           bool is_take_profit) {
        if (is_stop_loss) ++num_stop_loss;
        if (is_take_profit) ++num_take_profit;
        
        Trade trade{0, timestamp, open_price, close_price, quantity, profit, true};
        trades.push_back(trade);
    }

    void increment_trades() {
        ++num_trades;
    }

    void add_costs(double cost) {
        total_costs += cost;
    }

    uint16_t get_num_wins() const {
        uint16_t wins = 0;
        for (const auto& trade : trades) {
            if (trade.closed && trade.profit > 0) ++wins;
        }
        return wins;
    }

    uint16_t get_num_losses() const {
        uint16_t losses = 0;
        for (const auto& trade : trades) {
            if (trade.closed && trade.profit <= 0) ++losses;
        }
        return losses;
    }

    double get_win_rate() const {
        uint16_t wins = get_num_wins();
        uint16_t losses = get_num_losses();
        uint16_t total = wins + losses;
        return total > 0 ? static_cast<double>(wins) / total : 0.0;
    }

    void print_summary(std::ostream& os, double curr_cash, double holdings, 
                      double qty, double total_value) const;
};

/**
 * Compute maximum drawdown from an equity curve.
 */
inline double compute_max_drawdown(const std::vector<std::pair<int64_t, double>>& equity_curve) {
    if (equity_curve.empty()) return 0.0;
    
    double peak = equity_curve.front().second;
    double max_dd = 0.0;
    for (const auto& point : equity_curve) {
        if (point.second > peak) peak = point.second;
        double dd = (peak - point.second) / peak;
        if (dd > max_dd) max_dd = dd;
    }
    return max_dd;
}

/**
 * Compute Sharpe ratio from periodic returns.
 * Assumes risk-free rate of 0.
 * Returns annualized Sharpe ratio.
 */
inline double compute_sharpe_ratio(const std::vector<double>& returns, double years) {
    if (returns.size() < 2 || years <= 0.0) return 0.0;
    
    size_t n = returns.size();
    double mean = std::accumulate(returns.begin(), returns.end(), 0.0) / n;
    
    double var = 0.0;
    for (double r : returns) {
        var += (r - mean) * (r - mean);
    }
    var /= (n - 1);
    double stddev = std::sqrt(var);
    
    if (stddev <= 0.0) return 0.0;
    
    double periods_per_year = static_cast<double>(n) / years;
    return (mean / stddev) * std::sqrt(periods_per_year);
}

/**
 * Extract periodic returns from equity curve.
 */
inline std::vector<double> compute_returns(const std::vector<std::pair<int64_t, double>>& equity_curve) {
    std::vector<double> returns;
    if (equity_curve.size() < 2) return returns;
    
    returns.reserve(equity_curve.size() - 1);
    for (size_t i = 1; i < equity_curve.size(); ++i) {
        double r = (equity_curve[i].second / equity_curve[i-1].second) - 1.0;
        returns.push_back(r);
    }
    return returns;
}

/**
 * Compute performance metrics from an equity curve.
 */
inline PerformanceMetrics compute_performance_metrics(
    const std::vector<std::pair<int64_t, double>>& equity_curve) {
    
    PerformanceMetrics metrics;
    if (equity_curve.empty()) return metrics;
    
    double start_value = equity_curve.front().second;
    double end_value = equity_curve.back().second;
    metrics.total_return = (end_value / start_value) - 1.0;
    
    // Compute time period in years
    if (equity_curve.size() >= 2) {
        double seconds = static_cast<double>(
            equity_curve.back().first - equity_curve.front().first);
        metrics.years = seconds / (365.0 * 24.0 * 3600.0);
    }
    
    // Annualized return only for periods > 30 days
    const double min_period_years = 30.0 / 365.0;
    if (metrics.years >= min_period_years) {
        metrics.annual_return = std::pow(end_value / start_value, 1.0 / metrics.years) - 1.0;
        metrics.has_annual_return = true;
    }
    
    // Maximum drawdown
    metrics.max_drawdown = compute_max_drawdown(equity_curve);
    
    // Sharpe ratio
    if (equity_curve.size() >= 2) {
        std::vector<double> returns = compute_returns(equity_curve);
        metrics.sharpe_ratio = compute_sharpe_ratio(returns, metrics.years);
    }
    
    return metrics;
}

/**
 * Compute buy-and-hold benchmark metrics.
 */
inline BuyAndHoldMetrics compute_buy_and_hold_metrics(
    double init_cash, double init_price, double final_price, double years) {
    
    BuyAndHoldMetrics metrics;
    
    if (std::isnan(init_price) || init_price <= 0.0 || 
        std::isnan(final_price) || final_price <= 0.0) {
        return metrics;
    }
    
    metrics.quantity = std::floor(init_cash / init_price);
    metrics.cash_left = init_cash - (metrics.quantity * init_price);
    metrics.final_value = metrics.quantity * final_price + metrics.cash_left;
    metrics.total_return = (metrics.final_value / init_cash) - 1.0;
    
    const double min_period_years = 30.0 / 365.0;
    if (years >= min_period_years) {
        metrics.annual_return = std::pow(metrics.final_value / init_cash, 1.0 / years) - 1.0;
        metrics.has_annual_return = true;
    }
    
    metrics.valid = true;
    return metrics;
}

inline void PortfolioStats::print_summary(std::ostream& os, double curr_cash, double holdings, 
                                         double qty, double total_value) const {
    double profit_loss = total_value - init_cash;
    
    os << std::fixed << std::setprecision(4)
        << "init_time:" << init_timestamp
        << " curr_time:" << last_timestamp
        << " init_cash:" << init_cash
        << " curr_cash:" << curr_cash
        << " num_trades:" << num_trades
        << " num_closed:" << (get_num_wins() + get_num_losses())
        << " num_wins:" << get_num_wins()
        << " num_losses:" << get_num_losses()
        << " win_rate:" << get_win_rate()
        << " num_stop_loss:" << num_stop_loss
        << " num_take_profit:" << num_take_profit
        << " quantity:" << qty
        << " holdings:" << holdings
        << " valuation:" << total_value
        << " total_costs:" << total_costs
        << " profit:" << profit_loss;

    PerformanceMetrics perf = compute_performance_metrics(equity_curve);
    double adjusted_total_return = (total_value / init_cash) - 1.0;
    double adjusted_annual_return = 0.0;
    bool has_adjusted_annual_return = false;
    
    const double min_period_years = 30.0 / 365.0;
    if (perf.years >= min_period_years) {
        adjusted_annual_return = std::pow(total_value / init_cash, 1.0 / perf.years) - 1.0;
        has_adjusted_annual_return = true;
    }
    
    os << " total_return:" << adjusted_total_return;
    
    if (has_adjusted_annual_return) {
        os << " annual_return:" << adjusted_annual_return;
    } else {
        os << " annual_return:N/A";
    }

    BuyAndHoldMetrics bh = compute_buy_and_hold_metrics(
        init_cash, init_price, last_price, perf.years);
    
    if (bh.valid) {
        os << " buy_and_hold_return:" << bh.total_return;
        if (bh.has_annual_return) {
            os << " buy_and_hold_annual:" << bh.annual_return;
        }
    }

    os << " max_drawdown:" << perf.max_drawdown
       << " sharpe:" << perf.sharpe_ratio;
}

} // namespace tzu

#endif // STATS_H
