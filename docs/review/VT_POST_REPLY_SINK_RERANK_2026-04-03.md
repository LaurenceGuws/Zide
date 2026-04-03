# VT Post Reply Sink Rerank

Date: 2026-04-03

## Purpose

Rerank VT maturity after the reply-sink wave.

The question is no longer:

- can we name and land a byte-oriented reply sink?

That answer is now yes.

The next question is:

- what deeper protocol execution contract still blocks a more mature
  `TerminalCore` story?

## What Improved

The reply-sink wave materially improved protocol ownership feel.

The shell/runtime layer now owns explicit byte-reply emission through:

- [protocol_reply_sink.zig](/home/home/personal/zide/src/terminal/core/session/protocol_reply_sink.zig)

That sink now covers two coherent reply families:

- [dcs_apc.zig](/home/home/personal/zide/src/terminal/protocol/dcs_apc.zig)
- [osc_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_clipboard.zig)
- [palette.zig](/home/home/personal/zide/src/terminal/protocol/palette.zig)
- [osc_kitty_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_kitty_clipboard.zig)

So the old “protocol handlers naturally emit directly through shell bytes”
story is materially weaker now.

## What Does Not Win Next

### 1. More byte-oriented sink work

This no longer wins.

Reason:

- the remaining CSI family is writer-driven, not byte-built
- continuing this lane now would require a second explicit sink shape
- that is a different contract question, not automatic continuation

### 2. Sink uniformity for its own sake

This definitely does not win.

Reason:

- forcing CSI into the same sink just because it is the last reply family
  would be symmetry theater

## What Rises Again

### 1. Deeper protocol execution contract around `TerminalCore`

This is back on top.

The stronger remaining suspicion is no longer reply emission.
It is that protocol execution still splits along several semantic seams:

- text/control execution already feels more core-centered
- reply emission is cleaner now
- but protocol operations like CSI/OSC mode-setting, title/cwd/semantic prompt
  effects, and DECRQSS-style query assembly still do not obviously terminate
  on one clean “terminal protocol” contract

That means the next real maturity question is:

- what protocol execution contract should exist beside or on
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  so parser/protocol handling reads more terminal-centered without dragging in
  runtime mechanics?

## Best Next Direction

The next war should not be “reply sinks, continued.”

It should be a design-first protocol execution contract war around one named
semantic cluster, likely one of:

- CSI/ANSI mode semantics and screen effects
- OSC semantic effects such as title/cwd/progress/user-vars
- DECRQSS/query assembly sufficiency on core-side protocol helpers

## Bottom Line

The reply-sink wave is close to a clean stop-marker.

The next honest VT battlefield is deeper protocol execution maturity around
`TerminalCore`, not more sink work by inertia.
