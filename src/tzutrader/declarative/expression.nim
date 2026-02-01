## Expression Parser and Evaluator for Custom Indicators
##
## This module provides a safe, sandboxed expression evaluator for creating
## custom indicators using simple mathematical and logical expressions.
##
## Supported operators: +, -, *, /, <, >, <=, >=, ==, !=, and, or, not
## Supported functions: abs, min, max, sqrt, pow
##
## Safety features:
## - No file I/O, network access, or system calls
## - Whitelist-only approach (only explicitly allowed operations)
## - Resource limits to prevent infinite loops
## - All evaluation is pure (no side effects)
##
## Phase 3 Feature

import std/[tables, strutils, math]

type
  TokenKind* = enum
    tkNumber,      # Numeric literal
    tkIdentifier,  # Indicator name or variable
    tkOperator,    # +, -, *, /, <, >, etc.
    tkLParen,      # (
    tkRParen,      # )
    tkEOF          # End of input
  
  Token* = object
    kind*: TokenKind
    value*: string
    position*: int
  
  ExprKind* = enum
    exNumber,      # Numeric constant
    exIdentifier,  # Variable/indicator reference
    exBinary,      # Binary operation (left op right)
    exUnary,       # Unary operation (op expr)
    exFunction     # Function call
  
  ExprNode* = ref object
    case kind*: ExprKind
    of exNumber:
      numValue*: float64
    of exIdentifier:
      name*: string
    of exBinary:
      operator*: string
      left*, right*: ExprNode
    of exUnary:
      unaryOp*: string
      operand*: ExprNode
    of exFunction:
      funcName*: string
      args*: seq[ExprNode]
  
  ExpressionError* = object of CatchableError
    ## Error during expression parsing or evaluation

# ============================================================================
# Tokenizer
# ============================================================================

proc isOperatorChar(c: char): bool {.inline.} =
  c in {'+', '-', '*', '/', '<', '>', '=', '!'}

proc tokenize*(input: string): seq[Token] =
  ## Convert input string into tokens
  result = @[]
  var i = 0
  
  while i < input.len:
    let c = input[i]
    
    # Skip whitespace
    if c in {' ', '\t', '\n', '\r'}:
      inc i
      continue
    
    # Numbers (including decimal)
    if c.isDigit or (c == '.' and i + 1 < input.len and input[i + 1].isDigit):
      var numStr = ""
      while i < input.len and (input[i].isDigit or input[i] == '.'):
        numStr.add(input[i])
        inc i
      result.add(Token(kind: tkNumber, value: numStr, position: i - numStr.len))
      continue
    
    # Identifiers (indicator names, keywords)
    if c.isAlphaAscii or c == '_':
      var idStr = ""
      while i < input.len and (input[i].isAlphaNumeric or input[i] in {'_', '[', ']'}):
        idStr.add(input[i])
        inc i
      result.add(Token(kind: tkIdentifier, value: idStr, position: i - idStr.len))
      continue
    
    # Operators
    if c.isOperatorChar():
      var opStr = $c
      inc i
      # Check for multi-char operators (<=, >=, ==, !=)
      if i < input.len and input[i].isOperatorChar():
        opStr.add(input[i])
        inc i
      result.add(Token(kind: tkOperator, value: opStr, position: i - opStr.len))
      continue
    
    # Parentheses and comma
    if c == '(':
      result.add(Token(kind: tkLParen, value: "(", position: i))
      inc i
      continue
    
    if c == ')':
      result.add(Token(kind: tkRParen, value: ")", position: i))
      inc i
      continue
    
    if c == ',':
      result.add(Token(kind: tkOperator, value: ",", position: i))
      inc i
      continue
    
    # Unknown character
    raise newException(ExpressionError, "Unexpected character '" & $c & "' at position " & $i)
  
  # Add EOF token
  result.add(Token(kind: tkEOF, value: "", position: input.len))

# ============================================================================
# Parser (Recursive Descent with Operator Precedence)
# ============================================================================

type
  Parser = object
    tokens: seq[Token]
    pos: int

proc peek(p: Parser): Token {.inline.} =
  if p.pos < p.tokens.len:
    p.tokens[p.pos]
  else:
    p.tokens[^1]  # EOF

proc advance(p: var Parser): Token =
  result = p.peek()
  inc p.pos

proc expect(p: var Parser, kind: TokenKind): Token =
  let tok = p.advance()
  if tok.kind != kind:
    raise newException(ExpressionError, "Expected " & $kind & " but got " & $tok.kind)
  result = tok

proc parseExpression(p: var Parser): ExprNode
proc parsePrimary(p: var Parser): ExprNode

