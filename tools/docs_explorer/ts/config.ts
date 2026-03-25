import type { ProjectConfig } from "./shared/types.js";

export async function fetchJson<T>(path: string): Promise<T> {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${path}`);
  return res.json() as Promise<T>;
}

export function selectedProjectConfigPath(): string {
  const params = new URLSearchParams(location.search);
  const selected = params.get("config");
  if (!selected) {
    return location.hostname.endsWith("github.io")
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
  const project = await fetchJson<ProjectConfig>(selectedProjectConfigPath());
  const docsIndexPath = project.docsIndexPath ?? "./config/docs-index.json";
  const docs = await fetchJson<string[]>(docsIndexPath);
  return { project, docs };
}
