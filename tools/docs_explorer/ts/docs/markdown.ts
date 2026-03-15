import type { MarkedApi } from "../shared/vendor_types.js";

export function configureMarked(marked: MarkedApi): void {
  marked.setOptions({
    gfm: true,
    breaks: false,
    headerIds: true,
    mangle: false,
  });
}

function isExternalUrl(value: string): boolean {
  return /^(?:[a-z]+:|\/\/|#)/i.test(value);
}

function isRepoAbsolutePath(value: string, repoAbsolutePath?: string): boolean {
  return !!repoAbsolutePath && value.startsWith(`${repoAbsolutePath}/`);
}

function isDocPath(path: string): boolean {
  return path.endsWith(".md") || path.endsWith(".yaml");
}

function normalizeRepoPath(path: string): string {
  const parts = path.split("/");
  const normalized: string[] = [];

  for (const part of parts) {
    if (!part || part === ".") continue;
    if (part === "..") {
      normalized.pop();
      continue;
    }
    normalized.push(part);
  }

  return normalized.join("/");
}

function resolveDocRelativePath(docPath: string, assetPath: string): string {
  const docDirParts = docPath.split("/").slice(0, -1);
  const combined = [...docDirParts, ...assetPath.split("/")].join("/");
  return normalizeRepoPath(combined);
}

function asDocHash(path: string): string {
  return `#doc=${encodeURIComponent(path)}`;
}

function rewriteMediaUrls(
  html: string,
  docPath: string,
  repoBasePath: string,
  docs: string[],
  repoAbsolutePath?: string,
): string {
  const template = document.createElement("template");
  template.innerHTML = html;

  const selectors: Array<[string, string]> = [
    ["a[href]", "href"],
    ["img[src]", "src"],
    ["video[src]", "src"],
    ["video[poster]", "poster"],
    ["source[src]", "src"],
  ];

  for (const [selector, attribute] of selectors) {
    const elements = template.content.querySelectorAll<HTMLElement>(selector);
    elements.forEach((el) => {
      const raw = el.getAttribute(attribute);
      if (!raw) return;
      if (isRepoAbsolutePath(raw, repoAbsolutePath)) {
        const relative = raw.slice(repoAbsolutePath!.length + 1);
        if (
          attribute === "href" &&
          isDocPath(relative) &&
          docs.includes(relative)
        ) {
          el.setAttribute(attribute, asDocHash(relative));
        } else {
          el.setAttribute(attribute, `${repoBasePath}${relative}`);
        }
        return;
      }
      if (isExternalUrl(raw)) return;
      const resolved = resolveDocRelativePath(docPath, raw);
      if (
        attribute === "href" &&
        isDocPath(resolved) &&
        docs.includes(resolved)
      ) {
        el.setAttribute(attribute, asDocHash(resolved));
      } else {
        el.setAttribute(attribute, `${repoBasePath}${resolved}`);
      }
    });
  }

  return template.innerHTML;
}

export function renderMarkdown(
  marked: MarkedApi,
  source: string,
  docPath: string,
  repoBasePath: string,
  docs: string[],
  repoAbsolutePath?: string,
): string {
  const html = marked.parse(source);
  return rewriteMediaUrls(html, docPath, repoBasePath, docs, repoAbsolutePath);
}
