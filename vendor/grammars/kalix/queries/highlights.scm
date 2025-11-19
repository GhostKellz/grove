; Kalix syntax highlighting queries

; Keywords
[
  "contract"
  "state"
  "table"
  "event"
  "fn"
  "let"
  "const"
  "mut"
  "pub"
  "return"
  "view"
  "payable"
] @keyword

; Types - Built-in primitive types
[
  "u8" "u16" "u32" "u64" "u128"
  "i8" "i16" "i32" "i64" "i128"
  "bool" "string" "bytes"
  "Address" "Hash"
] @type.builtin

; Types - Generic types
"Map" @type.builtin

; Type identifiers in declarations
(type_expression
  (type_identifier) @type)

; Contract names
(contract_declaration
  name: (identifier) @type.definition)

; State declarations
(state_declaration
  name: (identifier) @variable.member)

; Table declarations
(table_declaration
  name: (identifier) @variable.member)

; Event declarations
(event_declaration
  name: (identifier) @constant)

; Event parameters
(event_parameter
  name: (identifier) @variable.parameter)

; Function declarations
(function_declaration
  name: (identifier) @function)

; Function qualifiers
(function_qualifier) @keyword.modifier

; Function parameters
(parameter
  name: (identifier) @variable.parameter)

; Function calls
(call_expression
  function: (identifier) @function.call)

(call_expression
  function: (member_expression
    property: (identifier) @function.call))

; Member access for state/table
(member_expression
  object: (identifier) @variable.builtin
  (#eq? @variable.builtin "state"))

(member_expression
  object: (identifier) @variable
  property: (identifier) @variable.member)

; Let bindings
(let_statement
  name: (identifier) @variable)

; Mutability keywords
(mutability) @keyword.modifier

; Literals
(boolean_literal) @boolean
(integer_literal) @number
(string_literal) @string
(escape_sequence) @string.escape

; Operators
[
  "="
  "+"
  "-"
  "*"
  "/"
  "%"
  "=="
  "!="
  "<"
  ">"
  "<="
  ">="
  "&&"
  "||"
  "!"
] @operator

; Punctuation
[
  "("
  ")"
  "{"
  "}"
] @punctuation.bracket

[
  ","
  ";"
  ":"
  "."
  "->"
] @punctuation.delimiter

; Comments
(comment) @comment
