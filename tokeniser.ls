
{ log, pad, truncate, colors, clean-src } = require \./utils
{ bright, blue, white, grey, yellow } = colors

const trunc = (n, txt) -> truncate n, (grey \...), (grey \:EOF), txt


# Token value is ALWAYS a string. Any post-processing goes in the
# parser function that turns this token into an AST node.

export const Token = (type, value, start = 0, line = 0) ->
  { type, start, end: start + value?.length - 1, line, value, length: value?.length }

export const Spec = (name, tag, ...patterns) ->
  { name, tag, patterns }


#
# Tokeniser
#

module.exports = class Tokeniser

  # Constructor

  (@spec, @options = { logging: on }) ->

    # Add common defaults to spec
    @spec.last =
      * Spec \EndOfFile    \EOF      /^$/
      * Spec \UnknownToken \UNKNOWN  /^.*/

    # Transformed data
    const flat-spec = [ tokens for _, tokens of spec ].flat!
    @matchlist = flat-spec.flat-map ({ tag, patterns }) -> patterns.map -> [ tag, it ]

    # Keep token symbols on class
    this <<< { [ tag, tag ] for { tag } in flat-spec }


  # Functions

  new-eof: ->
    Token @EOF, "", @cursor, @line

  log: (...args) ->
    if @options.logging
      console.log ...args
    return args.0

  match-rx: (regex, input) ->
    matched = regex.exec input
    return null if matched is null
    return matched.0

  read: ->
    if @cursor >= @input.length
      return @new-eof!

    for [ type, rx ] in @matchlist
      if str = @match-rx rx, @input.slice @cursor
        start = @column
        @cursor := @cursor + str.length
        @column := @column + str.length

        if type in [ @NEWLINE ]
          @line += 1
          @column = 0
          return @read!

        if type in [ @BLANK, @SPACE, @INDENT, @COMMENT ]
          return @read!

        if type is @STRCOM
          return Token @STRING, str.trim-left!, start, @line

        return Token type, str, start, @line

    @cursor := @cursor + 1 # Eat one unknown char to stop looping
    return Token @UNKNOWN, @input[@cursor], @cursor - 1, @line


  # Main Tokeniser

  tokenise: (@input) ->


    # State
    @cursor = 0
    @line   = 0
    @column = 0
    @tokens = []


    # Init

    @log \\n + (bright blue @input) + \\n

    f = 0
    while f < 1000
      f := f + 1
      next = @read!

      @log (white pad 10, next.type), (grey '<-'),
        trunc 50, (yellow clean-src next.value) + clean-src @input.slice @cursor

      @tokens.push next
      break if @tokens[*-1].type is @EOF

    @log ""

    return @tokens


