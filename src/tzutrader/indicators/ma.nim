import std/[math]
import base

type
  MA*[P: static int, S: static int = 1] = object
    accum*: float
    length*: int
    data*: Indicator[S, float]
    prevs*: array[P, float]
    pos*: int

proc initMA*[P: static int, S: static int = 1](): MA[P, S] =
  result.accum = 0.0
  result.length = 0
  result.pos = 0
  result.data = initIndicator[S, float]()
  for i in 0..<P:
    result.prevs[i] = NaN

proc update*[P: static int, S: static int](self: var MA[P, S], value: float) =
  if self.length < P:
    self.length += 1
  else:
    self.accum -= self.prevs[self.pos]
  self.prevs[self.pos] = value
  self.accum += value
  self.pos = (self.pos + 1) mod P
  if self.length < P:
    self.data.update(NaN)
  else:
    self.data.update(self.accum / P.float64)

proc `[]`*[P: static int, S: static int](self: MA[P, S], key: int): float =
  result = self.data[key]

proc reset*[P: static int, S: static int](self: var MA[P, S]) =
  self.length = 0
  self.accum = 0.0
  for i in 0..<P:
    self.prevs[i] = NaN
  self.data.reset()
  self.pos = 0
