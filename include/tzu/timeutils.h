#ifndef _TIMEUTILS_H
#define _TIMEUTILS_H

#include "defs.h"
#include <string>

namespace tzu {

/**
 * Convert a unix time to a string representation.
 * Unix time is represented as an integer that can represent seconds or 
 * fractions of seconds.
 */
std::string unixTimeToString(int64_t unixTime,
        TimeInterval interval = TimeInterval::SECONDS, bool local_time = false);

} // namespace tzu

#endif // _TIMEUTILS_H
