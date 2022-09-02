
const { log, parse-time, parse-complex, time-val } = require \../utils


#
# AST Node Constructors
#
# TODO: Move AST constructors to a common file (ast-nodes.ls)
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
  main: it

DeclStmt = (reach, type, name, value) ->
  if <[ local share uniq lift const ]>.includes reach
    kind:  \decl-stmt
    type:  type
    name:  name
    reach: reach
    value: value
  else
    throw "Unsupported reach keyword: #reach"

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

TreeNode = (type, main, ...body-args) ->
  args = while body-args.length and body-args.0.kind is \tree-prop then body-args.shift!
  kind: \treenode
  type: type
  main: main
  args: args
  body: body-args

TreeProp = (name, value) ->
  kind:  \tree-prop
  type:  value.type
  name:  name
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
  attr: it

AutoBool = ->
  kind: \literal
  type: \AutoBool
  value: !!it

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

AutoReal = ->
  kind: \literal
  type: \AutoReal
  value: it

AutoCplx = ->
  kind: \literal
  type: \AutoCplx
  value: parse-complex it

Symbol = ->
  kind: \symbol
  name: it

ProcDef = (name, main) ->
  kind: \procdef
  name: name
  main: main

Call = (name, ...args) ->
  kind: \call
  name: name
  args: args

FuncDef = (name, type, args, main) ->
  kind: \funcdef
  name: name
  type: type
  args: args
  main: main

Arg = (name, type, init = null) ->
  kind: \arg
  type: type
  name: name
  init: init

Binary = (oper, type, left, right) ->
  kind: \binary
  type: type
  oper: oper
  left: left
  right: right

Unary = (oper, type, main) ->
  kind: \unary
  type: type
  oper: oper
  main: main

Ident = (name, reach = \here) ->
  kind: \ident
  name: name
  reach: reach

Assign = (left, right) ->
  kind: \assign
  type: right.type
  left: left
  right: right


#
# Test Cases
#

export Degenerate =
  src: ""
  ast: Root!

export HashComment =
  src: "# I am a comment"
  val: null
  ast: Root!

export JustInt =
  src: "69"
  val: 69
  ast: Root ExprStmt AutoInt 69

export JustReal =
  src: "4.20"
  val: 4.2
  ast: Root ExprStmt AutoReal 4.2

export JustString =
  src: "\"String\""
  val: \String
  ast: Root ExprStmt AutoStr \String

export ComplexLiterals =
  src: "0e0;2e0;1e2;2e0.5pi;3i0;2i2"
  ast: Root do
    ExprStmt AutoCplx \0e0
    ExprStmt AutoCplx \2e0
    ExprStmt AutoCplx \1e2
    ExprStmt AutoCplx \2e0.5pi
    ExprStmt AutoCplx \3i0
    ExprStmt AutoCplx \2i2

export StringCommentEOF =
  src: "\" I'm like a comment"
  val: " I'm like a comment"
  ast: Root ExprStmt AutoStr " I'm like a comment"

export StringCommentNewline =
  src: """
  " I'm like a comment

  """
  val: " I'm like a comment"
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
  val: 34
  ast: Root ExprStmt AutoInt 34

export Add =
  src: "1 + 2"
  val: 3
  ast: Root ExprStmt Binary \+, \AutoInt, (AutoInt 1), (AutoInt 2)

export Subtract =
  src: "2 - 1"
  val: 1
  ast: Root ExprStmt Binary \-, \AutoInt, (AutoInt 2), (AutoInt 1)

export NestAdd =
  src: "3 + 4 + 5"
  val: 12
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
  val: \butts
  ast:
    Root do
      ExprStmt AutoInt 420
      ExprStmt AutoStr \butts

export MultipleNestingStatements =
  src: """
  420;
  2 + 3 + 4 + 5
  """
  val: 14
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
  val: null
  ast: Root Scope!

export CurlyBlock =
  src: "{42}"
  val: 42
  ast: Root Scope ExprStmt AutoInt 42

export CurlyMultiBlock =
  src: "{420;69}"
  val: 69
  ast: Root Scope do
    ExprStmt AutoInt 420
    ExprStmt AutoInt 69

