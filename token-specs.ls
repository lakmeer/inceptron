
# Require
const { log, any } = require \./utils

# Structs
const Spec = (name, tag, ...patterns) -> { name, tag, patterns }


#
# Tokeniser Token Specification Library
#

export LIBRARY = do

  Separators:
    * Spec \Newline               \NEWLINE          /^\n/
    * Spec \Semicolon             \SEMICOLON        /^;\n?/
    * Spec \Comma                 \COMMA            /^,/

  Whitespace:
    * Spec \Space                 \SPACE            /^[\s]+/
    * Spec \BlankLine             \BLANK            /^[\s]+$/, /^[\s]+\n/

  Grouping:
    * Spec \ScopeOpening          \SCOPE_BEG        /^{/
    * Spec \ScopeClosing          \SCOPE_END        /^}/
    * Spec \ParenthesesOpen       \PAR_OPEN         /^\(/
    * Spec \ParenthesesClose      \PAR_CLOSE        /^\)/

  Keywords:
    * Spec \KeywordIf             \IF               /^if\b/
    * Spec \KeywordElse           \ELSE             /^else\b/
    * Spec \KeywordRepeat         \REPEAT           /^(times|forever)\b/
    * Spec \KeywordOver           \OVER             /^over\b/
    * Spec \KeywordReach          \REACH            /^(local|share|uniq|lift|const)\b/
    * Spec \KeywordEase           \EASE             /^ease\b/
    * Spec \KeywordYield          \YIELD            /^yield\b/

  Literals:
    * Spec \LiteralNull           \NULL             /^null\b/
    * Spec \LiteralTime           \TIMELIKE         /^([\d]+h)?([\d]+m)?([\d]+s)?([\d]+ms)?\b/
    * Spec \LiteralAttribute      \ATTR             /^:[\w]+/
    * Spec \LiteralSubattribute   \SUBATTR          /^::[\w]+/
    * Spec \LiteralTreenode       \TREENODE         /^<[\w]+\b/
    * Spec \LiteralInteger        \INTLIKE          /^[\d]+/
    * Spec \LiteralSymbol         \SYMBOL           /^`\w+/
    * Spec \LiteralBoolean        \BOOL             /^(true|false)\b/
    * Spec \LiteralString         \STRING           /^"[^"\n]*"/
    * Spec \LiteralStringComment  \STRCOM           /^"[^"\n]*$/, /^"[^"\n]*/

  UnaryOperators:
    * Spec \OpUnaryNot            \OP_NOT           /^not\b/

  MathOperators:
    * Spec \OpAddition            \OP_ADD           /^\+/
    * Spec \OpSubtraction         \OP_SUB           /^\-/
    * Spec \OpMultiplication      \OP_MUL           /^\*/
    * Spec \OpDivision            \OP_DIV           /^\//
    * Spec \OpModulo              \OP_MOD           /^\%/
    * Spec \OpExponentiation      \OP_EXP           /^\^/

  BooleanOperators:
    * Spec \OpEquivalence         \OP_EQUIV         /^==/
    * Spec \OpEquality            \OP_EQ            /^=/
    * Spec \OpGreaterThan         \OP_GT            /^</
    * Spec \OpGreaterThenOrEqual  \OP_GTE           /^<=/
    * Spec \OpLessThan            \OP_LT            /^>/
    * Spec \OpLessThanOrEqual     \OP_LTE           /^>=/
    * Spec \OpLogicalAnd          \OP_AND           /^and\b/
    * Spec \OpLogicalOr           \OP_OR            /^or\b/
    * Spec \OpLogicalExclusiveOr  \OP_XOR           /^xor\b/

  ListOperators:
    * Spec \OpMap                 \OP_MAP           /^>>/
    * Spec \OpFilter              \OP_FILTER        /^||/
    * Spec \OpReduce              \OP_REDUCE        /^<</
    * Spec \OpConcat              \OP_CONCAT        /^~/

  AssigningOperators:
    * Spec \OpAssignment          \OP_ASSIGN        /^:=/
    * Spec \OpAddAssign           \OP_ADD_ASS       /^\+=/
    * Spec \OpSubAssign           \OP_SUB_ASS       /^\-=/
    * Spec \OpMultiplyAssign      \OP_MUL_ASS       /^\*=/
    * Spec \OpDivideAssign        \OP_DIV_ASS       /^\/=/
    * Spec \OpModuloAssign        \OP_MOD_ASS       /^\%=/
    * Spec \OpMapAssign           \OP_MAPASS        /^>>=/
    * Spec \OpFilterAssign        \OP_FILTASS       /^||=/
    * Spec \OpConcatAssign        \OP_CATASS        /^~=/

  Identifiers:
    * Spec \TypeIdentifier        \TYPE             /^[A-Z]\w+(`s)?/
    * Spec \Identifier            \IDENT            /^\w+/

  Meta:
    * Spec \EndOfFile             \EOF              /^$/
    * Spec \UnknownToken          \UNKNOWN          /^$/


# Helper Functions

const token-group = (group) -> [ TAGS[tag] for { tag } in LIBRARY[group] ]
const one-of      = (types) -> -> types.includes if it.type then that else it
const either      = (...ts) -> -> any [ ƒ it for ƒ in ts ]


# Transformed Exports

const FLAT_LIBRARY = [ tokens for _, tokens of LIBRARY ].flat!

export TAGS      = { [ tag, tag ] for { tag } in FLAT_LIBRARY }
export MATCHLIST = FLAT_LIBRARY.flat-map ({ tag, patterns }) -> patterns.map -> [ tag, it ]


# Groups and membership checkers

export is-literal   = one-of token-group \Literals
export is-bool-op   = one-of token-group \BooleanOperators
export is-math-op   = one-of token-group \MathOperators
export is-list-op   = one-of token-group \ListOperators
export is-assign-op = one-of token-group \AssigningOperators
export is-binary-op = either is-bool-op, is-math-op, is-list-op

