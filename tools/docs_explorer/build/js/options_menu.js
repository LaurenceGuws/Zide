import { setOptionsMenuOpen as setOptionsMenuState } from "./state.js";
export function installOptionsMenu(args) {
    const { state, optionsToggleEl, optionsMenuEl, onThemeToggle } = args;
    optionsMenuEl.addEventListener("click", (event) => {
        event.stopPropagation();
    });
    document.addEventListener("click", (event) => {
        const target = event.target;
        if (!(target instanceof Node))
            return;
        if (!optionsMenuEl.hidden && !optionsMenuEl.contains(target) && !optionsToggleEl.contains(target)) {
            setOptionsMenuOpen(state, optionsToggleEl, optionsMenuEl, false);
        }
    });
    optionsToggleEl.addEventListener("click", () => {
        setOptionsMenuOpen(state, optionsToggleEl, optionsMenuEl, optionsMenuEl.hidden);
    });
    onThemeToggle(() => {
        setOptionsMenuOpen(state, optionsToggleEl, optionsMenuEl, false);
    });
}
export function setOptionsMenuOpen(state, optionsToggleEl, optionsMenuEl, open) {
    setOptionsMenuState(state, open);
    optionsMenuEl.hidden = !open;
    optionsToggleEl.setAttribute("aria-expanded", open ? "true" : "false");
}
