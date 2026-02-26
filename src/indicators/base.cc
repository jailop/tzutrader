#include "indicators.h"
#include <stdexcept>

template <typename T>
T BaseIndicator<T>::update(T value) {
    pos = (pos + 1) % data.size();
    data[pos] = value;
    return value;
}

template <typename T>
T BaseIndicator<T>::operator[](int index) const {
    if (index > 0 || static_cast<size_t>(-index) > data.size())
        throw std::out_of_range("Index out of range");
    return data[(pos + data.size() + index) % data.size()];
}

template <typename T>
T inline BaseIndicator<T>::get() const noexcept {
    return data[pos];
}
