
# Helpers

{ log, parse-time, select, any, limit, header, big-header, dump, colors, treediff } = require \./utils
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
  [ \RANGE,       /^local\b/ ]
  [ \TRUE,        /^true\b/ ]
  [ \FALSE,       /^false\b/ ]
  [ \NULL,        /^null\b/ ]
  [ \AND,         /^and\b/ ]
  [ \OR,          /^or\b/ ]
  [ \TIMES,       /^times\b/ ]
  [ \OVER,        /^over\b/ ]
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

  # Operators
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

  # Identifiers
  [ \TYPE,        /^[A-Z]\w+/ ]
  [ \IDENT,       /^\w+/ ]

  # Whitespace
  [ \SPACE,       /^[\s]*/ ]
  [ \BLANK,       /^[\s]*$/ ]



# Token value is ALWAYS a string. Any post-processing goes in the
# parser function that turns this token into an AST node.

Token = (type, value) -> { type, value, length: value.length }


#
# Core functions
#

export const parse = (source) ->

  # Debug logger

  steps  = []
  bump   = (c, type) -> steps.push [ \BUMP, "#{lookahead.type} #{white c}" ]
  debug  = (...args) -> steps.push [ \DEBUG, clean-src args.join ' ' ]
  error  = (...args) -> steps.push [ \ERROR, clean-src args.join ' ' ]
  status = -> steps.push [ lookahead, ((yellow clean-src lookahead.value) + clean-src source.slice cursor), peek! ]

  wrap = (name, ƒ) -> (...args) ->
    bump blue \+ + name
    result = ƒ ...args
    bump grey \- + name
    return result


  # Tokeniser

  cursor    = 0
  lookahead = null

  set-lookahead = (token) ->
    lookahead := token
    status!

  eat = (type) ->
    steps.push [ \EAT, type ]

    token = lookahead

    if token.type isnt type
      error "Unexpected token (expected '#type', got #{token.type})"

    set-lookahead next!
    return token.value

  peek = ->
    if cursor >= source.length
      return [ \EOF, "" ]

    char = source[ cursor ]
    rest = source.slice cursor

    for [ type, rx ] in TOKEN_MATCHERS
      if token = match-rx rx, rest
        return [ type, token ]

    if !char
      error "Char token was '#{typeof! char}' at #{cursor}", source.slice cursor
    else
      throw error "Unexpected token: `#char`"

    return [ \UNKNOWN, char ]

  next = ->
    [ type, token ] = peek!
    cursor := cursor + token.length

    switch type
    | \BLANK, \SPACE, \INDENT => return next!
    | \STRCOM  => return Token \STRING, token.trim-left!
    | _        => return Token type, token

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
  is-literal = one-of <[ INTLIKE STRING ]>
  is-range   = one-of <[ local share uniq lift ]>
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
    body =
      switch lookahead.type
      | \SCOPE_END => eat \SCOPE_END; []
      | _          => Body!
    if lookahead.type is \SCOPE_END
      eat \SCOPE_END
    kind: \scope
    type: \???
    body: body

  # Statements

  Statement = wrap \Statement ->
    switch lookahead.type
    | \;         => EmptyStatement!
    | \IF        => IfStatement!
    | \ATTR      => AttrStatement!
    | \RANGE     => DeclarationStatement!
    | \TIMES     => RepeatStatement!
    | \OVER      => TimeStatement!
    | \YIELD     => Yield!
    | \TREENODE  => TreeNode!
    | \SCOPE_BEG => Scope!
    | _          => ExpressionStatement!

  EmptyStatement = wrap \EmptyStatement -> null

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
    range = eat \RANGE
    type  = eat \TYPE
    ident = Identifier!
    eat \OPER_EQ

    kind: \decl-stmt
    type: type
    range: range
    ident: ident
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
    switch lookahead.type
    | \PAREN_OPEN => ParenExpression!
    | \IDENT      =>
      left = Identifier!
      switch lookahead.type
      | \OPER_ASS => PartialAssignmentExpression left
      | _         => PartialBinaryExpression left
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

  BinaryExpression = wrap \BinaryExpression ->
    PartialBinaryExpression Variable!

  PartialBinaryExpression = (node) ->
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
    range: \here


  # Init

  set-lookahead Token \SOF, ""
  set-lookahead next!

  output = Root!

  return { output, steps }


