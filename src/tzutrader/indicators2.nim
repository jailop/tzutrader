import std/[math, deques]

type
  IndicatorType[T, U] = concept
    proc update(s: var Self, value: T)
    proc `[]`(s: Self, key: int): U
    proc reset(s: var Self)

  Indicator*[T] = object
    size*: int
    pos*: int
    data*: seq[T]

  IndicatorFloat* = Indicator[float]

  MA* = object
    periods*: int
    accum*: float
    length*: int
    data*: IndicatorFloat
    prevs*: seq[float]
    pos*: int

proc newIndicator*[T](size: int): Indicator[T] =
  result = Indicator[T](
    size: size,
    pos: -1,
    data: newSeq[T](size)
  )
  # result.reset()

proc reset*[T](self: var Indicator[T]) =
  self.pos = -1
  when T is float:
    for i in 0..<self.size:
      self.data[i] = NaN

proc newIndicatorFloat*(size: int): IndicatorFloat =
  result = newIndicator[float](size)

proc update*[T](self: var Indicator[T], value: T) =
  if self.pos == -1:
    self.pos = 0
  else:
    self.pos = (self.pos + 1) mod self.size
  self.data[self.pos] = value

proc `[]`*[T](self: Indicator[T], key: int): T =
  if key > 0 or -key >= self.size:
    raise newException(IndexDefect, "invalidad index")
  let pos = (self.pos + self.size + key) mod (self.size)
  result = self.data[pos]

proc newMA(periods: int, size: int = 1): MA =
  result = MA(
    periods: periods,
    length: 0,
    accum: 0.0,
    data: newIndicatorFloat(size),
    prevs: newSeq[float](periods),
    pos: 0
  )

proc update*(self: var MA, value: float) =
  if self.length < self.periods:
    self.length += 1
  else:
    self.accum -= self.prevs[self.pos]
  self.prevs[self.pos] = value
  self.accum += value
  self.pos = (self.pos + 1) mod self.periods
  if self.length < self.periods:
    self.data.update(NaN)
  else:
    self.data.update(self.accum / self.periods.float64)

proc `[]`*(self: MA, key: int): float =
  result = self.data[key]

proc reset(self: var MA) =
  self.length = 0
  self.accum = 0.0
  for i in 0..<self.periods:
    self.prevs[i] = NaN
  self.data.reset()
  self.pos = -1

proc print(ind: IndicatorType) =
  echo ind[0]

when isMainModule:
  var ma = newMA(2)
  var ind = newIndicatorFloat(1)
  ma.update(5.0)
  ma.update(4.0)
  ind.update(4.0)
  print(ma)
  print(ind)
