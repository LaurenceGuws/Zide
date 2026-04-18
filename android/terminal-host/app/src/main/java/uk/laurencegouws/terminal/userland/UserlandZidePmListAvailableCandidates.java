package uk.laurencegouws.terminal.userland;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.regex.Pattern;

/**
 * Derives Android <strong>edge</strong> install candidates from {@code zide-pm list-available} stdout.
 *
 * <p><strong>Source of truth:</strong> CLI output lines only — no Java/Android manifest parsing.
 * Edge install considers only package ids with the {@link #ANDROID_EDGE_PREFIX} prefix (case-insensitive
 * match on that literal) so generic catalog rows (for example {@code dev-baseline}, {@code jq}) are
 * rejected for this flow.</p>
 *
 * <p><strong>Selection:</strong> among eligible {@code zide-android-*} ids, the install spec is the
 * lexicographically smallest token (deterministic).</p>
 */
public final class UserlandZidePmListAvailableCandidates {
    /** Prefix for Android edge test-binary rows emitted under {@code ZIDE_PM_HOST_PLATFORM=android}. */
    public static final String ANDROID_EDGE_PREFIX = "zide-android-";

    /** Package id token: alnum first char, then alnum / dot / underscore / plus / hyphen. */
    private static final Pattern PACKAGE_TOKEN = Pattern.compile("^[a-zA-Z0-9][a-zA-Z0-9._+\\-]*$");

    private UserlandZidePmListAvailableCandidates() {
    }

    /**
     * First-column package tokens from {@code list-available} that pass the generic token grammar
     * (includes non-edge ids such as baseline tools — for diagnostics vs edge filtering).
     */
    public static List<String> parseAllFirstColumnPackageTokens(String listAvailableStdout) {
        final LinkedHashSet<String> orderedUnique = new LinkedHashSet<>();
        if (listAvailableStdout == null) {
            return new ArrayList<>();
        }
        for (String rawLine : listAvailableStdout.split("\\R")) {
            final String line = rawLine.trim();
            if (line.isEmpty() || line.startsWith("#")) {
                continue;
            }
            if (isHeaderOrNoiseLine(line)) {
                continue;
            }
            final String token = firstWhitespaceToken(line);
            if (token.isEmpty() || !PACKAGE_TOKEN.matcher(token).matches()) {
                continue;
            }
            orderedUnique.add(token);
        }
        return new ArrayList<>(orderedUnique);
    }

    /** Android edge candidates only ({@code zide-android-*}). */
    public static List<String> parseAndroidEdgeCandidatePackageSpecs(String listAvailableStdout) {
        final List<String> out = new ArrayList<>();
        for (String t : parseAllFirstColumnPackageTokens(listAvailableStdout)) {
            if (isAndroidEdgePackageId(t)) {
                out.add(t);
            }
        }
        return out;
    }

    /**
     * Lexicographically first {@code zide-android-*} spec, if any.
     *
     * @return empty when no line yields an Android edge id
     */
    public static Optional<String> selectLexicographicallyFirstInstallSpec(String listAvailableStdout) {
        final List<String> candidates = parseAndroidEdgeCandidatePackageSpecs(listAvailableStdout);
        if (candidates.isEmpty()) {
            return Optional.empty();
        }
        return candidates.stream().min(Comparator.naturalOrder());
    }

    static boolean isAndroidEdgePackageId(String token) {
        if (token == null) {
            return false;
        }
        return token.length() > ANDROID_EDGE_PREFIX.length()
                && token.regionMatches(true, 0, ANDROID_EDGE_PREFIX, 0, ANDROID_EDGE_PREFIX.length());
    }

    private static String firstWhitespaceToken(String line) {
        final int end = line.length();
        int i = 0;
        while (i < end && Character.isWhitespace(line.charAt(i))) {
            i++;
        }
        if (i >= end) {
            return "";
        }
        int j = i;
        while (j < end && !Character.isWhitespace(line.charAt(j))) {
            j++;
        }
        return line.substring(i, j);
    }

    private static boolean isHeaderOrNoiseLine(String line) {
        final String lower = line.toLowerCase(Locale.ROOT);
        if (lower.startsWith("warning:")
                || lower.startsWith("error:")
                || lower.startsWith("note:")
                || lower.startsWith("info:")) {
            return true;
        }
        final String first = firstWhitespaceToken(line);
        if (first.isEmpty()) {
            return true;
        }
        final String fl = first.toLowerCase(Locale.ROOT);
        if (fl.equals("package") || fl.equals("name") || fl.equals("packages") || fl.equals("available")) {
            return true;
        }
        if (line.chars().allMatch(c -> c == '-' || c == '=' || c == '_' || Character.isWhitespace(c))) {
            return true;
        }
        return false;
    }
}
