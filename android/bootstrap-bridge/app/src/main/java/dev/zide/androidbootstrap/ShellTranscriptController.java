package dev.zide.androidbootstrap;

import android.view.MotionEvent;
import android.view.View;
import android.widget.ScrollView;
import android.widget.TextView;

final class ShellTranscriptController {
    private final ScrollView outputScroll;
    private final TextView outputText;

    private boolean imeVisible = false;
    private boolean autoFollowEnabled = true;
    private String lastTranscript = "";

    ShellTranscriptController(ScrollView outputScroll, TextView outputText) {
        this.outputScroll = outputScroll;
        this.outputText = outputText;
    }

    void installScrollHandling() {
        outputScroll.setOnTouchListener((view, event) -> {
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    outputScroll.post(() -> autoFollowEnabled = isNearBottom());
                    break;
                default:
                    autoFollowEnabled = false;
                    break;
            }
            return false;
        });
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
