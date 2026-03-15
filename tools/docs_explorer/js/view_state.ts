import { setDocumentState } from "./state.js";
import { escapeHtml, repoRelative } from "./utils.js";
import type { AppShell, AppState } from "./types.js";

export function setDocumentLoading(
  state: AppState,
  repoBasePath: string,
  path: string,
): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    status: "loading",
  });
}

export function setDocumentReady(
  state: AppState,
  repoBasePath: string,
  path: string,
): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    status: "ready",
  });
}

export function setDocumentError(
  state: AppState,
  repoBasePath: string,
  path: string,
): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    status: "error",
  });
}

export function renderDocumentChrome(
  state: AppState,
  shell: AppShell,
  appIconPath: string,
  docs: string[] = [],
): void {
  shell.titleEl.innerHTML =
    `<span class="app-wordmark"><img class="app-wordmark-mark" src="${escapeHtml(appIconPath)}" alt="" aria-hidden="true" />ide Docs Explorer</span>` +
    `<span class="app-wordmark-sep" aria-hidden="true">-</span>` +
    `${renderBreadcrumb(state.document.title, docs)}`;
  shell.subtitleEl.textContent = state.document.subtitle;
  shell.rawLinkEl.href = state.document.rawLink;
}

function renderBreadcrumb(path: string, docs: string[]): string {
  const parts = path.split("/").filter(Boolean);
  if (parts.length === 0) return escapeHtml(path);
  return `<span class="doc-breadcrumb">${parts
    .map((part, index) => {
      const prefix = parts.slice(0, index + 1).join("/");
      const label = escapeHtml(part);
      if (index === parts.length - 1) {
        return `<span class="doc-breadcrumb-current">${label}</span>`;
      }
      const target = resolveBreadcrumbTarget(prefix, docs);
      if (!target) {
        return `<span class="doc-breadcrumb-part">${label}</span>`;
      }
      return `<a class="doc-breadcrumb-link" href="#doc=${encodeURIComponent(target)}">${label}</a>`;
    })
    .join(
      '<span class="doc-breadcrumb-sep" aria-hidden="true">/</span>',
    )}</span>`;
}

function resolveBreadcrumbTarget(
  prefix: string,
  docs: string[],
): string | null {
  if (
    prefix === "app_architecture" &&
    docs.includes("app_architecture/APP_LAYERING.md")
  ) {
    return "app_architecture/APP_LAYERING.md";
  }
  const candidates = [
    `${prefix}/README.md`,
    `${prefix}/DESIGN.md`,
    `${prefix}/INDEX.md`,
  ];
  return candidates.find((candidate) => docs.includes(candidate)) ?? null;
}
