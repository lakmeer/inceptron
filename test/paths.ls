
{ log, colors } = require \./utils
{ bright, red } = colors
Tokeniser = require \./tokeniser


# REGEX

#rx = /^\/(\w+\/?)+(\#\w+)?/
#rx = /^\/([\w]+\/?)+(\?\w+)*/
#rx = /[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)/
#rx = /[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)/

rx = //^

  # Path segments
  (\/
    (
      \w+
      | \*{1,2}
    )
  )+

  # Trailing slash
  \/?

  # First param with ?
  (\?
    \w+(=\w+)?
  )?

  # Subsquent params with &
  (&
    \w+
  )*

  //


# Micro-tokeniser

const Spec = (name, tag, ...patterns) -> { name, tag, patterns }

SPEC =
  * Spec \PathSlash       \SLASH   /^\//
  * Spec \PathGlob        \GLOB    /^[*]{1,2}/
  * Spec \PathWord        \WORD    /^[-\w]+/
  * Spec \PathHash        \HASH    /^[#]/
  * Spec \PathQuery       \QUERY   /^\?/
  * Spec \PathAmpersand   \AMP     /^\&/
  * Spec \PathEqual       \EQUAL   /^\=/


parse-path = (path) ->
  tk = new Tokeniser SPEC, logging: off
  tokens = tk.tokenise path

  next = tokens.shift!

  segments = []
  fragment = null
  query    = {}

  eat = (type) ->
    if next.type is type
      log \eat, (red type), ':', (tokens.map (.type) .join ' <- ')
      value = next.value
      next := tokens.shift!
      return value
    else
      log \no type, \found
      tokens.shift!
      throw "SyntaxError: Expected #type but got #{next.type}"


  try
    if next.type isnt tk.SLASH
      return false

    # Path section
    while tokens.length and next.type is tk.SLASH
      eat tk.SLASH

      if next.type is tk.GLOB
        segments.push eat tk.GLOB
      else
        segments.push eat tk.WORD

    # Query Section
    if next.type is tk.QUERY
      eat tk.QUERY

      if next.type isnt tk.WORD
        return false

      while next.type is tk.WORD
        key = eat tk.WORD
        query[key] = true # default if value not specified

        if next.type is tk.EQUAL
          eat tk.EQUAL
          value = eat tk.WORD
          query[key] = value # overwrite with specific value

        if next.type is tk.AMP
          eat tk.AMP

    # Fragment Section
    if next.type is tk.HASH
      eat tk.HASH
      fragment := ""

      if next.type is tk.WORD
        fragment := eat tk.WORD

    # Make sure there's no leftovers
    if next.type isnt tk.EOF
      log \excess, next.type
      return false

    log { segments, fragment, query }


  catch e
    return false


# START

console.clear!
console.log "\nNew Test Run:\n"

should-fail = <[
  /
  //
  not-a-path
  malformed/path
  /?
  *
  **
  **/*
  /***
  /noquery?
  /too/many/globs/****
  ?query&
  ?just
  ?just=query
  ?just=query&and=others
  /malformed?=query
  /malformed?query&extended&
]> ; <[
]>


for test in should-fail
  log ""
  log bright test
  if parse-path test
    console.log \❌
  else
    console.log '☑️ '

console.log "\n---------\n"

should-pass = <[ ]> ; <[
  /path
  /trailing/
  /double/path
  /no-fragment#
  /path#fragment
  /very/long/path/with/lots/of/segments
  /path/glob/*
  /path/superglob/**/*
  /path?query
  /path?query=value
  /path?multi&query
  /path?multi=query&with=values
  /*
  /**/*
  /**/**
]>

for test in should-pass
  log bright test
  if parse-path test
    console.log \✅\n
  else
    console.log \❌\n

