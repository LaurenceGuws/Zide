declare module "https://cdn.jsdelivr.net/npm/marked/lib/marked.esm.js" {
  import type { MarkedApi } from "./vendor_types.js";
  export const marked: MarkedApi;
}

declare module "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs" {
  import type { MermaidApi } from "./vendor_types.js";
  const mermaid: MermaidApi;
  export default mermaid;
}