proc parsePrimary(p: var Parser): ExprNode =
  ## Parse primary expression: number, identifier, function, or parenthesized expr
  let tok = p.peek()
  
  case tok.kind
  of tkNumber:
    discard p.advance()
    try:
      result = ExprNode(kind: exNumber, numValue: parseFloat(tok.value))
    except ValueError:
      raise newException(ExpressionError, "Invalid number: " & tok.value)
  
  of tkIdentifier:
    discard p.advance()
    let name = tok.value
    
    # Check if it's a function call
    if p.peek().kind == tkLParen:
      discard p.advance()  # Consume '('
      
      var args: seq[ExprNode] = @[]
      
      # Parse arguments
      if p.peek().kind != tkRParen:
        args.add(p.parseExpression())
        
        while p.peek().kind == tkOperator and p.peek().value == ",":
          discard p.advance()  # Consume ','
          args.add(p.parseExpression())
      
      discard p.expect(tkRParen)
      result = ExprNode(kind: exFunction, funcName: name, args: args)
    else:
      # Simple identifier
      result = ExprNode(kind: exIdentifier, name: name)
  
  of tkLParen:
    discard p.advance()  # Consume '('
    result = p.parseExpression()
    discard p.expect(tkRParen)
  
  of tkOperator:
    # Unary operator (-, not)
    discard p.advance()
    let op = tok.value
    if op in ["-", "!"]:
      let operand = p.parsePrimary()
      result = ExprNode(kind: exUnary, unaryOp: op, operand: operand)
    else:
      raise newException(ExpressionError, "Unexpected operator: " & op)
  
  else:
    raise newException(ExpressionError, "Unexpected token: " & $tok.kind)

proc parseUnary(p: var Parser): ExprNode =
  ## Parse unary expressions
  let tok = p.peek()
  if tok.kind == tkOperator and tok.value in ["-", "not", "!"]:
    discard p.advance()
    let operand = p.parseUnary()
    result = ExprNode(kind: exUnary, unaryOp: tok.value, operand: operand)
  else:
    result = p.parsePrimary()

proc parseMultiplicative(p: var Parser): ExprNode =
  ## Parse *, / operators (higher precedence)
  result = p.parseUnary()
  
  while p.peek().kind == tkOperator and p.peek().value in ["*", "/"]:
    let op = p.advance().value
    let right = p.parseUnary()
    result = ExprNode(kind: exBinary, operator: op, left: result, right: right)

proc parseAdditive(p: var Parser): ExprNode =
  ## Parse +, - operators
  result = p.parseMultiplicative()
  
  while p.peek().kind == tkOperator and p.peek().value in ["+", "-"]:
    let op = p.advance().value
    let right = p.parseMultiplicative()
    result = ExprNode(kind: exBinary, operator: op, left: result, right: right)

proc parseComparison(p: var Parser): ExprNode =
  ## Parse comparison operators: <, >, <=, >=, ==, !=
  result = p.parseAdditive()
  
  while p.peek().kind == tkOperator and p.peek().value in ["<", ">", "<=", ">=", "==", "!="]:
    let op = p.advance().value
    let right = p.parseAdditive()
    result = ExprNode(kind: exBinary, operator: op, left: result, right: right)

proc parseLogicalAnd(p: var Parser): ExprNode =
  ## Parse 'and' operator
  result = p.parseComparison()
  
  while p.peek().kind == tkIdentifier and p.peek().value == "and":
    discard p.advance()
    let right = p.parseComparison()
    result = ExprNode(kind: exBinary, operator: "and", left: result, right: right)

proc parseLogicalOr(p: var Parser): ExprNode =
  ## Parse 'or' operator (lowest precedence)
  result = p.parseLogicalAnd()
  
  while p.peek().kind == tkIdentifier and p.peek().value == "or":
    discard p.advance()
    let right = p.parseLogicalAnd()
    result = ExprNode(kind: exBinary, operator: "or", left: result, right: right)

proc parseExpression(p: var Parser): ExprNode =
  ## Parse full expression
  result = p.parseLogicalOr()

proc parse*(tokens: seq[Token]): ExprNode =
  ## Parse token stream into expression tree
  var parser = Parser(tokens: tokens, pos: 0)
  result = parser.parseExpression()
  
  # Ensure we consumed all tokens (except EOF)
  if parser.peek().kind != tkEOF:
    raise newException(ExpressionError, "Unexpected token after expression: " & parser.peek().value)

proc parseExpressionString*(input: string): ExprNode =
  ## Parse expression from string
  let tokens = tokenize(input)
  result = parse(tokens)

# ============================================================================
# Evaluator
# ============================================================================

const MaxEvaluationDepth = 100
  ## Maximum recursion depth to prevent stack overflow

