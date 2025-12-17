;; Interface / type literal property: foo: T   or   foo?: T
(property_signature
  name: (_) @parameter.name
  type: (type_annotation (_) @type))

;; Class field: foo: T   or   foo?: T
(public_field_definition
  name: (_) @parameter.name
  type: (type_annotation (_) @type))

;; Function/method params: (foo: T) / (foo?: T)
; works for function defs AND function types

; Common: required_parameter identifier type_annotation
(required_parameter
  (identifier) @parameter.name
  (type_annotation (_) @type))

(optional_parameter
  (identifier) @parameter.name
  (type_annotation (_) @type))

; Some grammars/situations use fields like name:/pattern:
(required_parameter
  name: (_) @parameter.name
  type: (type_annotation (_) @type))

(required_parameter
  pattern: (_) @parameter.name
  type: (type_annotation (_) @type))

(optional_parameter
  name: (_) @parameter.name
  type: (type_annotation (_) @type))

(optional_parameter
  pattern: (_) @parameter.name
  type: (type_annotation (_) @type))

;; Return types (no @parameter.name)
(function_declaration
  return_type: (type_annotation (_) @type))

(method_definition
  return_type: (type_annotation (_) @type))

(arrow_function
  return_type: (type_annotation (_) @type))
