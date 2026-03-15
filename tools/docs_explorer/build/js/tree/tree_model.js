export function buildTreeModel(paths) {
    const root = { name: "", path: "", dirs: new Map(), files: [] };
    for (const path of paths) {
        const parts = path.split("/");
        let node = root;
        let current = "";
        for (let i = 0; i < parts.length; i += 1) {
            const part = parts[i];
            current = current ? `${current}/${part}` : part;
            const isFile = i === parts.length - 1;
            if (isFile) {
                node.files.push({
                    path,
                    label: part,
                    detail: parts.slice(0, -1).join("/"),
                });
            }
            else {
                if (!node.dirs.has(part)) {
                    node.dirs.set(part, {
                        name: part,
                        path: current,
                        dirs: new Map(),
                        files: [],
                    });
                }
                node = node.dirs.get(part);
            }
        }
    }
    return root;
}