proc evaluate*(node: ExprNode, context: Table[string, float64], depth: int = 0): float64 =
  ## Evaluate expression tree with given context
  ## context maps indicator names to their current values
  ## depth tracks recursion depth to prevent infinite loops
  
  if depth > MaxEvaluationDepth:
    raise newException(ExpressionError, "Expression evaluation depth exceeded (possible infinite recursion)")
  
  case node.kind
  of exNumber:
    result = node.numValue
  
  of exIdentifier:
    # Look up value in context
    if not context.hasKey(node.name):
      raise newException(ExpressionError, "Undefined identifier: " & node.name)
    result = context[node.name]
  
  of exBinary:
    let leftVal = evaluate(node.left, context, depth + 1)
    let rightVal = evaluate(node.right, context, depth + 1)
    
    case node.operator
    of "+": result = leftVal + rightVal
    of "-": result = leftVal - rightVal
    of "*": result = leftVal * rightVal
    of "/":
      if rightVal == 0.0:
        raise newException(ExpressionError, "Division by zero")
      result = leftVal / rightVal
    of "<": result = if leftVal < rightVal: 1.0 else: 0.0
    of ">": result = if leftVal > rightVal: 1.0 else: 0.0
    of "<=": result = if leftVal <= rightVal: 1.0 else: 0.0
    of ">=": result = if leftVal >= rightVal: 1.0 else: 0.0
    of "==": result = if abs(leftVal - rightVal) < 1e-9: 1.0 else: 0.0
    of "!=": result = if abs(leftVal - rightVal) >= 1e-9: 1.0 else: 0.0
    of "and": result = if leftVal != 0.0 and rightVal != 0.0: 1.0 else: 0.0
    of "or": result = if leftVal != 0.0 or rightVal != 0.0: 1.0 else: 0.0
    else:
      raise newException(ExpressionError, "Unknown binary operator: " & node.operator)
  
  of exUnary:
    let operandVal = evaluate(node.operand, context, depth + 1)
    case node.unaryOp
    of "-", "!": result = -operandVal
    of "not": result = if operandVal == 0.0: 1.0 else: 0.0
    else:
      raise newException(ExpressionError, "Unknown unary operator: " & node.unaryOp)
  
  of exFunction:
    # Evaluate all arguments
    var args: seq[float64] = @[]
    for arg in node.args:
      args.add(evaluate(arg, context, depth + 1))
    
    # Call whitelisted functions only
    case node.funcName
    of "abs":
      if args.len != 1:
        raise newException(ExpressionError, "abs() takes exactly 1 argument")
      result = abs(args[0])
    
    of "min":
      if args.len != 2:
        raise newException(ExpressionError, "min() takes exactly 2 arguments")
      result = min(args[0], args[1])
    
    of "max":
      if args.len != 2:
        raise newException(ExpressionError, "max() takes exactly 2 arguments")
      result = max(args[0], args[1])
    
    of "sqrt":
      if args.len != 1:
        raise newException(ExpressionError, "sqrt() takes exactly 1 argument")
      if args[0] < 0:
        raise newException(ExpressionError, "sqrt() of negative number")
      result = sqrt(args[0])
    
    of "pow":
      if args.len != 2:
        raise newException(ExpressionError, "pow() takes exactly 2 arguments")
      result = pow(args[0], args[1])
    
    else:
      raise newException(ExpressionError, "Unknown or disallowed function: " & node.funcName)

proc evaluateExpression*(formula: string, context: Table[string, float64]): float64 =
  ## Parse and evaluate expression in one call
  let expr = parseExpressionString(formula)
  result = evaluate(expr, context)

# ============================================================================
# Expression Validation
# ============================================================================

proc validate*(node: ExprNode, allowedIdentifiers: seq[string]): bool =
  ## Validate that expression only references allowed identifiers
  ## Returns true if valid, false otherwise
  case node.kind
  of exNumber:
    result = true
  
  of exIdentifier:
    result = node.name in allowedIdentifiers
  
  of exBinary:
    result = validate(node.left, allowedIdentifiers) and 
             validate(node.right, allowedIdentifiers)
  
  of exUnary:
    result = validate(node.operand, allowedIdentifiers)
  
  of exFunction:
    # Check function is whitelisted
    if node.funcName notin ["abs", "min", "max", "sqrt", "pow"]:
      return false
    # Validate all arguments
    for arg in node.args:
      if not validate(arg, allowedIdentifiers):
        return false
    result = true

# ============================================================================
# Pretty Printing (for debugging)
# ============================================================================

proc `$`*(node: ExprNode): string =
  ## Convert expression tree to string (for debugging)
  case node.kind
  of exNumber:
    result = $node.numValue
  of exIdentifier:
    result = node.name
  of exBinary:
    result = "(" & $node.left & " " & node.operator & " " & $node.right & ")"
  of exUnary:
    result = node.unaryOp & $node.operand
  of exFunction:
    result = node.funcName & "("
    for i, arg in node.args:
      if i > 0:
        result.add(", ")
      result.add($arg)
    result.add(")")
