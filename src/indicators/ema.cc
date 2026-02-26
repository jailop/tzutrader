#include "indicators.h"
#include <cmath>

EMA::EMA(size_t period, double smoothing, size_t size)
    : data(size), alpha(smoothing / (period + 1.0)), prev(0.0), len(0),
      period(period) {}

double EMA::update(double value) {
    len++;
    if (len <= period) {
        prev += value;
    } else if (len == period){
        prev += value;
        prev /= period;
    } else {
        prev = (value * alpha) + (prev * (1.0 - alpha));
    }
    return data.update(len < period ? std::nan("") : prev);
}

double inline EMA::operator[](int index) {
    return data[index];
}

double inline EMA::get() {
    return data.get();
}

size_t inline EMA::size() {
    return data.size();
}
