package dev.zide.androidbootstrap;

import android.content.Context;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.ExtractedText;
import android.view.inputmethod.ExtractedTextRequest;
import android.view.inputmethod.InputConnection;

final class ShellInputView extends View {
    interface Host {
        void appendEvent(String message);

        void sendDirectText(String text);

        void sendDirectCodepoint(int codepoint);

        void refreshShellState();
    }

    private static final String SENTINEL = "........";

    private final Host host;
    private final StringBuilder editorBuffer = new StringBuilder();
    private int editorCursor = 0;
    private int editorComposingStart = -1;
    private int editorComposingEnd = -1;

    ShellInputView(Context context, Host host) {
        super(context);
        this.host = host;
        setFocusable(true);
        setFocusableInTouchMode(true);
        resetEditorState();
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
                if (newCursor == oldCursor) return true;

                final int from = Math.min(oldCursor, newCursor);
                final int to = Math.max(oldCursor, newCursor);
                int newlinesCrossed = 0;
                for (int i = from; i < to; i++) {
                    if (editorBuffer.charAt(i) == '\n') newlinesCrossed++;
                }

                if (newlinesCrossed > 0) {
                    final String esc = (newCursor < oldCursor) ? "\u001b[A" : "\u001b[B";
                    for (int i = 0; i < newlinesCrossed; i++) {
                        host.sendDirectText(esc);
                    }
                    host.appendEvent("input.nav " + (newCursor < oldCursor ? "up" : "down") + " x" + newlinesCrossed);
                } else {
                    final int delta = newCursor - oldCursor;
                    final String esc = (delta < 0) ? "\u001b[D" : "\u001b[C";
                    final int count = Math.abs(delta);
                    for (int i = 0; i < count; i++) {
                        host.sendDirectText(esc);
                    }
                    host.appendEvent("input.nav " + (delta < 0 ? "left" : "right") + " x" + count);
                }

                resetEditorState();
                host.refreshShellState();
                return true;
            }

