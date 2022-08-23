
const fs = require \fs


# Basics

export const nop      = -> it
export const log      = (...args) -> console.log(...args); args[0]
export const readfile = (name) -> fs.readFileSync("../sketches/#name.tron").toString!
export const header   = (str) -> log "--- #str ---"
export const undef    = (is undefined)
export const def      = (not) . undef
export const join     = (.join '')
export const defer    = (ƒ) -> set-timeout ƒ, 0
export const pad      = (str) -> (" " * (3 - String(str).length)) + String(str)

export const big-header = -> log "\n --- #it ---  \n"

