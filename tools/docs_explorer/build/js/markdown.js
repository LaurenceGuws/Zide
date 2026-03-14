export function configureMarked(marked) {
    marked.setOptions({
        gfm: true,
        breaks: false,
        headerIds: true,
        mangle: false,
    });
}
