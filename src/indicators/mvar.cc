#include <indicators.h>
#include <cmath>

MVar::MVar(size_t period, size_t dof, size_t size)
    : data(size), sma(period), prev(period), pos(0), len(0), sum(0.0),
      dof(dof) {}

double MVar::update(double value) {
    if (len < prev.size()) len++;
    prev[pos] = value;
    pos = (pos + 1) % prev.size();
    sma.update(value);
    if (len < prev.size()) {
        return data.update(std::nan(""));
    } else {
        double accum = 0.0;
        for (size_t i = 0; i < prev.size(); i++) {
            double diff = prev[i] - sma.get();
            accum += diff * diff;
        }
        return data.update(accum / (prev.size() - dof));
    }
}

double inline MVar::operator[](int index) {
    return data[index];
}

double inline MVar::get() {
    return data.get();
}

size_t inline MVar::size() {
    return data.size();
}
