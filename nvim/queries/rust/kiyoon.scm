; For toggle_option_type()
; not all types should be toggled. Only the definitions, not the uses.
(field_declaration
  type: (_) @type)

(function_item
  parameters: (parameters
    (parameter
      type: (_) @type)))

(function_item
  return_type: (_) @type)
