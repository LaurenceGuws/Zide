package dev.zide.terminal.userland;

import android.content.Context;
import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Map;

/** Runs userland package commands against the app-private prefix. */
public final class UserlandCommandRunner {
    private UserlandCommandRunner() {
    }

    public static String runZidePm(Context context, String processName, String... args) throws IOException {
        final String binaryPath = UserlandPolicy.prefixPath(context) + "/bin/zide-pm";
        final ProcessBuilder builder = new ProcessBuilder();
        final java.util.ArrayList<String> command = new java.util.ArrayList<>();
        command.add(binaryPath);
        for (String arg : args) {
            command.add(arg);
        }
        builder.command(command);
        builder.directory(context.getFilesDir());
        builder.redirectErrorStream(true);
        final Map<String, String> env = builder.environment();
        env.put("PREFIX", UserlandPolicy.prefixPath(context));
        env.put("HOME", new File(context.getFilesDir(), "home").getAbsolutePath());
        env.put("TMPDIR", new File(context.getFilesDir().getParentFile(), "tmp").getAbsolutePath());
        env.put("PATH", UserlandPolicy.prefixPath(context) + "/bin:/system/bin");
        env.put("SHELL", UserlandPolicy.shellPath(context));
        env.put("LD_LIBRARY_PATH", UserlandPolicy.prefixPath(context) + "/lib");
        final Process process = builder.start();
        final String output;
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
            final StringBuilder out = new StringBuilder();
            String line;
            boolean first = true;
            while ((line = reader.readLine()) != null) {
                if (!first) {
                    out.append('\n');
                }
                out.append(line);
                first = false;
            }
            output = out.toString();
        }
        final int exitCode;
        try {
            exitCode = process.waitFor();
        } catch (InterruptedException err) {
            Thread.currentThread().interrupt();
            throw new IOException("interrupted while running " + processName, err);
        }
        if (exitCode != 0) {
            throw new IOException(processName + " exit=" + exitCode + " output=" + output);
        }
        return output;
    }
}
