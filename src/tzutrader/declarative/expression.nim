## Expression Parser and Evaluator for Custom Indicators
##
## This module provides a simple expression language for creating custom indicators
## and dynamic position sizing in YAML strategies (Phase 3).
##
## Supported operations:
## - Arithmetic: +, -, *, /, (, )
## - Comparison: <, >, <=, >=, ==, !=
## - Logical: and, or, not
## - Functions: abs, max, min, sqrt
## - References: indicator_id, price, volume, etc.
##
## Examples:
##   (rsi_14 + rsi_21) / 2                  # Average of two RSIs
##   price * volume / 1000                   # Simplified dollar volume
##   (rsi_14 < 30) and (price > sma_200)    # Boolean expression
##   abs(macd - macd.signal)                 # Absolute MACD histogram

import std/[strutils, tables, math, strscans]

type
  ExprKind* = enum
    ekLiteral,      # Numeric literal
    ekReference,    # Reference to indicator or special value
    ekBinary,       # Binary operation (+, -, *, /, <, >, etc.)
    ekUnary,        # Unary operation (-, not, abs, sqrt)
    ekFunction      # Function call (max, min)
  
  BinaryOp* = enum
    boAdd, boSub, boMul, boDiv,
    boLess, boGreater, boLessEq, boGreaterEq, boEqual, boNotEqual,
    boAnd, boOr
  
  UnaryOp* = enum
    uoNegate, uoNot, uoAbs, uoSqrt
  
  FunctionOp* = enum
    foMax, foMin
  
  ExprNode* = ref object
    case kind*: ExprKind
    of ekLiteral:
      value*: float64
    of ekReference:
      refName*: string
    of ekBinary:
      op*: BinaryOp
      left*: ExprNode
      right*: ExprNode
    of ekUnary:
      unaryOp*: UnaryOp
      operand*: ExprNode
    of ekFunction:
      funcOp*: FunctionOp
      args*: seq[ExprNode]
  
  ParseError* = object of CatchableError
  EvalError* = object of CatchableError

# ============================================================================
# Tokenizer
# ============================================================================

type
  TokenKind = enum
    tkNumber, tkIdent, tkPlus, tkMinus, tkStar, tkSlash,
    tkLParen, tkRParen, tkComma,
    tkLess, tkGreater, tkLessEq, tkGreaterEq, tkEqual, tkNotEqual,
    tkAnd, tkOr, tkNot,
    tkEOF
  
  Token = object
    kind: TokenKind
    value: string
    floatVal: float64

proc tokenize(input: string): seq[Token] =
  result = @[]
  var i = 0
  
  while i < input.len:
    let c = input[i]
    
    # Skip whitespace
    if c in Whitespace:
      inc i
      continue
    
    # Numbers
    if c.isDigit or (c == '.' and i + 1 < input.len and input[i + 1].isDigit):
      var numStr = ""
      while i < input.len and (input[i].isDigit or input[i] == '.'):
        numStr.add(input[i])
        inc i
      try:
        let val = parseFloat(numStr)
        result.add(Token(kind: tkNumber, value: numStr, floatVal: val))
      except ValueError:
        raise newException(ParseError, "Invalid number: " & numStr)
      continue
    
    # Identifiers and keywords
    if c.isAlphaAscii or c == '_':
      var ident = ""
      while i < input.len and (input[i].isAlphaNumeric or input[i] in ['_', '.']):
        ident.add(input[i])
        inc i
      
      # Check for keywords
      case ident.toLowerAscii()
      of "and":
        result.add(Token(kind: tkAnd, value: ident))
      of "or":
        result.add(Token(kind: tkOr, value: ident))
      of "not":
        result.add(Token(kind: tkNot, value: ident))
      else:
        result.add(Token(kind: tkIdent, value: ident))
      continue
    
    # Operators and punctuation
    case c
    of '+':
      result.add(Token(kind: tkPlus, value: "+"))
      inc i
    of '-':
      result.add(Token(kind: tkMinus, value: "-"))
      inc i
    of '*':
      result.add(Token(kind: tkStar, value: "*"))
      inc i
    of '/':
      result.add(Token(kind: tkSlash, value: "/"))
      inc i
    of '(':
      result.add(Token(kind: tkLParen, value: "("))
      inc i
    of ')':
      result.add(Token(kind: tkRParen, value: ")"))
      inc i
    of ',':
      result.add(Token(kind: tkComma, value: ","))
      inc i
    of '<':
      if i + 1 < input.len and input[i + 1] == '=':
        result.add(Token(kind: tkLessEq, value: "<="))
        inc i, 2
      else:
        result.add(Token(kind: tkLess, value: "<"))
        inc i
    of '>':
      if i + 1 < input.len and input[i + 1] == '=':
        result.add(Token(kind: tkGreaterEq, value: ">="))
        inc i, 2
      else:
        result.add(Token(kind: tkGreater, value: ">"))
        inc i
    of '=':
      if i + 1 < input.len and input[i + 1] == '=':
        result.add(Token(kind: tkEqual, value: "=="))
        inc i, 2
      else:
        raise newException(ParseError, "Invalid operator: =  (use == for equality)")
    of '!':
      if i + 1 < input.len and input[i + 1] == '=':
        result.add(Token(kind: tkNotEqual, value: "!="))
        inc i, 2
      else:
        raise newException(ParseError, "Invalid operator: !  (use 'not' for logical NOT)")
    else:
      raise newException(ParseError, "Unexpected character: " & $c)
  
  result.add(Token(kind: tkEOF, value: ""))

