
# Imports

const { log, colors, dump } = require \./utils
const { plus, minus, bright, red, yellow, green, blue, white, magenta, cyan, grey } = colors


# Helpers

last = (xs) -> if xs.length then xs[*-1] else null
warn = -> log bright yellow it; it

assert = (desc, a, b = true) ->
  if b instanceof Array and not b.includes a
    log (red desc) + white " | expected one of [#{b.join \,}] but got `#a`"
  else if not b ~= a
    log (red desc) + white " | expected `#b` but got `#a`"
  else
    log bright green desc


# Reference constants

const BASIC_TYPES =
  <[ Int Real Num Str Bool Path Time Guid ]>

const ACCEPTED_TYPES =
  \+  : <[ Num Int Real AutoNum AutoInt AutoReal ]>
  \-  : <[ Num Int Real AutoNum AutoInt AutoReal ]>
  \*  : <[ Num Int Real AutoNum AutoInt AutoReal ]>
  \/  : <[ Num Int Real AutoNum AutoInt AutoReal ]>
  \~  : <[ Str Path AutoStr AutoPath List ]>
  \!  : <[ Bool ]>
  \== : <[ Bool AutoBool Num AutoNum Int AutoInt Real AutoReal Path AutoPath Str AutoStr ]>

const TYPE_INHERITS =
  \Num      : <[ Int Real Num AutoInt AutoReal AutoNum ]>
  \AutoNum  : <[ Int Real Num AutoInt AutoReal AutoNum ]>
  \Int      : <[ Int AutoInt ]>
  \AutoInt  : <[ Int AutoInt ]>
  \Real     : <[ Real AutoReal ]>
  \AutoReal : <[ Real AutoReal ]>


# TODO: Move these to a common file (types.ls) and import to both

class Nothing
  promote: (parent) ->
    return this

  toString: (d = 0) ->
    pad = "  " * d
    pad + grey "<Nothing>"

  unwrap: ->
    #log (yellow \unwrap), \Nothing
    null

class Attr
  (@name, @args) ->
    @type = \Attr

  toString: (d = 0) ->
    pad = "  " * d
    head = grey ":#{cyan @name} "

    # TOOD: use @type instead
    pad + head + @args.map (.toString!)

  unwrap: ->
    #log (yellow \unwrap), \Attr
    @args.map (.unwrap!)

class Value
  (@type, @reach, @value) ->
    if @value instanceof Array
      @isList = true

  toString: (d = 0) ->
    pad = "  " * d
    head = white "<#{@type} "

    # TOOD: use @type instead
    switch @type
    | \AutoStr  => pad + head + yellow \" + @value.trim() + \"
    | \AutoNum, \AutoInt, \AutoReal => pad + head + blue @value
    | \AutoCplx => pad + head + blue @value.txt
    | \AutoBool => pad + head + (if @value then (plus "?TRUE") else (minus "?FALSE"))
    | _        => pad + head + bright red "Unsupported Literal Type: #that"

  unwrap: ->
    #log (yellow \unwrap), \Value
    @value


class TreeNode
  (@type = "None", @reach, @children) ->
    if not (@children instanceof Array)
      @children = [ @children ]

    @attrs = []

  promote: (parent) ->
    if not TYPE_INHERITS[parent.type].includes @type
      error "Unwrapped block type '#{@type}' is not compatible with yielding scope type: '#{parent.type}'"
      return Nothing

    new TreeNode parent.type, parent.reach, @children

  set-attr: (attr) ->
    if not (attr instanceof Attr)
      return console.error (red "Tried to set attribute of #{@type} with a not-Attr object"), attr
    @attrs.push attr

  unwrap: ->
    #log (yellow \unwrap), \Treenode @type
    if @children.length
      last @children .unwrap!
    else
      null

  toString: (d = 0) ->
    head = blue "<#{@type}"
    pad = "  " * d

    stringify = ->
      if it instanceof TreeNode
        it.toString(d+1)
      else if it instanceof Value
        it.toString(d+1)
      else if it instanceof Nothing
        it.toString(d+1)
      else if typeof it is \undefined
        pad + "  " + red \??
      else
        pad + "  " + red "?? Don't know how to print #{@type}"

    # If there's only one child, put it on the same line
    if @children.length == 0 and @attrs.length == 0
      "#pad#head"
    else if @children.0 instanceof Value and @children.length == 1
      "#pad#head " +
        ((@children.map (.toString!)) ++ (@attrs.map (.toString(d + 1)))) .join "\n"
    else
      "#pad#head \n" +
        ((@attrs.map (.toString(d + 1))) ++ (@children.map stringify)).join "\n"

  # TODO: Auto-promote
  # If a block has exactly one child, and the type of
  # the child is a perfect match for the scope type,
  # it can promoted up to collapse one level.


