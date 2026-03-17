("text" @punctuation
  (#any-of? @punctuation "[" "]" "(" ")" "{" "}" "<" ">"))

("text" @operator
  (#any-of? @operator "=" ":" "," "." "/" "\\" "|" "->" "=>" "::"))

("text" @operator
  (#match? @operator "^[!@#$%^&*;?]+$"))

("text" @comment
  (#any-of? @comment "TRACE" "Trace" "trace" "DEBUG" "Debug" "debug"))

("text" @type
  (#any-of? @type "INFO" "Info" "info"))

("text" @keyword.control
  (#any-of? @keyword.control "WARN" "Warn" "warn" "WARNING" "Warning" "warning"))

("text" @error
  (#any-of? @error
    "ERROR" "Error" "error"
    "FATAL" "Fatal" "fatal"
    "CRITICAL" "Critical" "critical"
    "PANIC" "Panic" "panic"))

("text" @constant
  (#any-of? @constant
    "PASS" "Pass" "pass"
    "PASSED" "Passed" "passed"
    "SUCCESS" "Success" "success"
    "OK" "Ok" "ok"
    "TRUE" "True" "true"
    "FALSE" "False" "false"
    "NULL" "Null" "null"))

("text" @keyword_control
  (#any-of? @keyword_control
    "NOTICE" "Notice" "notice"
    "VERBOSE" "Verbose" "verbose"))

("text" @number
  (#match? @number "^[0-9][0-9]*$"))

("text" @number
  (#match? @number "^0x[0-9A-Fa-f][0-9A-Fa-f]*$"))

("text" @number
  (#match? @number "^[0-9][0-9]*\\.[0-9][0-9]*$"))

("text" @number
  (#match? @number "^[0-9][0-9]*[mun]s$"))

("text" @number
  (#match? @number "^[0-9][0-9]*ms$"))

("text" @attribute
  (#match? @attribute "^.*_id$"))

("text" @attribute
  (#match? @attribute "^.*_ms$"))

("text" @attribute
  (#any-of? @attribute "pid" "txn" "session" "retry" "rows" "code" "status" "user" "service"))

("text" @attribute
  (#match? @attribute "^[A-Za-z_][A-Za-z0-9_]*=.*$"))

("text" @string
  (#match? @string "^\".*\"$"))

("text" @string
  (#match? @string "^'.*'$"))

("text" @string
  (#match? @string "^`.*`$"))

("text" @namespace
  (#match? @namespace "^[A-Za-z_][A-Za-z0-9_.-]*/[A-Za-z0-9_.-].*$"))

("text" @link
  (#match? @link "^https?://.*$"))
