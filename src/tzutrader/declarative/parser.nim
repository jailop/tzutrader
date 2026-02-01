## YAML Parser for Declarative Strategies
##
## This module handles parsing YAML files into StrategyYAML objects.
## It converts raw YAML nodes into our typed schema representation.

import std/[tables, options, strutils]
import yaml
import ./schema

type
  ParseError* = object of CatchableError
    ## Error during YAML parsing

# ============================================================================
# Location Tracking (Phase 2 - Feature B2)
# ============================================================================

proc toSourceLocation(node: YamlNode): SourceLocation =
  ## Extract source location from YAML node for error reporting
  SourceLocation(
    line: node.startPos.line,
    column: node.startPos.column
  )

# ============================================================================
# YAML Node Helpers
# ============================================================================

proc getStr(node: YamlNode, default: string = ""): string =
  ## Safely extract string from YAML node
  if node.kind == yScalar:
    result = node.content
  else:
    result = default

proc getInt(node: YamlNode, default: int = 0): int =
  ## Safely extract int from YAML node
  if node.kind == yScalar:
    try:
      result = parseInt(node.content)
    except ValueError:
      result = default
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

proc getBool(node: YamlNode, default: bool = false): bool =
  ## Safely extract bool from YAML node
  if node.kind == yScalar:
    let s = node.content.toLowerAscii()
    result = s in ["true", "yes", "1", "on"]
  else:
    result = default

proc getSeq(node: YamlNode): seq[YamlNode] =
  ## Safely extract sequence from YAML node
  if node.kind == ySequence:
    result = node.elems
  else:
    result = @[]

proc getMapping(node: YamlNode): YamlNode =
  ## Return node if it's a mapping, else raise error
  if node.kind != yMapping:
    raise newException(ParseError, "Expected mapping but got " & $node.kind)
  result = node

# ============================================================================
# Parse Metadata
# ============================================================================

proc parseMetadata(node: YamlNode): MetadataYAML =
  ## Parse strategy metadata section
  result.name = ""
  result.description = ""
  result.tags = @[]
  
  if node.kind != yMapping:
    return
  
  for key, val in node.fields:
    case key.content
    of "name":
      result.name = val.getStr()
    of "description":
      result.description = val.getStr()
    of "author":
      result.author = some(val.getStr())
    of "created":
      result.created = some(val.getStr())
    of "tags":
      for tag in val.getSeq():
        result.tags.add(tag.getStr())
    else:
      discard

# ============================================================================
# Parse Parameters
# ============================================================================

proc parseParamValue(node: YamlNode): ParamValue =
  ## Parse a parameter value from YAML node
  ## Attempts to infer type from content
  if node.kind != yScalar:
    raise newException(ParseError, "Parameter values must be scalar")
  
  let content = node.content
  
  # Try bool first
  if content.toLowerAscii() in ["true", "false", "yes", "no"]:
    return newParamBool(node.getBool())
  
  # Try int
  try:
    let intVal = parseInt(content)
    return newParamInt(intVal)
  except ValueError:
    discard
  
  # Try float
  try:
    let floatVal = parseFloat(content)
    return newParamFloat(floatVal)
  except ValueError:
    discard
  
  # Default to string
  return newParamString(content)

# ============================================================================
# Parse Indicators
# ============================================================================

proc parseIndicator(node: YamlNode): IndicatorYAML =
  ## Parse a single indicator definition
  result.id = ""
  result.indicatorType = ""
  result.params = initTable[string, ParamValue]()
  result.source = none(string)
  result.output = none(string)
  result.location = some(toSourceLocation(node))  # Capture location
  
  if node.kind != yMapping:
    raise newException(ParseError, formatError("Indicator must be a mapping", result.location))
  
  for key, val in node.fields:
    case key.content
    of "id":
      result.id = val.getStr()
    of "type":
      result.indicatorType = val.getStr()
    of "params":
      if val.kind == yMapping:
        for paramKey, paramVal in val.fields:
          result.params[paramKey.content] = parseParamValue(paramVal)
    of "source":
      result.source = some(val.getStr())
    of "output":
      result.output = some(val.getStr())
    else:
      discard

