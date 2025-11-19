; Kalix text objects for code navigation

; Functions
(function_declaration) @function.outer
(function_declaration
  body: (block) @function.inner)

; Contracts
(contract_declaration) @class.outer

; Blocks
(block) @block.outer

; Parameters
(parameter_list) @parameter.outer
(parameter) @parameter.inner

; Calls
(call_expression) @call.outer
(argument_list) @call.inner

; Comments
(comment) @comment.outer
