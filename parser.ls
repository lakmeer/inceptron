
# Helpers

{ log, nop, parse-time, any, dump, colors, treediff, truncate } = require \./utils
{ treediff, any-diffs } = treediff
{ color, bright, grey, red, yellow, green, blue, magenta, white, plus, minus, invert } = colors

const clean-src = (txt, c=on) -> txt.replace /\n/g, if c then bright blue \⏎ else nop \⏎


#
# Token Matchers
#

TOKEN_MATCHERS =
  [ \NEWLINE,     /^\n/ ]
  [ \;,           /^;\n?/ ]

  # Grouping
  [ \SCOPE_BEG,   /^{/ ]
  [ \SCOPE_END,   /^}/ ]
  [ \PAREN_OPEN,  /^\(/ ]
  [ \PAREN_CLOSE, /^\)/ ]
  [ \COMMA,       /^,/ ]

  # Keywords
  [ \IF,          /^if\b/ ]
  [ \ELSE,        /^else\b/ ]
  [ \NULL,        /^null\b/ ]
  [ \REPEAT       /^(times|forever)\b/ ]
  [ \OVER,        /^over\b/ ]
  [ \REACH,       /^(local|share|uniq|lift|const)\b/ ]
  [ \EASE,        /^ease\b/ ]
  [ \YIELD,       /^yield\b/ ]

  # Literals
  [ \TIMELIKE,    /^([\d]+h)?([\d]+m)?([\d]+s)?([\d]+ms)?\b/ ]
  [ \ATTR,        /^:[\w]+/ ]
  [ \SUBATTR,     /^::[\w]+/ ]
  [ \TREENODE,    /^<[\w]+\b/ ]
  [ \INTLIKE,     /^[\d]+/ ]
  [ \SYMBOL,      /^`\w+/ ]
  [ \BOOL,        /^(true|false)\b/ ]
  [ \STRING,      /^"[^"\n]*"/ ]
  [ \STRCOM,      /^"[^"\n]*$/ ]
  [ \STRCOM,      /^"[^"\n]*/ ]

  # Operators
  [ \OPER_NOT,    /^!/ ]
  [ \OPER_ADD,    /^[\+]/ ]
  [ \OPER_SUB,    /^[\-]/ ]
  [ \OPER_MUL,    /^[\*]/ ]
  [ \OPER_DIV,    /^[\/]/ ]
  [ \OPER_ASS,    /^:=/ ]
  [ \OPER_EQUIV,  /^==/ ]
  [ \OPER_EQ,     /^=/ ]
  [ \OPER_GTE,    /^<=/ ]
  [ \OPER_GT,     /^</ ]
  [ \OPER_LTE,    /^>=/ ]
  [ \OPER_LT,     /^>/ ]
  [ \OPER_AND,    /^and\b/ ]
  [ \OPER_OR,     /^or\b/ ]
  [ \OPER_NOT,    /^not\b/ ]

  # Identifiers
  [ \TYPE,        /^[A-Z]\w+(`s)?/ ]
  [ \IDENT,       /^\w+/ ]

  # Whitespace
  [ \SPACE,       /^[\s]+/ ]
  [ \BLANK,       /^[\s]+$/ ]
  [ \BLANK,       /^[\s]+\n/ ]



# Token value is ALWAYS a string. Any post-processing goes in the
# parser function that turns this token into an AST node.

Token = (type, value) -> { type, value, length: value.length }


#
# Core Parse Function
#

