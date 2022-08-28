const { log, pad, pad-end, select, limit, header, dump, big-header, clean-src, colors, treediff, any } = require \../utils
const { blue, magenta, cyan, bright, yellow, green, red, grey, minus, invert, white } = colors

MODES = <[ Off Ast Steps Nodes Diff Compare ]>

margin = 11

format-step = ([ signal, dent, token, src ], ix) ->
  switch signal
  | \LOG   => "#{ cyan    pad margin, \debug     } | #{' ' * dent} #{src}"
  | \ERR   => "#{ red     pad margin, \error     } | #{' ' * dent} #{src}"
  | \NEW   => "#{ green   pad margin, token.type } | #{' ' * dent} #{src}"
  | \EAT   => "#{ magenta pad margin, token.type } | #{' ' * dent} #{src}"
  | _      => "#{ grey    pad margin, token.type } | #{' ' * dent} #{src}"

compact-step = ([ signal, dent, token, src ], ix) ->
  switch signal
  | \LOG   => "#{ blue    pad margin, \debug     } | #{src}"
  | \ERR   => "#{ red     pad margin, \error     } | #{src}"
  | \NEW   => "#{ green   pad margin, token.type } | #{src}"
  | \EAT   => "#{ magenta pad margin, token.type } | #{src}"
  | _      => "#{ grey    pad margin, token.type } | #{src}"

mode-menu = (mode) ->
  switch MODES.index-of mode
  | 0                =>  white (pad-end 8, mode) + "↓ "
  | MODES.length - 1 =>  white (pad-end 8, mode) + "↑ "
  | _                =>  white (pad-end 8, mode) + "↕ "


#
# Runner
#

module.exports = Runner = do ->

  options   = []
  results   = []
  examples  = []
  mode-ix   = 4
  current   = 0
  selection = 0


  # Processing

  load = (suite, Parser) ->

    examples := suite
    options  := Object.keys suite

    results :=
      for name, program of examples
        log bright name
        result = Parser.parse program.src
        name:   name
        diff:   treediff result.output, program.ast
        steps:  result.steps
        input:  program.ast
        output: result.output

    render!


  # Renderer

  render = ->
    summary   = " "
    selection = options[current]
    program   = examples[selection]
    mode      = MODES[mode-ix]

    summary-only = false

    console.clear!

    for result, ix in results
      { name, diff } = result
      passed = not diff.any and not any-errors
      summary += bright if passed then green \◉ else red \◯

    log summary
    log yellow \┏ + ('━' * current) + \┛

    { name, steps, diff, output } = select results, -> it.name is selection

    any-errors = any steps.map ([ type ]) -> type is \ERR
    passed     = not diff.any and not any-errors


    # Readout

    log (yellow \┗), (bright white \===), (bright blue current),
      '•', (bright if passed then green \Passed else red \Failed),
      '•', (mode-menu mode),
      '•', (bright yellow name)

    log ""
    log white program.src
    log ""

    if any-errors
      log minus "Parser errors\n"

    if diff.any
      log minus "AST Mismatch\n"

    log "---\n"

    switch mode
    | \Off =>

    | \Ast =>
      log dump output, color: on

    | \Steps =>
      for step in steps
        if step.0 isnt \BUMP
          log compact-step step

    | \Nodes =>
      for step in steps
        log format-step step

    | \Diff =>
      log diff.summary

    | \Compare =>
      width = 44
      left  = dump program.ast.body .split \\n
      right = dump output.body .split \\n

      log white (pad-end width, \Expected:) + (white \Actual:)

      for i from 0 til Math.max left.length, right.length
        log (bright green pad-end width, left[i]) + bright red right[i]

    | _ => throw "Unsupported inspector mode: #that"

  render-after = (ƒ) ->
    (...args) ->
      ƒ(...args)
      render!


  # Interface
  previous: render-after -> current  := limit 0, options.length - 1, current - 1
  next:     render-after -> current  := limit 0, options.length - 1, current + 1
  mode-up:  render-after -> mode-ix  := limit 0, MODES.length   - 1, mode-ix - 1
  mode-dn:  render-after -> mode-ix  := limit 0, MODES.length   - 1, mode-ix + 1
  set-last: render-after -> current  := options.length - 1
  select:   render-after -> current  := it
  set-mode: render-after -> mode-ix  := it
  render:   render
  proess:   process
  load:     load

  MODES: MODES