# Main

eval-expr = (expr, env, trace) ->
  switch expr.kind
    | \scope =>
      new TreeNode expr.type, \local,
        expr.body
          .map    -> each it, env, trace
          .filter -> not (it instanceof Nothing)  # Remove Expr`s that dont yield TreeNode

    | \expr-stmt =>
      each expr.main, env, trace

    | \literal =>
      new Value expr.type, \local, expr.value

    | \atom =>
      new Value \symbol, expr.name

    | \attr =>
      new Attr expr.name, expr.args.map -> each it, env, trace

    | \decl-stmt =>
      env[expr.name] = each expr.value, env, trace
      new Nothing!

    | \assign =>
      ident = env[expr.left]
      value = each expr.right, env, trace

      # TODO: Type check assignments
      env[expr.left] = each expr.right, env, trace
      new Nothing!

    | \ident =>
      if env[expr.name]
        that
      else
        throw "Couldn't find variable '#{expr.name}' in scope"
        new Nothing!

    | \yield =>
      each expr.main, env, trace

    | \timing =>
      switch expr.type
      | \forever =>
          # set-immediate -> each expr, env, trace
          each expr.main, env, trace
      | \times =>
        new TreeNode \None, \local, do
          [ each expr.main, env, trace for i from 1 to expr.freq ]
      | _ =>
        trace [ \WARN, warn "Unsupported timing type: '#{expr.type}'" ]

    | \binary =>
      left  = each expr.left, env, trace
      right = each expr.right, env, trace

      if not left
        log left
        throw \halt

      trace [ \ASSERT, assert "Left operand is a Value",  left  instanceof Value ]
      trace [ \ASSERT, assert "Right operand is a Value", right instanceof Value ]
      trace [ \ASSERT, assert "Left type is compatible",  left.type,  ACCEPTED_TYPES[expr.oper] ]
      trace [ \ASSERT, assert "Right type is compatible", right.type, ACCEPTED_TYPES[expr.oper] ]

      new Value expr.type, \local,
        switch expr.oper
        | \+  => left.value + right.value
        | \-  => left.value - right.value
        | \*  => left.value * right.value
        | \/  => left.value / right.value
        | \:= => log (red \:=), left, right
        | \== => left.value is right.value
        | _ =>
          trace [ \WARN, warn "Unsupported operator: '#{expr.oper}'" ]
          new Nothing

    | \funcdef =>
      env[expr.name] = (...args) ->
        # TODO: Typecheck args here
        new-env = env <<< { [ name, args[i] ] for { name }, i in expr.args }
        console.log new-env
        each(expr.main, new-env, trace).unwrap!

      log \invoke
      env[expr.name](2, 3);

      throw \halt
      new Nothing!


    | _ =>
      trace [ \WARN, warn "Can't handle this kind of Expr: '#{expr.kind}'" ]
      new Nothing


each = (expr, env, trace = ->) ->

  trace [ \EVAL, expr.kind, expr ]

  yld = eval-expr expr, env, trace

  # Analyse yielded blocks
  if yld instanceof TreeNode
    new-children = []

    for child, ix in yld.children
      switch child.type
      | \Attr => yld.set-attr child
      | \None => new-children ++= child.children
      | _     => new-children.push child

    yld.children = new-children

  return yld


#
# Exported Interface
#

export run = (root) ->
  tracestack = []

  try
    result = each root, {}, tracestack~push
    ast: root
    error: false
    result: result
    trace: tracestack

  catch ex
    ast: root
    error: ex.message
    result: undefined
    trace: tracestack

