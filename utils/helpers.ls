
const fs = require \fs


# Basics

export const nop      = -> it
export const log      = (...args) -> console.log(...args); args[0]
export const readfile = (name) -> fs.readFileSync("../sketches/#name.tron").toString!
export const undef    = (is undefined)
export const def      = (not) . undef
export const join     = (.join '')
export const defer    = (ƒ) -> set-timeout ƒ, 0
export const pad      = (str) -> (" " * (3 - String(str).length)) + String(str)
export const any      = -> it.reduce (or), false
export const all      = -> it.reduce (and), true
export const limit    = (a, b, n) -> if n < a then a else if n > b then b else n

export const header     = -> log "--- #itr ---"
export const big-header = -> log "\n--- #it ---\n"

