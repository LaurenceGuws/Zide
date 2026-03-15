import {
  clampSidebarWidth,
  layoutDefaults,
  persistSidebarCollapsed,
  persistSidebarWidth,
} from "./state.js";
import type { AppState } from "./types.js";

export function applySidebarWidth(
  appEl: HTMLElement,
  state: AppState,
  width: number,
): void {
  const clamped = clampSidebarWidth(width);
  state.sidebar.width = clamped;
  appEl.style.setProperty("--sidebar-width", `${clamped}px`);
  persistSidebarWidth(clamped);
}

export function applySidebarCollapsed(
  appEl: HTMLElement,
  state: AppState,
  collapsed: boolean,
): void {
  state.sidebar.collapsed = collapsed;
  appEl.dataset.sidebarCollapsed = collapsed ? "true" : "false";
  persistSidebarCollapsed(collapsed);
}

export function syncResponsiveSidebarState(
  appEl: HTMLElement,
  state: AppState,
): void {
  if (window.innerWidth <= layoutDefaults.collapseBreakpoint) {
    applySidebarCollapsed(appEl, state, true);
    return;
  }
  applySidebarCollapsed(appEl, state, state.sidebar.collapsed);
}

export function installSidebarControls(args: {
  appEl: HTMLElement;
  state: AppState;
  sidebarToggleEl: HTMLButtonElement;
  sidebarResizerEl: HTMLElement;
}): void {
  const { appEl, state, sidebarToggleEl, sidebarResizerEl } = args;

  sidebarToggleEl.addEventListener("click", () => {
    applySidebarCollapsed(
      appEl,
      state,
      appEl.dataset.sidebarCollapsed !== "true",
    );
  });

  let resizeState: { startX: number; startWidth: number } | null = null;

  sidebarResizerEl.addEventListener("pointerdown", (event: PointerEvent) => {
    if (window.innerWidth <= layoutDefaults.collapseBreakpoint) return;
    resizeState = {
      startX: event.clientX,
      startWidth: state.sidebar.width,
    };
    appEl.dataset.resizing = "true";
    sidebarResizerEl.setPointerCapture(event.pointerId);
  });

  sidebarResizerEl.addEventListener("pointermove", (event: PointerEvent) => {
    if (!resizeState) return;
    const delta = event.clientX - resizeState.startX;
    applySidebarWidth(appEl, state, resizeState.startWidth + delta);
  });

  const endResize = (): void => {
    resizeState = null;
    appEl.dataset.resizing = "false";
  };

  sidebarResizerEl.addEventListener("pointerup", endResize);
  sidebarResizerEl.addEventListener("pointercancel", endResize);
}
