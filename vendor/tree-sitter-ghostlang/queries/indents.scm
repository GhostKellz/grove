; Indentation queries for Ghostlang
; Defines how code should be indented in editors

; Indent inside block structures
[
  (block_statement)
  (lua_block)
  (object_literal)
  (array_literal)
] @indent

; Indent after control flow keywords (Lua-style)
(if_statement
  "then" @indent.begin)

(while_statement
  "do" @indent.begin)

(for_statement
  "do" @indent.begin)

(repeat_statement
  "repeat" @indent.begin)

; Dedent before closing tokens
[
  "}"
  "]"
  ")"
  "end"
  "until"
  "else"
  "elseif"
] @indent.dedent

; Align arguments when split across lines
(argument_list) @indent.align

; Keep closing braces aligned with opening statement
(block_statement
  "}" @indent.branch)

(object_literal
  "}" @indent.branch)

(array_literal
  "]" @indent.branch)

; Extend indentation for incomplete statements
(variable_declaration
  "=" @indent.extension)

(assignment_expression) @indent.continuation
