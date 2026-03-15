const chevronRight = `
<svg viewBox="0 0 20 20" width="10" height="10" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
  <path d="M7 4.5L13 10L7 15.5"/>
</svg>`;

const folderClosed = `
<svg viewBox="0 0 20 20" width="14" height="14" fill="currentColor" aria-hidden="true">
  <path d="M2.5 5.75A1.75 1.75 0 0 1 4.25 4h3.1c.45 0 .87.214 1.135.576L9.3 5.75h6.45a1.75 1.75 0 0 1 1.75 1.75v6.75A1.75 1.75 0 0 1 15.75 16H4.25A1.75 1.75 0 0 1 2.5 14.25V5.75Z"/>
</svg>`;

const folderOpen = `
<svg viewBox="0 0 20 20" width="14" height="14" fill="currentColor" aria-hidden="true">
  <path d="M2.75 6.25A1.75 1.75 0 0 1 4.5 4.5h2.85c.44 0 .86.21 1.125.566l.84 1.134h6.18a1.75 1.75 0 0 1 1.71 2.12l-1.08 5.1A1.75 1.75 0 0 1 14.41 14.8H4.75a1.75 1.75 0 0 1-1.715-1.4L2 8.3a1.75 1.75 0 0 1 1.715-2.05h-.965Z"/>
</svg>`;

export function treeCaretIcon(): string {
  return chevronRight;
}

export function treeFolderIcon(open: boolean): string {
  return open ? folderOpen : folderClosed;
}
