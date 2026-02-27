#include <iostream>
#include <string>
#include "tzu.h"

using namespace tzu;

int main(int argc, char** argv) {
    bool verbose = false;
    if (argc > 1 && std::string(argv[1]) == "-v") verbose = true;
    SimpleRunner<SimplePortfolio, RSIStrat<>, Csv<Ohlcv>> runner(std::cin);
    runner.run(verbose);
    return 0;
}
