## Validator for Declarative Strategy YAML
##
## This module performs semantic validation on parsed StrategyYAML objects.
## Checks for undefined references, invalid parameters, etc.

import std/[tables, sets, strutils]
import ./schema

type
  ValidationError* = object of CatchableError
    ## Semantic validation error
  
  WarningLevel* = enum
    ## Severity level for warnings
    wlInfo,      # Informational
    wlLow,       # Low severity - minor concern
    wlMedium,    # Medium severity - should consider fixing
    wlHigh       # High severity - strongly recommended to fix
  
  ValidationWarning* = object
    ## A non-blocking warning about strategy configuration
    level*: WarningLevel
    message*: string
    suggestion*: string  # Suggested fix
  
  ValidationResult* = object
    ## Result of validation with errors and warnings collected
    valid*: bool
    errors*: seq[string]
    warnings*: seq[ValidationWarning]  # Phase 2 - Feature B3

# ============================================================================
# Validation Helpers
# ============================================================================

proc newValidationResult*(): ValidationResult =
  ## Create a new validation result
  ValidationResult(valid: true, errors: @[], warnings: @[])

proc addError*(vr: var ValidationResult, msg: string) =
  ## Add an error to validation result
  vr.valid = false
  vr.errors.add(msg)

proc addWarning*(vr: var ValidationResult, level: WarningLevel, msg: string, suggestion: string = "") =
  ## Add a warning to validation result (Phase 2 - Feature B3)
  vr.warnings.add(ValidationWarning(level: level, message: msg, suggestion: suggestion))

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
      result.addError(formatError("Indicator ID cannot be empty", ind.location))
      continue
    
    if ind.id in ids:
      result.addError(formatError("Duplicate indicator ID: " & ind.id, ind.location))
    else:
      ids.incl(ind.id)
    
    if ind.indicatorType.strip() == "":
      result.addError(formatError("Indicator '" & ind.id & "' missing type", ind.location))

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
      result.addError(formatError("Undefined reference in condition: " & condition.left, condition.location))
    if not isValidRef(condition.right):
      result.addError(formatError("Undefined reference in condition: " & condition.right, condition.location))
  of ckAnd:
    if condition.andConditions.len == 0:
      result.addError(formatError("AND condition must have at least one child condition", condition.location))
    for child in condition.andConditions:
      let childResult = validateCondition(child, indicatorIds)
      if not childResult.valid:
        for err in childResult.errors:
          result.addError(err)
  of ckOr:
    if condition.orConditions.len == 0:
      result.addError(formatError("OR condition must have at least one child condition", condition.location))
    for child in condition.orConditions:
      let childResult = validateCondition(child, indicatorIds)
      if not childResult.valid:
        for err in childResult.errors:
          result.addError(err)
  of ckNot:
    result.addError(formatError("NOT conditions not supported in Phase 1", condition.location))

proc validateRule*(rule: RuleYAML, indicatorIds: HashSet[string]): ValidationResult =
  ## Validate an entry or exit rule
  result = validateCondition(rule.conditions, indicatorIds)

# Forward declaration for warning generation
proc generateWarnings*(vr: var ValidationResult, strategy: StrategyYAML)

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
  
  # Phase 2 - Feature B3: Generate warnings for risky/suboptimal configurations
  generateWarnings(result, strategy)

# ============================================================================
# Warning Generation (Phase 2 - Feature B3)
# ============================================================================

proc generateWarnings*(vr: var ValidationResult, strategy: StrategyYAML) =
  ## Generate warnings for potentially risky or suboptimal configurations
  
  # Warning: Very high position sizing
  case strategy.positionSizing.kind
  of psPercent:
    if strategy.positionSizing.percentCapital > 50:
      vr.addWarning(
        wlHigh,
        "Position size is very high (" & $strategy.positionSizing.percentCapital & "%). " &
        "This increases risk significantly.",
        "Consider reducing position size to 10-25% for better risk management"
      )
    elif strategy.positionSizing.percentCapital > 25:
      vr.addWarning(
        wlMedium,
        "Position size is above recommended range (" & $strategy.positionSizing.percentCapital & "%).",
        "Consider using 10-25% position sizing for balanced risk/reward"
      )
  of psFixed:
    # Can't determine if fixed size is too large without knowing account size
    discard
  of psDynamic:
    discard
  
  # Warning: No trend filter
  # Check if strategy uses only oscillators without trend confirmation
  var hasTrendIndicator = false
  var hasOscillator = false
  
  for ind in strategy.indicators:
    let indType = ind.indicatorType.toLowerAscii()
    
    # Trend indicators
    if indType in ["ma", "sma", "ema", "dema", "tema", "kama", "trima"]:
      hasTrendIndicator = true
    
    # Oscillators
    if indType in ["rsi", "stoch", "cci", "mfi", "cmo", "williamsr", "stochrsi"]:
      hasOscillator = true
  
  if hasOscillator and not hasTrendIndicator:
    vr.addWarning(
      wlMedium,
      "Strategy uses oscillators without trend confirmation.",
      "Consider adding a moving average or trend indicator to filter trades"
    )
  
  # Warning: Too many indicators (complexity warning)
  if strategy.indicators.len > 10:
    vr.addWarning(
      wlMedium,
      "Strategy uses many indicators (" & $strategy.indicators.len & "). " &
      "Complex strategies may overfit historical data.",
      "Consider simplifying to 3-5 key indicators"
    )
  elif strategy.indicators.len > 5:
    vr.addWarning(
      wlLow,
      "Strategy uses " & $strategy.indicators.len & " indicators. " &
      "Simpler strategies often perform better.",
      "Consider reducing to 3-5 indicators if possible"
    )
  
  # Warning: Very short indicator periods (overfitting risk)
  for ind in strategy.indicators:
    if ind.params.hasKey("period"):
      let period = ind.params["period"]
      if period.kind == pkInt and period.intVal < 5:
        vr.addWarning(
          wlMedium,
          "Indicator '" & ind.id & "' uses very short period (" & $period.intVal & "). " &
          "This may be too sensitive to noise.",
          "Consider using periods >= 5 for more stable signals"
        )
  
  # Warning: No exit strategy beyond simple threshold
  # This is informational - some strategies intentionally use simple exits
  if strategy.indicators.len == 1:
    vr.addWarning(
      wlInfo,
      "Strategy uses only one indicator. Consider adding confirmation indicators.",
      "Multi-indicator confirmation can reduce false signals"
    )
  
  # Warning: Same indicator used for entry and exit without variation
  # Check if entry and exit use the exact same conditions (potential issue)
  # This is a simplified check - just informational
  discard  # TODO: Add more sophisticated checks in future
