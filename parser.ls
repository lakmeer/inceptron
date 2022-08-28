
# Helpers

{ log, parse-time, any, dump, colors, treediff } = require \./utils
{ treediff, any-diffs } = treediff
{ color, bright, grey, red, yellow, green, blue, magenta, white, plus, minus } = colors

const clean-src = (txt = "") -> txt.replace /\n/g, bright blue \⏎


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
  [ \TRUE,        /^true\b/ ]
  [ \FALSE,       /^false\b/ ]
  [ \NULL,        /^null\b/ ]
  [ \TIMES,       /^times\b/ ]
  [ \OVER,        /^over\b/ ]
  [ \REACH,       /^local|share|uniq|lift|const\b/ ]
  [ \EASE,        /^ease\b/ ]
  [ \YIELD,       /^yield\b/ ]

  # Literals
  [ \TIMELIKE,    /^([\d]+h)?([\d]+m)?([\d]+s)?([\d]+ms)?\b/ ]
  [ \ATTR,        /^:[\w]+/ ]
  [ \SUBATTR,     /^::[\w]+/ ]
  [ \TREENODE,    /^<[\w]+\b/ ]
  [ \INTLIKE,     /^[\d]+/ ]
  [ \STRING,      /^"[^"]*"/ ]
  [ \STRCOM,      /^"[^"\n]*$/ ]
  [ \STRCOM,      /^"[^"\n]*/ ]

  # Identifiers
  [ \TYPE,        /^[A-Z]\w+/ ]
  [ \IDENT,       /^\w+/ ]

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

  # Whitespace
  [ \SPACE,       /^[\s]+/ ]
  [ \BLANK,       /^[\s]+$/ ]
  [ \BLANK,       /^[\s]+\n/ ]



# Token value is ALWAYS a string. Any post-processing goes in the
# parser function that turns this token into an AST node.

Token = (type, value) -> { type, value, length: value.length }


#
# Core functions
#

export const parse = (source) ->

  # Debug logger

  dent   = 0
  steps  = []
  bump   = (c, type) -> steps.push [ \BUMP, dent, lookahead, c ]
  debug  = (...args) -> steps.push [ \LOG,  dent, lookahead, clean-src args.join ' ' ]
  error  = (...args) -> steps.push [ \ERR,  dent, lookahead, clean-src args.join ' ' ]
  status =           -> steps.push [ \NEW,  dent, lookahead, ilog "#{green \new} #{lookahead.type}(#{yellow clean-src lookahead.value}) <- \"#{yellow clean-src lookahead.value}#{clean-src source.slice cursor}\"" ]
  ilog   = (...args) -> log ' ' * dent, ...args; return args[0]

  wrap = (name, ƒ) -> (...args) ->
    bump ilog blue \+ + name
    dent += 1
    result = ƒ ...args
    dent -= 1
    bump ilog grey \- + name
    return result


  # Tokeniser

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

  peek = (offset = 0) ->
    if cursor + offset >= source.length
      return [ \EOF, "" ]

    char = source[ cursor + offset ]
    rest = source.slice cursor + offset

    for [ type, rx ] in TOKEN_MATCHERS
      if token = match-rx rx, rest
        switch type
        | \BLANK, \SPACE, \INDENT => return peek offset + token.length
        | otherwise               => return [ type, token ]
        return [ type, token ]

    if !char
      error "Char token was '#{typeof! char}' at #{cursor + offset}", source.slice cursor + offset
    else
      throw error "Unexpected token: `#char`"

    return [ \UNKNOWN, char ]

  next = ->
    [ type, token ] = peek!
    cursor := cursor + token.length

    switch type
    | \STRCOM => return Token \STRING, token.trim-left!
    | _       => return Token type, token

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
      return node
    error "Can't assign to non-identifier"

  one-of = (types) -> -> types.includes it

  is-bool-op = one-of <[ OPER_EQUIV OPER_GT OPER_GTE OPER_LT OPER_LTE AND OR ]>
  is-math-op = one-of <[ OPER_ADD OPER_SUB OPER_MUL OPER_DIV ]>
  is-literal = one-of <[ TIMELIKE INTLIKE STRING ]>
  is-bin-op  = one-of <[ OPER_ADD OPER_SUB OPER_MUL OPER_DIV OPER_EQUIV OPER_GT OPER_GTE OPER_LT OPER_LTE AND OR ]>


  # Parser Nodes

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
    eat \SCOPE_END
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
    | \TIMES     => RepeatStatement!
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
    kind: \decl-stmt
    type: type
    reach: reach
    name: ident.name
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
    eat \TIMES
    kind: \repeat
    count: PrimaryExpression!
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
    args = if lookahead.type is \IDENT then TreePropList! else []
    kind: \treenode
    type: type
    args: args
    main: Body!

  TreeProperty = wrap \TreeProperty ->
    name = eat \IDENT
    eat \OPER_EQ
    value = PrimaryExpression!
    kind: \treeprop
    type: value.type
    name: name
    value: value

  TreePropList = wrap \TreeArgsList ->
    args = [ TreeProperty! ]
    while lookahead.type is \IDENT
      args.push TreeProperty!
    return args


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
    while lookahead.type isnt \EOF
      args.push AttrArgument!
    return args

  AttrArgument = wrap \AttrArgument ->
    switch lookahead.type
    | \SUBATTR => SubAttribute!
    | _        => PrimaryExpression!

  # Expressions

  PrimaryExpression = wrap \PrimaryExpression ->
    if is-literal lookahead.type
      return Literal!

    switch lookahead.type
    | \PAREN_OPEN => ParenExpression!
    | _           => BinaryExpression!

  Expression = wrap \Expression ->
    switch lookahead.type
    | \IDENT      => AssignmentExpression!
    | \INTLIKE    => BinaryExpression!
    | \STRING     => Literal!
    | \PAREN_OPEN => ParenExpression!
    | _           => debug "No expression for type #that"

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
        main: UnaryExpression!
    else
      return LeftHandSideExpression!

  BinaryExpression = wrap \BinaryExpression ->
    node = Variable!

    while is-bin-op lookahead.type
      oper = lookahead.type

      node :=
        kind: \binary
        type: \AutoNum
        oper: eat lookahead.type
        left: node
        right: PrimaryExpression!

      if is-bool-op oper
        node.type = \AutoBool
      else if node.left.type is node.right.type
        node.type = node.left.type

    return node

  AssignmentExpression = wrap \AssignmentExpression ->
    PartialAssignmentExpression LeftHandSideExpression!

  PartialAssignmentExpression = (left) ->
    if lookahead.type isnt \OPER_ASS
      return left

    eat \OPER_ASS
    right = BinaryExpression!

    kind:  \assign
    type:  right.type
    left:  check-valid-assign left
    right: right

  LeftHandSideExpression = wrap \LeftHandSideExpression ->
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
    | \STRING   => StringLiteral!
    | _         => null

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


