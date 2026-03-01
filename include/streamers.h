/**
 * This file defines data streamers. It is designed to be extensible by
 * having specific parser traits for each data type, iterators that read
 * from streams and parse lines, and simple reader classes that
 * integrate these components, like the `Csv` class reader.
 *
 * Note: Error handling is currently minimal. If a line fails to parse,
 * it is simply skipped and a warning is printed to standard error. It
 * is expected that the input is well-formed, being validated by a
 * pre-processing step, which is out of scope for this module.
 *
 * (C) 2026 Jaime Lopez <https://codeberg.org/jailop>
 */

#ifndef STREAMERS_H
#define STREAMERS_H

#include <istream>
#include <iostream>
#include <array>
#include <cstring>
#include "defs.h"

namespace tzu {

// trade-off: we work with a fixed-size buffer for line parsing
// to avoid dynamic memory allocation. This should be sufficient for
// typical CSV lines in financial data.
constexpr size_t MAX_BUFFER_SIZE = 2048;

/**
 * A traits class to parse a line of CSV into a specific data type.
 * Specialize this for each data type defined in `defs.h` you want to
 * parse from CSV.
 */
template<typename T>
struct CsvParseTraits;

/**
 * Specialization for Ohlcv data. Expects lines in the format:
 * timestamp,open,high,low,close,volume
 */
template<>
struct CsvParseTraits<Ohlcv> {
    static bool parse(const char* line_buffer, Ohlcv& out) {
        char* end;
        int64_t ts = std::strtol(line_buffer, &end, 10);
        double o = std::strtod(end, &end);
        double h = std::strtod(end, &end);
        double l = std::strtod(end, &end);
        double c = std::strtod(end, &end);
        double v = std::strtod(end, &end);
        if (*end != '\0' && *end != '\n') return false;
        out = Ohlcv(ts, o, h, l, c, v);
        return true;
    }
};

/**
 * Specialization for Tick data. Expects lines in the format:
 * timestamp,price,volume,side
 */
template<>
struct CsvParseTraits<Tick> {
    static bool parse(const char* line_buffer, Tick& out) {
        char* end;
        int64_t ts = std::strtol(line_buffer, &end, 10);
        double price = std::strtod(end, &end);
        double volume = std::strtod(end, &end);
        Side side = static_cast<Side>(std::strtol(end, &end, 10));
        if (*end != '\0' && *end != '\n') return false;
        out = Tick{ts, price, volume, static_cast<Side>(side)};
        return true;
    }
};

/**
 * Specialization for SingleValue data. Expects lines in the format:
 * timestamp,value
 */
template<>
struct CsvParseTraits<SingleValue> {
    static bool parse(const char* line_buffer, SingleValue& out) {
        char* end;
        int64_t ts = std::strtol(line_buffer, &end, 10);
        double value = std::strtod(end, &end);
        if (*end != '\0' && *end != '\n') return false;
        out = SingleValue{ts, value};
        return true;
    }
};

/**
 * An text input iterator that reads lines from a stream and parses them
 * into a specific data type.
 */
template<typename T, typename Parser>
class ParseIterator {
    std::istream* input_;
    T current_;
    bool end_ = false;
public:
    /**
     * Constructs an iterator that reads from the given input stream.
     * If `end` is true, constructs an end iterator.
     */
    ParseIterator(std::istream* input, bool end = false)
        : input_(input), end_(end) {
        if (!end_) { ++(*this); }
    }

    /**
     * Advances the iterator to the next valid line in the input stream.
     * Lines that fail to parse are skipped. If the end of the stream is
     * reached, sets the end flag.
     */
    ParseIterator& operator++() {
        std::array<char, MAX_BUFFER_SIZE> line_buffer;
        while (!end_ && 
                input_->getline(
                    line_buffer.data(),
                    static_cast<std::streamsize>(line_buffer.size()))) {
            char* buf = line_buffer.data();
            size_t len = std::strlen(buf);
            while (len > 0 && (buf[len - 1] == '\r' || buf[len - 1] == '\n')) {
                buf[--len] = '\0';
            }
            // Replace commas with spaces so numeric parsers using
            // strtod/strtol work as expected
            for (size_t i = 0; i < len; ++i) {
                if (buf[i] == ',') buf[i] = ' ';
            }
            if (Parser::parse(buf, current_)) {
                return *this;
            }
        }
        end_ = true;
        return *this;
    }
    
    /**
     * Dereferences the iterator to access the current parsed value. The
     * behavior is undefined if the iterator is at the end.
     */
    const T& operator*() const { return this->current_; }
    
    /**
     * Provides pointer-like access to the current parsed value. The
     * behavior is undefined if the iterator is at the end.
     */
    const T* operator->() const { return &(this->current_); }
    
    /**
     * Compares two iterators for equality. Two iterators are considered
     * equal if they are both end iterators or if they point to the same
     * position in the input stream.
     */
    bool operator==(const ParseIterator& other) const {
        return end_ == other.end_;
    }
    
    /**
     * Compares two iterators for inequality.
     */
    bool operator!=(const ParseIterator& other) const {
        return !(*this == other);
    }
};

/**
 * A simple CSV reader that provides an iterable interface to parse lines
 * from a stream into a specific data type. It uses the `CsvParseTraits`
 * specialization for the given type to perform the parsing.
 */
template<typename T>
class Csv {
    std::istream& input_;
    bool has_headers_;
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

} // namespace tzu

#endif // STREAMERS_H
