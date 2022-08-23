
const { log, colors, parse-time } = require \../utils
const { plus, minus } = colors


#
# Tests
#

tests =
  [ \1s     1000    ]
  [ \2m2s   122000  ]
  [ \2s2m   null    ]
  [ \0h     0       ]
  [ \0m     0       ]
  [ \0s     0       ]
  [ \0ms    0       ]
  [ \1h     3600000 ]
  [ \1m     60000   ]
  [ \1s     1000    ]
  [ \100ms  100     ]
  [ \0h0s   0       ]
  [ \0h25s  25000   ]
  [ \0m1x   null    ]
  [ \300p   null    ]
  [ \3h2x1s null    ]
  [ \3      null    ]
  [ \h3     null    ]
  [ \h3ms   null    ]


#
# Runner
#

export time-tests = (rx) ->
  for [ str, val ] in tests
    [ hit ] = rx.exec str

    result = if hit.length then parse-time hit else null

    if result isnt val
      log (minus "TIMELIKE test failed"), "'#str' expected #val but got #result"
    else
      log (plus  "TIMELIKE test passed"), "parsed #str -> #val"

    result is val

