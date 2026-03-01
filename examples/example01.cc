#include <iostream>
#include <string>
#include <utility>
#include "tzu.h"

using namespace tzu;

int main(int argc, char** argv) {
    bool verbose = (argc > 1 && std::string(argv[1]) == "-v");
    RSIStrat strat;
    BasicPortfolio portfolio(
        100000.0,   // initial capital
        0.001,      // trading fee 0.1%,
        0.10,       // stop-loss 10%
        0.20        // take-profit 20%
     );
    Csv<Ohlcv> csv(std::cin);
    BasicRunner<BasicPortfolio, RSIStrat, Csv<Ohlcv>> runner(
            std::move(portfolio),
            std::move(strat),
            std::move(csv));
    runner.run(verbose);
    return 0;
}
