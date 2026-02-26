#include <indicators.h>
#include <cmath>

namespace Ind {

template <size_t N>
double MVar<N>::update(double value) {
    if (len < size) len++;
    prev[pos] = value;
    pos = (pos + 1) % size;
    sma.update(value);
    if (len < size) {
        return std::nan("");
    } else {
        double accum = 0.0;
        for (size_t i = 0; i < size; i++) {
            double diff = prev[i] - sma.get();
            accum += diff * diff;
        }
        data = accum / (size - dof);
        return data;
    }
}

} // namespace Ind
