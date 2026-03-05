/**
 * Example using tzutrader MDD (Maximum Drawdown) indicator.
 * This example reads a CSV file containing timestamped price data,
 * updates the MDD indicator with each price, and prints the maximum
 * drawdown whenever it decreases.
 */

#include <tzu.h>
#include <fstream>

const char* datafile = "./tests/data/btcusd_singlevalue.csv";

int main() {
    std::ifstream file(datafile);
    if (!file.is_open()) {
        std::cerr << "Failed to open file: " << datafile << std::endl;
        return 1;
    }
    bool first_line = true;
    tzu::MDD mdd;
    tzu::Csv<tzu::SingleValue> csv(file);
    double previous_value = 0.0;
    std::cout << std::setw(19) << "Time" << " " << "MaxDrawDown" << std::endl;
    for (const auto& point : csv) {
        if (first_line) {
            first_line = false;
            continue;
        }
        double current_value = mdd.update(point.value);
        if (current_value < previous_value) {
            std::cout
                << tzu::unixTimeToString(point.timestamp) << " "
                << current_value << std::endl;
            previous_value = current_value;
        }
    }
    return 0;
}

