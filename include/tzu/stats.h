#ifndef STATS_H
#define STATS_H

#include <cstdint>
#include <cmath>
#include <vector>
#include <algorithm>
#include <numeric>

namespace tzu {

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

} // namespace tzu

#endif // STATS_H
