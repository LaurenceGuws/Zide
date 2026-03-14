import type { MarkedApi } from "./vendor_types.js";

export function configureMarked(marked: MarkedApi): void {
  marked.setOptions({
    gfm: true,
    breaks: false,
    headerIds: true,
    mangle: false,
  });
}
