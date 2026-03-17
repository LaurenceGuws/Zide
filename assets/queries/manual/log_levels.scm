("text" @number
  (#match? @number "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))

("text" @number
  (#match? @number "^[0-9]{2}:[0-9]{2}:[0-9]{2}([.,][0-9]+)?$"))

("text" @number
  (#match? @number "^[0-9]+$"))

("text" @comment
  (#any-of? @comment "TRACE" "DEBUG"))

("text" @type
  (#any-of? @type "INFO"))

("text" @keyword.control
  (#any-of? @keyword.control "WARN" "WARNING"))

("text" @error
  (#any-of? @error "ERROR" "FATAL" "CRITICAL" "PANIC"))

("text" @string
  (#match? @string "^0x[0-9A-Fa-f]+$"))
