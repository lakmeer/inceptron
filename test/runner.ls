const { log, pad, pad-end, equivalent, select, limit, header, dump, big-header, clean-src, colors, treediff, any } = require \../utils
const { blue, magenta, cyan, bright, yellow, green, red, grey, white, plus, minus, invert, expect, master, slave } = colors

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
  parse-errors = any result.steps.map ([ type ]) -> type is \ERR
  diff-errors  = result.diff.any
  exec-errors  = result.exec.errors.length

  errors = []

  if parse-errors => errors.push "Parsing error"
  if diff-errors  => errors.push "AST Mismatch"
  if exec-errors  => errors .= concat result.exec.errors

  passed: not (parse-errors or diff-errors or exec-errors)
  errors: errors


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
          errors = []

          has-output-test = program.has-own-property \val

          if expect.error
            errors.push "Exec error: Test AST threw " + master expect.error

          if actual.error
            errors.push "Exec error: Output AST threw " + output actual.error

          if has-output-test and program.val isnt actual.result?.unwrap!
            errors.push "Exec mismatch: Prescription and output diverge"

          if not equivalent expect.result?.unwrap!, actual.result?.unwrap!
            errors.push "Exec mismatch: Actual and Expected runs diverge"

          target: program.val
          tested: has-output-test
          expect: expect
          actual: actual
          errors: errors

    render!


  # Renderer

  render = ->
    selection = options[current]
    program   = examples[selection]
    mode      = MODES[mode-ix]

    console.clear!


    # Summary

    summary = " "
    for let result, ix in results
      summary += bright if passing(result).passed then green ' ◉' else red ' ◯'


    # Select result from result set

    result = select results, -> it.name is selection
    { name, steps, diff, output, tokens, run, exec } = result


    # Readout

    pass-details = passing result

    log summary
    log yellow \┏ + ('━━' * current) + \━┛
    log (yellow \┗), (bright white \===), (bright blue current),
      '•', (bright if pass-details.passed then green \Passed else red \Failed),
      '•', (mode-menu mode),
      '•', (bright yellow name)

    log ""
    log white program.src
    log ""


    # Errors

    for error in pass-details.errors
      log minus error


    # Inspector

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
      width = 50
      left  = dump program.ast.body .split \\n
      right = dump output.body .split \\n

      log white (pad-end width, \Expected:) + (white \Actual:)

      for i from 0 til Math.max left.length, right.length
        log (bright cyan pad-end width, left[i]) + bright magenta right[i]

    | \Execute =>

      if exec.tested
        log (bright "Expected Value:"), dump program.val, color: on
      else
        log bright magenta "No expected value set for '#name'"

      # Each output

      [ exec.expect, exec.actual ].map (it, ix) ->

        log white "\n---\n"
        if ix is 0
          log bright "\nRunning #{green \test} AST:\n"
        else
          log bright "Running #{red \output} AST:\n"

        if it.error
          log (minus \Exception), bright it.error
          log ""
          log it.trace?.map(format-trace).join \\n
        else
          log "\nOutput Tree:"
          log it.result?.to-string!
          log "\nUnwrapped Value:"
          log dump it.result?.unwrap!, color: on

      # Expectation

      if exec.tested
        log white "\n---\n"

        if exec.errors.length is 0
          log plus \OK
        else
          log "Output execution traceback:"
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

