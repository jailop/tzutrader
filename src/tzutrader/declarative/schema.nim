import std/[tables, options]

type
  SourceLocation* = object
    ## Location in the YAML source file (for better error messages)
    line*: int
    column*: int

  MetadataYAML* = object
    ## Strategy metadata - who, what, when
    name*: string
    description*: string
    author*: Option[string]
    created*: Option[string]
    tags*: seq[string]

  ParamKind* = enum
    ## Parameter value type discriminator
    pkInt, pkFloat, pkString, pkBool

  ParamValue* = object
    ## Parameter value - can be int, float, string, or bool
    case kind*: ParamKind
    of pkInt:
      intVal*: int
    of pkFloat:
      floatVal*: float
    of pkString:
      strVal*: string
    of pkBool:
      boolVal*: bool

  IndicatorYAML* = object
    ## Indicator definition - type and parameters
    id*: string                        # Unique identifier (e.g., "rsi_14")
    indicatorType*: string             # Type of indicator (e.g., "rsi", "macd")
    params*: Table[string, ParamValue] # Indicator-specific parameters
    source*: Option[string]            # Data source (open/high/low/close/volume) - Phase 2
    output*: Option[string]            # Output selection for multi-output indicators - Phase 2
    location*: Option[SourceLocation]  # Source location for error reporting - Phase 2

  ComparisonOp* = enum
    ## Comparison operators for conditions
    opLessThan = "<"
    opGreaterThan = ">"
    opLessEqual = "<="
    opGreaterEqual = ">="
    opEqual = "=="
    opNotEqual = "!="
    opCrossesAbove = "crosses_above"
    opCrossesBelow = "crosses_below"

  ConditionKind* = enum
    ## Discriminator for condition types
    ckSimple, # Simple comparison
    ckAnd,    # Boolean AND
    ckOr,     # Boolean OR
    ckNot     # Boolean NOT (Phase 3)

  ConditionYAML* = object
    ## A single condition in a rule
    ## Can be a simple comparison or a boolean combination
    location*: Option[SourceLocation] # Source location for error reporting - Phase 2
    case kind*: ConditionKind
    of ckSimple:
      # Simple comparison: left op right
      left*: string # Reference to indicator or value
      operator*: ComparisonOp
      right*: string # Reference to indicator or literal value
    of ckAnd:
      # Boolean AND of multiple conditions
      andConditions*: seq[ConditionYAML]
    of ckOr:
      # Boolean OR of multiple conditions
      orConditions*: seq[ConditionYAML]
    of ckNot:
      # Boolean NOT (Phase 3 - not implemented in Phase 1)
      notCondition*: ref ConditionYAML

  RuleYAML* = object
    ## Entry or exit rule - when to take action
    conditions*: ConditionYAML

  PositionSizingKind* = enum
    ## Position sizing strategy type
    psFixed,   # Fixed size (Phase 1)
    psPercent, # Percent of capital (Phase 2)
    psDynamic  # Dynamic calculation (Phase 3)

  PositionSizingYAML* = object
    ## How much to trade (Phase 1: fixed size only)
    case kind*: PositionSizingKind
    of psFixed:
      fixedSize*: float # Fixed position size (e.g., 100.0 shares)
    of psPercent:       # Phase 2+
      percentCapital*: float
    of psDynamic:       # Phase 3+
      dynamicExpr*: string

  StrategyYAML* = object
    ## Complete declarative strategy definition
    metadata*: MetadataYAML
    indicators*: seq[IndicatorYAML]
    entryRule*: RuleYAML
    exitRule*: RuleYAML
    positionSizing*: PositionSizingYAML

  DataSourceKind* = enum
    ## Type of data source
    dsYahoo,   # Yahoo Finance
    dsCsv,     # CSV file
    dsCoinbase # Coinbase (future)

  DataConfigYAML* = object
    ## Data source configuration for batch tests
    case source*: DataSourceKind
    of dsYahoo:
      symbols*: seq[string]
      startDate*: string
      endDate*: string
    of dsCsv:
      csvFile*: string
    of dsCoinbase:
      coinbaseSymbols*: seq[string]
      coinbaseStart*: string
      coinbaseEnd*: string

  PortfolioConfigYAML* = object
    ## Portfolio configuration
    initialCash*: float
    commission*: float
    minCommission*: Option[float]
    riskFreeRate*: Option[float]

  IndicatorOverride* = object
    ## Override for a single indicator parameter
    params*: Table[string, ParamValue]

  ConditionOverride* = object
    ## Override for entry/exit conditions
    entry*: Option[ConditionYAML]
    exit*: Option[ConditionYAML]

  StrategyOverrides* = object
    ## Parameter overrides for a strategy variant
    indicators*: Option[Table[string, IndicatorOverride]]
    conditions*: Option[ConditionOverride]
    positionSizing*: Option[PositionSizingYAML]

  StrategyVariantYAML* = object
    ## A strategy with optional parameter overrides
    file*: string                         # Path to strategy YAML file
    name*: string                         # Unique name for this variant
    overrides*: Option[StrategyOverrides] # Parameter overrides

  BatchOutputYAML* = object
    ## Output configuration for batch tests
    comparisonReport*: Option[string]  # HTML comparison report path
    individualResults*: Option[string] # Directory for individual CSVs
    formats*: seq[string]              # Output formats: csv, json, html

  BatchTestYAML* = object
    ## Complete batch test configuration
    version*: string
    metadata*: MetadataYAML
    data*: DataConfigYAML
    strategies*: seq[StrategyVariantYAML]
    portfolio*: PortfolioConfigYAML
    output*: BatchOutputYAML

  SweepRangeKind* = enum
    ## Type of parameter sweep range
    srkLinear, # Linear range with step
    srkList    # Explicit list of values

  SweepRange* = object
    ## Range of values for parameter sweep
    case kind*: SweepRangeKind
    of srkLinear:
      min*: float
      max*: float
      step*: float
    of srkList:
      values*: seq[float]

  SweepParameter* = object
    ## Parameter to sweep
    path*: string      # JSON path to parameter (e.g., "indicators.rsi_14.period")
    range*: SweepRange # Range of values

  SweepOutputYAML* = object
    ## Output configuration for parameter sweeps
    heatmap*: Option[string] # Heatmap visualization path
    bestResults*: string     # Top N results CSV
    fullResults*: string     # All results CSV

  ParameterSweepYAML* = object
    ## Complete parameter sweep configuration
    version*: string
    metadata*: MetadataYAML
    baseStrategy*: string            # Base strategy file path
    data*: DataConfigYAML
    portfolio*: PortfolioConfigYAML
    parameters*: seq[SweepParameter] # Parameters to sweep
    output*: SweepOutputYAML

