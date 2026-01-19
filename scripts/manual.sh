#!/usr/bin/env bash
set -euo pipefail

# Manual OSC 133/1337 test sequences for Zide terminal.
# Run inside the Zide integrated terminal.

printf %s $'\033]133;A;aid=123;k=c;redraw=0;special_key=1;click_events=1\007'
printf %s $'\033]133;B\007'
printf %s $'\033]133;C;cmdline=echo%20hello\007'
printf %s $'\033]133;D;0\007'

# OSC 1337 user var set (TEST=foo).
printf %s $'\033]1337;SetUserVar=TEST=Zm9v\007'

echo "manual OSC test sequences sent"
