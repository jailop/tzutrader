## Validator for Declarative Strategy YAML
##
## This module performs semantic validation on parsed StrategyYAML objects.
## Checks for undefined references, invalid parameters, etc.

import std/[tables, sets, strutils]
import ./schema

type
  ValidationError* = object of CatchableError
    ## Semantic validation error
  
  ValidationResult* = object
    ## Result of validation with errors collected
    valid*: bool
    errors*: seq[string]

# ============================================================================
# Validation Helpers
# ============================================================================

proc newValidationResult*(): ValidationResult =
  ## Create a new validation result
  ValidationResult(valid: true, errors: @[])

proc addError*(vr: var ValidationResult, msg: string) =
  ## Add an error to validation result
  vr.valid = false
  vr.errors.add(msg)

# ============================================================================
# Validation Functions (Stubs for Phase 1 Day 6-7)
# ============================================================================

proc validateMetadata*(metadata: MetadataYAML): ValidationResult =
  ## Validate strategy metadata
  result = newValidationResult()
  
  if metadata.name.strip() == "":
    result.addError("Strategy name cannot be empty")

proc validateIndicators*(indicators: seq[IndicatorYAML]): ValidationResult =
  ## Validate indicator definitions
  ## - Check for duplicate IDs
  ## - Check for valid indicator types (Phase 1: defer to runtime)
  ## - Check for valid parameters (Phase 1: defer to runtime)
  result = newValidationResult()
  
  var ids = initHashSet[string]()
  
  for ind in indicators:
    if ind.id.strip() == "":
      result.addError("Indicator ID cannot be empty")
      continue
    
    if ind.id in ids:
      result.addError("Duplicate indicator ID: " & ind.id)
    else:
      ids.incl(ind.id)
    
    if ind.indicatorType.strip() == "":
      result.addError("Indicator '" & ind.id & "' missing type")

proc validateCondition*(condition: ConditionYAML, indicatorIds: HashSet[string]): ValidationResult =
  ## Validate a condition
  ## - Check that referenced indicators exist
  ## - Check for empty condition lists in AND/OR
  result = newValidationResult()
  
  # Special references that are always valid
  const specialRefs = ["price", "volume", "open", "high", "low", "close"]
  
  proc isValidRef(refStr: string): bool =
    # Check if it's an indicator ID, a literal number, or a special reference
    # Also handle subfields like "macd.signal"
    if refStr in indicatorIds:
      return true
    
    # Check for subfield reference
    let parts = refStr.split('.')
    if parts.len == 2 and parts[0] in indicatorIds:
      return true  # Assume subfield is valid (runtime will validate)
    
    # Check for literal number
    if refStr[0].isDigit() or (refStr[0] == '-' and refStr.len > 1):
      return true
    
    # Check for special references
    return refStr.toLowerAscii() in specialRefs
  
  case condition.kind
  of ckSimple:
    # Check left and right references
    if not isValidRef(condition.left):
      result.addError("Undefined reference in condition: " & condition.left)
    if not isValidRef(condition.right):
      result.addError("Undefined reference in condition: " & condition.right)
  of ckAnd:
    if condition.andConditions.len == 0:
      result.addError("AND condition must have at least one child condition")
    for child in condition.andConditions:
      let childResult = validateCondition(child, indicatorIds)
      if not childResult.valid:
        for err in childResult.errors:
          result.addError(err)
  of ckOr:
    if condition.orConditions.len == 0:
      result.addError("OR condition must have at least one child condition")
    for child in condition.orConditions:
      let childResult = validateCondition(child, indicatorIds)
      if not childResult.valid:
        for err in childResult.errors:
          result.addError(err)
  of ckNot:
    result.addError("NOT conditions not supported in Phase 1")

proc validateRule*(rule: RuleYAML, indicatorIds: HashSet[string]): ValidationResult =
  ## Validate an entry or exit rule
  result = validateCondition(rule.conditions, indicatorIds)

proc validateStrategy*(strategy: StrategyYAML): ValidationResult =
  ## Validate a complete strategy
  ## Returns ValidationResult with all errors found
  result = newValidationResult()
  
  # Validate metadata
  let metaResult = validateMetadata(strategy.metadata)
  if not metaResult.valid:
    for err in metaResult.errors:
      result.addError(err)
  
  # Validate indicators
  let indResult = validateIndicators(strategy.indicators)
  if not indResult.valid:
    for err in indResult.errors:
      result.addError(err)
  
  # Build indicator ID set for reference validation
  var indicatorIds = initHashSet[string]()
  for ind in strategy.indicators:
    indicatorIds.incl(ind.id)
  
  # Validate entry rule
  let entryResult = validateRule(strategy.entryRule, indicatorIds)
  if not entryResult.valid:
    for err in entryResult.errors:
      result.addError("Entry rule: " & err)
  
  # Validate exit rule
  let exitResult = validateRule(strategy.exitRule, indicatorIds)
  if not exitResult.valid:
    for err in exitResult.errors:
      result.addError("Exit rule: " & err)
  
  # Validate position sizing
  case strategy.positionSizing.kind
  of psFixed:
    if strategy.positionSizing.fixedSize <= 0:
      result.addError("Position size must be positive")
  of psPercent:
    if strategy.positionSizing.percentCapital <= 0 or strategy.positionSizing.percentCapital > 100:
      result.addError("Percent position size must be between 0 and 100")
  of psDynamic:
    result.addError("Dynamic position sizing not yet implemented (Phase 3 feature)")
