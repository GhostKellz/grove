; Python folding queries for Grove
; Fold function definitions
(function_definition) @fold

; Fold class definitions
(class_definition) @fold

; Fold if statements
(if_statement) @fold

; Fold for loops
(for_statement) @fold

; Fold while loops
(while_statement) @fold

; Fold try-except blocks
(try_statement) @fold

; Fold with statements
(with_statement) @fold

; Fold match statements (Python 3.10+)
(match_statement) @fold

; Fold dictionary literals
(dictionary) @fold

; Fold list literals (only if multiline)
(list) @fold

; Fold tuple literals (only if multiline)
(tuple) @fold

; Fold lambda expressions (only if multiline)
(lambda) @fold

; Fold comprehensions
(list_comprehension) @fold
(dictionary_comprehension) @fold
(set_comprehension) @fold

; Fold decorated definitions
(decorated_definition) @fold

; Fold argument lists (multiline)
(argument_list) @fold

; Fold parameter lists (multiline)
(parameters) @fold
