#ifndef STREAMERS_H
#define STREAMERS_H

#include <istream>
#include <string>
#include <sstream>
#include "defs.h"

// Traits for parsing different types from CSV
// Specialize for each supported type

template<typename T>
struct CsvParseTraits;

template<>
struct CsvParseTraits<OHLCV> {
    static bool parse(const std::string& line, OHLCV& out) {
        std::istringstream ss(line);
        char sep;
        int64_t ts;
        double o, h, l, c, v;
        if (ss >> ts >> sep >> o >> sep >> h >> sep >> l >> sep >> c >> sep >> v) {
            out = OHLCV(ts, o, h, l, c, v);
            return true;
        }
        return false;
    }
};

template<>
struct CsvParseTraits<Tick> {
    static bool parse(const std::string& line, Tick& out) {
        std::istringstream ss(line);
        char sep;
        int64_t ts;
        double price, volume;
        int side = 2; // NONE
        if (ss >> ts >> sep >> price >> sep >> volume >> sep >> side) {
            out = Tick{ts, price, volume, static_cast<Side>(side)};
            return true;
        }
        return false;
    }
};

template<>
struct CsvParseTraits<SingleValue> {
    static bool parse(const std::string& line, SingleValue& out) {
        std::istringstream ss(line);
        char sep;
        int64_t ts;
        double value;
        if (ss >> ts >> sep >> value) {
            out = SingleValue{ts, value};
            return true;
        }
        return false;
    }
};

template<typename T>
class Csv {
    std::istream& input_;
public:
    explicit Csv(std::istream& input) : input_(input) {}

    class Iterator {
        std::istream* input_;
        T current_;
        bool end_ = false;
    public:
        Iterator(std::istream* input, bool end = false)
            : input_(input), end_(end) {
            if (!end_) ++(*this);
        }

        Iterator& operator++() {
            std::string line;
            while (std::getline(*input_, line)) {
                if (CsvParseTraits<T>::parse(line, current_)) {
                    return *this;
                }
            }
            end_ = true;
            return *this;
        }

        const T& operator*() const { return current_; }
        const T* operator->() const { return &current_; }
        bool operator==(const Iterator& other) const { return end_ == other.end_; }
        bool operator!=(const Iterator& other) const { return !(*this == other); }

    };

    Iterator begin() { return Iterator(&input_); }
    Iterator end() { return Iterator(&input_, true); }

};

#endif // STREAMERS_H
