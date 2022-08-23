
const ansi = (n) => "\u001b["+ n + "m"

const color = (...mods) => (txt) => mods.map(ansi).join('') + txt + ansi(0)

exports.BRIGHT  = BRIGHT  = 1;
exports.BLACK   = BLACK   = 30;
exports.RED     = RED     = 31;
exports.GREEN   = GREEN   = 32;
exports.YELLOW  = YELLOW  = 33;
exports.BLUE    = BLUE    = 34;
exports.MAGENTA = MAGENTA = 35;
exports.CYAN    = CYAN    = 36;
exports.WHITE   = WHITE   = 37;

exports.color = color;

exports.red     = color(BRIGHT, RED)
exports.green   = color(BRIGHT, GREEN)
exports.yellow  = color(BRIGHT, YELLOW)
exports.blue    = color(BRIGHT, BLUE)
exports.magenta = color(BRIGHT, MAGENTA)
exports.cyan    = color(BRIGHT, CYAN)
exports.white   = color(WHITE)
exports.grey    = color(BRIGHT, BLACK)

exports.bright = color(BRIGHT)
exports.plus   = color(BRIGHT, GREEN + 10)
exports.minus  = color(BRIGHT, RED   + 10)

