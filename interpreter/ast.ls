
export simple = do
  src: """
  " Simple Program

  yield 2 + 3
  """
  kind: \scope
  type: \Root
  main: null
  args: []
  body:
    * kind: \literal
      type: \Str
      main: " Simple Program"

    * kind: \yield
      main:
        kind: \binary
        type: \AutoNum
        oper: \+
        left:
          kind: \literal
          type: \AutoInt
          main: 2
        right:
          kind: \literal
          type: \AutoInt
          main: 3


export stateful = do
  src: """
  " Simple Stateful Program

  local Int x = 1
  x := 2
  yield x + 1
  """
  kind: \scope
  type: \Root
  main: null
  args: []
  body:
    * kind: \literal
      type: \Str
      main: " Simple Stateful Program"

    * kind: \decl
      reach: \local
      type: \Int
      name: \x
      main:
        * kind: \literal
          type: \AutoInt
          main: 1

    * kind: \assign
      reach: \here
      name: \x
      main:
        * kind: \literal
          type: \AutoInt
          main: 2

    * kind: \yield
      main:
        kind: \binary
        type: \Int
        oper: \+
        left:
          kind: \ident
          reach: \here
          name: \x
        right:
          kind: \literal
          type: \AutoInt
          main: 1


export example = do
  src: """
  " Example Program

  local Int pad = 3
  share Str txt = "Hello, Sailor"

  <Box
    :color `red
    :padding pad
    :visible true

    <Text txt
  """
  kind: \scope
  type: \Root
  main: null
  args: []
  body:
    * kind: \literal
      type: \Str
      main: " Example Program"

    * kind: \decl
      reach: \local
      type: \Int
      name: \pad
      main:
        kind: \literal
        type: \Int
        main: 3

    * kind: \decl
      reach: \share
      type: \Str
      name: \txt
      main:
        kind: \literal
        type: \Str
        main: "Hello, Sailor"

    * kind: \yield
      main:
        kind: \scope
        type: \Box
        main: null
        body:
          * kind: \attr
            name: \color
            args:
              * kind: \atom
                name: \red
              ...
          * kind: \attr
            name: \padding
            args:
              * kind: \ident
                name: \pad
                reach: \here
              ...
          * kind: \attr
            name: \visible
            args:
              * kind: \literal
                type: \Bool
                main: true
              ...
          * kind: \scope
            type: \Text
            args: []
            body:
              * kind: \ident
                name: \txt
                reach: \here
              ...


export forever = do
  src: """
  " Simple Forever Program

  local Int x = 0

  times 5
    x := x + 1
    <Text "Hello Sailor"
    <Text x

  forever
    x := x + 1

    <Box
      :attribute x
  """
  kind: \scope
  type: \Root
  main: null
  args: []
  body:
    * kind: \literal
      type: \Str
      main: " Simple Forever Program"

    * kind: \decl
      reach: \local
      type: \Int
      name: \x
      main:
        kind: \literal
        type: \Int
        main: 0

    * kind: \timing
      type: \times
      freq: 5
      over: 0
      ease: null
      main:
        kind: \scope
        type: \None
        args: []
        main: null
        body:
          * kind: \assign
            name: \x
            reach: \here
            main:
              kind: \binary
              type: \Int
              oper: \+
              left:
                kind: \ident
                name: \x
                reach: \here
              right:
                kind: \literal
                type: \AutoInt
                main: 1

          * kind: \scope
            type: \Text
            args: []
            main: null
            body:
              * kind: \literal
                type: \AutoStr
                main: "Hello Sailor"
              ...
          * kind: \scope
            type: \Text
            args: []
            main: null
            body:
              * kind: \ident
                name: \x
                type: \Int
              ...
          ...

    * kind: \timing
      type: \forever
      freq: 0
      over: 0
      ease: null
      main:
        kind: \scope
        main: null
        args: []
        body:
          * kind: \assign
            name: \x
            reach: \here
            main:
              kind: \binary
              type: \Int
              oper: \+
              left:
                kind: \ident
                name: \x
                reach: \here
              right:
                kind: \literal
                type: \AutoInt
                main: 1

          * kind: \scope
            type: \Box
            args: []
            main: null
            body:
              * kind: \attr
                name: \attribute
                args:
                  * kind: \ident
                    name: \x
                    reach: \here
                  ...
              ...
