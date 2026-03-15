import { renderMarkdown } from "./markdown.js";
import { currentFindFromHash, repoRelative } from "../shared/utils.js";
import { syncActiveLink } from "../tree/tree.js";
import { renderMermaidBlocks } from "./mermaid.js";
import { renderViewer, setViewerContent, setViewerError, setViewerLoading, } from "./viewer_state.js";
function renderViewerLoading(state, viewerEl, path) {
    setViewerLoading(state, path);
    renderViewer(state, viewerEl);
}
function renderViewerContent(state, viewerEl, html) {
    setViewerContent(state, html);
    renderViewer(state, viewerEl);
}
function renderViewerFailure(state, viewerEl, path, err) {
    setViewerError(state, path, err);
    renderViewer(state, viewerEl);
}
function focusSearchHit(viewerEl, term) {
    const query = term.trim();
    if (!query)
        return;
    const walker = document.createTreeWalker(viewerEl, NodeFilter.SHOW_TEXT);
    const lowerQuery = query.toLowerCase();
    while (walker.nextNode()) {
        const node = walker.currentNode;
        if (!(node instanceof Text))
            continue;
        const value = node.textContent ?? "";
        const index = value.toLowerCase().indexOf(lowerQuery);
        if (index < 0)
            continue;
        const range = document.createRange();
        range.setStart(node, index);
        range.setEnd(node, index + query.length);
        const mark = document.createElement("mark");
        mark.className = "viewer-search-hit";
        try {
            range.surroundContents(mark);
        }
        catch {
            mark.textContent = value.slice(index, index + query.length);
            range.deleteContents();
            range.insertNode(mark);
        }
        mark.scrollIntoView({ block: "center", behavior: "smooth" });
        return;
    }
}
export async function loadDoc(args) {
    const { state, repoBasePath, repoAbsolutePath, path, marked, mermaid, rootEl, viewerEl, docs, onLoading, onReady, onError, } = args;
    if (!path)
        return;
    onLoading(state, path);
    renderViewerLoading(state, viewerEl, path);
    syncActiveLink(state.tree.activePath);
    try {
        const res = await fetch(repoRelative(repoBasePath, path));
        if (!res.ok)
            throw new Error(`HTTP ${res.status}`);
        const source = await res.text();
        const html = renderMarkdown(marked, source, path, repoBasePath, docs, repoAbsolutePath);
        renderViewerContent(state, viewerEl, html);
        onReady(state, path);
        await renderMermaidBlocks(mermaid, rootEl, viewerEl);
        focusSearchHit(viewerEl, currentFindFromHash());
    }
    catch (err) {
        onError(state, path);
        renderViewerFailure(state, viewerEl, path, err);
    }
}