proc parseIndicators(node: YamlNode): seq[IndicatorYAML] =
  ## Parse indicators section
  result = @[]
  for indicatorNode in node.getSeq():
    result.add(parseIndicator(indicatorNode))

# ============================================================================
# Parse Conditions
# ============================================================================

proc parseOperator(s: string, loc: Option[SourceLocation] = none(SourceLocation)): ComparisonOp =
  ## Parse comparison operator from string
  case s
  of "<": opLessThan
  of ">": opGreaterThan
  of "<=": opLessEqual
  of ">=": opGreaterEqual
  of "==": opEqual
  of "!=": opNotEqual
  of "crosses_above": opCrossesAbove
  of "crosses_below": opCrossesBelow
  else:
    raise newException(ParseError, formatError("Unknown operator: " & s, loc))

proc parseCondition(node: YamlNode): ConditionYAML

proc parseSimpleCondition(node: YamlNode): ConditionYAML =
  ## Parse a simple comparison condition
  let loc = some(toSourceLocation(node))  # Capture location
  var left, op, right: string
  
  if node.kind != yMapping:
    raise newException(ParseError, formatError("Simple condition must be a mapping", loc))
  
  for key, val in node.fields:
    case key.content
    of "left":
      left = val.getStr()
    of "operator", "op":
      op = val.getStr()
    of "right":
      right = val.getStr()
    else:
      discard
  
  if left == "" or op == "" or right == "":
    raise newException(ParseError, formatError("Simple condition must have left, operator, and right", loc))
  
  result = newSimpleCondition(left, parseOperator(op, loc), right)
  result.location = loc  # Store location

proc parseAndCondition(node: YamlNode): ConditionYAML =
  ## Parse an AND condition
  let loc = some(toSourceLocation(node))  # Capture location
  var conditions: seq[ConditionYAML] = @[]
  
  for childNode in node.getSeq():
    conditions.add(parseCondition(childNode))
  
  result = newAndCondition(conditions)
  result.location = loc  # Store location

proc parseOrCondition(node: YamlNode): ConditionYAML =
  ## Parse an OR condition
  let loc = some(toSourceLocation(node))  # Capture location
  var conditions: seq[ConditionYAML] = @[]
  
  for childNode in node.getSeq():
    conditions.add(parseCondition(childNode))
  
  result = newOrCondition(conditions)
  result.location = loc  # Store location

proc parseCondition(node: YamlNode): ConditionYAML =
  ## Parse a condition (simple or compound)
  if node.kind == ySequence:
    # Implicit AND - list of conditions
    return parseAndCondition(node)
  
  if node.kind != yMapping:
    raise newException(ParseError, "Condition must be mapping or sequence")
  
  # Check for boolean operators
  for key, val in node.fields:
    case key.content
    of "all", "and":
      return parseAndCondition(val)
    of "any", "or":
      return parseOrCondition(val)
    of "not":
      # Parse NOT condition
      let loc = some(toSourceLocation(node))
      var notCond = new(ConditionYAML)
      notCond[] = parseCondition(val)
      result = ConditionYAML(kind: ckNot, notCondition: notCond)
      result.location = loc
      return result
    else:
      discard
  
  # Must be a simple condition
  return parseSimpleCondition(node)

# ============================================================================
# Parse Rules
# ============================================================================

proc parseRule(node: YamlNode): RuleYAML =
  ## Parse an entry or exit rule
  if node.kind != yMapping:
    raise newException(ParseError, "Rule must be a mapping")
  
  var conditionsNode: YamlNode = nil
  
  for key, val in node.fields:
    if key.content == "conditions":
      conditionsNode = val
      break
  
  if conditionsNode.isNil:
    raise newException(ParseError, "Rule must have 'conditions' field")
  
  result.conditions = parseCondition(conditionsNode)

# ============================================================================
# Parse Position Sizing
# ============================================================================

