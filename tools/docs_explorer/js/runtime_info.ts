import type { AppShell, ProjectConfig } from "./types.js";

export function renderRuntimeInfo(shell: AppShell, project: ProjectConfig): void {
  shell.optionsInfoEl.innerHTML = `
    <div class="options-info-label">About</div>
    <div class="options-info-row">
      <span class="options-info-key">Mode</span>
      <span class="options-info-value">Built ESM</span>
    </div>
    <div class="options-info-row">
      <span class="options-info-key">Repo Base</span>
      <span class="options-info-value">${escapeInfo(project.repoBasePath)}</span>
    </div>
  `;
}

function escapeInfo(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
