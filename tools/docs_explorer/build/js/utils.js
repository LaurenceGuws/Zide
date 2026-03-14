export function escapeHtml(text) {
    return text
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;");
}
export function repoRelative(basePath, path) {
    return `${basePath}${path}`;
}
export function currentDocFromHash(docs, defaultDocPath) {
    const hash = new URLSearchParams(location.hash.replace(/^#/, ""));
    const doc = hash.get("doc");
    return doc && docs.includes(doc) ? doc : defaultDocPath;
}