proc newParamInt*(val: int): ParamValue =
  ## Create an integer parameter
  ParamValue(kind: pkInt, intVal: val)

proc newParamFloat*(val: float): ParamValue =
  ## Create a float parameter
  ParamValue(kind: pkFloat, floatVal: val)

proc newParamString*(val: string): ParamValue =
  ## Create a string parameter
  ParamValue(kind: pkString, strVal: val)

proc newParamBool*(val: bool): ParamValue =
  ## Create a boolean parameter
  ParamValue(kind: pkBool, boolVal: val)

proc newSimpleCondition*(left: string, op: ComparisonOp,
    right: string): ConditionYAML =
  ## Create a simple comparison condition
  ConditionYAML(
    kind: ckSimple,
    left: left,
    operator: op,
    right: right
  )

proc newAndCondition*(conditions: seq[ConditionYAML]): ConditionYAML =
  ## Create a boolean AND condition
  ConditionYAML(
    kind: ckAnd,
    andConditions: conditions
  )

proc newOrCondition*(conditions: seq[ConditionYAML]): ConditionYAML =
  ## Create a boolean OR condition
  ConditionYAML(
    kind: ckOr,
    orConditions: conditions
  )

proc newNotCondition*(condition: ConditionYAML): ConditionYAML =
  ## Create a boolean NOT condition
  var condRef = new(ConditionYAML)
  condRef[] = condition
  ConditionYAML(
    kind: ckNot,
    notCondition: condRef
  )

proc newDataConfigYahoo*(symbols: seq[string], startDate: string,
    endDate: string): DataConfigYAML =
  ## Create a Yahoo Finance data configuration
  DataConfigYAML(
    source: dsYahoo,
    symbols: symbols,
    startDate: startDate,
    endDate: endDate
  )

proc newDataConfigCsv*(csvFile: string): DataConfigYAML =
  ## Create a CSV data configuration
  DataConfigYAML(
    source: dsCsv,
    csvFile: csvFile
  )

proc newPortfolioConfig*(initialCash: float = 100000.0,
                        commission: float = 0.001,
                        minCommission: Option[float] = none(float),
                        riskFreeRate: Option[float] = none(
                            float)): PortfolioConfigYAML =
  ## Create a portfolio configuration with sensible defaults
  PortfolioConfigYAML(
    initialCash: initialCash,
    commission: commission,
    minCommission: minCommission,
    riskFreeRate: riskFreeRate
  )

proc newStrategyVariant*(file: string,
                        name: string,
                        overrides: Option[StrategyOverrides] = none(
                            StrategyOverrides)): StrategyVariantYAML =
  ## Create a strategy variant
  StrategyVariantYAML(
    file: file,
    name: name,
    overrides: overrides
  )

proc newBatchOutput*(formats: seq[string] = @["csv"],
                    comparisonReport: Option[string] = none(string),
                    individualResults: Option[string] = none(
                        string)): BatchOutputYAML =
  ## Create batch output configuration
  BatchOutputYAML(
    formats: formats,
    comparisonReport: comparisonReport,
    individualResults: individualResults
  )

proc newSweepRangeLinear*(min: float, max: float, step: float): SweepRange =
  ## Create a linear parameter sweep range
  SweepRange(
    kind: srkLinear,
    min: min,
    max: max,
    step: step
  )

proc newSweepRangeList*(values: seq[float]): SweepRange =
  ## Create a list-based parameter sweep range
  SweepRange(
    kind: srkList,
    values: values
  )

proc newSweepParameter*(path: string, range: SweepRange): SweepParameter =
  ## Create a sweep parameter
  SweepParameter(
    path: path,
    range: range
  )

proc `$`*(p: ParamValue): string =
  ## Convert parameter to string for debugging
  case p.kind
  of pkInt: $p.intVal
  of pkFloat: $p.floatVal
  of pkString: p.strVal
  of pkBool: $p.boolVal

proc `$`*(op: ComparisonOp): string =
  ## Convert operator to string
  case op
  of opLessThan: "<"
  of opGreaterThan: ">"
  of opLessEqual: "<="
  of opGreaterEqual: ">="
  of opEqual: "=="
  of opNotEqual: "!="
  of opCrossesAbove: "crosses_above"
  of opCrossesBelow: "crosses_below"

proc `$`*(loc: SourceLocation): string =
  ## Convert source location to string (line:column format)
  "line " & $loc.line & ", column " & $loc.column

proc formatError*(msg: string, loc: Option[SourceLocation] = none(
    SourceLocation)): string =
  ## Format an error message with optional location information
  if loc.isSome():
    let l = loc.get()
    result = "[" & $l & "] " & msg
  else:
    result = msg
