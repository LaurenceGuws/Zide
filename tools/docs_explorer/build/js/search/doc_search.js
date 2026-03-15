import { setTextSearchState } from "../state.js";
import { docHash, escapeHtml } from "../shared/utils.js";
const SEARCH_ENDPOINT = "./__search";
const SEARCH_LIMIT = 80;
const SEARCH_DEBOUNCE_MS = 120;
export function installDocSearch(args) {
    const { state, shell, docs, enabled } = args;
    if (!enabled) {
        shell.globalSearchEl.disabled = true;
        shell.globalSearchEl.placeholder = "rg search unavailable here";
        shell.globalSearchStatusEl.textContent = "Ripgrep search is only available in local-dev mode.";
        setTextSearchState(state, {
            query: "",
            open: false,
            status: "unavailable",
            selectedIndex: -1,
        });
        return;
    }
    let debounceTimer = 0;
    let requestToken = 0;
    let abortController = null;
    let hits = [];
    function setSearchUi(next) {
        setTextSearchState(state, next);
        shell.globalSearchModalEl.hidden = !next.open;
    }
    function closeModal() {
        abortController?.abort();
        abortController = null;
        hits = [];
        renderHits();
        setSearchUi({
            query: shell.globalSearchEl.value,
            open: false,
            status: state.textSearch.status,
            selectedIndex: -1,
        });
    }
    function renderStatus(text) {
        shell.globalSearchStatusEl.textContent = text;
    }
    function renderPreview(hit, query) {
        const preview = hit.preview || "";
        const hasRange = hit.start >= 0 &&
            hit.end > hit.start &&
            hit.end <= preview.length;
        if (hasRange) {
            return (`${escapeHtml(preview.slice(0, hit.start))}` +
                `<mark>${escapeHtml(preview.slice(hit.start, hit.end))}</mark>` +
                `${escapeHtml(preview.slice(hit.end))}`);
        }
        const lowerPreview = preview.toLowerCase();
        const lowerQuery = query.toLowerCase();
        const matchIndex = lowerQuery ? lowerPreview.indexOf(lowerQuery) : -1;
        if (matchIndex < 0)
            return escapeHtml(preview);
        return (`${escapeHtml(preview.slice(0, matchIndex))}` +
            `<mark>${escapeHtml(preview.slice(matchIndex, matchIndex + query.length))}</mark>` +
            `${escapeHtml(preview.slice(matchIndex + query.length))}`);
    }
    function renderHits() {
        shell.globalSearchResultsEl.innerHTML = hits
            .map((hit, index) => {
            const selected = index === state.textSearch.selectedIndex;
            return `
          <button
            class="search-hit ${selected ? "active" : ""}"
            type="button"
            data-search-hit-index="${index}"
            role="option"
            aria-selected="${selected ? "true" : "false"}"
          >
            <span class="search-hit-path">${escapeHtml(hit.path)}</span>
            <span class="search-hit-meta">L${hit.line}:${hit.column}</span>
            <span class="search-hit-preview">${renderPreview(hit, state.textSearch.query)}</span>
          </button>
        `;
        })
            .join("");
    }
    function scrollSelectedHitIntoView() {
        if (state.textSearch.selectedIndex < 0)
            return;
        const selectedEl = shell.globalSearchResultsEl.querySelector(`[data-search-hit-index="${state.textSearch.selectedIndex}"]`);
        selectedEl?.scrollIntoView({ block: "nearest" });
    }
    function openSelectedHit(index) {
        const hit = hits[index];
        if (!hit)
            return;
        location.hash = docHash(hit.path, hit.matchText || state.textSearch.query);
        shell.globalSearchEl.blur();
        closeModal();
    }
    async function runSearch(query) {
        abortController?.abort();
        requestToken += 1;
        const token = requestToken;
        hits = [];
        renderHits();
        if (!query.trim()) {
            renderStatus("Type to search across docs.");
            setSearchUi({
                query,
                open: false,
                status: "idle",
                selectedIndex: -1,
            });
            return;
        }
        abortController = new AbortController();
        renderStatus(`Searching ${docs.length} docs for “${query}”…`);
        setSearchUi({
            query,
            open: true,
            status: "loading",
            selectedIndex: -1,
        });
        try {
            const response = await fetch(SEARCH_ENDPOINT, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    query,
                    docs,
                    limit: SEARCH_LIMIT,
                }),
                signal: abortController.signal,
            });
            if (!response.ok || !response.body) {
                throw new Error(`HTTP ${response.status}`);
            }
            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let buffer = "";
            while (true) {
                const { value, done } = await reader.read();
                if (done)
                    break;
                buffer += decoder.decode(value, { stream: true });
                let newlineIndex = buffer.indexOf("\n");
                while (newlineIndex >= 0) {
                    const line = buffer.slice(0, newlineIndex).trim();
                    buffer = buffer.slice(newlineIndex + 1);
                    if (line) {
                        const payload = JSON.parse(line);
                        if ("error" in payload) {
                            throw new Error(payload.error);
                        }
                        hits.push(payload);
                        if (token !== requestToken)
                            return;
                        if (state.textSearch.selectedIndex < 0) {
                            setSearchUi({
                                query,
                                open: true,
                                status: "loading",
                                selectedIndex: 0,
                            });
                        }
                        renderHits();
                        scrollSelectedHitIntoView();
                        renderStatus(`${hits.length} hit${hits.length === 1 ? "" : "s"} for “${query}”…`);
                    }
                    newlineIndex = buffer.indexOf("\n");
                }
            }
            if (token !== requestToken)
                return;
            renderHits();
            renderStatus(hits.length
                ? `${hits.length} result${hits.length === 1 ? "" : "s"} for “${query}”.`
                : `No results for “${query}”.`);
            setSearchUi({
                query,
                open: true,
                status: "ready",
                selectedIndex: hits.length ? Math.max(0, state.textSearch.selectedIndex) : -1,
            });
            scrollSelectedHitIntoView();
        }
        catch (err) {
            if (err instanceof DOMException && err.name === "AbortError")
                return;
            renderStatus(`Search failed: ${String(err)}`);
            setSearchUi({
                query,
                open: true,
                status: "error",
                selectedIndex: -1,
            });
        }
    }
    shell.globalSearchEl.addEventListener("focus", () => {
        if (state.textSearch.query.trim()) {
            shell.globalSearchModalEl.hidden = false;
            setSearchUi({
                query: state.textSearch.query,
                open: true,
                status: state.textSearch.status,
                selectedIndex: state.textSearch.selectedIndex,
            });
        }
    });
    shell.globalSearchEl.addEventListener("input", () => {
        window.clearTimeout(debounceTimer);
        const query = shell.globalSearchEl.value;
        debounceTimer = window.setTimeout(() => {
            void runSearch(query);
        }, SEARCH_DEBOUNCE_MS);
    });
    shell.globalSearchEl.addEventListener("keydown", (event) => {
        if (event.key === "Escape") {
            closeModal();
            shell.globalSearchEl.value = "";
            renderStatus("Type to search across docs.");
            setSearchUi({
                query: "",
                open: false,
                status: "idle",
                selectedIndex: -1,
            });
            return;
        }
        if (!hits.length)
            return;
        if (event.key === "ArrowDown") {
            event.preventDefault();
            const nextIndex = Math.min(hits.length - 1, Math.max(0, state.textSearch.selectedIndex + 1));
            setSearchUi({
                query: state.textSearch.query,
                open: true,
                status: state.textSearch.status,
                selectedIndex: nextIndex,
            });
            renderHits();
            scrollSelectedHitIntoView();
            return;
        }
        if (event.key === "ArrowUp") {
            event.preventDefault();
            const nextIndex = Math.max(0, state.textSearch.selectedIndex - 1);
            setSearchUi({
                query: state.textSearch.query,
                open: true,
                status: state.textSearch.status,
                selectedIndex: nextIndex,
            });
            renderHits();
            scrollSelectedHitIntoView();
            return;
        }
        if (event.key === "Enter" && state.textSearch.selectedIndex >= 0) {
            event.preventDefault();
            openSelectedHit(state.textSearch.selectedIndex);
        }
    });
    shell.globalSearchResultsEl.addEventListener("click", (event) => {
        const target = event.target;
        if (!(target instanceof HTMLElement))
            return;
        const button = target.closest("[data-search-hit-index]");
        if (!button)
            return;
        const index = Number(button.dataset.searchHitIndex);
        if (Number.isNaN(index))
            return;
        openSelectedHit(index);
    });
    document.addEventListener("click", (event) => {
        const target = event.target;
        if (!(target instanceof Node))
            return;
        if (!shell.globalSearchModalEl.hidden &&
            !shell.globalSearchModalEl.contains(target) &&
            !shell.globalSearchEl.contains(target)) {
            closeModal();
        }
    });
}
