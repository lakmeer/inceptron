
# Require

const { dump }           = require \./dump
const { log, def, join } = require \./helpers
const { master, slave } = require \./colors
const { detailed-diff }  = require \./diff


# Domain Helpers

first-key = -> if def it then Object.keys(it).0

any-diffs = (diff) ->
  !!Object.keys(diff.added).length or
  !!Object.keys(diff.deleted).length or
  !!Object.keys(diff.updated).length

chain-get = (target, chain) ->
  for k in chain
    if def target[k] and target[k] isnt null
      target := target[k]
    else
      return undefined
  return target

more-children = (obj, x) ->
  return true if obj === {}
  child = obj[ first-key obj ]
  switch typeof! child
  | \Null, \Undefined, \Boolean, \Number, \String, \Date => return false
  | \Object => return Object.keys(child).length > 0
  | \Array  => return child.length > 0
  return true


#
# Treediff
#

module.exports = (a, b) ->

  diff = detailed-diff a, b

  traverse = (thing, d = 0, chain = []) ->
    pad = "  " * d
    str = ""

    added   = chain-get diff.added,   chain
    missing = chain-get diff.deleted, chain
    changed = chain-get diff.updated, chain

    recurse = (thing, fn) ->
      for key, val of thing
        str += "\n#pad" + do
          txt = fn key, (traverse val, d + 1, chain ++ key)

          if (def missing) and (key is first-key missing) and not more-children missing
            slave txt
          else
            txt

    switch typeof! thing
    | \Object, \Array => recurse thing, (key, val) -> "#key: #val"
    | _ =>
      if def changed
        str += (slave dump thing, {}, d) + (master dump changed, {}, d)
      else
        str += dump thing, {}, d

    if (def added) and not more-children added
      if added isnt {}
        str += master dump added, {}, d

    if d is 0 and str.0 is \\n
      return str.slice 1
    else
      return str

  diff.summary = traverse a
  diff.any = any-diffs diff

  return diff

