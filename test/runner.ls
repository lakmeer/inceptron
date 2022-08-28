const { log, limit, header, dump, big-header, colors, treediff, any } = require \../utils
const { blue, magenta, bright, yellow, green, red, grey, plus, minus, white } = colors

MODES = <[ Status Ast Parser ParserWithNodes AstDiff ActualExpected ]>

format-step = ([ token, src, peek ], ix) ->
  switch token
  | \EAT   => "#{magenta \eat} | " + magenta src
  | \BUMP  => "#{       "   "} | " + grey src
  | \ERROR => "#{red     \err} | " + bright src
  | \DEBUG => "#{blue    \log} | " + blue src
  | _      => "#{green   \new} | #{bright token.type}(#{yellow token.value}) #{bright \<-} \"#src\""

mode-menu = (mode) ->
  switch MODES.index-of mode
  | 0                => white "↓ #mode"
  | MODES.length - 1 => white "↑ #mode"
  | _                => white "↕ #mode"


#
# Runner
#

module.exports = Runner = do ->

  examples  = []
  options   = []
  results   = []
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

    log results
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
      any-errors = any steps.map ([ type ]) -> type is \ERROR
      passed     = not diff.any and not any-errors

      summary += bright if passed then green ' ◉' else red ' ◯'

      if summary-only then continue

      # Readout

      if not inspecting
        for step in steps when step.0 is \ERROR
          log format-step step

      else
        big-header (bright yellow name) + ' ' + mode-menu mode

        summary-only := true
        first-err-ix := ix

        log white program.src
        log "\n---\n"

        if any-errors
          log minus "Parser errors"
          log ""
        else if diff.any
          log minus "AST Mismatch"
          log ""

        switch mode
        | \Status =>
          if passed
            log bright green "Passing"
          else
            log bright red "Failed"

        | \Ast =>
          log dump output, color: on

        | \Parser =>
          for step in steps
            if step.0 isnt \BUMP
              log format-step step

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

        | _ => throw "Unsupported view mode: #that"

    return output: summary, err-ix: first-err-ix

  render-after = (ƒ) ->
    (...args) ->
      ƒ(...args)
      summary = render!
      log \\n + summary.output
      log " " + "  " * summary.err-ix + yellow \▲


  # Interface
  previous: render-after -> current := limit 0, options.length - 1, current - 1
  next:     render-after -> current := limit 0, options.length - 1, current + 1
  mode-up:  render-after -> mode-ix := limit 0, MODES.length   - 1, mode-ix - 1
  mode-dn:  render-after -> mode-ix := limit 0, MODES.length   - 1, mode-ix + 1
  set-last: render-after -> current := options.length - 1
  select:   render-after -> current := it
  render:   render
  proess:   process
  load:     load

  MODES: MODES

