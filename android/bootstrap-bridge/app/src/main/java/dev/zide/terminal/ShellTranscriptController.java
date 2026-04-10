package dev.zide.terminal;

import android.view.MotionEvent;
import android.view.View;
import android.widget.ScrollView;
import android.widget.TextView;

final class ShellTranscriptController {
    interface Host {
        void onTranscriptTap();
    }

    private final ScrollView outputScroll;
    private final TextView outputText;
    private final Host host;

    private boolean imeVisible = false;
    private boolean autoFollowEnabled = true;
    private String lastTranscript = "";
    private float touchDownX = 0;
    private float touchDownY = 0;
    private int touchSlop = 0;

    ShellTranscriptController(ScrollView outputScroll, TextView outputText, Host host) {
        this.outputScroll = outputScroll;
        this.outputText = outputText;
        this.host = host;
    }

    void installScrollHandling() {
        touchSlop = android.view.ViewConfiguration.get(outputScroll.getContext()).getScaledTouchSlop();
        final View.OnTouchListener listener = (view, event) -> {
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    touchDownX = event.getX();
                    touchDownY = event.getY();
                    autoFollowEnabled = false;
                    break;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    final float dx = Math.abs(event.getX() - touchDownX);
                    final float dy = Math.abs(event.getY() - touchDownY);
                    if (event.getActionMasked() == MotionEvent.ACTION_UP && dx <= touchSlop && dy <= touchSlop) {
                        host.onTranscriptTap();
                    }
                    outputScroll.post(() -> autoFollowEnabled = isNearBottom());
                    break;
                default:
                    autoFollowEnabled = false;
                    break;
            }
            return false;
        };
        outputScroll.setOnTouchListener(listener);
        outputText.setOnTouchListener(listener);
    }

    void setImeVisible(boolean imeVisible) {
        this.imeVisible = imeVisible;
    }

    void applyTranscript(String transcript) {
        if (transcript.equals(lastTranscript)) {
            return;
        }
        lastTranscript = transcript;
        outputText.setText(transcript);
        if (shouldFollowOutput()) {
            outputScroll.post(() -> outputScroll.fullScroll(View.FOCUS_DOWN));
        }
    }

    private boolean shouldFollowOutput() {
        if (imeVisible) {
            return true;
        }
        return autoFollowEnabled;
    }

    private boolean isNearBottom() {
        final View content = outputScroll.getChildCount() > 0 ? outputScroll.getChildAt(0) : null;
        if (content == null) {
            return true;
        }
        final int remaining = content.getBottom() - (outputScroll.getScrollY() + outputScroll.getHeight());
        return remaining <= 32;
    }
}
