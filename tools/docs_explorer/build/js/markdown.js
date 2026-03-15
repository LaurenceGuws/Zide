export function configureMarked(marked) {
    marked.setOptions({
        gfm: true,
        breaks: false,
        headerIds: true,
        mangle: false,
    });
}
function isExternalUrl(value) {
    return /^(?:[a-z]+:|\/\/|#)/i.test(value);
}
function isRepoAbsolutePath(value, repoAbsolutePath) {
    return !!repoAbsolutePath && value.startsWith(`${repoAbsolutePath}/`);
}
function isDocPath(path) {
    return path.endsWith(".md") || path.endsWith(".yaml");
}
function normalizeRepoPath(path) {
    const parts = path.split("/");
    const normalized = [];
    for (const part of parts) {
        if (!part || part === ".")
            continue;
        if (part === "..") {
            normalized.pop();
            continue;
        }
        normalized.push(part);
    }
    return normalized.join("/");
}
function resolveDocRelativePath(docPath, assetPath) {
    const docDirParts = docPath.split("/").slice(0, -1);
    const combined = [...docDirParts, ...assetPath.split("/")].join("/");
    return normalizeRepoPath(combined);
}
function asDocHash(path) {
    return `#doc=${encodeURIComponent(path)}`;
}
function rewriteMediaUrls(html, docPath, repoBasePath, docs, repoAbsolutePath) {
    const template = document.createElement("template");
    template.innerHTML = html;
    const selectors = [
        ["a[href]", "href"],
        ["img[src]", "src"],
        ["video[src]", "src"],
        ["video[poster]", "poster"],
        ["source[src]", "src"],
    ];
    for (const [selector, attribute] of selectors) {
        const elements = template.content.querySelectorAll(selector);
        elements.forEach((el) => {
            const raw = el.getAttribute(attribute);
            if (!raw)
                return;
            if (isRepoAbsolutePath(raw, repoAbsolutePath)) {
                const relative = raw.slice(repoAbsolutePath.length + 1);
                if (attribute === "href" && isDocPath(relative) && docs.includes(relative)) {
                    el.setAttribute(attribute, asDocHash(relative));
                }
                else {
                    el.setAttribute(attribute, `${repoBasePath}${relative}`);
                }
                return;
            }
            if (isExternalUrl(raw))
                return;
            const resolved = resolveDocRelativePath(docPath, raw);
            if (attribute === "href" && isDocPath(resolved) && docs.includes(resolved)) {
                el.setAttribute(attribute, asDocHash(resolved));
            }
            else {
                el.setAttribute(attribute, `${repoBasePath}${resolved}`);
            }
        });
    }
    return template.innerHTML;
}
export function renderMarkdown(marked, source, docPath, repoBasePath, docs, repoAbsolutePath) {
    const html = marked.parse(source);
    return rewriteMediaUrls(html, docPath, repoBasePath, docs, repoAbsolutePath);
}
