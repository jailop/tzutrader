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
      raise newException(ParseError, "NOT operator not supported in Phase 1")
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