export ImplicitMultiBlock =
  src: "420;69"
  val: 69
  ast: Root do
    ExprStmt AutoInt 420
    ExprStmt AutoInt 69

export AssignmentExpression =
  src: """
  x := 2
  """
  ast: Root Assign \x, (AutoInt 2)

export DeclSingle =
  src: "local Int x = 42"
  ast: Root DeclStmt \local, \Int, \x, (AutoInt 42)

export ReachKeywords =
  src: """
  local Int a = 1
  share Int b = 2
  lift  Int c = 3
  uniq  Int d = 4
  local Int e = 5
  """
  ast: Root do
    DeclStmt \local, \Int, \a, (AutoInt 1)
    DeclStmt \share, \Int, \b, (AutoInt 2)
    DeclStmt \lift,  \Int, \c, (AutoInt 3)
    DeclStmt \uniq,  \Int, \d, (AutoInt 4)
    DeclStmt \local, \Int, \e, (AutoInt 5)

export BinaryBool =
  src: "2 == 2"
  val: true
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
      Assign \x, (AutoInt 42)

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
        Scope Assign \x, (AutoInt 42)
        Scope Assign \x, (AutoInt 420)

export BooleanKeywords =
  src: "true; false"
  ast: Root do
    ExprStmt (AutoBool true)
    ExprStmt (AutoBool false)

export LogicalKeywordsAnd =
  src: "x and y"
  ast: Root ExprStmt Binary \and, \AutoBool, (Ident \x), (Ident \y)

export LogicalKeywordsOr =
  src: "x or y"
  ast: Root ExprStmt Binary \or, \AutoBool, (Ident \x), (Ident \y)

export LogicalKeywordNot =
  src: "not x"
  ast: Root ExprStmt Unary \not, \AutoBool, (Ident \x)

export LogicalKeywordNestedNot =
  src: "not not not x"
  ast: Root ExprStmt do
    Unary \not, \AutoBool,
      Unary \not, \AutoBool,
        Unary \not, \AutoBool, (Ident \x)

export Times =
  src: """times 4 { x := x + 1 }"""
  ast:
    Root RepeatStmt (AutoInt 4),
      Scope Assign \x,
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
      Scope Assign \x, (AutoInt 5)

export OverEasy =
  src: """over 2s ease sq { x := 5 }"""
  ast:
    Root OverStmt (AutoTime \2s), (Ident \sq),
      Scope Assign \x, (AutoInt 5)

export YieldKeyword =
  src: "yield 4"
  ast:
    Root Yield AutoInt 4

export TreeConstructor =
  src: "<None"
  ast:
    Root TreeNode \None, null

export TreeMain =
  src: "<Text \"Hello, Sailor"
  ast:
    Root TreeNode \Text, AutoStr "Hello, Sailor"

export TreeProps =
  src: "<Box x=2 y=3"
  ast:
    Root TreeNode \Box, null,
      (TreeProp \x, AutoInt 2)
      (TreeProp \y, AutoInt 3)

export TreeBody =
  src: "<Box\n  x := 3"
  ast:
    Root TreeNode \Box, null,
      Assign \x, (AutoInt 3)

export DefineProcedure =
  src: """
  proc exampleProcedure {
    i := j^2
  }
  """
  ast: Root ProcDef \exampleProcedure,
        Scope Assign \i, Binary \^, \AutoNum, (Ident \j), (AutoInt 2)

export ProcedureCall =
  src: """
  exampleProcedure()
  """
  ast: Root ExprStmt Call \exampleProcedure

export DefineFunction =
  src: """
  func Int exampleFunction (Int a, Int b) -> {
    a * b
  }
  """
  ast: Root FuncDef \exampleFunction \Int, [ (Arg \a \Int), (Arg \b \Int) ],
        Scope ExprStmt Binary \*, \AutoNum, (Ident \a), (Ident \b)

export DefineFunctionOneLine =
  src: """
  func Int exampleFunction (Int a, Int b) -> a * b
  """
  ast: Root FuncDef \exampleFunction \Int, [ (Arg \a \Int), (Arg \b \Int) ],
        Binary \*, \AutoNum, (Ident \a), (Ident \b)

