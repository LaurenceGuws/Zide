package uk.laurencegouws.terminal.userland;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.regex.Pattern;

/**
 * Derives Android edge install candidates from {@code zide-pm list-available} stdout.
 *
 * <p><strong>Source of truth:</strong> CLI output lines only — no Java/Android manifest parsing.
 * Under {@code ZIDE_PM_HOST_PLATFORM=android}, {@code zide-pm} is expected to emit a stable,
 * line-oriented catalog; this type applies a conservative token grammar to each line.</p>
 *
 * <p><strong>Selection:</strong> parsed tokens are de-duplicated in first-seen order; the install
 * spec chosen for an explicit user-triggered install is the lexicographically smallest token for
 * deterministic behavior.</p>
 */
public final class UserlandZidePmListAvailableCandidates {
    /** Package id token: alnum first char, then alnum / dot / underscore / plus / hyphen. */
    private static final Pattern PACKAGE_TOKEN = Pattern.compile("^[a-zA-Z0-9][a-zA-Z0-9._+\\-]*$");

    private UserlandZidePmListAvailableCandidates() {
    }

    public static List<String> parseCandidatePackageSpecs(String listAvailableStdout) {
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

    /**
     * Picks one install argument for {@code zide-pm install} from {@code list-available} output.
     *
     * @return empty when no line yields a valid package token
     */
    public static Optional<String> selectLexicographicallyFirstInstallSpec(String listAvailableStdout) {
        final List<String> candidates = parseCandidatePackageSpecs(listAvailableStdout);
        if (candidates.isEmpty()) {
            return Optional.empty();
        }
        return candidates.stream().min(Comparator.naturalOrder());
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
