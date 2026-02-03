type
  IndicatorType*[T, U] = concept
    proc update(s: var Self, value: T)
    proc `[]`(s: Self, key: int): U
    proc reset(s: var Self)

  Indicator*[N: static int, T] = object
    pos*: int
    data*: array[N, T]

proc initIndicator*[N: static int, T](): Indicator[N, T] =
  result.pos = -1
  when T is float:
    for i in 0..<N:
      result.data[i] = NaN

proc reset*[N: static int, T](self: var Indicator[N, T]) =
  self.pos = -1
  when T is float:
    for i in 0..<N:
      self.data[i] = NaN

proc update*[N: static int, T](self: var Indicator[N, T], value: T) =
  if self.pos == -1:
    self.pos = 0
  else:
    self.pos = (self.pos + 1) mod N
  self.data[self.pos] = value

proc `[]`*[N: static int, T](self: Indicator[N, T], key: int): T =
  if key > 0 or -key >= N:
    raise newException(IndexDefect, "invalidad index")
  let pos = (self.pos + N + key) mod N
  result = self.data[pos]