proc parsePositionSizing(node: YamlNode): PositionSizingYAML =
  ## Parse position sizing configuration
  if node.kind != yMapping:
    raise newException(ParseError, "Position sizing must be a mapping")
  
  var sizingType = "fixed"
  var size = 100.0
  var percent = 10.0
  
  for key, val in node.fields:
    case key.content
    of "type":
      sizingType = val.getStr()
    of "size", "amount":
      size = val.getFloat()
    of "percent", "percentage":
      percent = val.getFloat()
    else:
      discard
  
  case sizingType
  of "fixed":
    result = PositionSizingYAML(kind: psFixed, fixedSize: size)
  of "percent", "percentage":
    # Validate percent is in reasonable range
    if percent <= 0.0 or percent > 100.0:
      raise newException(ParseError, "Position sizing percent must be between 0 and 100")
    result = PositionSizingYAML(kind: psPercent, percentCapital: percent)
  else:
    raise newException(ParseError, "Unsupported position sizing type: " & sizingType & " (use 'fixed' or 'percent')")

# ============================================================================
# Main Parse Function
# ============================================================================

proc parseStrategyYAML*(yamlContent: string): StrategyYAML =
  ## Parse a complete strategy from YAML string
  ## Raises ParseError if parsing fails
  
  var root: YamlNode
  
  try:
    load(yamlContent, root)
  except YamlParserError as e:
    raise newException(ParseError, "YAML syntax error: " & e.msg)
  except YamlConstructionError as e:
    raise newException(ParseError, "YAML construction error: " & e.msg)
  
  if root.kind != yMapping:
    raise newException(ParseError, "Strategy root must be a mapping")
  
  # Initialize with defaults
  result.metadata = MetadataYAML(name: "", description: "", tags: @[])
  result.indicators = @[]
  result.positionSizing = PositionSizingYAML(kind: psFixed, fixedSize: 100.0)
  
  # Parse each section
  for key, val in root.fields:
    case key.content
    of "metadata":
      result.metadata = parseMetadata(val)
    of "indicators":
      result.indicators = parseIndicators(val)
    of "entry":
      result.entryRule = parseRule(val)
    of "exit":
      result.exitRule = parseRule(val)
    of "position_sizing":
      result.positionSizing = parsePositionSizing(val)
    else:
      discard

proc parseStrategyYAMLFile*(filename: string): StrategyYAML =
  ## Parse a strategy from a YAML file
  let content = readFile(filename)
  result = parseStrategyYAML(content)

# ============================================================================
# Parse Batch Test Configuration (Phase 4)
# ============================================================================

proc parseDataConfig(node: YamlNode): DataConfigYAML =
  ## Parse data configuration section
  if node.kind != yMapping:
    raise newException(ParseError, "Data config must be a mapping")
  
  var source = "yahoo"
  
  for key, val in node.fields:
    if key.content == "source":
      source = val.getStr()
      break
  
  case source
  of "yahoo":
    var symbols: seq[string] = @[]
    var startDate = ""
    var endDate = ""
    
    for key, val in node.fields:
      case key.content
      of "symbols":
        for sym in val.getSeq():
          symbols.add(sym.getStr())
      of "start_date", "start":
        startDate = val.getStr()
      of "end_date", "end":
        endDate = val.getStr()
      else:
        discard
    
    result = newDataConfigYahoo(symbols, startDate, endDate)
  
  of "csv":
    var csvFile = ""
    
    for key, val in node.fields:
      if key.content == "file":
        csvFile = val.getStr()
        break
    
    result = newDataConfigCsv(csvFile)
  
  else:
    raise newException(ParseError, "Unsupported data source: " & source)

proc parsePortfolioConfig(node: YamlNode): PortfolioConfigYAML =
  ## Parse portfolio configuration section
  if node.kind != yMapping:
    raise newException(ParseError, "Portfolio config must be a mapping")
  
  var initialCash = 100000.0
  var commission = 0.001
  var minCommission = none(float)
  var riskFreeRate = none(float)
  
  for key, val in node.fields:
    case key.content
    of "initial_cash", "cash":
      initialCash = val.getFloat()
    of "commission":
      commission = val.getFloat()
    of "min_commission":
      minCommission = some(val.getFloat())
    of "risk_free_rate":
      riskFreeRate = some(val.getFloat())
    else:
      discard
  
  result = newPortfolioConfig(initialCash, commission, minCommission, riskFreeRate)

