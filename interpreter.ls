
# Imports

const { log, header, colors, dump } = require \./utils
const { plus, minus, bright, red, yellow, green, blue, white, cyan, grey, black } = colors


# Helpers

last   = (xs) -> if xs.length then xs[*-1] else null
warn   = -> yellow it

assert = (a, b = true) ->
  if b instanceof Array and not b.includes a
    error red "ASSERT expects one of [#{b.join \,}] but got `#a`"
  else if not b ~= a
    error red "ASSERT expects `#b` but got `#a`"



# Reference constants

const BASIC_TYPES =
  <[ Int Real Num Str Bool Path Time Guid ]>

const ACCEPTED_TYPES =
  \+ : <[ Num Int Real AutoNum AutoInt AutoReal ]>
  \- : <[ Num Int Real AutoNum AutoInt AutoReal ]>
  \* : <[ Num Int Real AutoNum AutoInt AutoReal ]>
  \/ : <[ Num Int Real AutoNum AutoInt AutoReal ]>
  \~ : <[ Str Path AutoStr AutoPath List ]>
  \! : <[ Bool ]>

const TYPE_INHERITS =
  \Num      : <[ Int Real Num AutoInt AutoReal AutoNum ]>
  \AutoNum  : <[ Int Real Num AutoInt AutoReal AutoNum ]>
  \Int      : <[ Int AutoInt ]>
  \AutoInt  : <[ Int AutoInt ]>
  \Real     : <[ Real AutoReal ]>
  \AutoReal : <[ Real AutoReal ]>


# Expr represents a live scope

# Block captures an expired scope

# TODO: Move these to a common file (types.ls) and import to both
# TODO: Use explicit Expr class for constructing the AST in ast.ls

class Nothing
  promote: (parent) ->
    return this

  toString: (d = 0) ->
    pad = "  " * d
    pad + grey "<Nothing>"

  unwrap: ->
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
    @args.map (.unwrap!)

class Value
  (@type, @reach, @value) ->
    if @value instanceof Array
      @isList = true

  toString: (d = 0) ->
    pad = "  " * d
    head = white "<#{@type} "

    # TOOD: use @type instead
    switch typeof @value
    | \string  => pad + head + bright green \" + @value.trim() + \"
    | \number  => pad + head + yellow @value
    | \boolean => pad + head + if @value then (plus "?TRUE") else (minus "?FALSE")

  unwrap: -> @value


class Block
  (@type = "None", @reach, @children) ->
    if not (@children instanceof Array)
      @children = [ @children ]

    @attrs = []

  promote: (parent) ->
    if not TYPE_INHERITS[parent.type].includes @type
      error "Unwrapped block type '#{@type}' is not compatible with yielding scope type: '#{parent.type}'"
      return Nothing

    new Block parent.type, parent.reach, @children

  set-attr: (attr) ->
    if not (attr instanceof Attr)
      return console.error (red "Tried to set attribute of #{@type} with a not-Attr object"), attr
    @attrs.push attr

  unwrap: ->
    last @children .unwrap!

  toString: (d = 0) ->
    head = blue "<#{@type}"
    pad = "  " * d

    stringify = ->
      if it instanceof Block
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

each = (expr, env) ->
  yld = switch expr.kind
    | \scope =>
      new Block expr.type, \local,
        expr.body
          .map    -> each it, env
          .filter -> not (it instanceof Nothing)  # Remove Expr`s that dont yield Blocks

    | \literal =>
      new Value expr.type, \local, expr.main

    | \atom =>
      new Value \symbol, expr.name

    | \attr =>
      new Attr expr.name, expr.args.map -> each it, env

    | \decl =>
      env[expr.name] = each expr.main, env
      new Nothing

    | \assign =>

      ident = env[expr.name]
      value = each expr.main, env

      # TODO: Type check assignments

      env[expr.name] = each expr.main, env
      new Nothing

    | \ident =>
      env[expr.name] or new Nothing

    | \yield =>
      each expr.main, env

    | \timing =>
      switch expr.type
      | \forever =>
          # set-immediate -> each expr, env
          each expr.main, env
      | \times =>
        new Block \None, \local, do
          for i from 1 to expr.freq
            each expr.main, env
      | _ =>
        warn "Unsupported timing type: '#{expr.type}'"

    | \binary =>
      left  = each expr.left, env
      right = each expr.right, env

      assert left  instanceof Value
      assert right instanceof Value
      assert left.type,  ACCEPTED_TYPES[expr.oper]
      assert right.type, ACCEPTED_TYPES[expr.oper]

      new Value expr.type, \local,
        switch expr.oper
        | \+  => left.value + right.value
        | \-  => left.value - right.value
        | \*  => left.value * right.value
        | \/  => left.value / right.value
        | \:= => log (red \:=), left, right
        | _ =>
          warn "Unsupport operator: '#{expr.oper}'"
          new Nothing

    | _ =>
      warn "Can't handle this kind of Expr: '#{expr.kind}'"
      new Nothing


  # Analyse yielded blocks
  if yld instanceof Block
    new-children = []

    for child, ix in yld.children
      switch child.type
      | \Attr => yld.set-attr child
      | \None => new-children ++= child.children
      | _     => new-children.push child

    yld.children = new-children

  return yld


#
# Test Runner
#

run-and-test = (selection) ->
  program = tests[selection]

  header bright green selection
  log bright program.src
  log ""

  #{ output, steps } = Parser.parse program.src

  result = each program.ast
  final = result.unwrap!

  log result.to-string!
  log bright "Final Value:", yellow final
  log ""

  if final and final === program.val
    header plus "#selection: Passed"
  else
    log bright red "Expected '#{program.val}' but got '#{final}'"
    log ""
    header minus "#selection: Failed"


#
# Run Tests
#

tests = require \./test

console.clear!

run-and-test \SimpleProgram

