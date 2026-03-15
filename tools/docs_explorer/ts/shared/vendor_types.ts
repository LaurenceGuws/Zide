export type MarkedApi = {
  parse(source: string): string;
  setOptions(options: Record<string, unknown>): void;
};

export type MermaidApi = {
  initialize(config: unknown): void;
  render(id: string, graph: string): Promise<{ svg: string }>;
};

export type HighlightJsApi = {
  highlightElement(element: HTMLElement): void;
  getLanguage(name: string): unknown;
  highlight(code: string, options: { language: string }): { value: string };
  highlightAuto(code: string): { value: string };
};
