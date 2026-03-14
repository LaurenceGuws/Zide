import type { ProjectConfig } from "./types.js";

export async function fetchJson<T>(path: string): Promise<T> {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${path}`);
  return res.json() as Promise<T>;
}

export async function loadProjectConfig(): Promise<{ project: ProjectConfig; docs: string[] }> {
  return Promise.all([
    fetchJson<ProjectConfig>("./config/project.json"),
    fetchJson<string[]>("./config/docs-index.json"),
  ]).then(([project, docs]) => ({ project, docs }));
}
