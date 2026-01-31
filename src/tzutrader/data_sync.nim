## Stream Synchronization Utilities
## 
## This module provides utilities for synchronizing multiple data streams
## with potentially different timestamps and frequencies.
##
## Synchronization Strategies:
## - ssAlign: Emit only when ALL streams have data at the same timestamp (strict)
## - ssCarryForward: Carry forward last value for streams without data
## - ssLeading: Emit on leading stream timestamps, others optional

import std/[tables, options]
import core
import strategies/base
import datastreamers/types

type
  SyncStrategy* = enum
    ssAlign         ## Emit only when ALL required streams have data
    ssCarryForward  ## Carry forward last value for missing data
    ssLeading       ## Emit on leading stream (usually OHLCV), others optional

  DataStream* = object
    ## A single data stream with its metadata
    kind*: DataKind
    required*: bool
    data*: seq[DataValue]  ## Pre-loaded data sorted by timestamp
    currentIndex*: int     ## Current position in stream

  StreamSet* = ref object
    ## A collection of synchronized streams
    streams*: seq[DataStream]
    strategy*: SyncStrategy
    leadingKind*: DataKind  ## Which stream is the leader (for ssLeading)

# Helper to get timestamp from DataValue
proc getTimestamp*(dv: DataValue): int64 =
  case dv.kind
  of dkOHLCV: dv.ohlcv.timestamp
  of dkQuote: dv.quote.timestamp
  of dkTick, dkOrderBook, dkTrades, dkGreeks, dkFundamentals:
    raise newException(ValueError, "Timestamp extraction not implemented for " & $dv.kind)

# Constructors
proc newDataStream*(kind: DataKind, required: bool, data: seq[DataValue]): DataStream =
  ## Create a new data stream
  result = DataStream(
    kind: kind,
    required: required,
    data: data,
    currentIndex: 0
  )

proc newStreamSet*(strategy: SyncStrategy = ssLeading, 
                   leadingKind: DataKind = dkOHLCV): StreamSet =
  ## Create a new stream set
  result = StreamSet(
    streams: @[],
    strategy: strategy,
    leadingKind: leadingKind
  )

proc addStream*(ss: StreamSet, stream: DataStream) =
  ## Add a stream to the set
  ss.streams.add(stream)

proc addStream*(ss: StreamSet, kind: DataKind, required: bool, data: seq[DataValue]) =
  ## Add a stream to the set (convenience method)
  ss.addStream(newDataStream(kind, required, data))

# Stream state inspection
proc hasMoreData*(stream: DataStream): bool =
  ## Check if stream has more data
  stream.currentIndex < stream.data.len

proc currentData*(stream: var DataStream): Option[DataValue] =
  ## Get current data value without advancing
  if stream.hasMoreData():
    some(stream.data[stream.currentIndex])
  else:
    none(DataValue)

proc currentTimestamp*(stream: var DataStream): Option[int64] =
  ## Get current timestamp without advancing
  let data = stream.currentData()
  if data.isSome:
    some(data.get.getTimestamp())
  else:
    none(int64)

proc advance*(stream: var DataStream) =
  ## Move to next data point
  if stream.hasMoreData():
    stream.currentIndex += 1

proc peekNextTimestamp*(stream: var DataStream): Option[int64] =
  ## Look ahead to next timestamp without advancing
  if stream.currentIndex + 1 < stream.data.len:
    some(stream.data[stream.currentIndex + 1].getTimestamp())
  else:
    none(int64)

# Synchronization iterators

iterator synchronizeAlign*(ss: StreamSet): DataContext =
  ## Synchronize streams with strict alignment (ssAlign)
  ## Only emit when ALL required streams have data at the same timestamp
  
  while true:
    # Find minimum timestamp across all streams with data
    var minTimestamp: Option[int64] = none(int64)
    var allExhausted = true
    
    for stream in ss.streams.mitems:
      if stream.hasMoreData():
        allExhausted = false
        let ts = stream.currentTimestamp()
        if ts.isSome:
          if minTimestamp.isNone or ts.get < minTimestamp.get:
            minTimestamp = ts
    
    if allExhausted:
      break
    
    if minTimestamp.isNone:
      break
    
    let targetTs = minTimestamp.get
    
    # Check if all required streams have data at this timestamp
    var allRequiredPresent = true
    var dataAtTimestamp: seq[DataValue] = @[]
    
    for stream in ss.streams.mitems:
      if not stream.hasMoreData():
        if stream.required:
          allRequiredPresent = false
          break
        continue
      
      let ts = stream.currentTimestamp()
      if ts.isSome and ts.get == targetTs:
        dataAtTimestamp.add(stream.currentData().get)
        stream.advance()
      elif stream.required:
        allRequiredPresent = false
        break
    
    # Emit only if all required streams had data
    if allRequiredPresent and dataAtTimestamp.len > 0:
      yield newDataContext(targetTs, dataAtTimestamp)

