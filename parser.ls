
# Helpers

{ log, pad, parse-time, colors, treediff, truncate, clean-src, take } = require \./utils
{ treediff, any-diffs } = treediff
{ color, bright, grey, red, yellow, green, blue, magenta, white, plus, minus, invert } = colors

{ TAGS, MATCHLIST, is-bool-op, is-binary-op, is-assign-op, is-literal } = require \./token-specs

const $ = TAGS
const trunc = (n, txt) -> truncate n, (grey \...), (grey \:EOF), txt


# Token value is ALWAYS a string. Any post-processing goes in the
# parser function that turns this token into an AST node.

Token = (type, value, start = 0, end = 0, line = 0) ->
  { type, start, end, line, value, length: value?.length }


#
# Tokeniser
#

export const tokenise = (source) ->

  cursor = 0
  line   = 0


  #
  # Functions
  #

  match-rx = (regex) ->
    matched = regex.exec source.slice cursor
    return null if matched is null
    return matched.0

  read = ->
    if cursor >= source.length
      return Token $.EOF, ""

    for [ type, rx ] in MATCHLIST
      if str = match-rx rx, source.slice cursor
        cursor := cursor + str.length

        switch type
        | $.BLANK, $.SPACE, $.INDENT => return read!
        | $.STRCOM                   => return Token $.STRING, str.trim-left!
        | otherwise                  => return Token type, str

    return Token $.UNKNOWN, source[cursor]


  # Init

  f      = 0
  tokens = []

  log \\n + (bright blue source) + \\n

  while f < 1000
    f := f + 1
    next = read!

    log (white pad 10, next.type), (grey '<-'),
      trunc 50, (yellow clean-src next.value) + clean-src source.slice cursor

    tokens.push next
    break if tokens[*-1].type is $.EOF

  log ""

  return tokens


#
# Parser
#

export const parse = (source) ->

  tokens = tokenise source


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
      type := TAGS[type]

    steps.push [ \EAT, dent, next, ilog "#{red \eat} #type" ]

    if next.type isnt type
      error "Unexpected token (expected '#type', got #{next.type})"

    value = next.value
    next := if tokens.length then tokens.shift! else Token \EOF, ""
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
    if next.type is $.NEWLINE
      eat $.NEWLINE
    list = []
    while next.type isnt $.EOF and next.type isnt $.SCOPE_END
      list.push Statement!
      log \WHILE_BODY yellow next.type
    return list

  Scope = wrap \Scope ->
    eat $.SCOPE_BEG
    body = Body!
    if next.type isnt $.EOF then eat $.SCOPE_END
    kind: \scope
    type: \???
    body: body


  # Statements

  Statement = wrap \Statement ->
    while next.type is $.NEWLINE or next.type is $.SEMICOLON
      eat next.type

    if (peek 1) is $.OP_ASSIGN then
      return AssignmentExpression!

    switch next.type
    | $.IF        => IfStatement!
    | $.ATTR      => AttrStatement!
    | $.REACH     => DeclarationStatement!
    | $.REPEAT    => RepeatStatement!
    | $.OVER      => TimeStatement!
    | $.YIELD     => Yield!
    | $.TREENODE  => TreeNode!
    | $.SCOPE_BEG => Scope!
    | _           => ExpressionStatement!

  ExpressionStatement = wrap \ExpressionStatement ->
    expr = PrimaryExpression!

    switch next.type
    | $.NEWLINE   => eat $.NEWLINE # This is a TDD prayer, could cause problems
    | $.SCOPE_END => eat $.SCOPE_END # This is a TDD prayer, could cause problems
    | $.EOF       => eat $.EOF
    | _           => eat $.SEMICOLON
    kind: \expr-stmt
    type: \???
    main: expr

  DeclarationStatement = wrap \DeclarationStatement ->
    reach = eat $.REACH
    type  = eat $.TYPE
    ident = Identifier!
    eat $.OP_EQ
    kind:  \decl-stmt
    type:  type
    name:  ident.name
    reach: reach
    value: PrimaryExpression!

  IfStatement = wrap \IfStatement ->
    eat $.IF
    cond = BinaryExpression!
    pass = Scope!
    fail = null

    if next.type is $.NEWLINE
      eat $.NEWLINE
    if next.type is $.ELSE
      eat $.ELSE
      if next.type is $.SCOPE_BEG
        fail := Scope!
      else
        fail := BinaryExpression!

    kind: \if
    cond: cond
    pass: pass
    fail: fail

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
    type: \???
    attr: Attribute!

  Yield = wrap \Yield ->
    eat $.YIELD
    kind: \yield
    main: PrimaryExpression!


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
    | next.type is $.PAR_OPEN => ParenExpression!
    | is-assign-op (peek 1)   => AssignmentExpression!
    | is-binary-op (peek 1)   => BinaryExpression!
    | next.type is $.IDENT    => Identifier!
    | _                       => Expression!

  Expression = wrap \Expression ->
    return Literal! if is-literal next.type

    switch next.type
    | $.OP_NOT   => UnaryExpression!
    | $.PAR_OPEN => ParenExpression!
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
        else if node.left.type is node.right.type
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


  # Leaves

  Variable = wrap \Variable ->
    switch next.type
    | $.IDENT => Identifier!
    | _      => Literal!

  Literal = wrap \Literal ->
    switch next.type
    | $.TIMELIKE => TimeLiteral!
    | $.INTLIKE  => NumericLiteral!
    | $.BOOL     => BooleanLiteral!
    | $.STRING   => StringLiteral!
    | $.SYMBOL   => Symbol!
    | _         => eat next.type; null

  Symbol = wrap \Symbol ->
    if eat $.SYMBOL
      kind: \symbol
      name: that.slice 1

  BooleanLiteral = wrap \BooleanLiteral ->
    if eat $.BOOL
      kind: \literal
      type: \AutoBool
      value: that is \true

  TimeLiteral = wrap \TimeLiteral ->
    if eat $.TIMELIKE
      kind: \literal
      type: \AutoTime
      value: parse-time that

  NumericLiteral = wrap \NumericLiteral ->
    if eat $.INTLIKE
      kind: \literal
      type: \AutoInt
      value: parse-int that

  StringLiteral = wrap \StringLiteral ->
    if eat $.STRING
      kind: \literal
      type: \AutoStr
      value: that.replace /^"/, '' .replace /"$/, ''

  Identifier = wrap \Identifier ->
    name = eat $.IDENT
    kind: \ident
    name: name
    reach: \here


  # Init

  log tokens.map (.type |> yellow)
  log ""

  token-list = [ it for it in tokens ]
  next := tokens.shift!
  status!
  output = Root!

  return { output, steps, token-list }


