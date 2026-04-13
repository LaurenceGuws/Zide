package dev.zide.terminal.input;

import android.content.Context;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.ExtractedText;
import android.view.inputmethod.ExtractedTextRequest;
import android.view.inputmethod.InputConnection;

/**
 * Invisible Android text-editor surface that translates IME and hardware-key events to PTY input.
 *
 * <p>This view owns Android {@link InputConnection} state only. It does not own terminal focus
 * policy, shell refresh, scrollback, or product text rendering.
 */
public final class ShellInputView extends View {
    public interface Host {
        final class ModifierLatchState {
            public final boolean ctrlLatched;
            public final boolean altLatched;

            ModifierLatchState(boolean ctrlLatched, boolean altLatched) {
                this.ctrlLatched = ctrlLatched;
                this.altLatched = altLatched;
            }
        }

        void sendDirectText(String text);

        void sendDirectCodepoint(int codepoint);

        void onInputFocusChanged(boolean hasFocus);

        void onModifierLatchChanged(ModifierLatchState state);
    }

    private static final String SENTINEL = "........";

    public enum ModifierLatch {
        CTRL,
        ALT,
    }

    private final Host host;
    private final StringBuilder editorBuffer = new StringBuilder();
    private int editorCursor = 0;
    private int editorComposingStart = -1;
    private int editorComposingEnd = -1;
    private boolean ctrlLatched = false;
    private boolean altLatched = false;
    private String suppressedCommitText = null;

    public ShellInputView(Context context, Host host) {
        super(context);
        this.host = host;
        setFocusable(true);
        setFocusableInTouchMode(true);
        setOnFocusChangeListener((view, hasFocus) -> {
            if (hasFocus) {
                resetEditorState();
            } else {
                editorComposingStart = -1;
                editorComposingEnd = -1;
                clearLatchedModifiers();
            }
            host.onInputFocusChanged(hasFocus);
        });
        resetEditorState();
        notifyModifierLatchChanged();
    }

    @Override
    public boolean onCheckIsTextEditor() {
        return true;
    }

