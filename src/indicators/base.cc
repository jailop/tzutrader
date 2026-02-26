#include "indicators.h"
#include <stdexcept>

template <typename T>
BaseIndicator<T>::BaseIndicator(size_t size) : data(size), pos(0) {}

template <typename T>
T BaseIndicator<T>::update(T value) {
    pos = (pos + 1) % data.size();
    data[pos] = value;
    return value;
}

template <typename T>
T BaseIndicator<T>::operator[](int index) {
    if (index > 0 || -index > data.size())
        throw std::out_of_range("Index out of range");
    return data[(pos + data.size() + index) % data.size()];
}

template <typename T>
T inline BaseIndicator<T>::get() {
    return data[pos];
}

template <typename T>
size_t inline BaseIndicator<T>::size() {
    return data.size();
}
