
const log = console.log.bind(console)

const timeToMs = (time: Time) => {
  if (time.match(/\d+s/)) return parseInt(time) * 1000;
  if (time.match(/\d+ms/)) return parseInt(time);
  throw new Error(`Unsupported time format: '${time}`)
}


type Int = number
type Proc = () => Int
type Time = string

interface ProcState {
  yieldValue: Int;
  channels: Record<string, Channel<Int>>;
  yield: (value: Int) => void;
  after: (time: Time, body: (ctx:ProcState) => void) => void;
  every: (time: Time, body: (ctx:ProcState) => void) => void;
  local: (name: string, value: Int) => void;
  ref: (name: string, value?:Int) => Int;
  watch: (effect: () => void) => void;
}


class Runtime {
  proc: Proc
  yieldValue: Int
  alive: boolean
  onTick: Function

  constructor(proc: Proc, onTick: Function) {
    this.proc = proc
    this.yieldValue = 0
    this.alive = true
    this.onTick = onTick
    document.addEventListener('keydown', (event) => { this.alive = false })
  }

  tick = () => {
    this.yieldValue = this.proc()
    if (this.alive) requestAnimationFrame(this.tick)
    this.onTick(this.getValue())
  }

  execute() {
    this.tick()
  }

  getValue(): Int {
    return this.yieldValue
  }
}

class Dep {
  subscribers: Set<Function>;

  constructor() {
    this.subscribers = new Set();
  }

  depend(watcher: Function) {
    this.subscribers.add(watcher);
  }

  notify() {
    this.subscribers.forEach(sub => sub());
  }
}

class Channel<T> {
  private value: T
  private dep: Dep
  private isConst: boolean

  constructor (initial: T, isConst: boolean = false) {
    this.value = initial
    this.isConst = isConst
    console.log("Is const?", isConst, this.isConst)
    if (!isConst) {
      this.dep = new Dep()
    }
  }

  get(): T {
    log('Channel::get', this.value, this.isConst ? '(const)' : '')
    if (this.isConst) return this.value
    if (activeWatchers.length) {
      this.dep.depend(activeWatchers[activeWatchers.length - 1]);
    }
    return this.value;
  }

  set(newValue: T): void {
    if (this.isConst) throw new Error("Channel::set - can't set a const Channel")
    log('Channel::set', newValue)

    if (newValue !== this.value) {
      this.value = newValue;
      this.dep.notify();
    }
  }
}


const activeWatchers: Function[] = [];

function $run(body: (context: ProcState) => void): Runtime {
  const state: ProcState = {
    yieldValue: 0,
    channels: {},

    yield: function(ch: Channel<Int>) {
      if (!(ch instanceof Channel)) {
        ch = new Channel(ch, true) // const channel
      }

      log('yield:', ch.get())

      this.watch(() => {
        this.yieldValue = ch.get();
      });

      return ch.get()
    },

    watch: function(effect: () => void) {
      activeWatchers.push(effect);
      effect(); // Run the effect now, also
      activeWatchers.pop();
    },

    local: function(name:string, value:Int) {
      this.channels[name] = new Channel(value)
    },

    ref: function(name:string, value?:Int) {
      log('ref:', name, value)
      let ch = this.channels[name]

      if (value !== undefined) {
        ch.set(value)
      }

      return ch
    },

    after: function(time: Time, body: (ctx: ProcState) => void) {
      log('after:', time)
      setTimeout(() => { body(this); }, timeToMs(time))
    },

    every: function(time: Time, body: (ctx: ProcState) => void) {
      log('every:', time)
      setInterval(() => { body(this); }, timeToMs(time))
    },
  };

  // Call the body with the state
  body(state);

  const runtime = new Runtime(() => state.yieldValue, (yld) => document.body.innerHTML = yld.toString());
  runtime.execute();
  return runtime;
}


// Usage:
$run($ => {
  $.local('a', 1)
  $.yield($.ref('a'))
  //$.when($.ref('a').eq(2)
  $.after('1s', $ => $.ref('a', 2))
});


/*
The next step I would like to make is some control flow. Since we don't have traditional execution model, the equivalent of 'if' in esolang will be `@when`:

```esolang
@run {
  @local $a 1
  @yield $a
  @when $a is 2 {
    @yield 10
  }
 @after 2s {
   $a 2
  }
}
```
This esolang program works like this:
- Establish local channel 'a' with value 1
- Yield the channel $a by default
- At any point in time, if the value of $a is 2, yield 10 instead of $a
- After 2 seconds, set the values of $a to 2

In templang, I would like it to look like this:
```templang

*/

