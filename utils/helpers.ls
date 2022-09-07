
const fs = require \fs


# Basics

export const nop        = -> it
export const log        = (...args) -> console.log(...args); args[0]
export const readfile   = (name) -> fs.readFileSync("../sketches/#name.tron").toString!
export const undef      = (is undefined)
export const def        = (not) . undef
export const join       = (.join '')
export const defer      = (ƒ) -> set-timeout ƒ, 0
export const pad        = (n, str="") -> ' ' * (n - str.length) + str
export const pad-end    = (n, str="") -> str + (' ' * (n - str.length))
export const any        = -> it.reduce (or), false
export const all        = -> it.reduce (and), true
export const limit      = (a, b, n) -> if n < a then a else if n > b then b else n
export const head       = -> if it.length then it[0] else null
export const select     = (it, ƒ) -> head it.filter ƒ
export const header     = -> log "--- #it ---\n"
export const big-header = -> log "\n=== #it\n"
export const truncate   = (n, ell, term, str) -> if str.length > n then (str.slice 0, n) + ell else str + term
export const clean-src  = (txt) -> txt.replace /\n/g, '⏎ '
export const take       = (n, xs) -> if n <= 0 then xs.slice 0, 0 else xs.slice 0, n

export const equivalent = (a, b) ->
  if (a and typeof a is \object) and (b and typeof b is \object)
    if Object.keys(a).length isnt Object.keys(b).length
      return false

    for key,val of a when not equivalent a[key], b[key]
      return false

    return true

  else
    a is b

export const own-props = ->
  { [ k, v ] for k, v of it when it.has-own-property k }