export const parse = (source) ->

  #
  # Debug logger
  #

  dent   = 0
  steps  = []
  ilog   = (...args) -> log ' ' * dent, ...args; return args[0]
  bump   = (c, type) -> steps.push [ \BUMP, dent, lookahead, c ]
  debug  = (...args) -> steps.push [ \LOG,  dent, lookahead, ilog invert clean-src args.join ' ' ]
  error  = (...args) -> steps.push [ \ERR,  dent, lookahead, ilog minus clean-src args.join ' ' ]
  status = -> steps.push [ \NEW,  dent, lookahead,
    ilog "#{green \new} #{lookahead.type} <- #{yellow clean-src lookahead.value, false}#{clean-src truncate 14, \..., source.slice cursor}" ]

  wrap = (name, ƒ) -> (...args) ->
    bump ilog blue \+ + name
    dent += 1
    result = ƒ ...args
    dent -= 1
    bump ilog grey \- + name
    return result


  #
  # Tokeniser
  #

  cursor    = 0
  lookahead = null

  set-lookahead = (token) ->
    lookahead := token
    status!

  eat = (type) ->
    steps.push [ \EAT, dent, lookahead, ilog "#{red \eat} #type" ]

    token = lookahead

    if token.type isnt type
      error "Unexpected token (expected '#type', got #{token.type})"

    set-lookahead next!
    return token.value

  peek = (d = 0) ->
    if cursor >= source.length
      return Token \EOF, ""

    char = source[ cursor ]
    rest = source.slice cursor

    for [ type, rx ] in TOKEN_MATCHERS
      if token = match-rx rx, rest
        switch type
        | \BLANK, \SPACE, \INDENT =>
          cursor := cursor + token.length
          return peek d + 1
        | _ =>
          return Token type, token

    if !char
      error "Char token was '#{typeof! char}' at #{cursor}", source.slice cursor
    else
      throw error "Unexpected token: `#char`"

    return Token \UNKNOWN, char

  next = ->
    token = peek!
    cursor := cursor + token.length

    if token.type is \STRCOM
      Token \STRING, token.value.trim-left!
    else
      token

  read = (ƒ) ->
    i = cursor
    while (ƒ source[cursor]) and (cursor < source.length)
      cursor := cursor + 1
    return source.slice i, cursor

  match-rx = (regex) ->
    matched = regex.exec source.slice cursor
    return null if matched is null
    return matched.0

  check-valid-assign = (node) ->
    if node.kind is \ident
      return node.name
    error "Can't assign to non-identifier"

  one-of = (types) -> -> types.includes it

  is-bool-op = one-of <[ OPER_EQUIV OPER_GT OPER_GTE OPER_LT OPER_LTE OPER_AND OPER_OR ]>
  is-math-op = one-of <[ OPER_ADD OPER_SUB OPER_MUL OPER_DIV ]>
  is-literal = one-of <[ TIMELIKE INTLIKE STRING BOOL SYMBOL ]>
  is-bin-op  = one-of <[ OPER_ADD OPER_SUB OPER_MUL OPER_DIV OPER_EQUIV OPER_GT OPER_GTE OPER_LT OPER_LTE OPER_AND OPER_OR ]>


  #
  # Parser Nodes
  #

  Root = wrap \Root ->
    kind: \scope
    type: \Root
    body: Body!

  Body = wrap \Body ->
    if lookahead.type is \NEWLINE # TODO: Find out how to kill this
      eat \NEWLINE
    list = [ ]
    while lookahead.type isnt \EOF and lookahead.type isnt \SCOPE_END
      list.push Statement!
    return list

  Scope = wrap \Scope ->
    eat \SCOPE_BEG
    body = Body!
    if lookahead.type isnt \EOF then eat \SCOPE_END
    kind: \scope
    type: \???
    body: body


  # Statements

  Statement = wrap \Statement ->
    while lookahead.type is \NEWLINE or lookahead.type is \;
      eat lookahead.type
      return Statement!

    switch lookahead.type
    | \IF        => IfStatement!
    | \ATTR      => AttrStatement!
    | \REACH     => DeclarationStatement!
    | \REPEAT    => RepeatStatement!
    | \OVER      => TimeStatement!
    | \YIELD     => Yield!
    | \TREENODE  => TreeNode!
    | \SCOPE_BEG => Scope!
    | _          => ExpressionStatement!

  ExpressionStatement = wrap \ExpressionStatement ->
    expr = PrimaryExpression!

    switch lookahead.type
    | \NEWLINE   => eat \NEWLINE # This is a TDD prayer, could cause problems
    | \SCOPE_END => eat \SCOPE_END # This is a TDD prayer, could cause problems
    | \EOF       => eat \EOF
    | \;         => eat \;
    | _          => eat \;
    kind: \expr-stmt
    type: \???
    main: expr

  DeclarationStatement = wrap \DeclarationStatement ->
    reach = eat \REACH
    type  = eat \TYPE
    ident = Identifier!
    eat \OPER_EQ
    kind:  \decl-stmt
    type:  type
    reach: reach
    name:  ident.name
    value: PrimaryExpression!

  IfStatement = wrap \IfStatement ->
    eat \IF
    cond = BinaryExpression!
    pass = Scope!

    fail = null

    if lookahead.type is \NEWLINE
      eat \NEWLINE
    if lookahead.type is \ELSE
      eat \ELSE
      if lookahead.type is \SCOPE_BEG
        fail := Scope!
      else
        fail := BinaryExpression!

    kind: \if
    cond: cond
    pass: pass
    fail: fail

  RepeatStatement = wrap \RepeatStatement ->
    keyword = eat \REPEAT
    kind: \repeat
    count: if keyword is \forever then \forever else PrimaryExpression!
    main: Scope!

  TimeStatement = wrap \TimeStatement ->
    eat \OVER
    kind: \time
    type: \over
    span: TimeLiteral!
    ease:
      if lookahead.type is \EASE
        eat \EASE
        PrimaryExpression!
      else
        null
    main: Scope!

  AttrStatement = wrap \AttrStatement ->
    kind: \attr-stmt
    type: \???
    attr: Attribute!

  Yield = wrap \Yield ->
    eat \YIELD
    kind: \yield
    main: PrimaryExpression!


  # TreeNodes

  TreeNode = wrap \TreeNode ->
    type = eat \TREENODE .slice 1
    main = null
    args = []

    if lookahead.type isnt \NEWLINE and lookahead.type isnt \EOF
      if peek!type isnt \OPER_EQ
        main := Expression!
      args := TreePropList!

    body = Body!

    if body.length is 1 and body[*-1].kind is \expr-stmt
      body[*-1] = body[*-1].main

    kind: \treenode
    type: type
    main: main
    args: args
    body: body

  TreePropList = wrap \TreeArgsList ->
    args = []
    while lookahead.type is \IDENT
      args.push TreeProperty!
    return args

  TreeProperty = wrap \TreeProperty ->
    name = eat \IDENT
    eat \OPER_EQ
    value = PrimaryExpression!
    kind: \tree-prop
    type: value?.type or \???
    name: name
    value: value


  # Attributes

  Attribute = wrap \Attribute ->
    name = (eat \ATTR).slice 1
    args = AttrArgsList!
    kind: \attr
    name: name
    args: args

  SubAttribute = wrap \SubAttribute ->
    name = (eat \SUBATTR).slice 2
    kind: \sub-attr
    name: name
    value: PrimaryExpression!

  AttrArgsList = wrap \AttrArgsList ->
    args = [ AttrArgument! ]
    while lookahead.type isnt \EOF and lookahead.type isnt \NEWLINE
      args.push AttrArgument!
    return args

  AttrArgument = wrap \AttrArgument ->
    switch lookahead.type
    | \SUBATTR => SubAttribute!
    | _        => Expression!


  # Expressions

  PrimaryExpression = wrap \PrimaryExpression ~>
    if lookahead.type is \PAREN_OPEN
      return ParenExpression!

    if is-bin-op peek!type
      return BinaryExpression!

    if peek!type is \OPER_ASS
      return AssignmentExpression!


    if lookahead.type is \IDENT
      return Identifier!

    return Expression!

  Expression = wrap \Expression ->
    if is-literal lookahead.type
      return Literal!

    switch lookahead.type
    | \PAREN_OPEN => ParenExpression!
    | \IDENT      => BinaryExpression!
    | \INTLIKE    => BinaryExpression!
    | \STRING     => Literal!
    | \SYMBOL     => Symbol!
    | \OPER_NOT   => UnaryExpression!
    | _           => debug "No expression for type #that"; eat that; null

  ParenExpression = wrap \ParenExpression ->
    eat \PAREN_OPEN
    expr = Expression!
    eat \PAREN_CLOSE
    return expr

  UnaryExpression = wrap \UnaryExpression ->
    oper =
      switch lookahead.type
      | \OPER_NOT => oper := eat \OPER_NOT
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

    while is-bin-op lookahead.type
      oper = lookahead.type

      node :=
        kind: \binary
        type: \AutoNum
        oper: eat lookahead.type
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

    if lookahead.type isnt \OPER_ASS
      return left

    eat \OPER_ASS
    right = BinaryExpression!

    kind:  \assign
    type:  right.type
    left:  check-valid-assign left
    right: right

  LeftHandSideExpression = wrap \LeftHandSideExpression ->
    if is-literal lookahead.type
      Literal!
    else
      Identifier!

  # Leaves

  Variable = wrap \Variable ->
    switch lookahead.type
    | \IDENT => Identifier!
    | _      => Literal!

  Literal = wrap \Literal ->
    switch lookahead.type
    | \TIMELIKE => TimeLiteral!
    | \INTLIKE  => NumericLiteral!
    | \BOOL     => BooleanLiteral!
    | \STRING   => StringLiteral!
    | \SYMBOL   => Symbol!
    | _         => eat lookahead.type; null

  Symbol = wrap \Symbol ->
    if eat \SYMBOL
      kind: \symbol
      name: that.slice 1

  BooleanLiteral = wrap \BooleanLiteral ->
    if eat \BOOL
      kind: \literal
      type: \AutoBool
      value: that is \true

  TimeLiteral = wrap \TimeLiteral ->
    if eat \TIMELIKE
      kind: \literal
      type: \AutoTime
      value: parse-time that

  NumericLiteral = wrap \NumericLiteral ->
    if eat \INTLIKE
      kind: \literal
      type: \AutoInt
      value: parse-int that

  StringLiteral = wrap \StringLiteral ->
    if eat \STRING
      kind: \literal
      type: \AutoStr
      value: that.replace /^"/, '' .replace /"$/, ''

  Identifier = wrap \Identifier ->
    name = eat \IDENT
    kind: \ident
    name: name
    reach: \here


  # Init

  set-lookahead Token \SOF, ""
  set-lookahead next!

  output = Root!

  return { output, steps }