iterator synchronizeCarryForward*(ss: StreamSet): DataContext =
  ## Synchronize streams with carry-forward (ssCarryForward)
  ## Carry forward last value for streams without current data
  
  var lastValues: Table[DataKind, DataValue]
  
  while true:
    # Find minimum timestamp across all streams with data
    var minTimestamp: Option[int64] = none(int64)
    var allExhausted = true
    
    for stream in ss.streams.mitems:
      if stream.hasMoreData():
        allExhausted = false
        let ts = stream.currentTimestamp()
        if ts.isSome:
          if minTimestamp.isNone or ts.get < minTimestamp.get:
            minTimestamp = ts
    
    if allExhausted:
      break
    
    if minTimestamp.isNone:
      break
    
    let targetTs = minTimestamp.get
    var dataAtTimestamp: seq[DataValue] = @[]
    var hasRequiredData = true
    
    # Process each stream
    for stream in ss.streams.mitems:
      if not stream.hasMoreData():
        # Try to use carried-forward value
        if lastValues.hasKey(stream.kind):
          dataAtTimestamp.add(lastValues[stream.kind])
        elif stream.required:
          hasRequiredData = false
          break
        continue
      
      let ts = stream.currentTimestamp()
      if ts.isSome and ts.get == targetTs:
        # Stream has data at this timestamp
        let data = stream.currentData().get
        dataAtTimestamp.add(data)
        lastValues[stream.kind] = data  # Remember for carry-forward
        stream.advance()
      else:
        # Stream doesn't have data at this timestamp, carry forward
        if lastValues.hasKey(stream.kind):
          dataAtTimestamp.add(lastValues[stream.kind])
        elif stream.required:
          hasRequiredData = false
          break
    
    # Emit if we have all required data (either fresh or carried forward)
    if hasRequiredData and dataAtTimestamp.len > 0:
      yield newDataContext(targetTs, dataAtTimestamp)

iterator synchronizeLeading*(ss: StreamSet): DataContext =
  ## Synchronize streams with leading stream (ssLeading)
  ## Emit on leading stream timestamps, pull latest from other streams
  
  # Find the leading stream
  var leadingStreamIdx = -1
  for i, stream in ss.streams:
    if stream.kind == ss.leadingKind:
      leadingStreamIdx = i
      break
  
  if leadingStreamIdx < 0:
    raise newException(ValueError, "Leading stream kind not found: " & $ss.leadingKind)
  
  var lastValues: Table[DataKind, DataValue]
  
  # Iterate on leading stream
  while ss.streams[leadingStreamIdx].hasMoreData():
    let leadingTs = ss.streams[leadingStreamIdx].currentTimestamp().get
    var dataAtTimestamp: seq[DataValue] = @[]
    var hasRequiredData = true
    
    # Add leading stream data
    let leadingData = ss.streams[leadingStreamIdx].currentData().get
    dataAtTimestamp.add(leadingData)
    lastValues[ss.leadingKind] = leadingData
    ss.streams[leadingStreamIdx].advance()
    
    # Process other streams - advance them to this timestamp or just past
    for i, stream in ss.streams.mpairs:
      if i == leadingStreamIdx:
        continue
      
      # Advance this stream to catch up to leading timestamp
      while stream.hasMoreData():
        let ts = stream.currentTimestamp().get
        if ts <= leadingTs:
          # Update last value as we advance
          lastValues[stream.kind] = stream.currentData().get
          if ts == leadingTs:
            stream.advance()
            break
          stream.advance()
        else:
          # Future data, don't advance
          break
      
      # Use the latest value we have
      if lastValues.hasKey(stream.kind):
        dataAtTimestamp.add(lastValues[stream.kind])
      elif stream.required:
        hasRequiredData = false
        break
    
    # Emit if we have all required data
    if hasRequiredData and dataAtTimestamp.len > 0:
      yield newDataContext(leadingTs, dataAtTimestamp)

iterator synchronize*(ss: StreamSet): DataContext =
  ## Synchronize streams according to the configured strategy
  case ss.strategy
  of ssAlign:
    for ctx in ss.synchronizeAlign():
      yield ctx
  of ssCarryForward:
    for ctx in ss.synchronizeCarryForward():
      yield ctx
  of ssLeading:
    for ctx in ss.synchronizeLeading():
      yield ctx

# Convenience functions

proc createStreamFromOHLCV*(kind: DataKind, required: bool, 
                            data: seq[OHLCV]): DataStream =
  ## Create a data stream from OHLCV sequence
  var dataValues: seq[DataValue] = @[]
  for bar in data:
    dataValues.add(newDataValue(bar))
  newDataStream(kind, required, dataValues)

proc createStreamFromQuotes*(kind: DataKind, required: bool,
                             data: seq[Quote]): DataStream =
  ## Create a data stream from Quote sequence
  var dataValues: seq[DataValue] = @[]
  for quote in data:
    dataValues.add(newDataValue(quote))
  newDataStream(kind, required, dataValues)

# Statistics and debugging

proc getStreamStats*(ss: StreamSet): Table[DataKind, tuple[total: int, consumed: int]] =
  ## Get statistics about stream consumption
  result = initTable[DataKind, tuple[total: int, consumed: int]]()
  for stream in ss.streams:
    result[stream.kind] = (total: stream.data.len, consumed: stream.currentIndex)

proc resetStreams*(ss: StreamSet) =
  ## Reset all streams to beginning
  for stream in ss.streams.mitems:
    stream.currentIndex = 0
