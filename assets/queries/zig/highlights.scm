; Comments
(comment) @comment

; Strings
(string) @string
(multiline_string) @string
(character) @string

; Numbers
(integer) @number
(float) @number

; Types / Builtins
(builtin_type) @type
(builtin_identifier) @builtin

; Variables
(identifier) @variable

; Functions
(call_expression function: (identifier) @function)
(function_declaration name: (identifier) @function)
