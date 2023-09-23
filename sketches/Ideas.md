# Define a proc
@proc proc-name : YieldType {

  # Options - are immutable after init
  --required-flag : Type
  --optional-flag "default value" 
  --boolean-flag?  # true if present, false if not
  --short-flag -s  # alias -s to this flag

  # Channels        # visibility
  @local $alpha 1   # this scope
  @broad $beta 1.0  # all children

  # Events
  !basic-event
  !args-event (a:Type, ...)

  # allow parent to inject code here
  # refs passed here are visible 
  $ $alpha, &beta
  
}

# Use a proc

@do {

  @local $channel 5

  # Event Selectors
  @on !basic-event  # this evt from any source
  @on $channel      # default (value changed)
  @on ?proc-name!   # any evt from matched proc type
  @on ?proc!event   # only this evt from matched proc
  @on $ref!event    # specific event from proc by ref

  # attach yield to spine
  proc-name -s 40 ($a, &b) {
    # code running inside proc-type
    @do log "inside proc-name", &a, &b
  }

  # capture yield as channel
  @as $ref proc-name -s 20
  @as &ref proc-name # take first yield as const

  # throw yield away
  @do proc-name --boolean-flag

  # procs defined here act like methods
  @proc method (arg:Type) {
    # call as $ref.method "value"
  }
}
