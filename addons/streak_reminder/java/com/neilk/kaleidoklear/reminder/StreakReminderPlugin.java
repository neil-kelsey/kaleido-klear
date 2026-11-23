package com.neilk.kaleidoklear.reminder;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.annotation.NonNull;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

/**
 * Godot 4.7 Android plugin v2. GDScript decides whether and when to remind;
 * this side only stores one alarm and re-reads the save when it fires.
 *
 * godot-notification-scheduler can schedule and survive reboot, but it posts
 * the title it was given at schedule time. A UTC streak can die at midnight
 * while the game is closed, so the alarm has to look at progress.json first.
 */
public final class StreakReminderPlugin extends GodotPlugin {
    private static final int PERMISSION_REQUEST = 44017;
    private static final String POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS";

    public StreakReminderPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "StreakReminder";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<SignalInfo>();
        signals.add(new SignalInfo("permission_result", Boolean.class));
        return signals;
    }

    @UsedByGodot
    public void schedule(String epochMillis, String title, String bodyTemplate) {
        android.content.Context context = appContext();
        if (context == null || epochMillis == null) {
            return;
        }
        try {
            ReminderEngine.scheduleDaily(context, Long.parseLong(epochMillis.trim()), safe(title), safe(bodyTemplate));
        } catch (RuntimeException error) {
            android.util.Log.w(ReminderEngine.TAG, "schedule ignored: " + error.getMessage());
        }
    }

    @UsedByGodot
    public void cancel() {
        android.content.Context context = appContext();
        if (context != null) {
            ReminderEngine.cancelDaily(context);
        }
    }

    @UsedByGodot
    public void scheduleInSeconds(int seconds, String title, String bodyTemplate) {
        android.content.Context context = appContext();
        if (context != null) {
            ReminderEngine.scheduleTest(context, seconds, safe(title), safe(bodyTemplate));
        }
    }

    @UsedByGodot
    public boolean hasPermission() {
        if (Build.VERSION.SDK_INT < 33) {
            return true;
        }
        Activity activity = getActivity();
        if (activity == null) {
            return false;
        }
        return activity.checkSelfPermission(POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
    }

    @UsedByGodot
    public void requestPermission() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (Build.VERSION.SDK_INT < 33 || hasPermission()) {
                    emitSignal("permission_result", Boolean.TRUE);
                    return;
                }
                Activity activity = getActivity();
                if (activity == null) {
                    emitSignal("permission_result", Boolean.FALSE);
                    return;
                }
                activity.requestPermissions(new String[] {POST_NOTIFICATIONS}, PERMISSION_REQUEST);
            }
        });
    }

    @UsedByGodot
    public boolean consumeOpenDaily() {
        android.content.Context context = appContext();
        boolean open = context != null && ReminderEngine.consumeOpenDaily(context);
        Activity activity = getActivity();
        if (activity != null) {
            Intent launch = activity.getIntent();
            if (launch != null && launch.getBooleanExtra("open_daily", false)) {
                launch.removeExtra("open_daily");
                open = true;
            }
        }
        return open;
    }

    @Override
    public void onMainRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode != PERMISSION_REQUEST) {
            return;
        }
        boolean granted = grantResults != null
            && grantResults.length > 0
            && grantResults[0] == PackageManager.PERMISSION_GRANTED;
        emitSignal("permission_result", Boolean.valueOf(granted));
    }

    private android.content.Context appContext() {
        Activity activity = getActivity();
        if (activity == null) {
            return null;
        }
        return activity.getApplicationContext();
    }

    private static String safe(String value) {
        return value == null ? "" : value;
    }
}