proc parseIndicatorOverride(node: YamlNode): IndicatorOverride =
  ## Parse indicator parameter overrides
  result.params = initTable[string, ParamValue]()
  
  if node.kind != yMapping:
    return
  
  for key, val in node.fields:
    if key.content == "params":
      if val.kind == yMapping:
        for paramKey, paramVal in val.fields:
          result.params[paramKey.content] = parseParamValue(paramVal)

proc parseConditionOverride(node: YamlNode): ConditionOverride =
  ## Parse condition overrides (entry/exit)
  if node.kind != yMapping:
    return
  
  for key, val in node.fields:
    case key.content
    of "entry":
      result.entry = some(parseCondition(val))
    of "exit":
      result.exit = some(parseCondition(val))
    else:
      discard

proc parseStrategyOverrides(node: YamlNode): StrategyOverrides =
  ## Parse strategy parameter overrides
  if node.kind != yMapping:
    return
  
  for key, val in node.fields:
    case key.content
    of "indicators":
      var indicatorOverrides = initTable[string, IndicatorOverride]()
      if val.kind == yMapping:
        for indKey, indVal in val.fields:
          indicatorOverrides[indKey.content] = parseIndicatorOverride(indVal)
      result.indicators = some(indicatorOverrides)
    
    of "conditions":
      result.conditions = some(parseConditionOverride(val))
    
    of "position_sizing":
      result.positionSizing = some(parsePositionSizing(val))
    
    else:
      discard

proc parseStrategyVariant(node: YamlNode): StrategyVariantYAML =
  ## Parse a strategy variant definition
  if node.kind != yMapping:
    raise newException(ParseError, "Strategy variant must be a mapping")
  
  var file = ""
  var name = ""
  var overrides = none(StrategyOverrides)
  
  for key, val in node.fields:
    case key.content
    of "file", "strategy":
      file = val.getStr()
    of "name":
      name = val.getStr()
    of "overrides":
      overrides = some(parseStrategyOverrides(val))
    else:
      discard
  
  if file == "":
    raise newException(ParseError, "Strategy variant must have 'file' field")
  if name == "":
    raise newException(ParseError, "Strategy variant must have 'name' field")
  
  result = newStrategyVariant(file, name, overrides)

proc parseBatchOutput(node: YamlNode): BatchOutputYAML =
  ## Parse batch output configuration
  var formats: seq[string] = @["csv"]
  var comparisonReport = none(string)
  var individualResults = none(string)
  
  if node.kind != yMapping:
    return newBatchOutput(formats, comparisonReport, individualResults)
  
  for key, val in node.fields:
    case key.content
    of "formats":
      formats = @[]
      for fmt in val.getSeq():
        formats.add(fmt.getStr())
    of "comparison_report":
      comparisonReport = some(val.getStr())
    of "individual_results":
      individualResults = some(val.getStr())
    else:
      discard
  
  result = newBatchOutput(formats, comparisonReport, individualResults)

proc parseBatchTestYAML*(yamlContent: string): BatchTestYAML =
  ## Parse a complete batch test configuration from YAML string
  var root: YamlNode
  
  try:
    load(yamlContent, root)
  except YamlParserError as e:
    raise newException(ParseError, "YAML syntax error: " & e.msg)
  except YamlConstructionError as e:
    raise newException(ParseError, "YAML construction error: " & e.msg)
  
  if root.kind != yMapping:
    raise newException(ParseError, "Batch test root must be a mapping")
  
  # Initialize with defaults
  result.version = "1.0"
  result.metadata = MetadataYAML(name: "", description: "", tags: @[])
  result.strategies = @[]
  result.portfolio = newPortfolioConfig()
  result.output = newBatchOutput()
  
  # Parse each section
  for key, val in root.fields:
    case key.content
    of "version":
      result.version = val.getStr()
    of "metadata":
      result.metadata = parseMetadata(val)
    of "data":
      result.data = parseDataConfig(val)
    of "strategies":
      for stratNode in val.getSeq():
        result.strategies.add(parseStrategyVariant(stratNode))
    of "portfolio":
      result.portfolio = parsePortfolioConfig(val)
    of "output":
      result.output = parseBatchOutput(val)
    else:
      discard

