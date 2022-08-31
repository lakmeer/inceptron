
# Requires

const { dump } = require \./dump
const colors   = require \./colors
const treediff = require \./treediff

const { PI, sin, cos, sqrt, atan2 } = Math


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

export const parse-radians = (rad) ->
  if rad.index-of(\pi) > -1
    PI * parse-float rad.replace \pi, ""
  else
    parse-float rad

export const parse-complex = (cplx) ->
  if cplx.index-of(\e) > -1
    [ mag, arg ] = cplx.split(\e).map parse-radians
    x: mag * cos arg
    y: mag * sin arg
    r: mag
    a: arg
  else if cplx.index-of(\i) > -1
    [ re, im ] = cplx.split(\i).map parse-radians
    x: re
    y: im
    r: sqrt(re*re + im*im)
    a: atan2 im, re
  else
    throw "Not a complex number literal: #cplx"


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

