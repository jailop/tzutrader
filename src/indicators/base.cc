#include "indicators.h"
#include <stdexcept>

namespace Ind {

template <typename T>
T Ind::BaseIndicator<T>::update(T value) {
    pos = (pos + 1) % data.size();
    data[pos] = value;
    return value;
}

template <typename T>
T Ind::BaseIndicator<T>::operator[](int index) const {
    if (index > 0 || static_cast<size_t>(-index) > data.size())
        throw std::out_of_range("Index out of range");
    return data[(pos + data.size() + index) % data.size()];
}

template <typename T>
T Ind::BaseIndicator<T>::get() const noexcept {
    return data[pos];
}

} // namespace Ind
