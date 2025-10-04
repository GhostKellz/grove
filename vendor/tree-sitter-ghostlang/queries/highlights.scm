; Syntax highlighting queries for Ghostlang
; These queries define how Grove should highlight different syntax elements

; Keywords
[
  "var"
  "local"
  "function"
  "if"
  "else"
  "while"
  "for"
  "in"
  "do"
  "end"
  "repeat"
  "until"
  "return"
  "break"
  "continue"
] @keyword

; Operators
[
  "="
  "+="
  "-="
  "*="
  "/="
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
  "?"
] @operator

; Punctuation
[
  ";"
  ","
  "."
  ":"
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

(local_function_declaration
  name: (identifier) @function)

(call_expression
  function: (identifier) @function.call)

(call_expression
  function: (member_expression
    property: (identifier) @function.call))

; Method calls
(method_call_expression
  method: (identifier) @function.call)

; Anonymous functions
(function_expression) @function

; Parameters
(parameter_list
  (identifier) @parameter)

; Varargs
(varargs) @parameter

; Variables
(variable_declaration
  name: (identifier) @variable)

(local_variable_declaration
  name: (identifier) @variable)

(assignment_expression
  left: (identifier) @variable)

; Loop control variables
(numeric_for_statement
  variable: (identifier) @variable)

(generic_for_statement
  variables: (identifier) @variable)

(for_statement
  variable: (identifier) @variable)

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

; Built-in functions (common editor APIs)
((identifier) @function.builtin
 (#match? @function.builtin "^(getCurrentLine|getLineText|setLineText|insertText|getAllText|replaceAllText|getCursorPosition|setCursorPosition|getSelection|setSelection|getSelectedText|replaceSelection|getFilename|getFileLanguage|isModified|notify|log|prompt|findAll|replaceAll|split|join|substring|indexOf|replace|createArray|arrayPush|arrayLength|arrayGet|createObject|objectSet|objectGet)$"))

; String interpolation and escapes
(escape_sequence) @string.escape

; Error highlighting for undefined constructs
(ERROR) @error