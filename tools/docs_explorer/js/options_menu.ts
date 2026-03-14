import { setOptionsMenuOpen as setOptionsMenuState } from "./state.js";
import type { AppState } from "./types.js";

export function installOptionsMenu(args: {
  state: AppState;
  optionsToggleEl: HTMLButtonElement;
  optionsMenuEl: HTMLElement;
  onThemeToggle: (registerClose: () => void) => void;
}): void {
  const { state, optionsToggleEl, optionsMenuEl, onThemeToggle } = args;

  optionsMenuEl.addEventListener("click", (event: MouseEvent) => {
    event.stopPropagation();
  });

  document.addEventListener("click", (event: MouseEvent) => {
    const target = event.target;
    if (!(target instanceof Node)) return;
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

export function setOptionsMenuOpen(
  state: AppState,
  optionsToggleEl: HTMLButtonElement,
  optionsMenuEl: HTMLElement,
  open: boolean,
): void {
  setOptionsMenuState(state, open);
  optionsMenuEl.hidden = !open;
  optionsToggleEl.setAttribute("aria-expanded", open ? "true" : "false");
}
