import std/[tables, strutils, math, strformat]
import ./schema
import ./parser # For parseStrategyYAMLFile

type
  SweepGeneratorError* = object of CatchableError
    ## Error during sweep generation

  ParameterSet* = Table[string, ParamValue]
    ## A single parameter combination

proc generateLinearRange(min, max, step: float): seq[float] =
  ## Generate linear range of values
  if step <= 0:
    raise newException(SweepGeneratorError, "Step must be positive")

  if min > max:
    raise newException(SweepGeneratorError, "Min must be <= max")

  result = @[]
  var current = min
  while current <= max:
    result.add(current)
    current += step

  # Ensure max is included if it's not due to floating point errors
  if result.len > 0 and result[^1] < max and abs(max - result[^1]) < step * 0.01:
    result[^1] = max

proc generateValues*(range: SweepRange): seq[float] =
  ## Generate all values for a sweep range
  case range.kind
  of srkLinear:
    result = generateLinearRange(range.min, range.max, range.step)
  of srkList:
    result = range.values

type
  ParameterPath* = object
    ## Parsed parameter path
    target*: string     # "indicators", "conditions", "position_sizing"
    identifier*: string # indicator ID or condition type (entry/exit)
    param*: string      # parameter name

proc parseParameterPath*(path: string): ParameterPath =
  ## Parse a parameter path like "indicators.rsi_14.period"
  ## Supported paths:
  ##   - indicators.<id>.params.<param>
  ##   - position_sizing.<param>
  ##   - conditions.entry.<field>
  ##   - conditions.exit.<field>

  let parts = path.split('.')

  if parts.len < 2:
    raise newException(SweepGeneratorError,
      &"Invalid parameter path: {path} (too few parts)")

  case parts[0]
  of "indicators":
    if parts.len < 3:
      raise newException(SweepGeneratorError,
        &"Invalid indicator path: {path} (need indicators.<id>.<param>)")

    result.target = "indicators"
    result.identifier = parts[1]

    # Handle both "indicators.rsi_14.period" and "indicators.rsi_14.params.period"
    if parts.len == 3:
      result.param = parts[2]
    elif parts.len == 4 and parts[2] == "params":
      result.param = parts[3]
    else:
      raise newException(SweepGeneratorError,
        &"Invalid indicator path: {path}")

  of "position_sizing":
    if parts.len != 2:
      raise newException(SweepGeneratorError,
        &"Invalid position_sizing path: {path} (need position_sizing.<param>)")

    result.target = "position_sizing"
    result.param = parts[1]

  of "conditions":
    if parts.len < 3:
      raise newException(SweepGeneratorError,
        &"Invalid conditions path: {path} (need conditions.<entry|exit>.<field>)")

    result.target = "conditions"
    result.identifier = parts[1] # entry or exit
    result.param = parts[2] # left, operator, or right

  else:
    raise newException(SweepGeneratorError,
      &"Invalid parameter path: {path} (unknown target '{parts[0]}')")

proc generateCombinations*(parameters: seq[SweepParameter]): seq[ParameterSet] =
  ## Generate all parameter combinations from sweep configuration
  ## Uses cartesian product for multi-dimensional sweeps

  if parameters.len == 0:
    return @[]

  # Generate values for each parameter
  var paramValues: seq[tuple[path: string, values: seq[float]]] = @[]
  for param in parameters:
    let values = generateValues(param.range)
    paramValues.add((path: param.path, values: values))

  # Calculate total combinations
  var totalCombinations = 1
  for pv in paramValues:
    totalCombinations *= pv.values.len

  if totalCombinations == 0:
    return @[]

  # Generate all combinations using cartesian product
  result = newSeq[ParameterSet](totalCombinations)

  for i in 0 ..< totalCombinations:
    var combination = initTable[string, ParamValue]()
    var index = i

    # Extract values for this combination
    for pv in paramValues:
      let valueIndex = index mod pv.values.len
      let value = pv.values[valueIndex]

      # Store as float param (will be converted later if needed)
      combination[pv.path] = newParamFloat(value)

      index = index div pv.values.len

    result[i] = combination

