const { log, pad, pad-end, select, limit, header, dump, big-header, clean-src, colors, treediff, any } = require \../utils
const { blue, magenta, cyan, bright, yellow, green, red, grey, plus, minus, invert, white } = colors

MODES = <[ Tokens Steps Nodes Ast Diff Compare Execute ]>

margin = 10

format-step = ([ signal, dent, token, src ], ix) ->
  switch signal
  | \LOG   => "#{ cyan    pad margin, \debug     } |#{' ' * dent} #{src}"
  | \ERR   => "#{ red     pad margin, \error     } |#{' ' * dent} #{src}"
  | \NEW   => "#{ green   pad margin, token.type } |#{' ' * dent} #{src}"
  | \EAT   => "#{ magenta pad margin, token.type } |#{' ' * dent} #{src}"
  | _      => "#{ grey    pad margin, token.type } |#{' ' * dent} #{src}"

compact-step = ([ signal, dent, token, src ], ix) ->
  switch signal
  | \LOG   => "#{ blue    pad margin, \debug     } |#{src}"
  | \ERR   => "#{ red     pad margin, \error     } |#{src}"
  | \NEW   => "#{ green   pad margin, token.type } |#{src}"
  | \EAT   => "#{ magenta pad margin, token.type } |#{src}"
  | _      => "#{ grey    pad margin, token.type } |#{src}"

format-trace = ([ kind, arg ]) ->
  switch kind
  | \EVAL   => "   #{ blue   \eval } | #{arg}"
  | \WARN   => "   #{ yellow \warn } | #{arg}"
  | \ERR    => "  #{ red    \error } | #{arg}"
  | \ASSERT => " #{ white  \assert } | #{arg}"
  | _       => "  #{ grey   \trace } | #{arg}"

mode-menu = (mode) ->
  switch MODES.index-of mode
  | 0                =>  white (pad-end 8, mode) + "↓ "
  | MODES.length - 1 =>  white (pad-end 8, mode) + "↑ "
  | _                =>  white (pad-end 8, mode) + "↕ "

passing = (result) ->
  no-errors = not any result.steps.map ([ type ]) -> type is \ERR
  no-diffs  = not result.diff.any
  no-exec   = not result.exec.error
  no-errors and no-diffs and no-exec


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

  load = (suite, Parser, Interpreter) ->

    examples := suite
    options  := Object.keys suite

    results :=
      for name, program of examples
        log bright name # For the pre-render output
        result = Parser.parse program.src
        name:   name
        diff:   treediff result.output, program.ast
        steps:  result.steps
        input:  program.ast
        output: result.output
        tokens: result.token-list
        exec: do
          expect = Interpreter.run program.ast
          actual = Interpreter.run result.output
          tested: program.val isnt undefined
          expect: expect
          actual: actual
          error:  (not expect.error) and (not actual.error) and program.val isnt actual.result?.unwrap!

    render!


  # Renderer

  render = ->
    selection = options[current]
    program   = examples[selection]
    mode      = MODES[mode-ix]

    console.clear!


    # Select result from result set

    result = select results, -> it.name is selection
    { name, steps, diff, output, tokens, run, exec } = result


    # Readout

    summary = " "
    for let result, ix in results
      summary += bright if passing(result) then green ' ◉' else red ' ◯'

    log summary
    log yellow \┏ + ('━' * current) + \┛
    log (yellow \┗), (bright white \===), (bright blue current),
      '•', (bright if passing(result) then green \Passed else red \Failed),
      '•', (mode-menu mode),
      '•', (bright yellow name)

    log ""
    log white program.src
    log ""


    if (any result.steps.map ([ type ]) -> type is \ERR)
      log minus "Parser errors"

    if diff.any
      log minus "AST Mismatch"

    if exec.tested
      if exec.error
        log minus "Execution Mismatch"

      if exec.expect.error
        log minus "#that in Expected AST"

      if exec.actual.error
        log minus "#that in Output AST"

    log white "\n---\n"

    switch mode
    | \Tokens =>
      log '- ' + [ "#{white type}(#{yellow clean-src value})" for { type, value } in tokens ].join '\n- '

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

    | \Execute =>

      log (bright "Expected Value:"), dump program.val, color: on

      # Each output

      [ exec.expect, exec.actual ].map (it, ix) ->

        if ix is 0
          log bright "\nRunning #{green \test} AST:\n"
        else
          log white "\n---\n"
          log bright "Running #{red \output} AST:\n"

        if it.error
          log (minus \Exception), bright it.error
          log it.trace
        else
          log it.result?.to-string!
          log ""
          log dump it.result?.unwrap!, color: on

      # Expectation

      if exec.tested
        log white "\n---\n"

        if program.val is exec.actual.result?.unwrap!
          log plus \OK
        else
          log (minus "Mismatch:")
          log "Expected value:", dump program.val,           color: on
          log "Actual value:  ", dump exec.actual.result?.unwrap!, color: on
          log ""
          #log dump exec.actual.result
          log exec.actual.trace?.map(format-trace).join \\n


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
  select:   render-after -> current  := limit 0, options.length - 1, it
  set-mode: render-after -> mode-ix  := limit 0, MODES.length - 1, it
  render:   render
  proess:   process
  load:     load

  MODES: MODES