            @Override
            public boolean setComposingText(CharSequence text, int newCursorPosition) {
                if (editorComposingStart >= 0 && editorComposingEnd > editorComposingStart) {
                    final int len = editorComposingEnd - editorComposingStart;
                    editorBuffer.delete(editorComposingStart, editorComposingEnd);
                    editorCursor = editorComposingStart;
                    for (int i = 0; i < len; i++) {
                        host.sendDirectCodepoint('\u007f');
                    }
                }

                final String s = text.toString();
                if (s.length() > 0) {
                    editorBuffer.insert(editorCursor, s);
                    editorComposingStart = editorCursor;
                    editorCursor += s.length();
                    editorComposingEnd = editorCursor;
                    host.sendDirectText(s);
                } else {
                    editorComposingStart = -1;
                    editorComposingEnd = -1;
                }
                host.appendEvent("input.compose len=" + s.length());
                host.refreshShellState();
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
                if (editorComposingStart >= 0 && editorComposingEnd > editorComposingStart) {
                    final int len = editorComposingEnd - editorComposingStart;
                    editorBuffer.delete(editorComposingStart, editorComposingEnd);
                    editorCursor = editorComposingStart;
                    for (int i = 0; i < len; i++) {
                        host.sendDirectCodepoint('\u007f');
                    }
                }
                editorComposingStart = -1;
                editorComposingEnd = -1;

                final String s = text.toString();
                editorBuffer.insert(editorCursor, s);
                editorCursor += s.length();
                host.sendDirectText(s);
                host.appendEvent("input.commit text=" + text);
                host.refreshShellState();
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
                    host.appendEvent("input.delete before=" + count);
                }
                if (afterLength > 0) {
                    final int delEnd = Math.min(editorBuffer.length(), editorCursor + afterLength);
                    editorBuffer.delete(editorCursor, delEnd);
                    host.appendEvent("input.delete after=" + (delEnd - editorCursor));
                }
                host.refreshShellState();
                return true;
            }

            @Override
            public boolean sendKeyEvent(KeyEvent event) {
                if (event.getAction() != KeyEvent.ACTION_DOWN) return super.sendKeyEvent(event);
                host.appendEvent("input.key code=" + event.getKeyCode()
                        + " name=" + KeyEvent.keyCodeToString(event.getKeyCode()));
                final Integer controlCodepoint = mapKeyToControlCodepoint(event);
                if (controlCodepoint != null) {
                    host.sendDirectCodepoint(controlCodepoint);
                    host.refreshShellState();
                    return true;
                }
                final String esc = mapKeyToEscape(event.getKeyCode());
                if (esc != null) {
                    host.sendDirectText(esc);
                    host.refreshShellState();
                    return true;
                }
                switch (event.getKeyCode()) {
                    case KeyEvent.KEYCODE_DEL:
                        host.sendDirectCodepoint('\u007f');
                        if (editorCursor > editorLineStart()) {
                            editorBuffer.deleteCharAt(editorCursor - 1);
                            editorCursor--;
                        }
                        host.refreshShellState();
                        return true;
                    case KeyEvent.KEYCODE_ENTER:
                    case KeyEvent.KEYCODE_NUMPAD_ENTER:
                        host.sendDirectCodepoint('\n');
                        resetEditorState();
                        host.refreshShellState();
                        return true;
                    case KeyEvent.KEYCODE_TAB:
                        host.sendDirectCodepoint('\t');
                        host.refreshShellState();
                        return true;
                    case KeyEvent.KEYCODE_ESCAPE:
                        host.sendDirectCodepoint('\u001b');
                        host.refreshShellState();
                        return true;
                    default:
                        return super.sendKeyEvent(event);
                }
            }
        };
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
        while (i >= 0 && editorBuffer.charAt(i) != '\n') i--;
        return i + 1;
    }

    private String mapKeyToEscape(int keyCode) {
        return switch (keyCode) {
            case KeyEvent.KEYCODE_DPAD_UP -> "\u001b[A";
            case KeyEvent.KEYCODE_DPAD_DOWN -> "\u001b[B";
            case KeyEvent.KEYCODE_DPAD_RIGHT -> "\u001b[C";
            case KeyEvent.KEYCODE_DPAD_LEFT -> "\u001b[D";
            case KeyEvent.KEYCODE_MOVE_HOME -> "\u001b[H";
            case KeyEvent.KEYCODE_MOVE_END -> "\u001b[F";
            case KeyEvent.KEYCODE_INSERT -> "\u001b[2~";
            case KeyEvent.KEYCODE_FORWARD_DEL -> "\u001b[3~";
            case KeyEvent.KEYCODE_PAGE_UP -> "\u001b[5~";
            case KeyEvent.KEYCODE_PAGE_DOWN -> "\u001b[6~";
            default -> null;
        };
    }

    private Integer mapKeyToControlCodepoint(KeyEvent event) {
        if (!event.isCtrlPressed()) {
            return null;
        }
        final int unicode = event.getUnicodeChar(KeyEvent.META_CTRL_ON);
        if (unicode >= 'a' && unicode <= 'z') {
            return unicode - 'a' + 1;
        }
        if (unicode >= 'A' && unicode <= 'Z') {
            return unicode - 'A' + 1;
        }
        return switch (event.getKeyCode()) {
            case KeyEvent.KEYCODE_A -> 0x01;
            case KeyEvent.KEYCODE_B -> 0x02;
            case KeyEvent.KEYCODE_C -> 0x03;
            case KeyEvent.KEYCODE_D -> 0x04;
            case KeyEvent.KEYCODE_E -> 0x05;
            case KeyEvent.KEYCODE_F -> 0x06;
            case KeyEvent.KEYCODE_G -> 0x07;
            case KeyEvent.KEYCODE_H -> 0x08;
            case KeyEvent.KEYCODE_I -> 0x09;
            case KeyEvent.KEYCODE_J -> 0x0a;
            case KeyEvent.KEYCODE_K -> 0x0b;
            case KeyEvent.KEYCODE_L -> 0x0c;
            case KeyEvent.KEYCODE_M -> 0x0d;
            case KeyEvent.KEYCODE_N -> 0x0e;
            case KeyEvent.KEYCODE_O -> 0x0f;
            case KeyEvent.KEYCODE_P -> 0x10;
            case KeyEvent.KEYCODE_Q -> 0x11;
            case KeyEvent.KEYCODE_R -> 0x12;
            case KeyEvent.KEYCODE_S -> 0x13;
            case KeyEvent.KEYCODE_T -> 0x14;
            case KeyEvent.KEYCODE_U -> 0x15;
            case KeyEvent.KEYCODE_V -> 0x16;
            case KeyEvent.KEYCODE_W -> 0x17;
            case KeyEvent.KEYCODE_X -> 0x18;
            case KeyEvent.KEYCODE_Y -> 0x19;
            case KeyEvent.KEYCODE_Z -> 0x1a;
            case KeyEvent.KEYCODE_LEFT_BRACKET -> 0x1b;
            case KeyEvent.KEYCODE_BACKSLASH -> 0x1c;
            case KeyEvent.KEYCODE_RIGHT_BRACKET -> 0x1d;
            case KeyEvent.KEYCODE_6 -> 0x1e;
            case KeyEvent.KEYCODE_MINUS, KeyEvent.KEYCODE_SLASH -> 0x1f;
            case KeyEvent.KEYCODE_SPACE, KeyEvent.KEYCODE_2 -> 0x00;
            default -> null;
        };
    }
}
