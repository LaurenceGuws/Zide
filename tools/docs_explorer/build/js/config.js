export async function fetchJson(path) {
    const res = await fetch(path);
    if (!res.ok)
        throw new Error(`HTTP ${res.status} for ${path}`);
    return res.json();
}
export function selectedProjectConfigPath() {
    const params = new URLSearchParams(location.search);
    const selected = params.get("config");
    if (!selected) {
        const isGithubPages = location.hostname.endsWith("github.io");
        const isProjectSitePath = location.pathname.startsWith("/Zide/");
        return isGithubPages || isProjectSitePath
            ? "./config/project.pages.json"
            : "./config/project.json";
    }
    const safe = selected.replace(/[^a-zA-Z0-9._-]/g, "");
    return `./config/${safe}`;
}
export async function loadProjectConfig() {
    return Promise.all([
        fetchJson(selectedProjectConfigPath()),
        fetchJson("./config/docs-index.json"),
    ]).then(([project, docs]) => ({ project, docs }));
}
