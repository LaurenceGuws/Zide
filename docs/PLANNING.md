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

**Status**
- [x] Detection layer
- [x] Hyprland scale (hyprctl)
- [ ] KDE scale (kscreen-doctor)
- [x] Integration + fallback
- [ ] Validation on Hyprland
- [ ] Validation on KDE
