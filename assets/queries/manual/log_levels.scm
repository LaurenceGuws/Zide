("text" @number
  (#match? @number "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))

("text" @number
  (#match? @number "^[0-9]{2}:[0-9]{2}:[0-9]{2}([.,][0-9]+)?$"))

("text" @number
  (#match? @number "^[0-9]+$"))

("text" @comment
  (#match? @comment "^[Tt][Rr][Aa][Cc][Ee]$|^[Dd][Ee][Bb][Uu][Gg]$"))

("text" @type
  (#match? @type "^[Ii][Nn][Ff][Oo]$"))

("text" @keyword.control
  (#match? @keyword.control "^[Ww][Aa][Rr][Nn]$|^[Ww][Aa][Rr][Nn][Ii][Nn][Gg]$"))

("text" @error
  (#match? @error "^[Ee][Rr][Rr][Oo][Rr]$|^[Ff][Aa][Tt][Aa][Ll]$|^[Cc][Rr][Ii][Tt][Ii][Cc][Aa][Ll]$|^[Pp][Aa][Nn][Ii][Cc]$"))

("text" @string
  (#match? @string "^0x[0-9A-Fa-f]+$"))
