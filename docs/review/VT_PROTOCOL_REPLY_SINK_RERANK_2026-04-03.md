# VT Protocol Reply Sink Rerank

Date: 2026-04-03

## Purpose

Rerank the reply-sink war after the byte-oriented sink wave.

The question is:

- should this lane continue immediately into CSI writer-driven replies
- or has the byte-built family now paid off enough to stop cleanly?

## What Landed

The byte-oriented sink wave is now real across two coherent reply families.

Live sink owner:

- [protocol_reply_sink.zig](/home/home/personal/zide/src/terminal/core/session/protocol_reply_sink.zig)

Adopter families now landed:

- [dcs_apc.zig](/home/home/personal/zide/src/terminal/protocol/dcs_apc.zig)
- [osc_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_clipboard.zig)
- [palette.zig](/home/home/personal/zide/src/terminal/protocol/palette.zig)
- [osc_kitty_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_kitty_clipboard.zig)

That means the remaining reply sink pressure is now concentrated in:

- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
- [csi_reply.zig](/home/home/personal/zide/src/terminal/protocol/csi_reply.zig)

## Current Read

This lane should not continue by symmetry alone.

Why:

- the landed sink shape is byte-oriented
- the remaining CSI family is writer-driven
- forcing CSI into the byte-oriented sink now would be a different contract
  question, not a continuation of the same clear wave

So the next honest read is:

- the byte-oriented sink lane is close to a stop-marker

## What Would Justify Continuation

Only one thing:

- a second explicit contract shape for writer-driven replies

That would need to answer:

- what the writer-driven sink is
- why it is not just `lockPtyWriter()` with a new name
- how it improves parser/protocol maturity instead of uniformity theater

## What Would Be Fake Progress

- forcing CSI replies through byte assembly just to match the first sink
- wrapping `lockPtyWriter()` in one more helper and calling that a new
  boundary
- continuing this lane only because it is active

## Conclusion

The byte-oriented sink war materially paid off.

The next honest move is:

1. stop this lane here unless a writer-driven sink shape is explicitly named
2. return to the deeper parser-owner / `TerminalCore` maturity question from
   the stronger baseline

## Bottom Line

The reply-sink lane is now close to a real stop-marker.

If VT continues immediately, it should do so because a new writer-driven reply
contract is explicit, not because CSI is the last family left.
