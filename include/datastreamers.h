#pragma once
#include <istream>
#include <string>
#include <sstream>
#include "defs.h"

class CSVOhlcv {
public:
    explicit CSVOhlcv(std::istream& input) : input_(input) {}

    class Iterator {
    public:
        Iterator(std::istream* input, bool end = false)
            : input_(input), end_(end) {
            if (!end_) ++(*this);
        }

        Iterator& operator++() {
            std::string line;
            while (std::getline(*input_, line)) {
                if (parseLine(line, current_)) {
                    return *this;
                }
            }
            end_ = true;
            return *this;
        }

        const OHLCV& operator*() const { return current_; }
        const OHLCV* operator->() const { return &current_; }
        bool operator==(const Iterator& other) const { return end_ == other.end_; }
        bool operator!=(const Iterator& other) const { return !(*this == other); }

    private:
        std::istream* input_;
        OHLCV current_;
        bool end_ = false;

        static bool parseLine(const std::string& line, OHLCV& out) {
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

    Iterator begin() { return Iterator(&input_); }
    Iterator end() { return Iterator(&input_, true); }

private:
    std::istream& input_;
};
