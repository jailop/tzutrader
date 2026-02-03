import std/[tables, options, strutils]
import yaml
import ../declarative/[schema as declSchema]
import schema
import alerts

type
  ScreenerParseError* = object of CatchableError
    ## Error during screener YAML parsing

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

proc parseParamValue(node: YamlNode): ParamValue =
  ## Parse a parameter value from YAML node
  ## Reuse the logic from declarative parser
  if node.kind != yScalar:
    raise newException(ScreenerParseError, "Parameter values must be scalar")

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

proc parseStrategyConfig(node: YamlNode): ScreenerStrategyConfig =
  ## Parse a single strategy configuration
  if node.kind != yMapping:
    raise newException(ScreenerParseError, "Strategy config must be a mapping")

  var kind = ""
  var name = ""
  var filePath = ""
  var params = initTable[string, ParamValue]()

  for key, val in node.fields:
    case key.content
    of "kind":
      kind = val.getStr()
    of "name":
      name = val.getStr()
    of "file_path", "filepath", "file":
      filePath = val.getStr()
    of "params":
      if val.kind == yMapping:
        for paramKey, paramVal in val.fields:
          params[paramKey.content] = parseParamValue(paramVal)
    else:
      discard

  # Determine strategy kind
  case kind.toLowerAscii()
  of "built_in", "builtin":
    if name.len == 0:
      raise newException(ScreenerParseError, "Built-in strategy must have a name")
    result = newBuiltInStrategy(name, params)

  of "yaml_file", "yamlfile", "yaml":
    if filePath.len == 0:
      raise newException(ScreenerParseError, "YAML strategy must have a file_path")
    result = newYamlStrategy(filePath)

  else:
    raise newException(ScreenerParseError, "Unknown strategy kind: " & kind & " (use 'built_in' or 'yaml_file')")

proc parseStrategies(node: YamlNode): seq[ScreenerStrategyConfig] =
  ## Parse strategies section
  result = @[]
  for strategyNode in node.getSeq():
    result.add(parseStrategyConfig(strategyNode))

proc parseDataConfig(node: YamlNode): ScreenerDataConfig =
  ## Parse data configuration section
  if node.kind != yMapping:
    raise newException(ScreenerParseError, "Data config must be a mapping")

  var source = "yahoo"

  for key, val in node.fields:
    if key.content == "source":
      source = val.getStr()
      break

  case source.toLowerAscii()
  of "yahoo", "yahoo_finance", "yfinance":
    var symbols: seq[string] = @[]
    var lookbackStr = "90d"
    var intervalStr = "1d"

    for key, val in node.fields:
      case key.content
      of "symbols":
        for sym in val.getSeq():
          symbols.add(sym.getStr())
      of "lookback":
        lookbackStr = val.getStr()
      of "interval":
        intervalStr = val.getStr()
      else:
        discard

    let lookback = parseLookbackPeriod(lookbackStr)
    let interval = parseTimeInterval(intervalStr)
    result = newYahooDataConfig(symbols, lookback, interval)

  of "coinbase", "cb":
    var pairs: seq[string] = @[]
    var lookbackStr = "7d"
    var intervalStr = "1h"

    for key, val in node.fields:
      case key.content
      of "pairs":
        for pair in val.getSeq():
          pairs.add(pair.getStr())
      of "lookback":
        lookbackStr = val.getStr()
      of "interval":
        intervalStr = val.getStr()
      else:
        discard

    let lookback = parseLookbackPeriod(lookbackStr)
    let interval = parseTimeInterval(intervalStr)
    result = newCoinbaseDataConfig(pairs, lookback, interval)

  of "csv":
    var directory = ""
    var lookbackStr = ""

    for key, val in node.fields:
      case key.content
      of "directory", "dir":
        directory = val.getStr()
      of "lookback":
        lookbackStr = val.getStr()
      else:
        discard

    let lookback = if lookbackStr.len > 0:
      some(parseLookbackPeriod(lookbackStr))
    else:
      none(LookbackPeriod)

    result = newCsvDataConfig(directory, lookback)

  else:
    raise newException(ScreenerParseError, "Unsupported data source: " &
        source & " (use 'yahoo', 'coinbase', or 'csv')")

