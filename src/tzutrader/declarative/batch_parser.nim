## Batch Test YAML Parser
##
## This module handles parsing batch test YAML files into BatchTestYAML objects.
## It extends the regular parser to support batch testing configurations.

import std/[tables, options, strutils]
import yaml
import ./schema

type
  BatchParseError* = object of CatchableError
    ## Error during batch test YAML parsing

# ============================================================================
# YAML Node Helpers (copied from parser.nim for consistency)
# ============================================================================

proc getStr(node: YamlNode, default: string = ""): string =
  ## Safely extract string from YAML node
  if node.kind == yScalar:
    result = node.content
  else:
    result = default

proc getFloat(node: YamlNode, default: float = 0.0): float =
  ## Safely extract float from YAML node
  if node.kind == yScalar:
    try:
      result = parseFloat(node.content)
    except ValueError:
      result = default
  else:
    result = default

proc getSeq(node: YamlNode): seq[YamlNode] =
  ## Safely extract sequence from YAML node
  if node.kind == ySequence:
    result = node.elems
  else:
    result = @[]

# ============================================================================
# Parse Data Source Configuration
# ============================================================================

proc parseDataSource(node: YamlNode): DataSourceYAML =
  ## Parse data source configuration
  result.source = ""
  result.symbols = @[]
  result.startDate = ""
  result.endDate = ""
  result.csvPath = none(string)
  
  if node.kind != yMapping:
    raise newException(BatchParseError, "data section must be a mapping")
  
  for key, val in node.fields:
    case key.content
    of "source":
      result.source = val.getStr()
      if result.source notin ["yahoo", "csv", "coinbase"]:
        raise newException(BatchParseError, 
          "Invalid data source: " & result.source & " (must be yahoo, csv, or coinbase)")
    of "symbols":
      for symbolNode in val.getSeq():
        result.symbols.add(symbolNode.getStr())
      if result.symbols.len == 0:
        raise newException(BatchParseError, "symbols list cannot be empty")
    of "start_date":
      result.startDate = val.getStr()
      if result.startDate == "":
        raise newException(BatchParseError, "start_date is required")
    of "end_date":
      result.endDate = val.getStr()
      if result.endDate == "":
        raise newException(BatchParseError, "end_date is required")
    of "csv_path":
      result.csvPath = some(val.getStr())
    else:
      discard

# ============================================================================
# Parse Parameter Overrides
# ============================================================================

proc parseParamValue(node: YamlNode): ParamValue =
  ## Parse a parameter value from YAML node
  if node.kind != yScalar:
    raise newException(BatchParseError, "Parameter value must be a scalar")
  
  # Try to parse as different types
  let content = node.content
  
  # Boolean
  if content.toLowerAscii() in ["true", "false", "yes", "no"]:
    let boolVal = content.toLowerAscii() in ["true", "yes"]
    return ParamValue(kind: pkBool, boolVal: boolVal)
  
  # Integer
  try:
    let intVal = parseInt(content)
    return ParamValue(kind: pkInt, intVal: intVal)
  except ValueError:
    discard
  
  # Float
  try:
    let floatVal = parseFloat(content)
    return ParamValue(kind: pkFloat, floatVal: floatVal)
  except ValueError:
    discard
  
  # String (fallback)
  return ParamValue(kind: pkString, strVal: content)

proc parseOverrides(node: YamlNode): seq[ParameterOverride] =
  ## Parse parameter overrides from YAML node
  result = @[]
  
  if node.kind != yMapping:
    return
  
  for indicatorKey, paramsNode in node.fields:
    let indicatorId = indicatorKey.content
    
    if paramsNode.kind != yMapping:
      raise newException(BatchParseError, 
        "Overrides for indicator '" & indicatorId & "' must be a mapping")
    
    for paramKey, paramVal in paramsNode.fields:
      result.add(ParameterOverride(
        indicatorId: indicatorId,
        paramName: paramKey.content,
        paramValue: parseParamValue(paramVal)
      ))

# ============================================================================
# Parse Strategy Configurations
# ============================================================================

proc parseStrategyConfig(node: YamlNode): StrategyConfigYAML =
  ## Parse a single strategy configuration
  result.file = ""
  result.name = ""
  result.overrides = @[]
  
  if node.kind != yMapping:
    raise newException(BatchParseError, "Strategy config must be a mapping")
  
  for key, val in node.fields:
    case key.content
    of "file":
      result.file = val.getStr()
      if result.file == "":
        raise newException(BatchParseError, "Strategy file path cannot be empty")
    of "name":
      result.name = val.getStr()
      if result.name == "":
        raise newException(BatchParseError, "Strategy name cannot be empty")
    of "overrides":
      result.overrides = parseOverrides(val)
    else:
      discard