proc parseBatchTestYAMLFile*(filename: string): BatchTestYAML =
  ## Parse a batch test configuration from a YAML file
  let content = readFile(filename)
  result = parseBatchTestYAML(content)

# ============================================================================
# Parse Parameter Sweep Configuration (Phase 4)
# ============================================================================

proc parseSweepRange(node: YamlNode): SweepRange =
  ## Parse parameter sweep range
  if node.kind != yMapping:
    raise newException(ParseError, "Sweep range must be a mapping")
  
  var rangeType = "linear"
  
  for key, val in node.fields:
    if key.content == "type":
      rangeType = val.getStr()
      break
  
  case rangeType
  of "linear":
    var min = 0.0
    var max = 100.0
    var step = 1.0
    
    for key, val in node.fields:
      case key.content
      of "min", "from":
        min = val.getFloat()
      of "max", "to":
        max = val.getFloat()
      of "step":
        step = val.getFloat()
      else:
        discard
    
    result = newSweepRangeLinear(min, max, step)
  
  of "list", "values":
    var values: seq[float] = @[]
    
    for key, val in node.fields:
      if key.content == "values":
        for v in val.getSeq():
          values.add(v.getFloat())
        break
    
    result = newSweepRangeList(values)
  
  else:
    raise newException(ParseError, "Unsupported sweep range type: " & rangeType)

proc parseSweepParameter(node: YamlNode): SweepParameter =
  ## Parse a sweep parameter definition
  if node.kind != yMapping:
    raise newException(ParseError, "Sweep parameter must be a mapping")
  
  var path = ""
  var range: SweepRange
  
  for key, val in node.fields:
    case key.content
    of "path", "parameter":
      path = val.getStr()
    of "range":
      range = parseSweepRange(val)
    else:
      discard
  
  if path == "":
    raise newException(ParseError, "Sweep parameter must have 'path' field")
  
  result = newSweepParameter(path, range)

proc parseSweepOutput(node: YamlNode): SweepOutputYAML =
  ## Parse sweep output configuration
  result.heatmap = none(string)
  result.bestResults = "best_results.csv"
  result.fullResults = "all_results.csv"
  
  if node.kind != yMapping:
    return
  
  for key, val in node.fields:
    case key.content
    of "heatmap":
      result.heatmap = some(val.getStr())
    of "best_results":
      result.bestResults = val.getStr()
    of "full_results", "all_results":
      result.fullResults = val.getStr()
    else:
      discard

proc parseParameterSweepYAML*(yamlContent: string): ParameterSweepYAML =
  ## Parse a complete parameter sweep configuration from YAML string
  var root: YamlNode
  
  try:
    load(yamlContent, root)
  except YamlParserError as e:
    raise newException(ParseError, "YAML syntax error: " & e.msg)
  except YamlConstructionError as e:
    raise newException(ParseError, "YAML construction error: " & e.msg)
  
  if root.kind != yMapping:
    raise newException(ParseError, "Parameter sweep root must be a mapping")
  
  # Initialize with defaults
  result.version = "1.0"
  result.metadata = MetadataYAML(name: "", description: "", tags: @[])
  result.parameters = @[]
  result.portfolio = newPortfolioConfig()
  result.output = SweepOutputYAML(
    heatmap: none(string),
    bestResults: "best_results.csv",
    fullResults: "all_results.csv"
  )
  
  # Parse each section
  for key, val in root.fields:
    case key.content
    of "version":
      result.version = val.getStr()
    of "metadata":
      result.metadata = parseMetadata(val)
    of "base_strategy", "strategy":
      result.baseStrategy = val.getStr()
    of "data":
      result.data = parseDataConfig(val)
    of "portfolio":
      result.portfolio = parsePortfolioConfig(val)
    of "parameters":
      for paramNode in val.getSeq():
        result.parameters.add(parseSweepParameter(paramNode))
    of "output":
      result.output = parseSweepOutput(val)
    else:
      discard

proc parseParameterSweepYAMLFile*(filename: string): ParameterSweepYAML =
  ## Parse a parameter sweep configuration from a YAML file
  let content = readFile(filename)
  result = parseParameterSweepYAML(content)
