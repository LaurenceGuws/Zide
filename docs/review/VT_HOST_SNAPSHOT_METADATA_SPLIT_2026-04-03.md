# VT Host Snapshot Metadata Split

Date: 2026-04-03

## Purpose

Land the snapshot-versus-metadata normalization slice.

The exact weakness was:

- snapshot still duplicated `title` and `cwd`
- metadata already owned that same terminal truth more honestly

## Split

Snapshot is now viewport publication only:

- cells
- cursor state
- alt/screen flags
- coarse damage
- generation

Metadata now owns terminal metadata only:

- title
- cwd
- scrollback count
- scrollback offset

## Why This Matters

This removes one duplicated host story.

Hosts no longer need to learn:

- title/cwd from snapshot publication
- and title/cwd from terminal metadata

The host contract is more deliberate now:

- snapshot means publication truth
- metadata means terminal metadata truth

## Live Surfaces Updated

- `src/terminal/ffi/shared.zig`
- `src/terminal/ffi/c_api.zig`
- `src/terminal/ffi/core_api.zig`
- `src/terminal_ffi_check.zig`
- `src/terminal_ffi_pty_smoke.zig`

## Current Judgment

This is the right kind of host normalization:

- narrower public categories
- less duplicate truth
- more boring host contract