proc parseStrategies(node: YamlNode): seq[StrategyConfigYAML] =
  ## Parse all strategy configurations
  result = @[]
  
  if node.kind != ySequence:
    raise newException(BatchParseError, "strategies section must be a sequence")
  
  for stratNode in node.getSeq():
    result.add(parseStrategyConfig(stratNode))
  
  if result.len == 0:
    raise newException(BatchParseError, "At least one strategy is required")

# ============================================================================
# Parse Portfolio Configuration
# ============================================================================

proc parsePortfolio(node: YamlNode): PortfolioConfigYAML =
  ## Parse portfolio configuration
  result.initialCash = 100000.0  # default
  result.commission = 0.001       # default 0.1%
  
  if node.kind != yMapping:
    raise newException(BatchParseError, "portfolio section must be a mapping")
  
  for key, val in node.fields:
    case key.content
    of "initial_cash":
      result.initialCash = val.getFloat(100000.0)
      if result.initialCash <= 0:
        raise newException(BatchParseError, "initial_cash must be positive")
    of "commission":
      result.commission = val.getFloat(0.001)
      if result.commission < 0 or result.commission >= 1.0:
        raise newException(BatchParseError, 
          "commission must be between 0 and 1 (e.g., 0.001 for 0.1%)")
    else:
      discard

# ============================================================================
# Parse Output Configuration
# ============================================================================

proc parseOutput(node: YamlNode): OutputConfigYAML =
  ## Parse output configuration
  result.comparisonReport = none(string)
  result.individualResults = none(string)
  result.format = none(string)
  
  if node.kind != yMapping:
    return
  
  for key, val in node.fields:
    case key.content
    of "comparison_report":
      let path = val.getStr()
      if path != "":
        result.comparisonReport = some(path)
    of "individual_results":
      let path = val.getStr()
      if path != "":
        result.individualResults = some(path)
    of "format":
      let fmt = val.getStr().toLowerAscii()
      if fmt in ["html", "csv", "json"]:
        result.format = some(fmt)
      elif fmt != "":
        raise newException(BatchParseError, 
          "Invalid output format: " & fmt & " (must be html, csv, or json)")
    else:
      discard

# ============================================================================
# Main Parse Function
# ============================================================================

proc parseBatchTestYAML*(yamlContent: string): BatchTestYAML =
  ## Parse a batch test configuration from YAML string
  ## Raises BatchParseError if parsing fails
  
  var root: YamlNode
  
  try:
    load(yamlContent, root)
  except YamlParserError as e:
    raise newException(BatchParseError, "YAML syntax error: " & e.msg)
  except YamlConstructionError as e:
    raise newException(BatchParseError, "YAML construction error: " & e.msg)
  
  if root.kind != yMapping:
    raise newException(BatchParseError, "Batch test root must be a mapping")
  
  # Initialize with defaults
  result.version = "1.0"
  result.output = OutputConfigYAML()
  
  var hasData = false
  var hasStrategies = false
  var hasPortfolio = false
  
  # Parse each section
  for key, val in root.fields:
    case key.content
    of "version":
      result.version = val.getStr("1.0")
    of "type":
      let typeVal = val.getStr()
      if typeVal != "batch_test":
        raise newException(BatchParseError, 
          "Invalid type: " & typeVal & " (expected 'batch_test')")
    of "data":
      result.data = parseDataSource(val)
      hasData = true
    of "strategies":
      result.strategies = parseStrategies(val)
      hasStrategies = true
    of "portfolio":
      result.portfolio = parsePortfolio(val)
      hasPortfolio = true
    of "output":
      result.output = parseOutput(val)
    else:
      discard
  
  # Validate required sections
  if not hasData:
    raise newException(BatchParseError, "Missing required 'data' section")
  if not hasStrategies:
    raise newException(BatchParseError, "Missing required 'strategies' section")
  if not hasPortfolio:
    raise newException(BatchParseError, "Missing required 'portfolio' section")

proc parseBatchTestYAMLFile*(filename: string): BatchTestYAML =
  ## Parse a batch test configuration from a YAML file
  let content = readFile(filename)
  result = parseBatchTestYAML(content)
