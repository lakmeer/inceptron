
# Helpers

{ log, header, big-header, dump, colors, treediff } = require \./utils
{ treediff, any-diffs } = treediff
{ color, bright, grey, red, yellow, green, blue, magenta, white } = colors

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
  [ \,,           /^,/ ]

  # Keywords
  [ \IF,          /^\bif\b/ ]
  [ \RANGE,       /^\blocal\b/ ]

  # Primitive Literals
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

  # Identifiers
  [ \TYPE,        /^[A-Z]\w+/ ]
  [ \IDENT,       /^\w+/ ]

  # Whitespace
  [ \SPACE,       /^[\s]*/ ]
  [ \BLANK,       /^[\s]*$/ ]


#
# Core functions
#

const parse = (source) ->

  # Token value is ALWAYS a string. Any post-processing goes in the
  # parser function that turns this token into an AST node.

  Token = (type, value) -> { type, value, length: value.length }


  # Debug logger

  steps  = []
  bump   = (c, type) -> steps.push [ \BUMP,  "#{grey type} #{white c}" ]
  debug  = (...args) -> steps.push [ \DEBUG, clean-src args.join ' ' ]
  error  = (...args) -> steps.push [ \ERROR, clean-src args.join ' ' ]
  status = -> steps.push [ lookahead, ((yellow clean-src lookahead.value) + clean-src source.slice cursor), peek! ]


  # Tokeniser

  cursor    = 0
  lookahead = null

  set-lookahead = (token) ->
    lookahead := token
    status!

  eat = (type) ->
    steps.push [ \EAT, type ]

    token = lookahead

    if token is null or token.type is \EOF
      error "Unexpected end of input (expected #type)"

    if token.type isnt type
      error "Unexpected token (expected '#type', got #{token.type})"

    set-lookahead next!
    return token.value

  peek = ->
    char = source[ cursor ]
    rest = source.slice cursor

    for [ type, rx ] in TOKEN_MATCHERS
      if token = match-rx rx, rest
        return [ type, token ]

    error "Unexpected token: `#char`"
    return [ \UNKNOWN, char ]

  next = ->
    if cursor >= source.length
      return Token \EOF, ""

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

  is-bin-op  = one-of <[ OPER_ADD OPER_SUB OPER_MUL OPER_DIV OPER_EQUIV ]>
  is-math-op = one-of <[ OPER_ADD OPER_SUB OPER_MUL OPER_DIV ]>
  is-literal = one-of <[ INTLIKE STRING ]>
  is-range   = one-of <[ local share uniq lift ]>


  # Parser Nodes

  Root = ->
    bump \Root, lookahead.type
    kind: \scope
    type: \Root
    body: Body!

  Body = ->
    bump \Body, lookahead.type
    list = [ Statement! ]
    while lookahead.type isnt \EOF
      list.push Statement!
    return list

  Scope = ->
    bump \Scope, lookahead.type
    eat \SCOPE_BEG
    body =
      switch lookahead.type
      | \SCOPE_END => eat \SCOPE_END; []
      | _          => Body!
    kind: \scope
    type: \???
    body: body

  # Statement

  Statement = ->
    bump \Statement, lookahead.type
    switch lookahead.type
    | \;         => EmptyStatement!
    | \IF        => IfStatement!
    | \RANGE     => DeclarationStatement!
    | \SCOPE_BEG => Scope!
    | _          => ExpressionStatement!

  EmptyStatement = -> null

  ExpressionStatement = ->
    bump \ExpressionStatement, lookahead.type
    expr = PrimaryExpression!
    switch lookahead.type
    | \NEWLINE   => eat \NEWLINE # This is a TDD prayer, could cause problems
    | \EOF       => void
    | _          => eat \;
    kind: \expr-stmt
    type: \???
    main: expr

  DeclarationStatement = ->
    bump \DeclarationStatement, lookahead.type
    range = eat \RANGE
    type  = eat \TYPE
    ident = Identifier!
    eat \OPER_EQ

    kind: \decl-stmt
    type: type
    range: range
    ident: ident
    value: PrimaryExpression!

  IfStatement = ->
    bump \IfStatement, lookahead.type
    eat \IF
    cond = BinaryExpression!
    pass = Scope!
    fail = null
    if lookahead.type is \SCOPE_BEG
      fail := Scope!
    kind: \if
    cond: cond
    pass: pass
    fail: fail

  VariableDeclaration = ->
    bump \VariableDeclaration, lookahead.type
    ident = Identifier!
    eat \OPER_ASS
    kind: \ident
    type: \???
    value: Expression!

  # Expression

  PrimaryExpression = ->
    bump \PrimaryExpression, lookahead.type
    return BinaryExpression! if is-literal lookahead.type
    switch lookahead.type
    | \PAREN_OPEN => ParenExpression!
    | \IDENT      =>
      left = Identifier!
      switch lookahead.type
      | \OPER_ASS => PartialAssignmentExpression left
      | _         => PartialBinaryExpression left
    | _           => BinaryExpression!

  Expression = ->
    bump \Expression, lookahead.type
    switch lookahead.type
    | \IDENT      => AssignmentExpression!
    | \INTLIKE    => BinaryExpression!
    | \STRING     => Literal!
    | \PAREN_OPEN => ParenExpression!
    | _           => debug "No expression for type #that"

  ParenExpression = ->
    bump \ParenExpression, lookahead.type
    eat \PAREN_OPEN
    expr = Expression!
    eat \PAREN_CLOSE
    return expr

  BinaryExpression = ->
    bump \BinaryExpression, lookahead.type
    PartialBinaryExpression Variable!

  Variable = ->
    switch lookahead.type
    | \IDENT => Identifier!
    | _      => Literal!

  PartialBinaryExpression = (node) ->
    while is-bin-op lookahead.type
      oper = lookahead.type

      node :=
        kind: \binary
        type: \AutoNum
        oper: eat lookahead.type
        left: node
        right: PrimaryExpression!

      if oper is \OPER_EQUIV
        node.type = \AutoBool
      else if node.left.type is node.right.type
        node.type = node.left.type

    return node

  AssignmentExpression = ->
    bump \AssignmentExpression, lookahead.type
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

  LeftHandSideExpression = ->
    bump \LeftHandSideExpression, lookahead.type
    Identifier!

  # Leaves

  Literal = ->
    bump \Literal, lookahead.type
    switch lookahead.type
    | \INTLIKE => NumericLiteral!
    | \STRING  => StringLiteral!
    | _        => null

  NumericLiteral = ->
    bump \NumericLiteral, lookahead.type
    if eat \INTLIKE
      kind: \literal
      type: \AutoInt
      value: parse-int that

  StringLiteral = ->
    bump \StringLiteral, lookahead.type
    if eat \STRING
      kind: \literal
      type: \AutoStr
      value: that.replace /^"/, '' .replace /"$/, ''

  Identifier = ->
    bump \Identifier, lookahead.type
    name = eat \IDENT
    kind: \ident
    name: name
    range: \here


  # Init

  set-lookahead Token \SOF, ""
  set-lookahead next!

  output = Root!

  return { output, steps }


