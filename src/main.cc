#include <fstream>
#include <iostream>
#include "tzu.h"

using namespace tzu;

int main() {
    std::ifstream inputFile("./tests/data/btcusd.csv");
    if (!inputFile.is_open()) {
        std::cerr << "Failed to open the file." << std::endl;
        return 1;
    }
    Csv<Ohlcv> csv(inputFile);
    for (const auto& record : csv) {
        std::cout << "Timestamp: " << record.timestamp
                    << ", Open: " << record.open
                    << ", High: " << record.high
                    << ", Low: " << record.low
                    << ", Close: " << record.close
                    << ", Volume: " << record.volume << std::endl;
    }
    return 0;
}
