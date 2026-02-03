import indicators/[base, ma]

proc print(ind: IndicatorType) =
  try:
    echo ind[0]
  except:
    raise newException(IndexDefect, "invalid index")

when isMainModule:
  var m = initMA[3, 1]()
  var ind = initIndicator[1, int]()
  m.update(5.0)
  m.update(4.0)
  m.update(3.0)
  ind.update(4)
  print(m)
  print(ind)
