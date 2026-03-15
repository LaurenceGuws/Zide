import type { ProjectConfig } from "./types.js";

export async function fetchJson<T>(path: string): Promise<T> {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${path}`);
  return res.json() as Promise<T>;
}

export function selectedProjectConfigPath(): string {
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

export async function loadProjectConfig(): Promise<{
  project: ProjectConfig;
  docs: string[];
}> {
  return Promise.all([
    fetchJson<ProjectConfig>(selectedProjectConfigPath()),
    fetchJson<string[]>("./config/docs-index.json"),
  ]).then(([project, docs]) => ({ project, docs }));
}
