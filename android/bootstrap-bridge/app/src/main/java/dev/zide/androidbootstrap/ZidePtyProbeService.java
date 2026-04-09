package dev.zide.androidbootstrap;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.util.Log;

public final class ZidePtyProbeService extends Service {
    public static final String ACTION_START_FOREGROUND_PTY_PROBE =
        "dev.zide.androidbootstrap.action.START_FOREGROUND_PTY_PROBE";
    public static final String ACTION_STOP_FOREGROUND_PTY_PROBE =
        "dev.zide.androidbootstrap.action.STOP_FOREGROUND_PTY_PROBE";

    private static final String TAG = "ZideAndroidBootstrap";
    private static final String CHANNEL_ID = "zide.bootstrap.pty_probe";
    private static final int NOTIFICATION_ID = 1001;

    private static boolean nativeLoaded = false;

    static {
        try {
            System.loadLibrary("zide_android_bridge");
            nativeLoaded = true;
        } catch (UnsatisfiedLinkError err) {
            Log.e(TAG, "service failed to load native bridge", err);
        }
    }

    private static native long nativeStartPtyProbeBridge();
    private static native void nativeStopPtyProbeBridge();
    private static native boolean nativeIsPtyProbeAliveBridge();
    private static native long nativePtyProbeChildPidBridge();
    private static native int nativePtyProbeStartStatusBridge();

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        final String action = intent != null ? intent.getAction() : null;
        if (ACTION_STOP_FOREGROUND_PTY_PROBE.equals(action)) {
            stopProbeService("service.stop");
            return START_NOT_STICKY;
        }

        startProbeService("service.start");
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        stopProbeService("service.destroy");
        super.onDestroy();
    }

    private void startProbeService(String logPrefix) {
        if (!nativeLoaded) {
            Log.w(TAG, logPrefix + " nativeLoaded=false");
            stopSelf();
            return;
        }

        final long pid = nativeStartPtyProbeBridge();
        final boolean alive = nativeIsPtyProbeAliveBridge();
        final int status = nativePtyProbeStartStatusBridge();

        setupNotificationChannel();
        startForeground(NOTIFICATION_ID, buildNotification(alive, pid, status));
        Log.i(
            TAG,
            logPrefix +
                " pid=" + pid +
                " alive=" + alive +
                " status=" + ptyProbeStartStatusLabel(status)
        );
    }

    private void stopProbeService(String logPrefix) {
        if (nativeLoaded) {
            nativeStopPtyProbeBridge();
        }
        final boolean alive = nativeLoaded && nativeIsPtyProbeAliveBridge();
        final long pid = nativeLoaded ? nativePtyProbeChildPidBridge() : -1;
        Log.i(TAG, logPrefix + " pid=" + pid + " alive=" + alive);
        stopForeground(STOP_FOREGROUND_REMOVE);
        stopSelf();
    }

    private void setupNotificationChannel() {
        final NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager == null) {
            return;
        }
        final NotificationChannel channel = new NotificationChannel(
            CHANNEL_ID,
            "Zide PTY Probe",
            NotificationManager.IMPORTANCE_LOW
        );
        channel.setDescription("Foreground PTY probe for Android service survival experiments");
        manager.createNotificationChannel(channel);
    }

    private Notification buildNotification(boolean alive, long pid, int status) {
        final Intent contentIntent = new Intent(this, ZideBootstrapActivity.class);
        final PendingIntent pendingIntent = PendingIntent.getActivity(
            this,
            0,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        return new Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Zide PTY Service Probe")
            .setContentText(
                "alive=" + alive +
                    " pid=" + pid +
                    " status=" + ptyProbeStartStatusLabel(status)
            )
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build();
    }

    private static String ptyProbeStartStatusLabel(int status) {
        return switch (status) {
            case 1 -> "started";
            case 2 -> "unsupported";
            case 3 -> "delete-log-failed";
            case 4 -> "init-failed";
            case 5 -> "write-failed";
            case 6 -> "missing-pid";
            default -> "none";
        };
    }
}
