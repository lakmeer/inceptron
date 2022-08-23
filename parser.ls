
# Helpers

{ log, any, limit, header, big-header, dump, colors, treediff } = require \./utils
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
  [ \ATTR,        /^:[\w]+/ ]
  [ \SUBATTR,     /^::[\w]+/ ]
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
      error "Unexpected token: `#char`"

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

  is-bin-op  = one-of <[ OPER_ADD OPER_SUB OPER_MUL OPER_DIV OPER_EQUIV ]>
  is-math-op = one-of <[ OPER_ADD OPER_SUB OPER_MUL OPER_DIV ]>
  is-literal = one-of <[ INTLIKE STRING ]>
  is-range   = one-of <[ local share uniq lift ]>


  # Parser Nodes

  Root = wrap \Root ->
    kind: \scope
    type: \Root
    body: Body!

  Body = wrap \Body ->
    list = [ Statement! ]
    while lookahead.type isnt \EOF and lookahead.type isnt \SCOPE_END
      list.push Statement!
    return list

  Scope = wrap \Scope ->
    eat \SCOPE_BEG
    body =
      switch lookahead.type
      | \SCOPE_END => eat \SCOPE_END; []
      | _          => Body!
    kind: \scope
    type: \???
    body: body

  # Statements

  Statement = wrap \Statement ->
    ret = switch lookahead.type
    | \;         => EmptyStatement!
    | \IF        => IfStatement!
    | \ATTR      => AttrStatement!
    | \RANGE     => DeclarationStatement!
    | \SCOPE_BEG => Scope!
    | _          => ExpressionStatement!
    return ret

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
    if lookahead.type is \SCOPE_BEG
      fail := Scope!
    eat \SCOPE_END
    kind: \if
    cond: cond
    pass: pass
    fail: fail

  AttrStatement = wrap \AttrStatement ->
    kind: \attr-stmt
    type: \???
    attr: Attribute!

  VariableDeclaration = wrap \VariableDeclaration ->
    ident = Identifier!
    eat \OPER_ASS
    kind: \ident
    type: \???
    value: Expression!

  # Attributes

  Attribute = wrap \Attribute ->
    name = (eat \ATTR).slice 1
    args = ArgsList!
    kind: \attr
    name: name
    args: args

  SubAttribute = wrap \SubAttribute ->
    name = (eat \SUBATTR).slice 2
    kind: \sub-attr
    name: name
    value: PrimaryExpression!

  ArgsList = wrap \ArgsList ->
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
    return BinaryExpression! if is-literal lookahead.type
    switch lookahead.type
    | \PAREN_OPEN => ParenExpression!
    | \SUBATTR    => SubAttr!
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

  Variable = wrap \Variable ->
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

  Literal = wrap \Literal ->
    switch lookahead.type
    | \INTLIKE => NumericLiteral!
    | \STRING  => StringLiteral!
    | _        => null

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


#
# Run Tests
#

# Helpers

examples  = require \./test
options   = Object.keys examples
current   = options.length

format-step = ([ token, src, peek ], ix) ->
  switch token
  | \ERROR => "#{red     \err} | " + bright src
  | \DEBUG => "#{blue    \log} | " + blue src
  | \EAT   => "#{magenta \eat} | " + magenta src
  | \BUMP  => "#{grey    \---} | " + grey src
  | _      => "#{green   \new} | #{bright token.type}(#{yellow clean-src token.value}) #{bright \<-} \"#src\""


# Test run function

run-tests = (current) ->
  selection = options[current]
  program   = examples[selection]

  console.clear!
  big-header bright "RUNNING TEST CASES"

  for name, program of examples
    result = parse program.src
    output = result.output
    diff   = treediff program.ast, output
    steps  = result.steps

    inspecting = selection is name
    any-errors = any steps.map ([ type ]) -> type is \ERROR
    passed     = not diff.any and not any-errors


    # Readout

    if passed
      big-header bright green name

      if inspecting
        log white program.src
        big-header \Parser
        log steps.map(format-step).join \\n
        big-header \Output
        log dump output, color: on
        return log bright blue "\n... finished inspecting #name"

    else
      big-header bright red name

      for step in steps when step.0 is \ERROR
        log format-step step

      if inspecting
        log white program.src
        big-header \Parser
        log result.steps.map(format-step).join \\n
        big-header \Output
        log (color 1,41) "AST Mismatch"
        log ""
        log diff.summary
        green dump program.ast.body
        red dump output.body
        log ""
        return log bright red "\nTest '#name' Failed"


# Begin

stdin = process.stdin

stdin.setRawMode on .resume!
stdin.setEncoding \utf8

stdin.on \data, (key) ->
  process.exit! if key is '\u0003'
  str = key.toString!
  prev = current
  if str.length is 3
    switch str.char-code-at 2
    | 65 => current := limit 0, options.length, current - 1
    | 66 => current := limit 0, options.length, current + 1
  if prev isnt current
    run-tests current

run-tests current

