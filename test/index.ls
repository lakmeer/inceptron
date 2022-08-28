
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

DeclStmt = (reach, type, ident, value) ->
  allowed = <[ local share uniq lift const ]>
  if allowed.includes reach
    kind:  \decl-stmt
    type:  type
    reach: reach
    ident: ident
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
  val: null
  ast: Root!

export JustNum =
  src: "69"
  val: 69
  ast: Root ExprStmt AutoInt 69

export JustString =
  src: "\"String\""
  val: \String
  ast: Root ExprStmt AutoStr \String

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
  ast: Root ExprStmt Assign (Ident \x), (AutoInt 2)

export DeclSingle =
  src: "local Int x = 42"
  ast: Root DeclStmt \local, \Int, (Ident \x), (AutoInt 42)

export ReachKeywords =
  src: """
  local Int a = 1
  share Int b = 2
  lift  Int c = 3
  uniq  Int d = 4
  local Int e = 5
  """
  ast: Root do
    DeclStmt \local, \Int, (Ident \a), (AutoInt 1)
    DeclStmt \share, \Int, (Ident \b), (AutoInt 2)
    DeclStmt \lift,  \Int, (Ident \c), (AutoInt 3)
    DeclStmt \uniq,  \Int, (Ident \d), (AutoInt 2)
    DeclStmt \local, \Int, (Ident \e), (AutoInt 5)

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

export SelfEvalExpr =
  src: "3"
  ast: Root ExprStmt AutoInt 3
  val: 3

export ComplexAddition =
  src: "(2 + 3) + 5"
  ast: Root ExprStmt do
    Binary \+, \AutoInt,
      Binary \+, \AutoInt, (AutoInt 2), (AutoInt 3)
      AutoInt 5
  val: 10

export Environments =
  src: ""
  ast: Root []
  val: null


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
    kind: \scope
    type: \Root
    main: null
    args: []
    body:
      * kind: \literal
        type: \Str
        main: " Simple Program"
      * kind: \yield
        main:
          kind: \binary
          type: \AutoNum
          oper: \+
          left:
            kind: \literal
            type: \AutoInt
            main: 2
          right:
            kind: \literal
            type: \AutoInt
            main: 3


export StatefulProgram =
  src: """
  " Simple Stateful Program

  local Int x = 1
  x := 2
  yield x + 1
  """
  ast:
    kind: \scope
    type: \Root
    main: null
    args: []
    body:
      * kind: \literal
        type: \Str
        main: " Simple Stateful Program"

      * kind: \decl
        reach: \local
        type: \Int
        name: \x
        main:
          * kind: \literal
            type: \AutoInt
            main: 1

      * kind: \assign
        reach: \here
        name: \x
        main:
          * kind: \literal
            type: \AutoInt
            main: 2

      * kind: \yield
        main:
          kind: \binary
          type: \Int
          oper: \+
          left:
            kind: \ident
            reach: \here
            name: \x
          right:
            kind: \literal
            type: \AutoInt
            main: 1

/*
export ExampleProgram =
  src: """
  " Example Program

  local Int pad = 3
  share Str txt = "Hello, Sailor"

  <Box
    :color `red
    :padding pad
    :visible true

    <Text txt
  """
  ast:
    kind: \scope
    type: \Root
    main: null
    args: []
    body:
      * kind: \literal
        type: \Str
        main: " Example Program"

      * kind: \decl
        reach: \local
        type: \Int
        name: \pad
        main:
          kind: \literal
          type: \Int
          main: 3

      * kind: \decl
        reach: \share
        type: \Str
        name: \txt
        main:
          kind: \literal
          type: \Str
          main: "Hello, Sailor"

      * kind: \yield
        main:
          kind: \scope
          type: \Box
          main: null
          body:
            * kind: \attr
              name: \color
              args:
                * kind: \atom
                  name: \red
                ...
            * kind: \attr
              name: \padding
              args:
                * kind: \ident
                  name: \pad
                  reach: \here
                ...
            * kind: \attr
              name: \visible
              args:
                * kind: \literal
                  type: \Bool
                  main: true
                ...
            * kind: \scope
              type: \Text
              args: []
              body:
                * kind: \ident
                  name: \txt
                  reach: \here
                ...


export ForeverProgram =
  src: """
  " Simple Forever Program

  local Int x = 0

  times 5
    x := x + 1
    <Text "Hello Sailor"
    <Text x

  forever
    x := x + 1

    <Box
      :attribute x
  """
  ast:
    kind: \scope
    type: \Root
    main: null
    args: []
    body:
      * kind: \literal
        type: \Str
        main: " Simple Forever Program"

      * kind: \decl
        reach: \local
        type: \Int
        name: \x
        main:
          kind: \literal
          type: \Int
          main: 0

      * kind: \timing
        type: \times
        freq: 5
        over: 0
        ease: null
        main:
          kind: \scope
          type: \None
          args: []
          main: null
          body:
            * kind: \assign
              name: \x
              reach: \here
              main:
                kind: \binary
                type: \Int
                oper: \+
                left:
                  kind: \ident
                  name: \x
                  reach: \here
                right:
                  kind: \literal
                  type: \AutoInt
                  main: 1

            * kind: \scope
              type: \Text
              args: []
              main: null
              body:
                * kind: \literal
                  type: \AutoStr
                  main: "Hello Sailor"
                ...
            * kind: \scope
              type: \Text
              args: []
              main: null
              body:
                * kind: \ident
                  name: \x
                  type: \Int
                ...
            ...

      * kind: \timing
        type: \forever
        freq: 0
        over: 0
        ease: null
        main:
          kind: \scope
          main: null
          args: []
          body:
            * kind: \assign
              name: \x
              reach: \here
              main:
                kind: \binary
                type: \Int
                oper: \+
                left:
                  kind: \ident
                  name: \x
                  reach: \here
                right:
                  kind: \literal
                  type: \AutoInt
                  main: 1

            * kind: \scope
              type: \Box
              args: []
              main: null
              body:
                * kind: \attr
                  name: \attribute
                  args:
                    * kind: \ident
                      name: \x
                      reach: \here
                    ...
                ...
                */