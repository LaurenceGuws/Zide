declare global {
  interface Window {
    hljs?: import("./vendor_types.js").HighlightJsApi;
  }
}

export {};
