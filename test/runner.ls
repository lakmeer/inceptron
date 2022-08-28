const { log, pad, limit, header, dump, big-header, clean-src, colors, treediff, any } = require \../utils
const { blue, magenta, cyan, bright, yellow, green, red, grey, plus, minus, invert, white } = colors

MODES = <[ Status Ast Parser ParserWithNodes AstDiff ActualExpected ]>

margin = 11

format-step = ([ signal, dent, token, src ], ix) ->
  switch signal
  | \LOG   => "#{ cyan    pad margin, \debug     } | #{invert src}"
  | \ERR   => "#{ red     pad margin, \error     } | #{minus src}"
  | \NEW   => "#{ green   pad margin, token.type } | #{' ' * dent} #{src}"
  | \EAT   => "#{ magenta pad margin, token.type } | #{' ' * dent} #{src}"
  | _      => "#{ grey    pad margin, token.type } | #{' ' * dent} #{src}"

compact-step = ([ signal, dent, token, src ], ix) ->
  switch signal
  | \LOG   => "#{ blue    pad margin, \debug     } | #{invert src}"
  | \ERR   => "#{ red     pad margin, \error     } | #{minus src}"
  | \NEW   => "#{ green   pad margin, token.type } | #{src}"
  | \EAT   => "#{ magenta pad margin, token.type } | #{src}"
  | _      => "#{ grey    pad margin, token.type } | #{src}"

mode-menu = (mode) ->
  switch MODES.index-of mode
  | 0                => white "↓ #mode"
  | MODES.length - 1 => white "↑ #mode"
  | _                => white "↕ #mode"



#
# Runner
#

module.exports = Runner = do ->

  options   = []
  results   = []
  examples  = []
  mode-ix   = 0
  current   = 0
  selection = 0


  # Processing

  load = (suite, Parser) ->

    examples := suite
    options  := Object.keys suite

    results :=
      for name, program of examples
        result = Parser.parse program.src
        name:   name
        diff:   treediff program.ast, result.output
        steps:  result.steps
        input:  program.ast
        output: result.output

    render!


  # Renderer

  render = ->
    summary   = ""
    selection = options[current]
    program   = examples[selection]
    mode      = MODES[mode-ix]

    summary-only = false
    first-err-ix = -1

    console.clear!

    for result, ix in results

      { name, steps, diff, output } = result

      inspecting = selection is name
      any-errors = any steps.map ([ type ]) -> type is \ERR
      passed     = not diff.any and not any-errors

      summary += bright if passed then green ' ◉' else red ' ◯'

      if summary-only then continue


      # Readout

      if inspecting
        log white program.src
        log "\n---\n"

        summary-only := true
        first-err-ix := ix

        big-header (bright yellow name) + ' ' + mode-menu mode

        if any-errors
          log minus "Parser errors"
          log ""

        if diff.any
          log minus "AST Mismatch"
          log ""

        switch mode
        | \Status =>
          if passed
            log bright green \Pass
          else
            log bright red \Fail

        | \Ast =>
          log dump output, color: on

        | \Parser =>
          for step in steps
            if step.0 isnt \BUMP
              log compact-step step

        | \ParserWithNodes =>
          for step in steps
            log format-step step

        | \AstDiff =>
          log diff.summary

        | \ActualExpected =>
          log white \Expected:
          log bright green dump program.ast.body
          log ""
          log white \Actual:
          log bright red dump output.body

    return output: summary, err-ix: first-err-ix

  render-after = (ƒ) ->
    (...args) ->
      ƒ(...args)
      summary = render!
      log \\n + summary.output
      log " " + "  " * summary.err-ix + yellow \^


  # Interface
  previous: render-after -> current  := limit 0, options.length - 1, current - 1
  next:     render-after -> current  := limit 0, options.length - 1, current + 1
  mode-up:  render-after -> mode-ix  := limit 0, MODES.length   - 1, mode-ix - 1
  mode-dn:  render-after -> mode-ix  := limit 0, MODES.length   - 1, mode-ix + 1
  set-last: render-after -> current  := options.length - 1
  select:   render-after -> current  := it
  render:   render
  proess:   process
  load:     load

  MODES: MODES

