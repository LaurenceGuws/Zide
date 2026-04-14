package dev.zide.terminal.host.runtime;

import android.content.Context;

import dev.zide.terminal.userland.UserlandRelease;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

/** Owns runtime asset staging and userland release loading for the Android host. */
public final class RuntimeAssetsController {
    /** Host callbacks for staging and logging. */
    public interface Host {
        Context context();

        void appendEvent(String event);
    }

    private static final String[] RUNTIME_FONT_ASSETS = {
            "IosevkaTermNerdFont-Regular.ttf",
            "JetBrainsMonoNerdFont-Regular.ttf",
            "NotoColorEmoji.ttf",
            "NotoEmoji-Regular.ttf",
            "NotoSans-Regular.ttf",
            "NotoSansMono-Regular.ttf",
            "NotoSansSymbols-Regular.ttf",
            "NotoSansSymbols2-Regular.ttf",
            "SymbolsNerdFontMono-Regular.ttf",
    };

    private final Host host;

    public RuntimeAssetsController(Host host) {
        this.host = host;
    }

    public void prepareRuntimeAssets() {
        final File runtimeRoot = host.context().getFilesDir();
        final File fontsDir = new File(new File(runtimeRoot, "assets"), "fonts");
        if (!fontsDir.isDirectory() && !fontsDir.mkdirs()) {
            host.appendEvent("runtime.assets mkdirFailed path=" + fontsDir.getAbsolutePath());
            return;
        }

        final long assetStamp = currentPackageAssetStamp();
        final File stampFile = new File(fontsDir, ".stamp");
        final String expectedStamp = Long.toString(assetStamp);
        final String currentStamp = readTextFile(stampFile);
        if (!expectedStamp.equals(currentStamp)) {
            for (String assetName : RUNTIME_FONT_ASSETS) {
                try {
                    copyAssetToFile(assetName, new File(fontsDir, assetName));
                } catch (IOException err) {
                    host.appendEvent("runtime.assets copyFailed asset=" + assetName + " err=" + err.getClass().getSimpleName());
                    return;
                }
            }
            writeTextFile(stampFile, expectedStamp);
            host.appendEvent("runtime.assets refreshed stamp=" + expectedStamp);
        } else {
            host.appendEvent("runtime.assets reused stamp=" + expectedStamp);
        }

        host.appendEvent("runtime.assets ready path=" + fontsDir.getAbsolutePath());
    }

    public UserlandRelease loadUserlandRelease() {
        try {
            return UserlandRelease.load(host.context());
        } catch (IOException err) {
            host.appendEvent("userland.release loadFailed err=" + err.getClass().getSimpleName());
            return new UserlandRelease("", "", "", "");
        }
    }

    public long currentPackageAssetStamp() {
        try {
            return host.context().getPackageManager().getPackageInfo(host.context().getPackageName(), 0).lastUpdateTime;
        } catch (Exception err) {
            return 0L;
        }
    }

    private static String readTextFile(File file) {
        if (!file.isFile()) {
            return "";
        }
        try (FileInputStream in = new FileInputStream(file)) {
            final ByteArrayOutputStream out = new ByteArrayOutputStream();
            final byte[] buffer = new byte[256];
            while (true) {
                final int read = in.read(buffer);
                if (read < 0) {
                    break;
                }
                out.write(buffer, 0, read);
            }
            return out.toString().trim();
        } catch (IOException err) {
            return "";
        }
    }

    private void writeTextFile(File file, String text) {
        try (FileOutputStream out = new FileOutputStream(file, false)) {
            out.write(text.getBytes());
            out.getFD().sync();
        } catch (IOException err) {
            host.appendEvent("runtime.assets stampWriteFailed err=" + err.getClass().getSimpleName());
        }
    }

    private void copyAssetToFile(String assetName, File destination) throws IOException {
        try (InputStream in = host.context().getAssets().open(assetName);
                FileOutputStream out = new FileOutputStream(destination, false)) {
            final byte[] buffer = new byte[8192];
            while (true) {
                final int read = in.read(buffer);
                if (read < 0) {
                    break;
                }
                out.write(buffer, 0, read);
            }
            out.getFD().sync();
        }
    }
}