# ============================================================================
# Recursive Descent Parser
# ============================================================================

type
  Parser = object
    tokens: seq[Token]
    pos: int

proc peek(p: Parser): Token =
  if p.pos < p.tokens.len:
    p.tokens[p.pos]
  else:
    Token(kind: tkEOF, value: "")

proc advance(p: var Parser): Token =
  result = p.peek()
  if p.pos < p.tokens.len:
    inc p.pos

proc parseExpr(p: var Parser): ExprNode
proc parsePrimary(p: var Parser): ExprNode

proc parsePrimary(p: var Parser): ExprNode =
  let tok = p.peek()
  
  case tok.kind
  of tkNumber:
    discard p.advance()
    result = ExprNode(kind: ekLiteral, value: tok.floatVal)
  
  of tkIdent:
    discard p.advance()
    # Check if it's a function call
    if p.peek().kind == tkLParen:
      # Function call
      discard p.advance()  # consume '('
      var args: seq[ExprNode] = @[]
      
      if p.peek().kind != tkRParen:
        args.add(p.parseExpr())
        while p.peek().kind == tkComma:
          discard p.advance()  # consume ','
          args.add(p.parseExpr())
      
      if p.peek().kind != tkRParen:
        raise newException(ParseError, "Expected ')' after function arguments")
      discard p.advance()  # consume ')'
      
      # Determine function type
      case tok.value.toLowerAscii()
      of "max":
        result = ExprNode(kind: ekFunction, funcOp: foMax, args: args)
      of "min":
        result = ExprNode(kind: ekFunction, funcOp: foMin, args: args)
      of "abs":
        if args.len != 1:
          raise newException(ParseError, "abs() expects 1 argument")
        result = ExprNode(kind: ekUnary, unaryOp: uoAbs, operand: args[0])
      of "sqrt":
        if args.len != 1:
          raise newException(ParseError, "sqrt() expects 1 argument")
        result = ExprNode(kind: ekUnary, unaryOp: uoSqrt, operand: args[0])
      else:
        raise newException(ParseError, "Unknown function: " & tok.value)
    else:
      # Simple reference
      result = ExprNode(kind: ekReference, refName: tok.value)
  
  of tkLParen:
    discard p.advance()  # consume '('
    result = p.parseExpr()
    if p.peek().kind != tkRParen:
      raise newException(ParseError, "Expected ')'")
    discard p.advance()  # consume ')'
  
  of tkMinus:
    discard p.advance()
    result = ExprNode(kind: ekUnary, unaryOp: uoNegate, operand: p.parsePrimary())
  
  of tkNot:
    discard p.advance()
    result = ExprNode(kind: ekUnary, unaryOp: uoNot, operand: p.parsePrimary())
  
  else:
    raise newException(ParseError, "Unexpected token: " & tok.value)

proc parseMulDiv(p: var Parser): ExprNode =
  result = p.parsePrimary()
  
  while p.peek().kind in [tkStar, tkSlash]:
    let opTok = p.advance()
    let right = p.parsePrimary()
    let op = if opTok.kind == tkStar: boMul else: boDiv
    result = ExprNode(kind: ekBinary, op: op, left: result, right: right)