export FunctionCall =
  src: """
  exampleFunction(2, 3)
  """
  ast: Root ExprStmt Call \exampleFunction, (AutoInt 2), (AutoInt 3)



#
# Interpreter Tests
#

export SimpleProgram =
  src: """
  " Simple Program

  yield 2 + 3
  """
  val: 5
  ast:
    Root do
      ExprStmt AutoStr " Simple Program"
      Yield Binary \+ \AutoInt, (AutoInt 2), (AutoInt 3)

export StatefulProgram =
  src: """
  " Simple Stateful Program

  local Int x = 1
  x := 2
  yield x + 1
  """
  ast:
    Root do
      ExprStmt AutoStr " Simple Stateful Program"
      DeclStmt \local, \Int, \x, (AutoInt 1)
      Assign \x, (AutoInt 2)
      Yield Binary \+ \AutoNum, (Ident \x), (AutoInt 1)

export ExampleProgram =
  src: """
  " Example Program

  local Int pad = 3
  share Str txt = "Hello, Sailor"

  <Box
    :color `red
    :padding pad
    :visible true

    <Text txt  #>
  """
  ast:
    Root do
      ExprStmt AutoStr " Example Program"
      DeclStmt \local \Int \pad, (AutoInt 3)
      DeclStmt \share \Str \txt, (AutoStr "Hello, Sailor")

      TreeNode \Box, null,
        AttrStmt Attr \color,   (Symbol \red)
        AttrStmt Attr \padding, (Ident \pad)
        AttrStmt Attr \visible, (AutoBool true)
        TreeNode \Text, (Ident \txt)


export SetAndUseValue =
  src: """
  " Define and then use a simple value

  local Real x = 2.2

  yield x
  """
  val: 2.2
  ast:
    Root do
      ExprStmt AutoStr " Define and then use a simple value"
      DeclStmt \local \Real \x (AutoReal 2.2)
      Yield (Ident \x)

export FunctionDefineAndUse =
  src: """
  " Define and then use a function

  func Real double (Real a) -> 2.0 * a

  double(3.0)
  """
  val: 6.0
  ast:
    Root do
      ExprStmt AutoStr " Define and then use a function"
      FuncDef \double \Real [ (Arg \a \Real) ],
        Binary \* \AutoNum (AutoReal 2.0), (Ident \a)
      ExprStmt Call \double (AutoReal 3.0)

/*

# Waiting on indentation

export ForeverProgram =
  src: """
  " Simple Forever Program

  local Int x = 0

  times 5 {
    x := x + 1
    <Text "Hello, Sailor"
    <Text x
  }

  forever {
    x := x + 1

    <Box
      :attribute x
  """
  ast:
    Root do
      ExprStmt AutoStr " Simple Forever Program"
      DeclStmt \local \Int \x, (AutoInt 0)
      RepeatStmt (AutoInt 5),
        Scope do
          Assign \x, Binary \+, \AutoNum, (Ident \x), (AutoInt 1)
          TreeNode \Text, (AutoStr "Hello, Sailor")
          TreeNode \Text, (Ident \x)
      RepeatStmt \forever,
        Scope do
          Assign \x, Binary \+, \AutoNum, (Ident \x), (AutoInt 1)
          TreeNode \Box, null,
            AttrStmt Attr \attribute, (Ident \x)


# Waiting on operator precedence:

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

export NestedAddition =
  src: "2 + 3 + 5"
  ast: Root ExprStmt do
    Binary \+, \AutoInt,
      Binary \+, \AutoInt, (AutoInt 2), (AutoInt 3)
      AutoInt 5
  val: 10

export ForcedAddition =
  src: "2 + (3 + 5)"
  ast: Root ExprStmt do
    Binary \+, \AutoInt,
      AutoInt 2
      Binary \+, \AutoInt, (AutoInt 3), (AutoInt 5)
  val: 10

export ComplexAddition =
  src: "(2 + 3) + 5"
  ast: Root ExprStmt do
    Binary \+, \AutoInt,
      Binary \+, \AutoInt, (AutoInt 2), (AutoInt 3)
      AutoInt 5
  val: 10

*/

