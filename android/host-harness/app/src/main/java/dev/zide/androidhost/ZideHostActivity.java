package dev.zide.androidhost;

import android.app.Activity;
import android.content.res.Configuration;
import android.os.Bundle;
import android.os.SystemClock;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

public final class ZideHostActivity extends Activity implements SurfaceHolder.Callback2, View.OnFocusChangeListener, TextWatcher {
    private static final String TAG = "ZideAndroidHost";
    private static final int MAX_LOG_CHARS = 12000;

    private final StringBuilder eventLog = new StringBuilder();
    private TextView statusText;
    private TextView eventLogText;
    private SurfaceView surfaceView;
    private EditText imeProbe;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        statusText = findViewById(R.id.status_text);
        eventLogText = findViewById(R.id.event_log);
        surfaceView = findViewById(R.id.host_surface);
        imeProbe = findViewById(R.id.ime_probe);
        Button showImeButton = findViewById(R.id.show_ime_button);
        Button hideImeButton = findViewById(R.id.hide_ime_button);

        surfaceView.getHolder().addCallback(this);
        imeProbe.setOnFocusChangeListener(this);
        imeProbe.addTextChangedListener(this);
        showImeButton.setOnClickListener(v -> showIme());
        hideImeButton.setOnClickListener(v -> hideIme());

        appendEvent("activity.onCreate saved=" + (savedInstanceState != null));
        updateStatus("created");
    }

    @Override
    protected void onStart() {
        super.onStart();
        appendEvent("activity.onStart");
        updateStatus("started");
    }

    @Override
    protected void onResume() {
        super.onResume();
        appendEvent("activity.onResume");
        updateStatus("resumed");
    }

    @Override
    protected void onPause() {
        appendEvent("activity.onPause");
        updateStatus("paused");
        super.onPause();
    }

    @Override
    protected void onStop() {
        appendEvent("activity.onStop");
        updateStatus("stopped");
        super.onStop();
    }

    @Override
    protected void onDestroy() {
        appendEvent("activity.onDestroy");
        updateStatus("destroyed");
        super.onDestroy();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        appendEvent("activity.onWindowFocusChanged focus=" + hasFocus);
        updateStatus(hasFocus ? "window-focused" : "window-unfocused");
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        appendEvent("activity.onConfigurationChanged orientation=" + orientationName(newConfig.orientation));
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        appendEvent("surface.created valid=" + holder.getSurface().isValid());
        updateStatus("surface-created");
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        appendEvent("surface.changed format=" + format + " size=" + width + "x" + height);
        updateStatus("surface-changed");
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        appendEvent("surface.destroyed");
        updateStatus("surface-destroyed");
    }

    @Override
    public void surfaceRedrawNeeded(SurfaceHolder holder) {
        appendEvent("surface.redrawNeeded valid=" + holder.getSurface().isValid());
        updateStatus("surface-redraw-needed");
    }

    @Override
    public void onFocusChange(View view, boolean hasFocus) {
        if (view == imeProbe) {
            appendEvent("ime.focus changed=" + hasFocus);
            updateStatus(hasFocus ? "ime-focused" : "ime-unfocused");
        }
    }

    @Override
    public void beforeTextChanged(CharSequence s, int start, int count, int after) {
    }

    @Override
    public void onTextChanged(CharSequence s, int start, int before, int count) {
        appendEvent("ime.text changed length=" + s.length());
    }

    @Override
    public void afterTextChanged(Editable s) {
    }

    private void showIme() {
        imeProbe.requestFocus();
        InputMethodManager imm = getSystemService(InputMethodManager.class);
        if (imm != null) {
            imm.showSoftInput(imeProbe, InputMethodManager.SHOW_IMPLICIT);
        }
        appendEvent("ime.show requested");
    }

    private void hideIme() {
        InputMethodManager imm = getSystemService(InputMethodManager.class);
        if (imm != null) {
            imm.hideSoftInputFromWindow(imeProbe.getWindowToken(), 0);
        }
        imeProbe.clearFocus();
        appendEvent("ime.hide requested");
    }

    private void updateStatus(String state) {
        final int surfaceWidth = surfaceView.getWidth();
        final int surfaceHeight = surfaceView.getHeight();
        final boolean surfaceValid = surfaceView.getHolder().getSurface().isValid();
        statusText.setText(
            "state=" + state +
                " windowFocus=" + hasWindowFocus() +
                " imeFocus=" + imeProbe.hasFocus() +
                " surfaceValid=" + surfaceValid +
                " surfaceSize=" + surfaceWidth + "x" + surfaceHeight
        );
    }

    private void appendEvent(String message) {
        final String line = String.format("[%08d] %s", SystemClock.uptimeMillis(), message);
        Log.i(TAG, line);
        if (eventLog.length() > 0) {
            eventLog.append('\n');
        }
        eventLog.append(line);
        if (eventLog.length() > MAX_LOG_CHARS) {
            eventLog.delete(0, eventLog.length() - MAX_LOG_CHARS);
        }
        eventLogText.setText(eventLog.toString());
    }

    private static String orientationName(int orientation) {
        if (orientation == Configuration.ORIENTATION_LANDSCAPE) return "landscape";
        if (orientation == Configuration.ORIENTATION_PORTRAIT) return "portrait";
        return "undefined";
    }
}