proc parseAddSub(p: var Parser): ExprNode =
  result = p.parseMulDiv()
  
  while p.peek().kind in [tkPlus, tkMinus]:
    let opTok = p.advance()
    let right = p.parseMulDiv()
    let op = if opTok.kind == tkPlus: boAdd else: boSub
    result = ExprNode(kind: ekBinary, op: op, left: result, right: right)

proc parseComparison(p: var Parser): ExprNode =
  result = p.parseAddSub()
  
  while p.peek().kind in [tkLess, tkGreater, tkLessEq, tkGreaterEq, tkEqual, tkNotEqual]:
    let opTok = p.advance()
    let right = p.parseAddSub()
    let op = case opTok.kind
      of tkLess: boLess
      of tkGreater: boGreater
      of tkLessEq: boLessEq
      of tkGreaterEq: boGreaterEq
      of tkEqual: boEqual
      of tkNotEqual: boNotEqual
      else: boEqual  # Should never happen
    result = ExprNode(kind: ekBinary, op: op, left: result, right: right)

proc parseAnd(p: var Parser): ExprNode =
  result = p.parseComparison()
  
  while p.peek().kind == tkAnd:
    discard p.advance()
    let right = p.parseComparison()
    result = ExprNode(kind: ekBinary, op: boAnd, left: result, right: right)

proc parseOr(p: var Parser): ExprNode =
  result = p.parseAnd()
  
  while p.peek().kind == tkOr:
    discard p.advance()
    let right = p.parseAnd()
    result = ExprNode(kind: ekBinary, op: boOr, left: result, right: right)

proc parseExpr(p: var Parser): ExprNode =
  result = p.parseOr()

proc parseExpression*(input: string): ExprNode =
  ## Parse an expression string into an AST
  var p = Parser(tokens: tokenize(input), pos: 0)
  result = p.parseExpr()
  
  if p.peek().kind != tkEOF:
    raise newException(ParseError, "Unexpected tokens after expression")

# ============================================================================
# Evaluator
# ============================================================================

proc evaluateExpression*(node: ExprNode, values: Table[string, float64]): float64 =
  ## Evaluate an expression tree with given variable values
  ## Returns NaN if any reference is undefined or NaN
  
  case node.kind
  of ekLiteral:
    result = node.value
  
  of ekReference:
    if not values.hasKey(node.refName):
      raise newException(EvalError, "Undefined reference: " & node.refName)
    result = values[node.refName]
  
  of ekBinary:
    let left = evaluateExpression(node.left, values)
    let right = evaluateExpression(node.right, values)
    
    # Handle NaN propagation
    if left.isNaN or right.isNaN:
      return NaN
    
    case node.op
    of boAdd: result = left + right
    of boSub: result = left - right
    of boMul: result = left * right
    of boDiv:
      if right == 0.0:
        return NaN  # Division by zero
      result = left / right
    of boLess: result = if left < right: 1.0 else: 0.0
    of boGreater: result = if left > right: 1.0 else: 0.0
    of boLessEq: result = if left <= right: 1.0 else: 0.0
    of boGreaterEq: result = if left >= right: 1.0 else: 0.0
    of boEqual: result = if abs(left - right) < 1e-9: 1.0 else: 0.0
    of boNotEqual: result = if abs(left - right) >= 1e-9: 1.0 else: 0.0
    of boAnd: result = if (left != 0.0) and (right != 0.0): 1.0 else: 0.0
    of boOr: result = if (left != 0.0) or (right != 0.0): 1.0 else: 0.0
  
  of ekUnary:
    let operand = evaluateExpression(node.operand, values)
    
    if operand.isNaN:
      return NaN
    
    case node.unaryOp
    of uoNegate: result = -operand
    of uoNot: result = if operand == 0.0: 1.0 else: 0.0
    of uoAbs: result = abs(operand)
    of uoSqrt:
      if operand < 0.0:
        return NaN
      result = sqrt(operand)
  
  of ekFunction:
    var argVals: seq[float64] = @[]
    for arg in node.args:
      let val = evaluateExpression(arg, values)
      if val.isNaN:
        return NaN
      argVals.add(val)
    
    if argVals.len == 0:
      raise newException(EvalError, "Function requires at least one argument")
    
    case node.funcOp
    of foMax: result = max(argVals)
    of foMin: result = min(argVals)
