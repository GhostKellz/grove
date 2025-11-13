; Syntax highlighting queries for Ghostlang v0.2.3
; These queries define how Grove should highlight different syntax elements
; Including blockchain/Web3 support

; Keywords - C-style and Lua-style
[
  "var"
  "local"
  "function"
  "if"
  "then"
  "elseif"
  "else"
  "while"
  "do"
  "end"
  "for"
  "in"
  "repeat"
  "until"
  "return"
  "break"
  "continue"
] @keyword

; Lua-style logical operators (also keywords)
[
  "and"
  "or"
  "not"
] @keyword.operator

; Operators - C-style and Lua-style
[
  "+"
  "-"
  "*"
  "/"
  "%"
  "=="
  "!="
  "~="
  "<"
  ">"
  "<="
  ">="
  "&&"
  "||"
  "!"
  "?"
  ":"
  ".."
] @operator

; Assignment operators (shown as string in AST due to aliasing)
(assignment_expression
  operator: (string) @operator)

; Punctuation
[
  ";"
  ","
  "."
] @punctuation.delimiter

; Brackets
[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

; Function names
(function_declaration
  name: (identifier) @function)

(call_expression
  function: (identifier) @function.call)

(call_expression
  function: (member_expression
    property: (identifier) @function.call))

; Parameters
(parameter_list
  (identifier) @parameter)

; Variables
(variable_declaration
  name: (identifier) @variable)

(assignment_expression
  left: (identifier) @variable)

; Properties and methods
(member_expression
  property: (identifier) @property)

; Object keys
(object_member
  (identifier) @property)

; Literals
(number_literal) @number
(string_literal) @string
(boolean_literal) @boolean
(null_literal) @constant.builtin

; Comments
(comment) @comment

; Built-in functions - v0.1.0 additions
((identifier) @function.builtin
 (#match? @function.builtin "^(getCurrentLine|getLineText|setLineText|insertText|getAllText|replaceAllText|getCursorPosition|setCursorPosition|getSelection|setSelection|getSelectedText|replaceSelection|getFilename|getFileLanguage|isModified|notify|log|prompt|findAll|replaceAll|split|join|substring|indexOf|replace|createArray|arrayPush|arrayPop|arrayGet|arraySet|arrayLength|tableInsert|tableRemove|tableConcat|createObject|objectSet|objectGet|objectKeys|pairs|ipairs|stringMatch|stringFind|stringGsub|stringUpper|stringLower|stringFormat)$"))

; Blockchain & Web3 API - v0.2.3 additions
; emit() function for event emission
((identifier) @function.builtin
 (#eq? @function.builtin "emit"))

; web3 namespace identifier
((identifier) @namespace
 (#eq? @namespace "web3"))

; Web3 API methods
(member_expression
  object: (identifier) @namespace (#eq? @namespace "web3")
  property: (identifier) @function.builtin
  (#match? @function.builtin "^(getCaller|getThis|require|transfer|getBalance|getTimestamp|getBlockNumber|getGasLimit|getGasPrice|hash|verifySignature|encodeABI|decodeABI|emitEvent|revert|assert|getStorage|setStorage|deleteStorage|call|delegateCall|staticCall|create|create2)$"))

; Blockchain type annotations (if used in comments or identifiers)
((identifier) @type.builtin
 (#match? @type.builtin "^(Address|Hash|Signature|Receipt|Transaction|Block|Event|Gas)$"))

; String interpolation and escapes
(escape_sequence) @string.escape

; Error highlighting for undefined constructs
(ERROR) @error