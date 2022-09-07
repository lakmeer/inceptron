
# Imports

const { log, colors, dump } = require \./utils
const { plus, minus, bright, red, yellow, green, blue, white, magenta, cyan, grey } = colors


# Helpers

last = (xs) -> if xs.length then xs[*-1] else null
warn = -> log bright yellow it; it

assert = (desc, a, b = true) ->
  if b instanceof Array and not b.includes a
    [ false, desc, "expected one of [#{b.join \,}] but got `#a`" ]
  else if not b ~= a
    [ false, desc, "expected `#b` but got `#a`" ]
  else
    [ true, desc ]


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


# Environment

class Env
  (@store = {}) ->
    @watch = []

  get: (k) ->
    if @store[k] then that else null

  set: (k, v) ->
    @store[k] = v
    @emit \change, k, v
    trace [ \ENV, this ]

  on: (sel, λ) ->
    @watch.push [ ...sel.split(\!), λ ]

  emit: (ev, o, v) ->
    [ λ(v) for [ k, e, λ ] in @watch when @match ev, k, e, o ]

  match: (ev, k, e, s) ->
    ev is e

  fork: ->
    new Env { [ k, v ] for k, v of @store }

  summary: ->
    lines = []
    for k, v of @store => lines.push [ k, v ]
    #for it, ix in @watch => lines.push \???
    lines


# TODO: Move these to a common file (tree-nodes.ls) and import to both

class Error
  (@error-type, @text) ->
    @type = \Error

  toString: ->
    "#{minus " #{@error-type} "} #{@text}"

  unwrap: ->
    { @type, @text }

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
      @is-list = true

  toString: (d = 0) ->
    pad = "  " * d

    if @is-list
      head = white "<#{@type}`s [\n"
      pad + head + @value.map(-> it.to-string(d + 1)).join(\\n) +
      pad + "\n\]"

    else
      head = white "<#{@type} "

      # TOOD: use @type instead
      switch @type
      | \Str,  \AutoStr  => pad + head + yellow \" + @value.trim() + \"
      | \Num,  \AutoNum  => pad + head + blue @value
      | \Int,  \AutoInt  => pad + head + blue @value
      | \Real, \AutoReal => pad + head + blue @value
      | \Cplx, \AutoCplx => pad + head + blue @value.txt
      | \Time, \AutoTime => pad + head + bright green @value
      | \Time, \AutoPath => pad + head + bright magenta '/' + @value.join '/'
      | \Book, \AutoBool => pad + head + (if @value then (plus "?TRUE") else (minus "?FALSE"))
      | _        => pad + head + bright red "Unsupported Literal Type: #that"

  unwrap: ->
    if @type in <[ Path AutoPath ]>
      log @value
      \/ + @value.join \/
    else if @is-list
      @value.map (.unwrap!)
    else
      @value


class Lambda
  (@type, @argtypes, @env, @main) ->
    @kind = \lambda

  eval: (args, env, trace) ->
    new-env = env.fork!

    # TODO: Runtime typecheck of args
    for { value }, ix in args
      { name, type } = @argtypes[ix]
      new-env.set name, new Value type, \local, value

    return each @main, new-env, trace

  toString: (d = 0) ->
    pad = "  " * d
    pad + "#{bright magenta \<Lambda} λ(#{@argtypes.map (.type) .join ', '}) -> #{@type}"


class TreeNode
  (@type = "None", @reach, @children) ->
    if not (@children instanceof Array)
      @children = [ @children ]

    @attrs = []

  promote: (parent) ->
    if not TYPE_INHERITS[parent.type].includes @type
      error "Unwrapped block type '#{@type}' is not compatible with yielding scope type: '#{parent.type}'"
      return new Nothing!

    new TreeNode parent.type, parent.reach, @children

  set-attr: (attr) ->
    if not (attr instanceof Attr)
      return console.error (red "Tried to set attribute of #{@type} with a not-Attr object"), attr
    @attrs.push attr

  unwrap: ->
    if @children.length
      last @children .unwrap?!
    else
      null

  toString: (d = 0) ->
    head = blue "<#{@type}"
    pad = "  " * d

    stringify = ->
      if not it.type or it is \undefined
        pad + "  " + red "?? Don't know how to print #{it.type}"
      else
        pad + "  " + it.toString d + 1

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
      env.set expr.name, each expr.value, env, trace
      new Nothing!

    | \assign =>
      ident = env[expr.left]
      value = each expr.right, env, trace
      env.set expr.left, value
      new Nothing!

    | \ident =>
      if env.get expr.name
        that
      else
        new Error \ReferenceError, "Could not find referent of '#{expr.name}' in scope"

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

    | \emit =>
      args = expr.args.map -> each it, env, trace
      env.emit expr.name, ...args

    | \on =>
      env.on expr.name, (...args) -> each  console.log \it, args

    | \binary =>
      left  = each expr.left, env, trace
      right = each expr.right, env, trace

      trace [ \ASSERT, ...assert "Left operand is a Value",  left  instanceof Value ]
      trace [ \ASSERT, ...assert "Right operand is a Value", right instanceof Value ]
      trace [ \ASSERT, ...assert "Left type is compatible",  left.type,  ACCEPTED_TYPES[expr.oper] ]
      trace [ \ASSERT, ...assert "Right type is compatible", right.type, ACCEPTED_TYPES[expr.oper] ]

      new Value expr.type, \local,
        switch expr.oper
        | \+   => left.value + right.value
        | \-   => left.value - right.value
        | \*   => left.value * right.value
        | \/   => left.value / right.value
        | \~   => left.value + right.value
        | \^   => Math.pow(left.value, right.value)
        | \==  => left.value is right.value
        | \or  => left.value or right.value
        | \and => left.value and right.value
        | _ =>
          trace [ \WARN, warn "Unsupported operator: '#{expr.oper}'" ]
          new Nothing!

    | \procdef =>
      proc = new Lambda \Nothing, [], env.fork!, expr.main
      env.set expr.name, proc
      return proc

    | \funcdef =>
      func = new Lambda expr.type, expr.args, env.fork!, expr.main
      env.set expr.name, func
      return func

    | \call =>
      if env.get expr.name
        that.eval expr.args, env, trace
      else
        new Error \ReferenceError, "Could not find referent of '#{expr.name}' in scope"

    | \list =>
      new Value expr.type, \local, expr.members.map -> each it, env, trace

    | _ =>
      trace [ \WARN, warn "Can't handle this kind of Expr: '#{expr.kind}'" ]
      new Nothing!


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

  #try
  result = each root, (new Env!), tracestack~push
  ast: root
  error: false
  result: result
  trace: tracestack

  #catch ex
    #ast: root
    #error: ex.message
    #result: undefined
    #trace: tracestack

