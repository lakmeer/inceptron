
const { log, parse-time, time-val } = require \../utils


#
# AST Node Constructors
#

Root = (...body) ->
  kind: \scope
  type: \Root
  body: body

Scope = (...body) ->
  kind: \scope
  type: \???
  body: body

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

IfStmt = (cond, pass, fail = null) ->
  kind: \if
  cond: cond
  pass: pass
  fail: fail

RepeatStmt = (count, main) ->
  kind: \repeat
  count: count
  main: main

OverStmt = (span, ease, main) ->
  kind: \time
  type: \over
  span: span
  ease: ease
  main: main

Yield = (main) ->
  kind: \yield
  main: main

TreeNode = (type, ...args) ->
  main = []

  if args.length and args[*-1].kind isnt \treeprop
    main := args.pop!

  kind: \treenode
  type: type
  args: args
  main: main

TreeProp = (name, value) ->
  kind: \treeprop
  type: value.type
  name: name
  value: value

Attr = (name, ...args) ->
  kind: \attr
  name: name
  args: args

SubAttr = (name, value) ->
  kind: \sub-attr
  name: name
  value: value

AttrStmt = ->
  kind: \attr-stmt
  type: \???
  attr: it

AutoInt = ->
  kind: \literal
  type: \AutoInt
  value: it

AutoStr = ->
  kind: \literal
  type: \AutoStr
  value: it

AutoTime = ->
  kind: \literal
  type: \AutoTime
  value: if typeof! it is \String then parse-time it else it

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

export Attribute =
  src: ":attribute 3"
  ast: Root AttrStmt Attr \attribute, (AutoInt 3)

export AttributeMulti =
  src: ":padding 3 4 5"
  ast: Root AttrStmt Attr \padding, (AutoInt 3), (AutoInt 4), (AutoInt 5)

export AttributeNamedArgs =
  src: ":padding ::top 3 ::bottom 4 ::vert 5"
  ast: Root AttrStmt Attr \padding,
    SubAttr \top,    (AutoInt 3)
    SubAttr \bottom, (AutoInt 4)
    SubAttr \vert,   (AutoInt 5)

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
    Scope do
      ExprStmt Assign (Ident \x), (AutoInt 42)

export IfElse =
  src: """
  if x == 69 {
    x := 42
  } else {
    x := 420
  }
  """
  ast: Root IfStmt do
        Binary \==, \AutoBool, (Ident \x), (AutoInt 69)
        Scope ExprStmt Assign (Ident \x), (AutoInt 42)
        Scope ExprStmt Assign (Ident \x), (AutoInt 420)

export LogicalKeywordsAnd =
  src: """x and y"""
  ast: Root ExprStmt Binary \and, \AutoBool, (Ident \x), (Ident \y)

export LogicalKeywordsOr =
  src: """x or y"""
  ast: Root ExprStmt Binary \or, \AutoBool, (Ident \x), (Ident \y)

export Times =
  src: """times 4 { x := x + 1 }"""
  ast:
    Root RepeatStmt (AutoInt 4),
      Scope ExprStmt Assign (Ident \x),
        Binary \+, \AutoNum, (Ident \x), (AutoInt 1)

export TimeUnits =
  src: "1s;2s;3m;4h1m;4h1m0ms;3h20s;500ms;"
  ast:
    Root do
      ExprStmt AutoTime time-val s: 1
      ExprStmt AutoTime time-val s: 2
      ExprStmt AutoTime time-val m: 3
      ExprStmt AutoTime time-val h: 4, m: 1
      ExprStmt AutoTime time-val h: 4, m: 1, ms: 0
      ExprStmt AutoTime time-val s: 20, h: 3
      ExprStmt AutoTime time-val ms: 500

export Over =
  src: """over 2s { x := 5 }"""
  ast:
    Root OverStmt (AutoTime \2s), null,
      Scope ExprStmt Assign (Ident \x), (AutoInt 5)

export OverEasy =
  src: """over 2s ease sq { x := 5 }"""
  ast:
    Root OverStmt (AutoTime \2s), (Ident \sq),
      Scope ExprStmt Assign (Ident \x), (AutoInt 5)

export YieldKeyword =
  src: "yield 4"
  ast:
    Root Yield AutoInt 4

export TreeConstructor =
  src: "<None"
  ast:
    Root TreeNode \None

export TreeProps =
  src: "<Box x=2 y=3"
  ast:
    Root TreeNode \Box,
      (TreeProp \x, AutoInt 2)
      (TreeProp \y, AutoInt 3)


# Waiting on operator precedence:

/*

export OperatorPrecedence =
  src: """
  2 + 3 * 4 - 1;
  """
  ast:
    Root do
      ExprStmt do
          Binary \+ \AutoInt,
            AutoInt 2
            Binary \- \AutoInt,
              Binary \* \AutoInt,
                AutoInt 3
                AutoInt 4
              AutoInt 1

export ComparitorsGreater =
  src: "x > 0 and y >= 0"
  ast: Root ExprStmt Binary \and, \AutoBool,
        Binary \>,  \AutoBool, (Ident \x), AutoInt 0
        Binary \>=, \AutoBool, (Ident \y), AutoInt 0

export ComparitorsLesser =
  src: "x < 0 or y <= 0"
  ast: Root ExprStmt Binary \or, \AutoBool,
        Binary \<,  \AutoBool, (Ident \x), AutoInt 0
        Binary \<=, \AutoBool, (Ident \y), AutoInt 0

*/

