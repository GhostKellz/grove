; JavaScript folding queries for Grove
; Fold function declarations
(function_declaration) @fold

; Fold arrow functions
(arrow_function) @fold

; Fold function expressions
(function_expression) @fold

; Fold generator functions
(generator_function_declaration) @fold
(generator_function) @fold

; Fold class declarations
(class_declaration) @fold

; Fold class body
(class_body) @fold

; Fold method definitions
(method_definition) @fold

; Fold if statements
(if_statement) @fold

; Fold for loops
(for_statement) @fold
(for_in_statement) @fold

; Fold while loops
(while_statement) @fold
(do_statement) @fold

; Fold switch statements
(switch_statement) @fold
(switch_case) @fold

; Fold try-catch blocks
(try_statement) @fold

; Fold object literals
(object) @fold

; Fold array literals (multiline)
(array) @fold

; Fold template strings
(template_string) @fold

; Fold JSX elements
(jsx_element) @fold
(jsx_fragment) @fold

; Fold blocks
(statement_block) @fold

; Fold import/export statements
(export_statement) @fold

; Fold parenthesized expressions (multiline)
(parenthesized_expression) @fold

; Fold argument lists (multiline)
(arguments) @fold

; Fold formal parameters (multiline)
(formal_parameters) @fold
