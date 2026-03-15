const LANGUAGE_ALIASES = {
    sh: "bash",
    shell: "bash",
    console: "bash",
    zsh: "bash",
    ps1: "powershell",
    pwsh: "powershell",
    yml: "yaml",
    ts: "typescript",
    js: "javascript",
    md: "markdown",
};
function normalizedLanguage(codeEl) {
    for (const className of Array.from(codeEl.classList)) {
        if (!className.startsWith("language-"))
            continue;
        const raw = className.slice("language-".length).toLowerCase();
        return LANGUAGE_ALIASES[raw] ?? raw;
    }
    return null;
}
export function renderHighlightedCode(hljs, viewerEl) {
    if (!hljs)
        return;
    const blocks = viewerEl.querySelectorAll("pre > code");
    blocks.forEach((code) => {
        if (code.classList.contains("language-mermaid"))
            return;
        const source = code.textContent || "";
        const language = normalizedLanguage(code);
        if (language && hljs.getLanguage(language)) {
            code.innerHTML = hljs.highlight(source, { language }).value;
            code.classList.add("hljs");
            code.dataset.highlightLanguage = language;
            return;
        }
        code.innerHTML = hljs.highlightAuto(source).value;
        code.classList.add("hljs");
        delete code.dataset.highlightLanguage;
    });
}
