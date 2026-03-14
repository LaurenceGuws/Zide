export type MarkedApi = {
  parse(source: string): string;
  setOptions(options: Record<string, unknown>): void;
};

export type MermaidApi = {
  initialize(config: unknown): void;
  render(id: string, graph: string): Promise<{ svg: string }>;
};
