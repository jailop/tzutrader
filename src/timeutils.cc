#include <stdexcept>
#include <ctime>
#include <sstream>
#include <iomanip>
#include "tzu/timeutils.h"

namespace tzu {

std::string unixTimeToString(int64_t unixTime, TimeInterval interval,
        bool local_time) {
    switch (interval) {
        case TimeInterval::SECONDS:
            break;
        case TimeInterval::MILLISECONDS:
            unixTime /= 1000;
            break;
        case TimeInterval::MICROSECONDS:
            unixTime /= 1000000;
            break;
        case TimeInterval::NANOSECONDS:
            unixTime /= 1000000000;
            break;
        default:
            throw std::invalid_argument("Invalid time interval");
    }
    std::tm* tm = local_time ? std::localtime(&unixTime) :
        std::gmtime(&unixTime);
    std::ostringstream ss;
    ss << std::put_time(tm, "%Y-%m-%d %H:%M:%S");
    return ss.str();
}

} // namespace tzu
