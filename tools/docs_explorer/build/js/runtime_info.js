export function renderRuntimeInfo(shell, project) {
    shell.optionsInfoEl.innerHTML = `
    <div class="options-info-label">About</div>
    <div class="options-info-row">
      <span class="options-info-key">Mode</span>
      <span class="options-info-value">${escapeInfo(project.runtimeMode || "built-esm")}</span>
    </div>
    <div class="options-info-row">
      <span class="options-info-key">Repo Base</span>
      <span class="options-info-value">${escapeInfo(project.repoBasePath)}</span>
    </div>
  `;
}
function escapeInfo(text) {
    return text
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;");
}
