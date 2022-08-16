
# Imports

const { color } = require \console-log-colors
const { red, redBright, yellow, green, greenBright, blue, white, cyan, grey, black } = color


# Helpers

log   = (...args) -> console~log ...args; args.0
last  = (xs) -> if xs.length then xs[*-1] else null
error = log << red
warn  = log << yellow

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


class Attr
  (@name, @args) ->

  toString: (d = 0) ->
    pad = "  " * d
    head = grey ":#{cyan @name} "

    # TOOD: use @type instead
    pad + head + @args.map (.toString!)


class Value
  (@type, @reach, @value) ->
    if @value instanceof Array
      @isList = true

  toString: (d = 0) ->
    pad = "  " * d
    head = grey "<#{@type} "

    # TOOD: use @type instead
    switch typeof @value
    | \string  => pad + head + green \" + @value.trim() + \"
    | \number  => pad + head + yellow @value
    | \boolean => pad + head + if @value then (greenBright "?TRUE") else (redBright "?FALSE")



class Block
  (@type, @reach, @children) ->
    if not (@children instanceof Array)
      @children = [ @children ]

  promote: (parent) ->
    if not TYPE_INHERITS[parent.type].includes @type
      error "Unwrapped block type '#{@type}' is not compatible with yielding scope type: '#{parent.type}'"
      return Nothing

    new Block parent.type, parent.reach, @children

  toString: (d = 0) ->
    head = "#{blue @reach} #{white "<#{@type}"}"
    pad = "  " * d

    stringify = ->
      if it instanceof Block
        it.toString(d+1)
      else if it instanceof Value
        it.toString(d+1)
      else if it instanceof Nothing
        it.toString(d+1)
      else if it instanceof Attr
        it.toString(d+1)
      else
        log it
        pad + red "Don't know how to print #{@type}"

    if @children.0 instanceof Value and @children.length == 1
      "#pad#head " + @children.0.toString! + "\n"
    else
      "#pad#head \n" + @children.map stringify .join "\n"

  # TODO: Auto-promote
  # If a block has exactly one child, and the type of
  # the child is a perfect match for the scope type,
  # it can promoted up to collapse one level.


# Main

run = (ast) ->
  queue = []

  each = (node, env = {}) ->
    switch node.kind
    | \scope =>
      new Block node.type, \local,
        node.body
          .map    -> each it, env
          .filter -> not (it instanceof Nothing)  # Remove Expr`s that dont yield Blocks

      # TODO: Detect yielded Attrs and apply them to this instance

    | \literal =>
      new Value node.type, \local, node.main

    | \atom =>
      new Value \symbol, node.name

    | \attr =>
      new Attr node.name, node.args.map -> each it, env

    | \decl =>
      env[node.name] = each node.main, env
      new Nothing

    | \ident =>
      env[node.name] or new Nothing

    | \yield =>
      each node.main, env

    | \binary =>
      left  = each node.left, env
      right = each node.right, env

      assert left  instanceof Value
      assert right instanceof Value
      assert left.type,  ACCEPTED_TYPES[node.oper]
      assert right.type, ACCEPTED_TYPES[node.oper]

      new Value node.type, \local,
        switch node.oper
        | \+ => left.value + right.value
        | \- => left.value - right.value
        | \+ => left.value + right.value
        | \/ => left.value / right.value
        | \~ => left.value / right.value
        | _ =>
          warn "Unsupport operator: '#{node.oper}'"
          new Nothing

    | _ =>
      warn "Can't handle this expr kind: '#{node.kind}'"
      new Nothing


  return each ast



# Start

examples = require \./ast

program = examples.example

render = (.toString!)

log ""
log "\n--- SOURCE  ---\n"
log grey program.src
log "\n--- AST     ---\n"
log program.body
log "\n--- COMPUTE ---\n"
log out = run program
log "\n--- RESULT  ---\n"
log render out

