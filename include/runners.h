#ifndef RUNNERS_H
#define RUNNERS_H

#include "strategies.h"
#include "portfolios.h"
#include "streamers.h"

namespace tzu {

template <typename Strat, typename Portfolio, typename Streamer>
class SimpleRunner {
    Strat strat;
    Portfolio portfolio;
    Streamer streamer;
public:
    SimpleRunner(std::istream& input) : streamer(input) {}
    void run(bool verbose = false) {
        for (const auto& row : streamer) {
            auto sig = strat.update(row);
            if (sig.side != Side::NONE) {
                portfolio.update(sig);
                if (verbose)
                    std::cout << portfolio << std::endl;
            }
        }
        if (!verbose)
            std::cout << portfolio << std::endl;
    }
};

} // namespace tzu

#endif // RUNNERS_H
