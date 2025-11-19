; Kalix local variable scoping queries

; Scopes
(source_file) @local.scope
(contract_declaration) @local.scope
(function_declaration) @local.scope
(block) @local.scope

; Definitions
(contract_declaration
  name: (identifier) @local.definition.type)

(state_declaration
  name: (identifier) @local.definition.field)

(table_declaration
  name: (identifier) @local.definition.field)

(event_declaration
  name: (identifier) @local.definition.constant)

(function_declaration
  name: (identifier) @local.definition.function)

(parameter
  name: (identifier) @local.definition.parameter)

(event_parameter
  name: (identifier) @local.definition.parameter)

(let_statement
  name: (identifier) @local.definition.variable)

; References
(identifier) @local.reference
