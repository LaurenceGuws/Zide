import { clampSidebarWidth, layoutDefaults, persistSidebarCollapsed, persistSidebarWidth, } from "./state.js";
export function applySidebarWidth(appEl, state, width) {
    const clamped = clampSidebarWidth(width);
    state.sidebar.width = clamped;
    appEl.style.setProperty("--sidebar-width", `${clamped}px`);
    persistSidebarWidth(clamped);
}
export function applySidebarCollapsed(appEl, state, collapsed) {
    state.sidebar.collapsed = collapsed;
    appEl.dataset.sidebarCollapsed = collapsed ? "true" : "false";
    persistSidebarCollapsed(collapsed);
}
export function syncResponsiveSidebarState(appEl, state) {
    if (window.innerWidth <= layoutDefaults.collapseBreakpoint) {
        applySidebarCollapsed(appEl, state, true);
        return;
    }
    applySidebarCollapsed(appEl, state, state.sidebar.collapsed);
}
export function installSidebarControls(args) {
    const { appEl, state, sidebarToggleEl, sidebarResizerEl } = args;
    sidebarToggleEl.addEventListener("click", () => {
        applySidebarCollapsed(appEl, state, appEl.dataset.sidebarCollapsed !== "true");
    });
    let resizeState = null;
    sidebarResizerEl.addEventListener("pointerdown", (event) => {
        if (window.innerWidth <= layoutDefaults.collapseBreakpoint)
            return;
        resizeState = {
            startX: event.clientX,
            startWidth: state.sidebar.width,
        };
        appEl.dataset.resizing = "true";
        sidebarResizerEl.setPointerCapture(event.pointerId);
    });
    sidebarResizerEl.addEventListener("pointermove", (event) => {
        if (!resizeState)
            return;
        const delta = event.clientX - resizeState.startX;
        applySidebarWidth(appEl, state, resizeState.startWidth + delta);
    });
    const endResize = () => {
        resizeState = null;
        appEl.dataset.resizing = "false";
    };
    sidebarResizerEl.addEventListener("pointerup", endResize);
    sidebarResizerEl.addEventListener("pointercancel", endResize);
}
