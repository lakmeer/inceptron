
# Requires

const { dump } = require \./dump
const colors   = require \./colors
const helpers  = require \./helpers
const treediff = require \./treediff


# Re-export

const { log, nop, header, big-header, readfile, undef, def, join, defer, pad, any, all, limit } = helpers

export dump
export colors
export treediff
export log, nop, header, big-header, readfile, undef, def, join, defer, pad, any, all, limit



# Traverse-Assert - recursively compare two nested ASTs

const err = colors.color 1, 41

export const traverse-assert = (expect, actual) ->
  for key, exp-val of expect

    # Node shape mismatch
    if typeof actual[key] is \undefined
      return err("TA:Key") + ": key `#key` is missing"

    # Get actuals
    act-val  = actual[key]
    act-type = typeof act-val
    exp-type = typeof exp-val

    # Node type mismatch
    if act-type isnt exp-type
      return err("TA:Type") + ": expected `#exp-type` but got `#act-type`"

    # Non-nested node types
    if act-type isnt \object and exp-type isnt \object
      if act-val isnt exp-val
        return err("TA:Val") + ": value at `#key` should be '#exp-val' but was '#act-val'"

    # Nested node types
    else
      return traverse-assert expect[key], actual[key]

  return \OK

