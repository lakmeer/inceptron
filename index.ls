
# Requires

const Runner      = require \./test/runner
const Parser      = require \./parser
const Interpreter = require \./interpreter


#
# Parser
#

parser-tests = ->

  # Key Listener

  [ UP, DOWN, RIGHT, LEFT ] = [ 65, 66, 67, 68 ]

  stdin = process.stdin
  stdin.setRawMode on .resume!
  stdin.setEncoding \utf8

  stdin.on \data, (key) ->
    str = key.toString!

    if key is \\u0003 then process.exit!

    switch str
    | \q => process.exit!
    | \k => Runner.mode-up!
    | \j => Runner.mode-dn!

    if str.length is 3
      switch str.char-code-at 2
      | LEFT  => Runner.previous!
      | RIGHT => Runner.next!
      | DOWN  => Runner.mode-dn!
      | UP    => Runner.mode-up!

  # Initialise runner with test suite
  Runner.load (require \./test), Parser, Interpreter
  Runner.set-mode 0
  Runner.select 30


parser-tests!
