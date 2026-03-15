export async function injectShellIcons(args) {
    const { sourceLinkIconEl, supportLinkIconEl, optionsToggleIconEl, sidebarToggleIconEl, } = args;
    await Promise.all([
        injectSvg(sourceLinkIconEl, "./assets/icons/github.svg"),
        injectSvg(supportLinkIconEl, "./assets/icons/kofi.svg"),
        injectSvg(optionsToggleIconEl, "./assets/icons/ellipsis.svg"),
        injectSvg(sidebarToggleIconEl, "./assets/icons/sidebar.svg"),
    ]);
}
async function injectSvg(target, path) {
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
