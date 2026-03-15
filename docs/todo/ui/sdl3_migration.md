# SDL3 Migration TODO

## Scope

Add the SDL3 path behind a switch, validate it, then keep SDL3 as the default and only build path.

## Constraints

- SDL3 is already the default while validation completes.
- Keep logging output identical where practical.
- Treat shim work as extraction-only.

Status note, 2026-03-15:

- This lane is effectively closed.
- SDL3 is the default/live path now.
- The only remaining item here is cleanup of temporary logging residue if any is
  still worth carrying.

## TODO

- [x] `S0-01` Add SDL3 build path behind a switch
- [x] `S0-02` Document SDL3 install and build flag
- [x] `S1-01` Create SDL shim module
- [x] `S1-02` Route window creation and GL context through the shim
- [x] `S2-01` Shim event structs and enums for window and input
- [x] `S2-02` Shim text input and text editing payloads
- [x] `S3-01` Add SDL3 implementation inside the shim
- [x] `S3-02` Compile-only SDL3 smoke check
- [x] `S4-01` Runtime smoke for window, input, and text input
- [x] `S4-02` Fix SDL3 text input pointer lifetime
- [ ] `S4-03` Clean up temporary SDL3 input logging
- [x] `S5-01` Drop the fallback build