proc parseOutputConfig(node: YamlNode): ScreenerOutputConfig =
  ## Parse output configuration section
  var format = "terminal"
  var detailLevel = "summary"
  var filepath = ""
  var saveHistory = false
  var historyDir = "screener_history"

  if node.kind == yMapping:
    for key, val in node.fields:
      case key.content
      of "format":
        format = val.getStr()
      of "detail_level", "detail":
        detailLevel = val.getStr()
      of "filepath", "file_path", "file":
        filepath = val.getStr()
      of "save_history", "saveHistory":
        saveHistory = val.getBool()
      of "history_dir", "historyDir":
        historyDir = val.getStr()
      else:
        discard

  let outputFormat = case format.toLowerAscii()
    of "terminal", "term", "console": ofTerminal
    of "csv": ofCsv
    of "json": ofJson
    of "markdown", "md": ofMarkdown
    else:
      raise newException(ScreenerParseError, "Invalid output format: " &
          format & " (use 'terminal', 'csv', 'json', or 'markdown')")

  let detail = case detailLevel.toLowerAscii()
    of "summary", "brief": dlSummary
    of "detailed", "detail", "full": dlDetailed
    else:
      raise newException(ScreenerParseError, "Invalid detail level: " &
          detailLevel & " (use 'summary' or 'detailed')")

  let path = if filepath.len > 0: some(filepath) else: none(string)

  result = ScreenerOutputConfig(
    format: outputFormat,
    detailLevel: detail,
    filepath: path,
    saveHistory: saveHistory,
    historyDir: historyDir
  )

proc parseFilters(node: YamlNode): ScreenerFilters =
  ## Parse filters configuration section
  var signalTypeStrs: seq[string] = @[]
  var minStrengthStr = "moderate"
  var topN = -1

  if node.kind == yMapping:
    for key, val in node.fields:
      case key.content
      of "signal_types", "signals":
        for typeNode in val.getSeq():
          signalTypeStrs.add(typeNode.getStr())
      of "min_strength", "strength":
        minStrengthStr = val.getStr()
      of "top_n", "topn", "top":
        topN = val.getInt()
      else:
        discard

  # Parse signal types
  var signalTypes: seq[AlertType] = @[]
  if signalTypeStrs.len > 0:
    for typeStr in signalTypeStrs:
      case typeStr.toLowerAscii()
      of "buy", "buy_signal", "buysignal":
        signalTypes.add(atBuySignal)
      of "sell", "sell_signal", "sellsignal":
        signalTypes.add(atSellSignal)
      of "exit_long", "exitlong":
        signalTypes.add(atExitLong)
      of "exit_short", "exitshort":
        signalTypes.add(atExitShort)
      of "neutral":
        signalTypes.add(atNeutral)
      else:
        raise newException(ScreenerParseError, "Invalid signal type: " & typeStr)
  else:
    # Default to buy and sell signals
    signalTypes = @[atBuySignal, atSellSignal]

  # Parse min strength
  let minStrength = case minStrengthStr.toLowerAscii()
    of "weak", "low": asWeak
    of "moderate", "medium", "mod": asModerate
    of "strong", "high": asStrong
    else:
      raise newException(ScreenerParseError, "Invalid strength: " &
          minStrengthStr & " (use 'weak', 'moderate', or 'strong')")

  let topNOption = if topN > 0: some(topN) else: none(int)

  result = newScreenerFilters(signalTypes, minStrength, topNOption)

proc parseScreenerYAML*(yamlContent: string): ScreenerConfig =
  ## Parse a complete screener configuration from YAML string
  ## Raises ScreenerParseError if parsing fails

  var root: YamlNode

  try:
    load(yamlContent, root)
  except YamlParserError as e:
    raise newException(ScreenerParseError, "YAML syntax error: " & e.msg)
  except YamlConstructionError as e:
    raise newException(ScreenerParseError, "YAML construction error: " & e.msg)

  if root.kind != yMapping:
    raise newException(ScreenerParseError, "Screener config root must be a mapping")

  # Initialize with defaults
  var metadata = MetadataYAML(name: "", description: "", tags: @[])
  var strategies: seq[ScreenerStrategyConfig] = @[]
  var dataConfig: ScreenerDataConfig
  var outputConfig = newOutputConfig()
  var filters = newScreenerFilters()

  var hasData = false

  # Parse each section
  for key, val in root.fields:
    case key.content
    of "metadata":
      # Reuse metadata parser from declarative module
      if val.kind == yMapping:
        for metaKey, metaVal in val.fields:
          case metaKey.content
          of "name":
            metadata.name = metaVal.getStr()
          of "description":
            metadata.description = metaVal.getStr()
          of "author":
            metadata.author = some(metaVal.getStr())
          of "created":
            metadata.created = some(metaVal.getStr())
          of "tags":
            for tag in metaVal.getSeq():
              metadata.tags.add(tag.getStr())
          else:
            discard

    of "strategies":
      strategies = parseStrategies(val)

    of "data":
      dataConfig = parseDataConfig(val)
      hasData = true

    of "output":
      outputConfig = parseOutputConfig(val)

    of "filters":
      filters = parseFilters(val)

    else:
      discard

  if not hasData:
    raise newException(ScreenerParseError, "Data configuration is required")

  if strategies.len == 0:
    raise newException(ScreenerParseError, "At least one strategy must be specified")

  result = newScreenerConfig(metadata, strategies, dataConfig, outputConfig, filters)

proc parseScreenerYAMLFile*(filename: string): ScreenerConfig =
  ## Parse a screener configuration from a YAML file
  let content = readFile(filename)
  result = parseScreenerYAML(content)
