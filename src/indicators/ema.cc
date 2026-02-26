#include "indicators.h"
#include <cmath>

double Ind::EMA::update(double value) {
    len++;
    if (len <= period) {
        prev += value;
    } else if (len == period){
        prev += value;
        prev /= period;
    } else {
        prev = (value * alpha) + (prev * (1.0 - alpha));
    }
    data = len < period ? std::nan("") : prev;
    return data;
}
