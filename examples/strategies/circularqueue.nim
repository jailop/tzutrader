type
  CircularQueue*[T] = object
    data: seq[T]
    head, tail, count, capacity: int

proc newCircularQueue*[T](size: int): CircularQueue[T] =
  result = CircularQueue[T](
    data: newSeq[T](size),
    capacity: size,
    head: 0,
    tail: 0,
    count: 0
  )

proc isFull*(q: CircularQueue): bool =
  q.count == q.capacity

proc isEmpty*(q: CircularQueue): bool =
  q.count == 0

proc enqueue*[T](q: var CircularQueue[T], item: T) =
  if q.isFull():
    raise newException(FieldDefect, "Queue is full")
  q.data[q.tail] = item
  q.tail = (q.tail + 1) mod q.capacity
  inc q.count

proc dequeue*[T](q: var CircularQueue[T]): T =
  if q.isEmpty():
    raise newException(FieldDefect, "Queue is empty")
  let item = q.data[q.head]
  q.head = (q.head + 1) mod q.capacity
  dec q.count
  return item

proc peek*[T](q: CircularQueue[T]): T =
  ## Returns the item at the head of the queue without removing it.
  if q.isEmpty():
    raise newException(FieldDefect, "Cannot peek an empty queue")
  return q.data[q.head]
