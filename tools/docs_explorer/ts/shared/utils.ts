export function escapeHtml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

export function repoRelative(basePath: string, path: string): string {
  return `${basePath}${path}`;
}

export function currentDocFromHash(
  docs: string[],
  defaultDocPath: string,
): string {
  const hash = new URLSearchParams(location.hash.replace(/^#/, ""));
  const doc = hash.get("doc");
  return doc && docs.includes(doc) ? doc : defaultDocPath;
}

export function currentFindFromHash(): string {
  const hash = new URLSearchParams(location.hash.replace(/^#/, ""));
  return hash.get("find") ?? "";
}

export function docHash(path: string, find = ""): string {
  const hash = new URLSearchParams();
  hash.set("doc", path);
  if (find) hash.set("find", find);
  return `#${hash.toString()}`;
}
