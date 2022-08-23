
#
# AST Node Constructors
#

ExprStmt = ->
  kind: \expr-stmt
  type: \???
  main: it

DeclStmt = (range, type, ident, value) ->
  kind: \decl-stmt
  type: type
  range: range
  ident: ident
  value: value

IfStmt = (cond, pass, fail) ->
  kind: \if
  cond: cond
  pass: pass
  fail: fail

AutoInt = ->
  kind: \literal
  type: \AutoInt
  value: it

AutoStr = ->
  kind: \literal
  type: \AutoStr
  value: it

Binary = (oper, type, left, right) ->
  kind: \binary
  type: type
  oper: oper
  left: left
  right: right

Ident = (name, range = \here) ->
  kind: \ident
  name: name
  range: range

Assign = (left, right) ->
  kind: \assign
  type: right.type
  left: left
  right: right

Scope = (...body) ->
  kind: \scope
  type: \???
  body: body

Root = (...body) ->
  kind: \scope
  type: \Root
  body: body


#
# Test Cases
#

export JustNum =
  src: "69"
  ast: Root ExprStmt AutoInt 69

export JustString =
  src: "\"String\""
  ast: Root ExprStmt AutoStr \String

export StringCommentEOF =
  src: "\" I'm like a comment"
  ast: Root ExprStmt AutoStr " I'm like a comment"

export StringCommentNewline =
  src: """
  " I'm like a comment

  """
  ast: Root ExprStmt AutoStr " I'm like a comment"

export Whitespace =
  src: "  \n    34"
  ast: Root ExprStmt AutoInt 34

export Add =
  src: "1 + 2"
  ast: Root ExprStmt Binary \+, \AutoInt, (AutoInt 1), (AutoInt 2)

export Subtract =
  src: "2 - 1"
  ast: Root ExprStmt Binary \-, \AutoInt, (AutoInt 2), (AutoInt 1)

export NestAdd =
  src: "3 + 4 + 5"
  ast:
    Root do
      ExprStmt do
        Binary \+, \AutoInt,
          AutoInt 3
          Binary \+, \AutoInt,
            AutoInt 4
            AutoInt 5

export MultipleStatements =
  src: """
  420;
  "butts"
  """
  ast:
    Root do
      ExprStmt AutoInt 420
      ExprStmt AutoStr \butts

export MultipleNestingStatements =
  src: """
  420;
  2 + 3 + 4 + 5
  """
  ast:
    Root do
      ExprStmt AutoInt 420
      ExprStmt do
        Binary \+, \AutoInt,
          AutoInt 2
          Binary \+, \AutoInt,
            AutoInt 3
            Binary \+, \AutoInt,
              AutoInt 4
              AutoInt 5

export CurlyEmptyBlock =
  src: "{}"
  ast: Root Scope!

export CurlyBlock =
  src: "{42}"
  ast: Root Scope ExprStmt AutoInt 42

export CurlyMultiBlock =
  src: "{420;69}"
  ast: Root Scope do
    ExprStmt AutoInt 420
    ExprStmt AutoInt 69

export ImplicitMultiBlock =
  src: "420;69"
  ast: Root do
    ExprStmt AutoInt 420
    ExprStmt AutoInt 69

export AssignmentExpression =
  src: """
  x := 2
  """
  ast: Root ExprStmt Assign (Ident \x), (AutoInt 2)

export DeclSingle =
  src: "local Int x = 42"
  ast: Root DeclStmt \local, \Int, (Ident \x), (AutoInt 42)

export BinaryBool =
  src: "2 == 2"
  ast: Root ExprStmt Binary \==, \AutoBool, (AutoInt 2), (AutoInt 2)

export BinaryVarBool =
  src: "x == 2"
  ast: Root ExprStmt Binary \==, \AutoBool, (Ident \x), (AutoInt 2)


export IfSimple =
  src: """
  if x == 69 {
    x := 42
  }
  """
  ast: Root IfStmt do
    Binary \==, \AutoBool,
      Ident \x
      AutoInt 69
    Scope
      ExprStmt Assign (Ident \x), (AutoInt 69)


/*
export OperatorPrecedence =
  src: """
  2 + 3 * 4 - 1;
  """
  ast:
    Program do
      ExprStmt do
          Binary \+ \AutoInt,
            AutoInt 2
            Binary \- \AutoInt,
              Binary \* \AutoInt,
                AutoInt 3
                AutoInt 4
              AutoInt 1
*/

