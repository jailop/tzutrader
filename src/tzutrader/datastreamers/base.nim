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
# Note: These are implemented in the api module with dynamic dispatch
# Each concrete streamer type implements their own version:
#   proc next*(stream: ConcreteStreamer[T]): bool
#   proc reset*(stream: ConcreteStreamer[T])
#   proc len*(stream: ConcreteStreamer[T]): int
#   proc current*(stream: ConcreteStreamer[T]): T
#
# The api module provides generic versions that dispatch to concrete types.

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
