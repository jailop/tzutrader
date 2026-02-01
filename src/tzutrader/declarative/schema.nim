## Schema Type Definitions for YAML-based Declarative Strategies
##
## This module defines the core types that represent a declarative strategy
## loaded from a YAML configuration file. These types form the abstract
## syntax tree (AST) for the strategy definition.

import std/[tables, options]

type
  # ============================================================================
  # Source Location (Phase 2 - Feature B2)
  # ============================================================================
  
  SourceLocation* = object
    ## Location in the YAML source file (for better error messages)
    line*: int
    column*: int
    
  # ============================================================================
  # Strategy Metadata
  # ============================================================================
  
  MetadataYAML* = object
    ## Strategy metadata - who, what, when
    name*: string
    description*: string
    author*: Option[string]
    created*: Option[string]
    tags*: seq[string]
  
  # ============================================================================
  # Parameters
  # ============================================================================
  
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
  
  # ============================================================================
  # Indicators
  # ============================================================================
  
  IndicatorYAML* = object
    ## Indicator definition - type and parameters
    id*: string                      # Unique identifier (e.g., "rsi_14")
    indicatorType*: string           # Type of indicator (e.g., "rsi", "macd")
    params*: Table[string, ParamValue]  # Indicator-specific parameters
    source*: Option[string]          # Data source (open/high/low/close/volume) - Phase 2
    output*: Option[string]          # Output selection for multi-output indicators - Phase 2
    location*: Option[SourceLocation]  # Source location for error reporting - Phase 2
  
  # ============================================================================
  # Conditions (Boolean Logic)
  # ============================================================================
  
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
    ckSimple,  # Simple comparison
    ckAnd,     # Boolean AND
    ckOr,      # Boolean OR
    ckNot      # Boolean NOT (Phase 3)
  
  ConditionYAML* = object
    ## A single condition in a rule
    ## Can be a simple comparison or a boolean combination
    location*: Option[SourceLocation]  # Source location for error reporting - Phase 2
    case kind*: ConditionKind
    of ckSimple:
      # Simple comparison: left op right
      left*: string                  # Reference to indicator or value
      operator*: ComparisonOp
      right*: string                 # Reference to indicator or literal value
    of ckAnd:
      # Boolean AND of multiple conditions
      andConditions*: seq[ConditionYAML]
    of ckOr:
      # Boolean OR of multiple conditions
      orConditions*: seq[ConditionYAML]
    of ckNot:
      # Boolean NOT (Phase 3 - not implemented in Phase 1)
      notCondition*: ref ConditionYAML
  
  # ============================================================================
  # Rules (Entry/Exit Logic)
  # ============================================================================
  
  RuleYAML* = object
    ## Entry or exit rule - when to take action
    conditions*: ConditionYAML
  
  # ============================================================================
  # Position Sizing
  # ============================================================================
  
  PositionSizingKind* = enum
    ## Position sizing strategy type
    psFixed,    # Fixed size (Phase 1)
    psPercent,  # Percent of capital (Phase 2)
    psDynamic   # Dynamic calculation (Phase 3)
  
  PositionSizingYAML* = object
    ## How much to trade (Phase 1: fixed size only)
    case kind*: PositionSizingKind
    of psFixed:
      fixedSize*: float            # Fixed position size (e.g., 100.0 shares)
    of psPercent:                  # Phase 2+
      percentCapital*: float
    of psDynamic:                  # Phase 3+
      dynamicExpr*: string
  
  # ============================================================================
  # Complete Strategy Definition
  # ============================================================================
  
  StrategyYAML* = object
    ## Complete declarative strategy definition
    metadata*: MetadataYAML
    indicators*: seq[IndicatorYAML]
    entryRule*: RuleYAML
    exitRule*: RuleYAML
    positionSizing*: PositionSizingYAML

# ============================================================================
# Helper Constructors
# ============================================================================

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

proc newSimpleCondition*(left: string, op: ComparisonOp, right: string): ConditionYAML =
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

# ============================================================================
# Display/Debug Helpers
# ============================================================================

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

proc formatError*(msg: string, loc: Option[SourceLocation] = none(SourceLocation)): string =
  ## Format an error message with optional location information
  if loc.isSome():
    let l = loc.get()
    result = "[" & $l & "] " & msg
  else:
    result = msg
