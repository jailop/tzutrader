#ifndef STREAMERS_H
#define STREAMERS_H

#include <istream>
#include <iostream>
#include <array>
#include "defs.h"

constexpr size_t MAX_BUFFER_SIZE = 2048;

template<typename T>
struct CsvParseTraits;

template<>
struct CsvParseTraits<OHLCV> {
    static bool parse(const char* line_buffer, OHLCV& out) {
        char* end;
        int64_t ts = std::strtol(line_buffer, &end, 10);
        double o = std::strtod(end, &end);
        double h = std::strtod(end, &end);
        double l = std::strtod(end, &end);
        double c = std::strtod(end, &end);
        double v = std::strtod(end, &end);
        if (*end != '\0' && *end != '\n') return false;
        out = OHLCV(ts, o, h, l, c, v);
        return true;
    }
};

template<>
struct CsvParseTraits<Tick> {
    static bool parse(const char* line_buffer, Tick& out) {
        char* end;
        int64_t ts = std::strtol(line_buffer, &end, 10);
        double price = std::strtod(end, &end);
        double volume = std::strtod(end, &end);
        int side = (*end != '\0') ? std::strtol(end, nullptr, 10) : 2;
        if (*end != '\0' && *end != '\n') return false;
        out = Tick{ts, price, volume, static_cast<Side>(side)};
        return true;
    }
};

template<>
struct CsvParseTraits<SingleValue> {
    static bool parse(const char* line_buffer, SingleValue& out) {
        char* end;
        int64_t ts = std::strtol(line_buffer, &end, 10);
        double value = std::strtod(end, nullptr);
        if (*end != '\0' && *end != '\n') return false;
        out = SingleValue{ts, value};
        return true;
    }
};

template<typename T, typename Parser>
class ParseIterator {
    std::istream* input_;
    T current_;
    bool end_ = false;
public:
    ParseIterator(std::istream* input, bool end = false)
        : input_(input), end_(end) {
        if (!end_) { ++(*this); }
    }
    ParseIterator& operator++() {
        std::array<char, MAX_BUFFER_SIZE> line_buffer;
        while (!end_ && input_->getline(line_buffer.data(), line_buffer.size())) {
            while (!line_buffer.empty() 
                    && (line_buffer.back() == '\r'
                        || line_buffer.back() == '\n')) {
                line_buffer[line_buffer.size() - 1] = '\0';
            }
            if (Parser::parse(line_buffer.data(), current_)) {
                return *this;
            }
        }
        end_ = true;
        return *this;
    }
    const T& operator*() const { return this->current_; }
    const T* operator->() const { return &(this->current_); }
    bool operator==(const ParseIterator& other) const {
        return end_ == other.end_;
    }
    bool operator!=(const ParseIterator& other) const {
        return !(*this == other);
    }
};

template<typename T>
class Csv {
    bool has_headers_;
    std::istream& input_;
public:
    explicit Csv(std::istream& input, bool has_headers = true)
            : input_(input), has_headers_(has_headers) {
        if (has_headers_) {
            std::string header_line;
            std::getline(input_, header_line);
        }
    }
    using Iterator = ParseIterator<T, CsvParseTraits<T>>;
    Iterator begin() { return Iterator(&input_); }
    Iterator end() { return Iterator(&input_, true); }
};

#endif // STREAMERS_H
