const fs = require('fs')


# Helpers

const log = (...args) -> console.log(...args); args[0]
const readfile = (name) -> fs.readFileSync("../sketches/#name.tron").toString!


# Core functions

const parse = (source) ->
  i = 0

  word   = ""
  tokens = []
  dent = 0
  sol    = true

  next = ->
    log \|-> word
    switch word
    | "node"    => fallthrough
    | "comp"    => tokens.push [ \DEF_COMP,   word,            dent ]
    | "lift"    => tokens.push [ \KEY_LIFT,   null,            dent ]
    | "uniq"    => tokens.push [ \KEY_UNIQ,   null,            dent ]
    | "local"   => tokens.push [ \KEY_LOCAL,  null,            dent ]
    | "if"      => tokens.push [ \IF,         null,            dent ]
    | "then"    => tokens.push [ \THEN,       null,            dent ]
    | "("       => tokens.push [ \OPEN_PAR,   null,            dent ]
    | ")"       => tokens.push [ \CLOSE_PAR,  null,            dent ]
    | "="       => tokens.push [ \OP,         \ASSIGN,         dent ]
    | "->"      => tokens.push [ \OP,         \FUNC,           dent ]
    | ">>"      => tokens.push [ \OP,         \MAP,            dent ]
    | ">>="     => tokens.push [ \OP,         \MAP_ASSIGN,     dent ]
    | "||"      => tokens.push [ \OP,         \FILTER,         dent ]
    | "||="     => tokens.push [ \OP,         \FILTER_ASSIGN,  dent ]
    | "<<"      => tokens.push [ \OP,         \REDUCE,         dent ]
    | "<<="     => tokens.push [ \OP,         \REDUCE_ASSIGN,  dent ]
    | "..."     => tokens.push [ \NOYIELD,    null,            dent ]
    | ""        => tokens.push [ \NEWLINE,    null,            dent ]
    | _ =>
      if (parse-int word) ~= word
        tokens.push [\NUMBER, word, dent]
      else if word.0.toUpperCase! === word.0
        tokens.push [\TYPE, word, dent]
      else
        tokens.push [\IDENT, word, dent]

    word := ""

  while i++ < source.length - 1
    char = source[i]

    switch char
    | "\n" =>
      dent := 0
      sol := true
      next!

    | " " =>
      if sol then
        dent += 1
      else
        next!

    | "(" ")" =>
      next!
      word := char
      next!

    | _ =>
      if sol then
        sol := false
        next!
      word += char

  tokens


# Tests files

log ""
log "TEST PROGRAM:"

tokens = parse readfile \0

i    = 0
out  = ""

while i < tokens.length - 1
  prev  = tokens[i - 1]
  token = tokens[i]
  next  = tokens[i + 1]

  [ tag, value, dent ] = token
  [ next-tag, next-value, next-dent ] = next or [ \EOF null ]
  [ prev-tag, prev-value, prev-dent ] = prev or [ \SOF null ]

  switch true
  | tag is \NEWLINE and dent is 0
    tokens.splice i, 1
  | tag is \NEWLINE and next-dent > dent
    tokens.splice i, 1, [ \INDENT ]
  | tag is \NEWLINE and next-dent < dent
    tokens.splice i, 1, [ \DEDENT ]
  | tag is \INDENT and i is 0
    tokens.splice i, 1

  i := i + 1

log tokens

for token in tokens
  [ tag, value, dent ] = token

  switch token.0
  | \DEF_COMP   => out += \node
  | \IDENT      => out += value
  | \NUMBER     => out += value
  | \KEY_LIFT   => out += \lift
  | \KEY_LOCAL  => out += \local
  | \KEY_UNIQ   => out += \uniq
  | \OPEN_PAR   => out += \(
  | \CLOSE_PAR  => out += \)
  | \IF         => out += \if
  | \THEN       => out += \then
  | \TYPE       => out += "[#value]"
  | \NOYIELD    => out += "..."
  | \OP         =>
    switch token.1
    | \ASSIGN => out += \=
    | _       => out += \-=-
  | \NEWLINE  => out += "\n" + "_" * (dent - 1)

  out += " "

log out

