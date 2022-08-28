
# Requires

const { dump } = require \./dump
const colors   = require \./colors
const treediff = require \./treediff


# Re-export

module.exports <<< require \./helpers

export dump
export colors
export treediff


# TimeVal - turns HMS values into milliseconds

export const time-val = ({ h = 0, m = 0, s = 0, ms = 0 }) ->
  h * 60 * 60 * 1000 + m * 60 * 1000 + s * 1000 + ms

export const parse-time = (time) ->
  cursor = 0
  res = {}
  val = ""

  while cursor < time.length
    char = time[cursor]

    if char.match /\d/
      val += char
    else
      if char is \m and time[cursor + 1] is \s
        res[ \ms ] = parse-int val
        cursor := cursor + 1
      else
        res[ char ] = parse-int val
      val := ""
    cursor := cursor + 1

  return time-val res


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

