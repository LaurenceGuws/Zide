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

("text" @number
  (#match? @number "^[0-9][0-9]*$"))

("text" @number
  (#match? @number "^0x[0-9A-Fa-f][0-9A-Fa-f]*$"))

("text" @attribute
  (#match? @attribute "^.*_id$"))

("text" @attribute
  (#match? @attribute "^.*_ms$"))

("text" @attribute
  (#any-of? @attribute "pid" "txn" "session" "retry" "rows" "code" "status" "user" "service"))

("text" @constant
  (#any-of? @constant "ok" "OK" "true" "TRUE" "false" "FALSE"))
