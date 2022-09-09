
# Require

const { log, nop } = require \./helpers
const { color, bright, BRIGHT, BLACK, WHITE, RED, YELLOW, GREEN, BLUE, CYAN } = require \./colors


#
# Dump: Custom stringify function
#

export const dump = (thing, opt = { color: off }, d = 0) ->
  const _nul = if not opt.color then nop else color BRIGHT, WHITE, CYAN + 10
  const _dim = if not opt.color then nop else color BRIGHT, BLACK
  const _key = if not opt.color then nop else color WHITE
  const _tru = if not opt.color then nop else color BRIGHT, WHITE, GREEN + 10
  const _fal = if not opt.color then nop else color BRIGHT, WHITE, RED + 10
  const _str = if not opt.color then nop else color BRIGHT, YELLOW
  const _num = if not opt.color then nop else color BRIGHT, BLUE

  pad = if opt.color then _dim("> " * d) else "  " * d
  str = ""

  switch typeof! thing
  | \Object =>
    if Object.keys(thing).length is 0 then return "{}"
    i = d
    for key, val of thing
      if i++ then str += \\n
      str += "#pad#{_key key}: #{ dump val, opt, d + 1 }"
    return str

  | \Array =>
    if thing.length is 0 then return "[]"
    for key, val of thing
      if key + d then str += \\n
      str += "#pad#{_key "[#key]"} #{ dump val, opt, d + 1 }"
    return str

  | \Null      => return _nul " NULL "
  | \Boolean   => return (if thing then (_tru " TRUE ") else (_fal " FALSE "))
  | \Number    => return _num thing.to-string!
  | \String    => return _str \" + thing + \"
  | \Undefined => return _dim "undefined"
