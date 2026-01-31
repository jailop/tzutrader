## CSV Data Streamer
##
## Provides streaming access to OHLCV data from CSV files.
##
## CSV Format:
##   timestamp,open,high,low,close,volume
##   1609459200,100.0,105.0,95.0,102.0,1000000.0
##
## Features:
## - O(1) memory streaming for large CSV files
## - Time range filtering
## - Symbol extraction from filename
## - Automatic header detection

import std/[strutils, os, tables]
import ../core
import types
import base

type
  CSVStreamer*[T] = ref object of DataStreamer[T]
    ## CSV file streamer for OHLCV data
    filename: string
    file: File
    hasHeader: bool
    lineNum: int
    currentBar: OHLCV
    hasCurrentBar: bool
    totalLines: int
    startTime: int64
    endTime: int64

# Helper procs

proc countLines(filename: string): int =
  ## Count total lines in file (for len() implementation)
  result = 0
  var f = open(filename, fmRead)
  defer: f.close()
  for line in f.lines:
    if line.strip().len > 0:
      result.inc

proc parseCSVLine(line: string, lineNum: int): OHLCV =
  ## Parse a single CSV line into OHLCV bar
  let parts = line.split(',')
  if parts.len < 6:
    raise newException(DataError,
      "Invalid CSV format at line " & $lineNum & ": expected 6 columns, got " & $parts.len)
  
  try:
    result = OHLCV(
      timestamp: parseBiggestInt(parts[0].strip()),
      open: parseFloat(parts[1].strip()),
      high: parseFloat(parts[2].strip()),
      low: parseFloat(parts[3].strip()),
      close: parseFloat(parts[4].strip()),
      volume: parseFloat(parts[5].strip())
    )
  except ValueError as e:
    raise newException(DataError,
      "Failed to parse CSV at line " & $lineNum & ": " & e.msg)

# Public interface

proc newCSVStreamer*[T](params: StreamParams): CSVStreamer[T] =
  ## Create a new CSV streamer
  ##
  ## Type parameter T must be OHLCV
  ##
  ## Args:
  ##   params: Stream parameters with CSV-specific fields:
  ##     - symbol: Symbol name (extracted from filename if empty)
  ##     - metadata["filename"]: Path to CSV file (required)
  ##     - metadata["hasHeader"]: "true" or "false" (default: "true")
  ##     - startTime: Optional start timestamp filter
  ##     - endTime: Optional end timestamp filter
  ##
  ## Raises:
  ##   UnsupportedDataTypeError: If T is not OHLCV
  ##   DataError: If filename is not provided or file doesn't exist
  when T isnot OHLCV:
    raise newException(UnsupportedDataTypeError,
      "CSV streamer only supports OHLCV data type, got: " & $getDataKind[T]())
  
  # Get required filename parameter
  if "filename" notin params.metadata:
    raise newException(DataError, "CSV streamer requires 'filename' in metadata")
  
  let filename = params.metadata["filename"]
  if not fileExists(filename):
    raise newException(DataError, "CSV file not found: " & filename)
  
  # Get optional parameters
  let hasHeader = params.metadata.getOrDefault("hasHeader", "true") == "true"
  let symbol = if params.symbol.len > 0: params.symbol else: filename.splitFile().name
  
  result = CSVStreamer[T](
    filename: filename,
    hasHeader: hasHeader,
    lineNum: 0,
    hasCurrentBar: false,
    totalLines: -1,  # Lazy calculation
    startTime: params.startTime,
    endTime: params.endTime,
    symbol: symbol
  )
  
  # Open file for streaming
  result.file = open(filename, fmRead)

proc newCSVStreamer*[T](filename: string, symbol: string = "",
                        startTime: int64 = 0, endTime: int64 = high(int64),
                        hasHeader: bool = true): CSVStreamer[T] =
  ## Convenience constructor for CSV streamer
  ##
  ## Args:
  ##   filename: Path to CSV file
  ##   symbol: Symbol name (extracted from filename if empty)
  ##   startTime: Optional start timestamp filter (default: 0)
  ##   endTime: Optional end timestamp filter (default: unlimited)
  ##   hasHeader: Skip first line if true (default: true)
  var params = StreamParams(
    provider: dpCSV,
    symbol: symbol,
    startTime: startTime,
    endTime: endTime,
    metadata: {"filename": filename, "hasHeader": $hasHeader}.toTable
  )
  result = newCSVStreamer[T](params)

# Implement DataStreamer interface

method next*(stream: CSVStreamer[OHLCV]): bool =
  ## Advance to next data point
  ## Returns true if successful, false if end of stream
  stream.hasCurrentBar = false
  
  while not stream.file.endOfFile():
    let line = stream.file.readLine()
    stream.lineNum.inc
    
    # Skip header if present
    if stream.hasHeader and stream.lineNum == 1:
      continue
    
    # Skip empty lines
    if line.strip().len == 0:
      continue
    
    # Parse the line
    let bar = parseCSVLine(line, stream.lineNum)
    
    # Apply time range filter
    if bar.timestamp < stream.startTime:
      continue
    if bar.timestamp > stream.endTime:
      return false  # Past end time, stop
    
    # Found valid bar
    stream.currentBar = bar
    stream.hasCurrentBar = true
    return true
  
  # End of file
  return false

proc current*(stream: CSVStreamer[OHLCV]): OHLCV =
  ## Get current data point
  ## Must call next() first
  if not stream.hasCurrentBar:
    raise newException(DataError, "No current data - call next() first")
  return stream.currentBar

method reset*(stream: CSVStreamer[OHLCV]) =
  ## Reset stream to beginning
  stream.file.close()
  stream.file = open(stream.filename, fmRead)
  stream.lineNum = 0
  stream.hasCurrentBar = false

method len*(stream: CSVStreamer[OHLCV]): int =
  ## Get total number of items in stream
  ## Note: This requires reading the entire file once
  if stream.totalLines < 0:
    stream.totalLines = countLines(stream.filename)
    if stream.hasHeader:
      stream.totalLines.dec
  return stream.totalLines

method hasNext*(stream: CSVStreamer[OHLCV]): bool =
  ## Check if more data is available
  ## Note: For file streams, this peeks ahead which may affect performance
  return not stream.file.endOfFile()

# Cleanup

proc close*(stream: CSVStreamer[OHLCV]) =
  ## Close the CSV file
  ## Call this when done streaming to free resources
  if not stream.file.isNil:
    stream.file.close()
