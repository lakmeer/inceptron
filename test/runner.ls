const { log, limit, header, dump, big-header, colors, treediff, any } = require \../utils
const { magenta, bright, yellow, green, red, grey, plus, minus, white } = colors

modes = [ 0 to 5 ]
[ NONE, COMPACT, PARSER, PARSER_ALL, DIFF, DIFF_FULL ] = modes

format-step = ([ token, src, peek ], ix) ->
  switch token
  | \EAT   => "#{magenta \eat} | " + magenta src
  | \BUMP  => "#{       "   "} | " + grey src
  | \ERROR => "#{red     \err} | " + bright src
  | \DEBUG => "#{blue    \log} | " + blue src
  | _      => "#{green   \new} | #{bright token.type}(#{yellow token.value}) #{bright \<-} \"#src\""


#
# Runner
#

module.exports = Runner = do ->

  mode      = DIFF
  examples  = []
  current   = 0
  options   = []
  selection = 0
  results   = []


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
    summary   = grey "-"
    selection = options[current]
    program   = examples[selection]

    console.clear!

    log "\n\n\n"
    big-header bright "RUNNING TEST CASES"

    for result in results

      { name, steps, diff, output } = result

      inspecting = selection is name
      any-errors = any steps.map ([ type ]) -> type is \ERROR
      passed     = not diff.any and not any-errors


      # Readout

      if passed
        big-header plus name
        summary += plus  "+"
      else
        big-header minus name
        summary += minus "-"

      if not inspecting
        for step in steps when step.0 is \ERROR
          log format-step step

      else
        log white program.src
        log ""

        if any-errors
          log minus "Parser errors"
          log ""
        else if diff.any
          log minus "AST Mismatch"
          log ""

        switch mode
        | NONE =>
          if passed
            log bright green \Passed
          else
            log bright red \Failed

        | COMPACT =>
          header \Output
          log dump output, color: on

        | PARSER =>
          header \Parser
          for step in steps
            if step.0 isnt \BUMP
              log format-step step

        | PARSER_ALL =>
          header \ParserWithBumps
          for step in steps
            log format-step step

        | DIFF =>
          header \Diff
          log diff.summary

        | DIFF_FULL =>
          header \FullDiff
          log white \Expected:
          log green dump program.ast.body
          log ""
          log white \Actual:
          log red dump output.body

        return \\n + summary

  render-after = (ƒ) ->
    (...args) ->
      ƒ(...args)
      log render!


  # Interface
  previous: render-after -> current  := limit 0, options.length - 1, current - 1
  next:     render-after -> current  := limit 0, options.length - 1, current + 1
  in:       render-after -> mode     := limit 0, modes.length   - 1, mode    - 1
  out:      render-after -> mode     := limit 0, modes.length   - 1, mode    + 1
  set-last: render-after -> current  := options.length - 1
  render:   render
  proess:   process
  load:     load