    @Override
    public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
        outAttrs.inputType = EditorInfo.TYPE_CLASS_TEXT
                | EditorInfo.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                | EditorInfo.TYPE_TEXT_FLAG_MULTI_LINE;
        outAttrs.imeOptions = EditorInfo.IME_FLAG_NO_EXTRACT_UI
                | EditorInfo.IME_FLAG_NO_FULLSCREEN
                | EditorInfo.IME_ACTION_NONE;
        outAttrs.initialSelStart = editorCursor;
        outAttrs.initialSelEnd = editorCursor;
        return new BaseInputConnection(this, false) {
            @Override
            public ExtractedText getExtractedText(ExtractedTextRequest request, int flags) {
                final ExtractedText et = new ExtractedText();
                et.text = editorBuffer.toString();
                et.startOffset = 0;
                et.selectionStart = editorCursor;
                et.selectionEnd = editorCursor;
                return et;
            }

            @Override
            public CharSequence getTextBeforeCursor(int n, int flags) {
                final int start = Math.max(0, editorCursor - n);
                return editorBuffer.substring(start, editorCursor);
            }

            @Override
            public CharSequence getTextAfterCursor(int n, int flags) {
                final int end = Math.min(editorBuffer.length(), editorCursor + n);
                return editorBuffer.substring(editorCursor, end);
            }

            @Override
            public boolean setSelection(int start, int end) {
                final int oldCursor = editorCursor;
                final int newCursor = Math.max(0, Math.min(start, editorBuffer.length()));
                if (newCursor == oldCursor)
                    return true;

                final int from = Math.min(oldCursor, newCursor);
                final int to = Math.max(oldCursor, newCursor);
                int newlinesCrossed = 0;
                for (int i = from; i < to; i++) {
                    if (editorBuffer.charAt(i) == '\n')
                        newlinesCrossed++;
                }

                if (newlinesCrossed > 0) {
                    final String esc = (newCursor < oldCursor) ? "\u001b[A" : "\u001b[B";
                    for (int i = 0; i < newlinesCrossed; i++) {
                        host.sendDirectText(esc);
                    }
                } else {
                    final int delta = newCursor - oldCursor;
                    final String esc = (delta < 0) ? "\u001b[D" : "\u001b[C";
                    final int count = Math.abs(delta);
                    for (int i = 0; i < count; i++) {
                        host.sendDirectText(esc);
                    }
                }

                resetEditorState();
                return true;
            }

            @Override
            public boolean setComposingText(CharSequence text, int newCursorPosition) {
                final String s = text.toString();
                if (consumeLatchedImeText(s)) {
                    return true;
                }
                replaceComposition(s);
                return true;
            }

            @Override
            public boolean finishComposingText() {
                editorComposingStart = -1;
                editorComposingEnd = -1;
                return true;
            }

            @Override
            public boolean commitText(CharSequence text, int newCursorPosition) {
                final String s = text.toString();
                if (suppressedCommitText != null && suppressedCommitText.equals(s)) {
                    suppressedCommitText = null;
                    return true;
                }
                if (consumeLatchedImeText(s)) {
                    return true;
                }
                final String previous = currentCompositionText();
                if (editorComposingStart >= 0) {
                    replaceComposition(s);
                    editorComposingStart = -1;
                    editorComposingEnd = -1;
                } else {
                    editorBuffer.insert(editorCursor, s);
                    editorCursor += s.length();
                    host.sendDirectText(s);
                }
                if (previous.equals(s)) {
                    editorComposingStart = -1;
                    editorComposingEnd = -1;
                }
                return true;
            }

            @Override
            public boolean deleteSurroundingText(int beforeLength, int afterLength) {
                if (beforeLength > 0) {
                    final int delStart = Math.max(0, editorCursor - beforeLength);
                    final int count = editorCursor - delStart;
                    editorBuffer.delete(delStart, editorCursor);
                    editorCursor = delStart;
                    for (int i = 0; i < count; i++) {
                        host.sendDirectCodepoint('\u007f');
                    }
                }
                if (afterLength > 0) {
                    final int delEnd = Math.min(editorBuffer.length(), editorCursor + afterLength);
                    editorBuffer.delete(editorCursor, delEnd);
                }
                return true;
            }

            @Override
            public boolean sendKeyEvent(KeyEvent event) {
                if (handleTerminalKeyEvent(event)) {
                    return true;
                }
                return super.sendKeyEvent(event);
            }
        };
    }

    public boolean handleHardwareKeyEvent(KeyEvent event) {
        return handleTerminalKeyEvent(event);
    }

    public void toggleModifierLatch(ModifierLatch modifier) {
        switch (modifier) {
            case CTRL:
                ctrlLatched = !ctrlLatched;
                break;
            case ALT:
                altLatched = !altLatched;
                break;
        }
        notifyModifierLatchChanged();
    }

    public Host.ModifierLatchState modifierLatchState() {
        return new Host.ModifierLatchState(ctrlLatched, altLatched);
    }

    private void resetEditorState() {
        editorBuffer.setLength(0);
        editorBuffer.append(SENTINEL).append('\n').append(SENTINEL).append('\n').append(SENTINEL);
        editorCursor = SENTINEL.length() + 1;
        editorComposingStart = -1;
        editorComposingEnd = -1;
    }

    private int editorLineStart() {
        int i = editorCursor - 1;
        while (i >= 0 && editorBuffer.charAt(i) != '\n')
            i--;
        return i + 1;
    }

    private String currentCompositionText() {
        if (editorComposingStart >= 0 && editorComposingEnd >= editorComposingStart) {
            return editorBuffer.substring(editorComposingStart, editorComposingEnd);
        }
        return "";
    }

    private void replaceComposition(String next) {
        final String previous = currentCompositionText();
        final int composeStart = editorComposingStart >= 0 ? editorComposingStart : editorCursor;
        final int oldEnd = editorComposingEnd >= editorComposingStart && editorComposingStart >= 0 ? editorComposingEnd
                : editorCursor;

        int commonPrefix = 0;
        final int maxPrefix = Math.min(previous.length(), next.length());
        while (commonPrefix < maxPrefix && previous.charAt(commonPrefix) == next.charAt(commonPrefix)) {
            commonPrefix += 1;
        }

        final int removed = previous.length() - commonPrefix;
        for (int i = 0; i < removed; i++) {
            host.sendDirectCodepoint('\u007f');
        }

        final String appended = next.substring(commonPrefix);
        if (!appended.isEmpty()) {
            host.sendDirectText(appended);
        }

        editorBuffer.delete(composeStart, oldEnd);
        editorBuffer.insert(composeStart, next);
        editorComposingStart = composeStart;
        editorComposingEnd = composeStart + next.length();
        editorCursor = editorComposingEnd;
        if (next.isEmpty()) {
            editorComposingStart = -1;
            editorComposingEnd = -1;
        }
    }

    private String mapKeyToEscape(int keyCode) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_DPAD_UP:
                return "\u001b[A";
            case KeyEvent.KEYCODE_DPAD_DOWN:
                return "\u001b[B";
            case KeyEvent.KEYCODE_DPAD_RIGHT:
                return "\u001b[C";
            case KeyEvent.KEYCODE_DPAD_LEFT:
                return "\u001b[D";
            case KeyEvent.KEYCODE_MOVE_HOME:
                return "\u001b[H";
            case KeyEvent.KEYCODE_MOVE_END:
                return "\u001b[F";
            case KeyEvent.KEYCODE_INSERT:
                return "\u001b[2~";
            case KeyEvent.KEYCODE_FORWARD_DEL:
                return "\u001b[3~";
            case KeyEvent.KEYCODE_PAGE_UP:
                return "\u001b[5~";
            case KeyEvent.KEYCODE_PAGE_DOWN:
                return "\u001b[6~";
            default:
                return null;
        }
    }

    private Integer mapKeyToControlCodepoint(KeyEvent event, boolean ctrlActive) {
        if (!ctrlActive) {
            return null;
        }
        final int unicode = event.getUnicodeChar(KeyEvent.META_CTRL_ON);
        if (unicode != 0) {
            final Integer mapped = mapCodepointToControlCodepoint(unicode);
            if (mapped != null) {
                return mapped;
            }
        }
        switch (event.getKeyCode()) {
            case KeyEvent.KEYCODE_A:
                return 0x01;
            case KeyEvent.KEYCODE_B:
                return 0x02;
            case KeyEvent.KEYCODE_C:
                return 0x03;
            case KeyEvent.KEYCODE_D:
                return 0x04;
            case KeyEvent.KEYCODE_E:
                return 0x05;
            case KeyEvent.KEYCODE_F:
                return 0x06;
            case KeyEvent.KEYCODE_G:
                return 0x07;
            case KeyEvent.KEYCODE_H:
                return 0x08;
            case KeyEvent.KEYCODE_I:
                return 0x09;
            case KeyEvent.KEYCODE_J:
                return 0x0a;
            case KeyEvent.KEYCODE_K:
                return 0x0b;
            case KeyEvent.KEYCODE_L:
                return 0x0c;
            case KeyEvent.KEYCODE_M:
                return 0x0d;
            case KeyEvent.KEYCODE_N:
                return 0x0e;
            case KeyEvent.KEYCODE_O:
                return 0x0f;
            case KeyEvent.KEYCODE_P:
                return 0x10;
            case KeyEvent.KEYCODE_Q:
                return 0x11;
            case KeyEvent.KEYCODE_R:
                return 0x12;
            case KeyEvent.KEYCODE_S:
                return 0x13;
            case KeyEvent.KEYCODE_T:
                return 0x14;
            case KeyEvent.KEYCODE_U:
                return 0x15;
            case KeyEvent.KEYCODE_V:
                return 0x16;
            case KeyEvent.KEYCODE_W:
                return 0x17;
            case KeyEvent.KEYCODE_X:
                return 0x18;
            case KeyEvent.KEYCODE_Y:
                return 0x19;
            case KeyEvent.KEYCODE_Z:
                return 0x1a;
            case KeyEvent.KEYCODE_LEFT_BRACKET:
                return 0x1b;
            case KeyEvent.KEYCODE_BACKSLASH:
                return 0x1c;
            case KeyEvent.KEYCODE_RIGHT_BRACKET:
                return 0x1d;
            case KeyEvent.KEYCODE_6:
                return 0x1e;
            case KeyEvent.KEYCODE_MINUS:
            case KeyEvent.KEYCODE_SLASH:
                return 0x1f;
            case KeyEvent.KEYCODE_SPACE:
            case KeyEvent.KEYCODE_2:
                return 0x00;
            default:
                return null;
        }
    }

    private Integer mapCodepointToControlCodepoint(int codepoint) {
        if (codepoint >= 'a' && codepoint <= 'z') {
            return codepoint - 'a' + 1;
        }
        if (codepoint >= 'A' && codepoint <= 'Z') {
            return codepoint - 'A' + 1;
        }
        switch (codepoint) {
            case '[':
                return 0x1b;
            case '\\':
                return 0x1c;
            case ']':
                return 0x1d;
            case '6':
                return 0x1e;
            case '-':
            case '/':
                return 0x1f;
            case ' ':
            case '2':
                return 0x00;
            default:
                return null;
        }
    }

    private boolean consumeLatchedImeText(String text) {
        if ((!ctrlLatched && !altLatched) || text.isEmpty()) {
            return false;
        }
        final int firstCodepoint = text.codePointAt(0);
        final int firstCodepointLength = Character.charCount(firstCodepoint);
        if (altLatched) {
            host.sendDirectCodepoint('\u001b');
        }
        if (ctrlLatched) {
            final Integer controlCodepoint = mapCodepointToControlCodepoint(firstCodepoint);
            if (controlCodepoint != null) {
                host.sendDirectCodepoint(controlCodepoint);
            } else {
                host.sendDirectCodepoint(firstCodepoint);
            }
        } else {
            host.sendDirectCodepoint(firstCodepoint);
        }
        if (firstCodepointLength < text.length()) {
            host.sendDirectText(text.substring(firstCodepointLength));
        }
        suppressedCommitText = text;
        resetEditorState();
        clearLatchedModifiers();
        return true;
    }

    private void clearLatchedModifiers() {
        if (!ctrlLatched && !altLatched) {
            return;
        }
        ctrlLatched = false;
        altLatched = false;
        notifyModifierLatchChanged();
    }

    private void notifyModifierLatchChanged() {
        host.onModifierLatchChanged(modifierLatchState());
    }

    private boolean handleTerminalKeyEvent(KeyEvent event) {
        if (event.getAction() != KeyEvent.ACTION_DOWN) {
            return false;
        }
        final boolean ctrlActive = event.isCtrlPressed() || ctrlLatched;
        final boolean altActive = event.isAltPressed() || altLatched;
        final boolean latchedModifiersConsumed = ctrlLatched || altLatched;
        final Integer controlCodepoint = mapKeyToControlCodepoint(event, ctrlActive);
        if (controlCodepoint != null) {
            if (altActive) {
                host.sendDirectCodepoint('\u001b');
            }
            host.sendDirectCodepoint(controlCodepoint);
            if (latchedModifiersConsumed) {
                clearLatchedModifiers();
            }
            return true;
        }
        final String esc = mapKeyToEscape(event.getKeyCode());
        if (esc != null) {
            if (altActive) {
                host.sendDirectCodepoint('\u001b');
            }
            host.sendDirectText(esc);
            if (latchedModifiersConsumed) {
                clearLatchedModifiers();
            }
            return true;
        }
        switch (event.getKeyCode()) {
            case KeyEvent.KEYCODE_DEL:
                host.sendDirectCodepoint('\u007f');
                if (editorCursor > editorLineStart()) {
                    editorBuffer.deleteCharAt(editorCursor - 1);
                    editorCursor--;
                }
                return true;
            case KeyEvent.KEYCODE_ENTER:
            case KeyEvent.KEYCODE_NUMPAD_ENTER:
                host.sendDirectCodepoint('\n');
                resetEditorState();
                return true;
            case KeyEvent.KEYCODE_TAB:
                host.sendDirectCodepoint('\t');
                return true;
            case KeyEvent.KEYCODE_ESCAPE:
                host.sendDirectCodepoint('\u001b');
                return true;
            default:
                final int unicode = event.getUnicodeChar();
                if (unicode == 0 || Character.isISOControl(unicode)) {
                    return false;
                }
                final String text = new String(Character.toChars(unicode));
                if (altActive) {
                    host.sendDirectCodepoint('\u001b');
                }
                if (ctrlActive) {
                    final Integer mapped = mapCodepointToControlCodepoint(unicode);
                    if (mapped != null) {
                        host.sendDirectCodepoint(mapped);
                    } else {
                        host.sendDirectText(text);
                    }
                } else {
                    editorBuffer.insert(editorCursor, text);
                    editorCursor += text.length();
                    host.sendDirectText(text);
                }
                if (latchedModifiersConsumed) {
                    clearLatchedModifiers();
                }
                return true;
        }
    }
}
