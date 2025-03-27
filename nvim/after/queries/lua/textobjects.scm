; extends

(assignment_statement
  (variable_list
    name: (_))
  (expression_list
    value: (function_definition
      body: (_) @function.inner))) @function.outer
