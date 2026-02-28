# Planning

## Wayland fractional scaling: compositor-aware mouse scale

**Goal**
Make mouse hit-testing correct on Wayland fractional scaling by pulling the compositor’s scale factor when available.

**Scope**
- Detect compositor type.
- Read scale for Hyprland and KDE.
- Apply scale to mouse input (default), with env override.

**Plan**
1) **Detection layer**
   - Detect Wayland session (`WAYLAND_DISPLAY`).
   - Identify compositor via env hints:
     - Hyprland: `HYPRLAND_INSTANCE_SIGNATURE`
     - KDE: `KDE_FULL_SESSION` or `KDE_SESSION_VERSION`
2) **Hyprland implementation**
   - Call `hyprctl -j monitors`.
   - Parse active monitor scale.
3) **KDE implementation**
   - Call `kscreen-doctor -o` (if available).
   - Parse scale from output.
4) **Integration**
   - Wire the scale into renderer mouse scaling.
   - Keep `ZIDE_MOUSE_SCALE` override.
5) **Validation**
   - Test on Hyprland (scale 1.6).
   - Test on KDE (once available).

**Status (last updated: 2026-01-28)**
- [x] Detection layer
- [x] Hyprland scale (hyprctl)
- [ ] KDE scale (kscreen-doctor)
- [x] Integration + fallback
- [ ] Validation on Hyprland (no verified run recorded)
- [ ] Validation on KDE (no verified run recorded)

**Decision reference**
- Decision logged in `app_architecture/DECISIONS.md` on 2026-01-15; implementation landed, validation still pending.

## Terminal backend embeddability / FFI bridge

**Goal**
Turn terminal modularity into a real host boundary: a desktop-first, UI-free bridge around the existing PTY/protocol/snapshot backend.

**Scope**
- lock exported bridge shape
- define event and snapshot ownership contracts
- add a minimal Python `ctypes` smoke host
- install a bridge C header for non-Python consumers

**Status (last updated: 2026-02-28)**
- [x] Added `app_architecture/terminal/ffi_bridge_todo.yaml`
- [x] Added bridge design baseline
- [x] Added event inventory baseline
- [~] Exported C ABI surface (minimal opaque-handle slice landed)
- [x] Python smoke host against real bridge
- [x] Installed C header for bridge consumers
- [x] Separate PTY-backed verifier for bridge-owned shell startup

**Decision reference**
- See `app_architecture/terminal/FFI_BRIDGE_DESIGN.md`.
