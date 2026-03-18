# Theme Style Fixture

This file is the manual visual target for imported editor theme styles.

## Markup

Regular body text with a [link](https://example.com/path/to/resource).

*Italic emphasis should slant.*

**Bold emphasis should render heavier.**

~~Strikethrough should draw a strike line.~~

<u>Underline-like markup should at least surface as decorated text where the grammar/theme supports it.</u>

### Mixed Inline Cases

- `inline code`
- *italic* with **bold** nearby
- ~~deleted~~ and [linked text](https://zide.dev)

## Code

```zig
const std = @import("std");

pub fn main() !void {
    const ok = true;
    const answer = 42;
    std.log.info("style fixture {d}", .{answer});
}
```

## Plain Text

Watch comments, keywords, numbers, strings, links, and headings under imported themes.
