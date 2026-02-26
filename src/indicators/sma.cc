#include "indicators.h"
#include <cmath>

SMA::SMA(size_t period, size_t size)
    : data(size), prev(period), pos(0), len(0), sum(0.0) {}

double SMA::update(double value) {
    if (len < prev.size())
        len++;
    else
        sum -= prev[pos];
    sum += value;
    prev[pos] = value;
    pos = (pos + 1) % prev.size();
    return data.update(len < prev.size() 
            ? std::nan("") 
            : sum / prev.size());
} 

double inline SMA::operator[](int index) {
    return data[index];
}

double inline SMA::get() {
    return data.get();
}

size_t inline SMA::size() {
    return data.size();
}
