package dev.zide.terminal;

import android.content.Context;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import org.json.JSONException;
import org.json.JSONObject;

final class UserlandRelease {
    private static final String ASSET_NAME = "userland_release.json";

    final String manifestUrl;
    final String artifactName;
    final String artifactVersion;
    final String provider;

    UserlandRelease(String manifestUrl, String artifactName, String artifactVersion, String provider) {
        this.manifestUrl = manifestUrl;
        this.artifactName = artifactName;
        this.artifactVersion = artifactVersion;
        this.provider = provider;
    }

    static UserlandRelease load(Context context) throws IOException {
        try (InputStream in = context.getAssets().open(ASSET_NAME); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            final byte[] buffer = new byte[4096];
            while (true) {
                final int read = in.read(buffer);
                if (read < 0) {
                    break;
                }
                out.write(buffer, 0, read);
            }
            final JSONObject doc = new JSONObject(out.toString(StandardCharsets.UTF_8.name()));
            final String manifestUrl = doc.optString("manifest_url", "");
            final String artifactName = doc.optString("artifact_name", "");
            final String artifactVersion = doc.optString("artifact_version", "");
            final String provider = doc.optString("provider", "");
            if (manifestUrl.isEmpty() || artifactName.isEmpty() || artifactVersion.isEmpty() || provider.isEmpty()) {
                throw new IOException("userland release asset missing required fields");
            }
            return new UserlandRelease(manifestUrl, artifactName, artifactVersion, provider);
        } catch (JSONException err) {
            throw new IOException("invalid userland release asset json", err);
        }
    }
}
