function matchesZide(window) {
    const resourceClass = (window.resourceClass || '').toString().toLowerCase();
    const desktopFileName = (window.desktopFileName || '').toString().toLowerCase();
    const resourceName = (window.resourceName || '').toString().toLowerCase();
    return resourceClass === 'laurenceguws.zide.terminal' ||
        desktopFileName === 'laurenceguws.zide.terminal' ||
        resourceName === 'zide-terminal' ||
        resourceClass === 'zide-terminal';
}

for (const window of workspace.windowList()) {
    if (!window || !window.normalWindow) continue;
    if (!matchesZide(window)) continue;
    const area = workspace.clientArea(KWin.MaximizeArea, window);
    window.setMaximize(true, true);
    window.frameGeometry = area;
    console.info('kwin-zide-one-shot: geometry ' + area.x + ',' + area.y + ' ' + area.width + 'x' + area.height + ' :: ' + [window.resourceClass, window.resourceName, window.caption, window.desktopFileName].join(' | '));
}
