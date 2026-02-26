#include "indicators.h"
#include <cmath>

namespace Ind {

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

} // namespace Ind
