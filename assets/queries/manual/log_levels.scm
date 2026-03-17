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
