## Data Streamers - Base Interface
##
## This module defines the base DataStreamer interface that all
## provider-specific streamers implement.

import ./types

type
  DataStreamer*[T] = ref object of RootObj
    ## Generic streaming interface for data type T
    ## All provider-specific streamers inherit from this
    symbol*: string            # Symbol being streamed

# Core streaming methods
# Note: These use method dispatch without generic parameters to avoid deprecation warnings
# Subclasses override these for their specific types (e.g., YahooStreamer[OHLCV])

method next*[T](streamer: DataStreamer[T]): bool {.base.} =
  ## Advance to next item in stream
  ## Returns true if successful, false if end of stream
  ## This is the PRIMARY method that all streamers must implement
  false

method reset*[T](streamer: DataStreamer[T]) {.base.} =
  ## Reset stream to beginning
  discard

method len*[T](streamer: DataStreamer[T]): int {.base.} =
  ## Total number of items in stream (if known)
  ## Returns -1 if unknown (e.g., live streaming)
  -1

method hasNext*[T](streamer: DataStreamer[T]): bool {.base.} =
  ## Check if more data is available
  ## Default: assume more data is available
  true

# current() is implemented as procs in each streamer subclass
# We can't have a generic method, so each concrete type must define:
#   proc current*(stream: ConcreteStreamer[T]): T

# Note: The items() iterator is defined in the api module where
# all concrete streamer types are imported

# Convenience methods built on core methods

proc toSeq*[T](streamer: DataStreamer[T]): seq[T] =
  ## Convenience: Consume entire stream into a sequence
  ## 
  ## WARNING: This defeats the purpose of streaming for large datasets!
  ## Only use for small datasets or when you truly need random access.
  ## For large datasets, use the iterator interface instead.
  result = @[]
  for item in streamer.items():
    result.add(item)

# String representation
proc `$`*[T](streamer: DataStreamer[T]): string =
  ## String representation of data streamer
  result = "DataStreamer[" & $T & "]("
  result.add "symbol=" & streamer.symbol
  let length = streamer.len()
  if length >= 0:
    result.add ", len=" & $length
  result.add ")"
