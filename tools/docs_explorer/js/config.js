export async function fetchJson(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${path}`);
  return res.json();
}

/** @returns {Promise<{project: import("./types.js").ProjectConfig, docs: string[]}>} */
export async function loadProjectConfig() {
  return Promise.all([
    fetchJson("./config/project.json"),
    fetchJson("./config/docs-index.json"),
  ]).then(([project, docs]) => ({ project, docs }));
}
