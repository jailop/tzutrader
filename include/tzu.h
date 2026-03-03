/**
 * @file tzu.h
 * @brief Main header file for the tzutrader library
 * 
 * Include this header to access all components of the tzutrader backtesting library.
 * 
 * @section intro_sec Introduction
 * 
 * tzutrader is a composable C++ backtesting library that processes market data
 * in a streaming fashion. The library is designed around small, focused components
 * that can be combined to create custom backtesting systems.
 * 
 * @section components_sec Core Components
 * 
 * - **Data Types** (defs.h): Fundamental structures like Ohlcv, Signal, Tick
 * - **Indicators** (indicators.h): SMA, EMA, RSI, MACD, and more
 * - **Strategies** (strategies.h): Trading signal generation
 * - **Portfolios** (portfolios.h): Position and risk management
 * - **Streamers** (streamers.h): Data input and parsing
 * - **Runners** (runners.h): Backtest orchestration
 * 
 * @section example_sec Quick Example
 * 
 * @code
 * #include "tzu.h"
 * using namespace tzu;
 * 
 * int main() {
 *     RSIStrat strategy(14, 30, 70);
 *     BasicPortfolio portfolio(100000.0, 0.001, 0.10, 0.20);
 *     Csv<Ohlcv> csv(std::cin);
 *     
 *     BasicRunner<BasicPortfolio, RSIStrat, Csv<Ohlcv>> runner(
 *         portfolio, strategy, csv
 *     );
 *     runner.run(false);
 *     return 0;
 * }
 * @endcode
 * 
 * @section links_sec Links
 * 
 * - User Guide: https://jailop.codeberg.page/tzutrader/docs/
 * - API Reference: https://jailop.codeberg.page/tzutrader/docs/html/
 * - Repository: https://codeberg.org/jailop/tzutrader
 * 
 * @note This is an experimental project. The API may change as the design evolves.
 * 
 * @author Jaime Lopez
 * @copyright 2026
 */

#ifndef TZU_H
#define TZU_H

#include "tzu/runners.h"

#endif // TZU_H
