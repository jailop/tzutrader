#include <indicators.h>
#include <cmath>

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
