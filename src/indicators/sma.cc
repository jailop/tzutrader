#include "indicators.h"
#include <cmath>

namespace Ind {

template <size_t N>
double SMA<N>::update(double value) {
    if (len < prev.size())
        len++;
    else
        sum -= prev[pos];
    sum += value;
    prev[pos] = value;
    pos = (pos + 1) % prev.size();
    data = len < prev.size() 
            ? std::nan("") 
            : sum / prev.size();
    return data;
} 

} // namespace Ind