#
# Run Tests
#

format-step = ([ token, src, peek ], ix) ->
  switch token
  | \ERROR => "#{red     \err} | " + bright src
  | \DEBUG => "#{blue    \log} | " + blue src
  | \EAT   => "#{magenta \eat} | " + magenta src
  | \BUMP  => "#{grey    \---} | " + grey src
  | _      => "#{green   \new} | #{bright token.type}(#{yellow clean-src token.value}) #{bright \<-} \"#src\""

examples  = require \./test
options   = Object.keys examples
selection = options.18
program   = examples[selection]


# console.clear!


for let name, program of examples
  result = parse program.src
  output = result.output
  diff   = treediff program.ast, output

  if not diff.any
    if selection is name
      big-header green name
      log program.src
      big-header \Parser
      log result.steps.map(format-step).join \\n
      # big-header \Output
      # log dump output, color: on
    else
      header green name

  else
    big-header red name
    log white program.src
    big-header \Parser
    log result.steps.map(format-step).join \\n
    log ""
    log (color 1,41) "AST Mismatch"
    #log diff.summary
    big-header \Output
    #log green dump program.ast.body
    #log red dump output.body
    log ""
    throw red "\nTest '#name' Failed"

  if selection is name
    log "\n"
    throw yellow "\nInspection Complete"

