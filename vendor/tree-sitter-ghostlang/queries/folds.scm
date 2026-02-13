; Fold queries for Ghostlang
; Defines regions that can be collapsed in code editors

; Function bodies (both C-style and Lua-style)
(function_declaration
  body: (_) @fold)

(local_function_declaration
  body: (_) @fold)

; Control flow blocks
(if_statement) @fold

(while_statement) @fold

(for_statement) @fold

(repeat_statement) @fold

; C-style block statements
(block_statement) @fold

; Lua-style blocks
(lua_block) @fold

; Data structures
(object_literal) @fold

(array_literal) @fold

; Multi-line comments
(comment) @fold

; Parameter lists (for long function signatures)
(parameter_list) @fold

; Argument lists (for long function calls)
(argument_list) @fold
