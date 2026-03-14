import { setOptionsMenuOpen as setOptionsMenuState } from "./state.js";

export function installOptionsMenu({ state, optionsToggleEl, optionsMenuEl, onThemeToggle }) {
  optionsMenuEl.addEventListener("click", (event) => {
    event.stopPropagation();
  });

  document.addEventListener("click", (event) => {
    if (!optionsMenuEl.hidden && !optionsMenuEl.contains(event.target) && !optionsToggleEl.contains(event.target)) {
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
