
# Helpers

{ log, dump, pad, parse-time, parse-complex, parse-path, colors, treediff, truncate, clean-src, take } = require \./utils
{ treediff, any-diffs } = treediff
{ color, bright, grey, red, yellow, green, blue, magenta, white, plus, minus, invert } = colors

{ LIBRARY, is-bool-op, is-math-op, is-binary-op, is-assign-op, is-list-op, is-literal } = require \./token-specs

Tokeniser = require \./tokeniser

const $ = new Tokeniser LIBRARY



#
# Parser
#

export const parse = (source) ->

  tokens = $.tokenise source


  #
  # Debug logger
  #

  dent   = 0
  steps  = []
  ilog   = (...args) -> log ' ' * dent, ...args; return args[0]
  bump   = (c, type) -> steps.push [ \BUMP, dent, next, c ]
  debug  = (...args) -> steps.push [ \LOG,  dent, next, ilog invert clean-src args.join ' ' ]
  error  = (...args) -> steps.push [ \ERR,  dent, next, ilog minus  clean-src args.join ' ' ]
  status =           -> steps.push [ \NEW,  dent, next, ilog "#{bright green \new} #{bright str-token next} <- #{(take 4 tokens).map str-token .join ' '}" ]

  str-token = (token) -> "[#{token.type}:#{yellow clean-src token.value}]"

  wrap = (name, ƒ) -> (...args) ->
    bump ilog blue \+ + name
    dent += 1
    result = ƒ ...args
    dent -= 1
    bump ilog grey \- + name
    return result


  #
  # Token Sequence
  #

  next = null

  eat = (type) ->
    if typeof type is \symbol
      type := $[type]

    steps.push [ \EAT, dent, next, ilog "#{red \eat} #type" ]

    if next.type isnt type
      error "Unexpected token (expected '#type', got #{next.type})"

    value = next.value
    next := if tokens.length then tokens.shift! else tk.new-eof!
    status!

    return value

  peek = (n) ->
    if tokens.length > n - 1
      tokens[n - 1].type
    else
      \EOF

  check-valid-assign = (node) ->
    if node.kind is \ident
      return node.name
    error "Can't assign to non-identifier"


  #
  # Parser Nodes
  #

  Root = wrap \Root ->
    kind: \scope
    type: \Root
    body: Body!

  Body = wrap \Body ->
    list = []
    while next.type isnt $.EOF and next.type isnt $.SCOPE_CLOSE
      if next.type is $.NEWLINE
        eat $.NEWLINE
      else
        list.push Statement!
        if next.type is $.SEMICOLON then eat $.SEMICOLON

    return list

  Scope = wrap \Scope ->
    eat $.SCOPE_OPEN
    body = Body!
    if next.type isnt $.EOF then eat $.SCOPE_CLOSE
    kind: \scope
    type: \???
    body: body


  # Statements

  Statement = wrap \Statement ->
    while next.type in [ $.NEWLINE, $.SEMICOLON ]
      eat next.type

    if (peek 1) is $.OP_ASSIGN
      return AssignmentExpression!

    switch next.type
    | $.NEWLINE    => eat $.NEWLINE
    | $.ATTR       => AttrStatement!
    | $.PROC       => ProcStatement!
    | $.FUNC       => FuncStatement!
    | $.REACH      => DeclarationStatement!
    | $.REPEAT     => RepeatStatement!
    | $.OVER       => TimeStatement!
    | $.EMIT       => EmitStatement!
    | $.ON         => OnStatement!
    | $.YIELD      => Yield!
    | $.TREENODE   => TreeNode!
    | $.SCOPE_OPEN => Scope!
    | _            => ExpressionStatement!

  ExpressionStatement = wrap \ExpressionStatement ->
    expr = PrimaryExpression!
    kind: \expr-stmt
    main: expr

  DeclarationStatement = wrap \DeclarationStatement ->
    reach = eat $.REACH
    type  = eat $.TYPE
    ident = Identifier!
    eat $.OP_EQ
    value = PrimaryExpression!
    if value.kind is \list
      value.type = type.replace \`s, ''

    kind:  \decl-stmt
    type:  type
    name:  ident.name
    reach: reach
    value: value


  RepeatStatement = wrap \RepeatStatement ->
    keyword = eat $.REPEAT
    kind: \repeat
    count: if keyword is \forever then \forever else PrimaryExpression!
    main: Scope!

  TimeStatement = wrap \TimeStatement ->
    eat $.OVER
    span = TimeLiteral!
    ease = null

    if next.type is $.EASE
      eat $.EASE
      ease := PrimaryExpression!

    kind: \time
    type: \over
    span: span
    ease: ease
    main: Scope!

  AttrStatement = wrap \AttrStatement ->
    kind: \attr-stmt
    attr: Attribute!

  Yield = wrap \Yield ->
    eat $.YIELD
    kind: \yield
    main: PrimaryExpression!

  ProcStatement = wrap \ProcStatement ->
    eat $.PROC
    kind: \procdef
    name: eat $.IDENT
    main: Scope!

  FuncStatement = wrap \FuncStatement ->
    eat $.FUNC
    type = eat $.TYPE
    name = eat $.IDENT
    args = ArgList!
    eat \ARR_RIGHT
    kind: \funcdef
    name: name
    type: type
    args: args
    main:
      if next.type is $.SCOPE_OPEN
        Scope!
      else
        PrimaryExpression!

  EmitStatement = wrap \EmitStatement ->
    eat $.EMIT
    name = eat $.EVENT .slice 1
    args = []
    while not next.type in [ $.NEWLINE, $.EOF, $.SCOPE_CLOSE ]
      args.push Expression!
      if next.type is $.COMMA => eat $.COMMA
    kind: \emit
    name: name
    args: args

  OnStatement = wrap \OnStatement ->
    eat $.ON
    type = null
    if next.type is $.TYPE => type := eat $.TYPE
    name = eat $.EVENT .slice 1
    kind: \on
    type: type
    name: name
    main:
      if next.type is $.SCOPE_OPEN
        Scope!
      else
        PrimaryExpression!


  # TreeNodes

  TreeNode = wrap \TreeNode ->
    type = eat $.TREENODE .slice 1
    main = null
    args = []

    if next.type isnt $.NEWLINE and next.type isnt $.EOF
      if (peek 1) isnt $.OP_EQ
        main := Expression!
      args := TreePropList!

    body = Body!

    # Bump first body entry to main if it's appropriate
    if body.length is 1 and body[*-1].kind is \expr-stmt
      body[*-1] = body[*-1].main

    kind: \treenode
    type: type
    main: main
    args: args
    body: body

  TreePropList = wrap \TreePropList ->
    args = []
    while next.type is $.IDENT
      args.push TreeProperty!
    return args

  TreeProperty = wrap \TreeProperty ->
    name = eat $.IDENT
    eat $.OP_EQ
    value = PrimaryExpression!
    kind: \tree-prop
    type: value?.type or \???
    name: name
    value: value


  # Attributes

  Attribute = wrap \Attribute ->
    name = (eat $.ATTR).slice 1
    args = AttrArgsList!
    kind: \attr
    name: name
    args: args

  SubAttribute = wrap \SubAttribute ->
    name = (eat $.SUBATTR).slice 2
    kind: \sub-attr
    name: name
    value: PrimaryExpression!

  AttrArgsList = wrap \AttrArgsList ->
    args = [ AttrArgument! ]
    while next.type isnt $.EOF and next.type isnt $.NEWLINE
      args.push AttrArgument!
    return args

  AttrArgument = wrap \AttrArgument ->
    switch next.type
    | $.SUBATTR => SubAttribute!
    | _        => Expression!


  # Expressions

  PrimaryExpression = wrap \PrimaryExpression ~>
    switch true
    | is-assign-op (peek 1)    => AssignmentExpression!
    | is-binary-op (peek 1)    => BinaryExpression!
    | next.type is $.IF        => IfExpression!
    | next.type is $.LIST_OPEN => ListLiteral!
    | next.type is $.PAR_OPEN  => ParenExpression!
    | next.type is $.IDENT     =>
      if (peek 1) is $.PAR_OPEN
        FunctionCall!
      else
        Identifier!
    | _ => Expression!

  Expression = wrap \Expression ->
    return Literal! if is-literal next.type

    switch next.type
    | $.OP_NOT   => UnaryExpression!
    | $.IDENT    => BinaryExpression!
    | $.INTLIKE  => BinaryExpression!
    | $.STRING   => Literal!
    | $.SYMBOL   => Symbol!
    | _          => debug "No expression for type #that"; eat that; null

  ParenExpression = wrap \ParenExpression ->
    eat $.PAR_OPEN
    expr = Expression!
    eat $.PAR_CLOSE
    return expr

  UnaryExpression = wrap \UnaryExpression ->
    oper =
      switch next.type
      | $.OP_NOT => oper := eat $.OP_NOT
      | _         => null

    if oper
      return do
        kind: \unary
        oper: oper
        type: \AutoBool
        main: UnaryExpression!
    else
      return LeftHandSideExpression!

  BinaryExpression = wrap \BinaryExpression ->
    node = LeftHandSideExpression!

    while is-binary-op next.type
      oper = next.type

      node :=
        kind: \binary
        type: \AutoNum
        oper: eat next.type
        left: node
        right: PrimaryExpression!

      if node isnt null
        if is-bool-op oper
          node.type = \AutoBool
        else if is-list-op oper
          node.type = \AutoStr
        else if is-math-op oper
          node.type = \AutoNum

          if node.left.type is node.right.type and node.left.type
            node.type = node.left.type
      else
        error "BinaryExpression: LHS node is null"

    return node

  AssignmentExpression = wrap \AssignmentExpression ->
    left = LeftHandSideExpression!

    if next.type isnt $.OP_ASSIGN
      return left

    eat $.OP_ASSIGN
    right = BinaryExpression!

    kind:  \assign
    type:  right.type
    left:  check-valid-assign left
    right: right

  LeftHandSideExpression = wrap \LeftHandSideExpression ->
    if is-literal next.type
      Literal!
    else
      Identifier!

  IfExpression = wrap \IfExpression ->
    eat $.IF
    cond = Expression!
    pass = Scope!
    fail = null

    if next.type is $.NEWLINE
      eat $.NEWLINE
    if next.type is $.ELSE
      eat $.ELSE
      if next.type is $.IF
        fail := IfExpression!
      else if next.type is $.SCOPE_OPEN
        fail := Scope!
      else
        fail := BinaryExpression!

    kind: \if
    cond: cond
    pass: pass
    fail: fail

  FunctionCall = wrap \FunctionCall ->
    kind: \call
    name: eat $.IDENT
    args: ExpressionList!

  ExpressionList = wrap \ExpressionList ->
    eat $.PAR_OPEN
    list = []
    while next.type isnt $.PAR_CLOSE and next.type isnt $.EOF
      list.push Expression!
      if next.type is $.COMMA
        eat $.COMMA
    eat $.PAR_CLOSE
    return list

  ArgList = wrap \ArgList ->
    eat $.PAR_OPEN
    args = []
    while next.type isnt $.PAR_CLOSE and next.type isnt $.EOF
      args.push Argument!
      if next.type is $.COMMA
        eat $.COMMA
    eat $.PAR_CLOSE
    return args

  Argument = wrap \Argument ->
    type = eat $.TYPE
    name = eat $.IDENT
    init = null
    if next.type is $.OP_EQ
      eat $.OP_EQ
      init := Literal!
    kind: \arg
    type: type
    name: name
    init: init


  # Leaves

  Variable = wrap \Variable ->
    switch next.type
    | $.IDENT => Identifier!
    | _       => Literal!

  Literal = wrap \Literal ->
    switch next.type
    | $.NULL     => NullLiteral!
    | $.BOOL     => BooleanLiteral!
    | $.INTLIKE  => IntegerLiteral!
    | $.REALLIKE => RealLiteral!
    | $.CPLXLIKE => ComplexLiteral!
    | $.TIMELIKE => TimeLiteral!
    | $.PATHLIKE => PathLiteral!
    | $.STRING   => StringLiteral!
    | $.SYMBOL   => Symbol!
    | _          => eat next.type; null

  ListLiteral = wrap \ListLiteral ->
    eat $.LIST_OPEN
    members = []
    while next.type isnt $.LIST_CLOSE
      members.push Expression!
      if next.type is $.COMMA => eat $.COMMA
    eat $.LIST_CLOSE
    kind: \list
    type: if members.length then members[0].type else \???
    members: members

  Symbol = wrap \Symbol ->
    if eat $.SYMBOL
      kind: \symbol
      name: that.slice 1

  NullLiteral = wrap \NullLiteral ->
    if eat $.NULL
      kind: \literal
      type: \Null
      value: null

  BooleanLiteral = wrap \BooleanLiteral ->
    if eat $.BOOL
      kind: \literal
      type: \AutoBool
      value: that is \true

  IntegerLiteral = wrap \IntegerLiteral ->
    if eat $.INTLIKE
      kind: \literal
      type: \AutoInt
      value: parse-int that

  RealLiteral = wrap \RealLiteral ->
    if eat $.REALLIKE
      kind: \literal
      type: \AutoReal
      value: parse-float that

  ComplexLiteral = wrap \ComplexLiteral ->
    if eat $.CPLXLIKE
      kind: \literal
      type: \AutoCplx
      value: parse-complex that

  TimeLiteral = wrap \TimeLiteral ->
    if eat $.TIMELIKE
      kind: \literal
      type: \AutoTime
      value: parse-time that

  StringLiteral = wrap \StringLiteral ->
    if eat $.STRING
      kind: \literal
      type: \AutoStr
      value: that.replace /^"/, '' .replace /"$/, ''

  PathLiteral = wrap \PathLiteral ->
    if eat $.PATHLIKE
      kind: \literal
      type: \AutoPath
      value: that.split \/ .filter -> it

  Identifier = wrap \Identifier ->
    if eat $.IDENT
      kind: \ident
      name: that
      reach: \here


  # Init

  token-list = [ it for it in tokens ]
  next := tokens.shift!
  status!
  output = Root!

  return { output, steps, token-list }


