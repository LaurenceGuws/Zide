export async function injectShellIcons(args: {
  sourceLinkIconEl: HTMLElement;
  optionsToggleIconEl: HTMLElement;
  sidebarToggleIconEl: HTMLElement;
}): Promise<void> {
  const { sourceLinkIconEl, optionsToggleIconEl, sidebarToggleIconEl } = args;
  await Promise.all([
    injectSvg(sourceLinkIconEl, "./assets/icons/github.svg"),
    injectSvg(optionsToggleIconEl, "./assets/icons/ellipsis.svg"),
    injectSvg(sidebarToggleIconEl, "./assets/icons/sidebar.svg"),
  ]);
}

async function injectSvg(target: HTMLElement, path: string): Promise<void> {
  const response = await fetch(path);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} for ${path}`);
  }
  const svg = await response.text();
  target.innerHTML = svg;
  const svgEl = target.querySelector("svg");
  if (svgEl) {
    svgEl.setAttribute("width", "16");
    svgEl.setAttribute("height", "16");
    svgEl.setAttribute("preserveAspectRatio", "xMidYMid meet");
    svgEl.setAttribute("focusable", "false");
  }
}
