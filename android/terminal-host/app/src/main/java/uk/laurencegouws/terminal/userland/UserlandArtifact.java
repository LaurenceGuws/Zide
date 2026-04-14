package uk.laurencegouws.terminal.userland;

/**
 * Parsed artifact contract from the mobile package authority manifest.
 *
 * <p>This package-private value object is used by {@link UserlandInstaller}; it should not grow
 * install behavior or Android UI policy.
 */
final class UserlandArtifact {
    final String manifestSource;
    final String name;
    final String version;
    final String url;
    final String sha256;
    final long size;
    final String archiveRoot;
    final String provider;
    final String hardcodedTermuxPolicy;
    final String runtimeSupportLinks;

    UserlandArtifact(
            String manifestSource,
            String name,
            String version,
            String url,
            String sha256,
            long size,
            String archiveRoot,
            String provider,
            String hardcodedTermuxPolicy,
            String runtimeSupportLinks) {
        this.manifestSource = manifestSource;
        this.name = name;
        this.version = version;
        this.url = url;
        this.sha256 = sha256;
        this.size = size;
        this.archiveRoot = archiveRoot;
        this.provider = provider;
        this.hardcodedTermuxPolicy = hardcodedTermuxPolicy;
        this.runtimeSupportLinks = runtimeSupportLinks;
    }
}
