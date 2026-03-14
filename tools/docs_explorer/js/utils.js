export function escapeHtml(text) {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

export function repoRelative(path) {
  return `../../${path}`;
}

export function currentDocFromHash(docs, defaultDocPath) {
  const hash = new URLSearchParams(location.hash.replace(/^#/, ""));
  const doc = hash.get("doc");
  return docs.includes(doc) ? doc : defaultDocPath;
}
