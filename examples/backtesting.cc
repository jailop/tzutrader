// Example backtesting runner
// Compiles with:
//   g++ -std=c++17 -I./include examples/backtesting.cc -o examples/backtesting
// Usage:
//   cat tests/data/btcusd.csv | ./examples/backtesting [-v]

#include <iostream>
#include <string>
#include "tzu.h"

using namespace tzu;

int main(int argc, char** argv) {
    bool verbose = false;
    if (argc > 1 && std::string(argv[1]) == "-v") verbose = true;

    SimpleRunner<RSIStrat<>, SimplePortfolio, Csv<Ohlcv>> runner(std::cin);
    runner.run(verbose);
    return 0;
}