proc applyParameterSet*(
  baseDef: StrategyYAML,
  paramSet: ParameterSet
): StrategyYAML =
  ## Apply a parameter set to a base strategy definition
  ## Returns a new strategy with parameters applied

  result = baseDef # Copy

  for path, value in paramSet:
    let parsed = parseParameterPath(path)

    case parsed.target
    of "indicators":
      # Find the indicator
      var found = false
      for i in 0 ..< result.indicators.len:
        if result.indicators[i].id == parsed.identifier:
          # Update the parameter
          result.indicators[i].params[parsed.param] = value
          found = true
          break

      if not found:
        raise newException(SweepGeneratorError,
          &"Indicator '{parsed.identifier}' not found in strategy")

    of "position_sizing":
      # Update position sizing parameter
      case parsed.param
      of "percent", "percentage":
        if value.kind == pkFloat:
          result.positionSizing = PositionSizingYAML(
            kind: psPercent,
            percentCapital: value.floatVal
          )
      of "size", "amount":
        if value.kind == pkFloat:
          result.positionSizing = PositionSizingYAML(
            kind: psFixed,
            fixedSize: value.floatVal
          )
      else:
        raise newException(SweepGeneratorError,
          &"Unknown position_sizing parameter: {parsed.param}")

    of "conditions":
      # Update condition parameter (left, operator, right)
      # Note: This is simplified - only works for simple conditions
      var targetCondition = if parsed.identifier == "entry":
                             addr result.entryRule.conditions
                           else:
                             addr result.exitRule.conditions

      if targetCondition[].kind != ckSimple:
        raise newException(SweepGeneratorError,
          "Can only sweep simple conditions (not compound AND/OR/NOT)")

      case parsed.param
      of "left":
        if value.kind == pkString:
          targetCondition[].left = value.strVal
      of "operator", "op":
        if value.kind == pkString:
          # Parse operator string
          let opStr = value.strVal
          targetCondition[].operator = case opStr
            of "<": opLessThan
            of ">": opGreaterThan
            of "<=": opLessEqual
            of ">=": opGreaterEqual
            of "==": opEqual
            of "!=": opNotEqual
            of "crosses_above": opCrossesAbove
            of "crosses_below": opCrossesBelow
            else:
              raise newException(SweepGeneratorError,
                  &"Unknown operator: {opStr}")
      of "right":
        # Convert to string
        case value.kind
        of pkFloat:
          targetCondition[].right = $value.floatVal
        of pkInt:
          targetCondition[].right = $value.intVal
        of pkString:
          targetCondition[].right = value.strVal
        of pkBool:
          targetCondition[].right = $value.boolVal
      else:
        raise newException(SweepGeneratorError,
          &"Unknown condition parameter: {parsed.param}")

    else:
      raise newException(SweepGeneratorError,
        &"Unknown target: {parsed.target}")

proc generateSweepVariants*(
  baseStrategyFile: string,
  parameters: seq[SweepParameter]
): seq[tuple[variant: StrategyYAML, params: ParameterSet]] =
  ## Generate all strategy variants for a parameter sweep
  ## Returns a sequence of (strategy, parameter_set) tuples

  # Load base strategy
  let baseDef = parseStrategyYAMLFile(baseStrategyFile)

  # Generate parameter combinations
  let combinations = generateCombinations(parameters)

  # Generate a variant for each combination
  result = newSeq[tuple[variant: StrategyYAML, params: ParameterSet]](
      combinations.len)

  for i, paramSet in combinations:
    let variant = applyParameterSet(baseDef, paramSet)
    result[i] = (variant: variant, params: paramSet)

proc countCombinations*(parameters: seq[SweepParameter]): int =
  ## Count total number of combinations in a parameter sweep
  result = 1
  for param in parameters:
    let values = generateValues(param.range)
    result *= values.len

proc estimateSweepTime*(
  numCombinations: int,
  numSymbols: int,
  avgTimePerBacktest: float = 2.0
): float =
  ## Estimate total execution time for a parameter sweep
  ## avgTimePerBacktest is in seconds
  result = float(numCombinations * numSymbols) * avgTimePerBacktest

proc `$`*(paramSet: ParameterSet): string =
  ## Convert parameter set to string for display
  var parts: seq[string] = @[]
  for path, value in paramSet:
    parts.add(&"{path}={value}")
  result = parts.join(", ")

proc toTable*(paramSet: ParameterSet): Table[string, string] =
  ## Convert parameter set to string table for storage/display
  result = initTable[string, string]()
  for path, value in paramSet:
    result[path] = $value
