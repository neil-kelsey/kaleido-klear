package com.neilk.kaleidoklear.reminder;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

/**
 * One daily alarm and an optional 10-second test alarm.
 * Both are inexact: setAndAllowWhileIdle from API 23, setWindow before that.
 * The daily alarm is re-checked against user://progress.json and settings.cfg
 * when it fires, so a streak that died at UTC midnight is not announced.
 */
public final class ReminderEngine {
    static final String TAG = "StreakReminder";
    static final String CHANNEL_ID = "kaleido_daily_reminder";
    static final String PREFS = "kaleido_streak_reminder";
    static final int REQ_DAILY = 7101;
    static final int REQ_TEST = 7102;
    static final int REQ_OPEN = 7100;
    static final long CATCH_UP_MS = 6L * 60L * 60L * 1000L;
    /** Inexact window on API 22 and older. The alarm may fire anywhere in this span. */
    static final long WINDOW_MS = 15L * 60L * 1000L;

    private ReminderEngine() {}

    static void scheduleDaily(Context context, long whenMillis, String title, String body) {
        SharedPreferences prefs = prefs(context);
        prefs.edit()
            .putBoolean("daily_armed", true)
            .putLong("daily_trigger", whenMillis)
            .putString("daily_title", title)
            .putString("daily_body", body)
            .apply();
        arm(context, REQ_DAILY, whenMillis, title, body, false);
        Log.i(TAG, "scheduled daily at " + whenMillis);
    }

    static void scheduleTest(Context context, int seconds, String title, String body) {
        long when = System.currentTimeMillis() + Math.max(1, seconds) * 1000L;
        arm(context, REQ_TEST, when, title, body, true);
        Log.i(TAG, "scheduled test in " + seconds + "s");
    }

    static void cancelDaily(Context context) {
        AlarmManager manager = alarms(context);
        if (manager != null) {
            manager.cancel(pending(context, REQ_DAILY, "", "", false));
        }
        prefs(context).edit()
            .putBoolean("daily_armed", false)
            .remove("daily_trigger")
            .apply();
        Log.i(TAG, "cancelled daily");
    }

    static void restoreAfterBoot(Context context) {
        SharedPreferences prefs = prefs(context);
        if (!prefs.getBoolean("daily_armed", false)) {
            return;
        }
        long when = prefs.getLong("daily_trigger", 0L);
        String title = prefs.getString("daily_title", "Kaleido Klear");
        String body = prefs.getString("daily_body", "");
        long now = System.currentTimeMillis();
        if (when > now) {
            arm(context, REQ_DAILY, when, title, body, false);
            Log.i(TAG, "restored daily after boot");
            return;
        }
        if (now - when <= CATCH_UP_MS) {
            Intent fire = new Intent(context, ReminderReceiver.class);
            fire.putExtra("test", false);
            fire.putExtra("title", title);
            fire.putExtra("body", body);
            context.sendBroadcast(fire);
            Log.i(TAG, "boot catch-up");
            return;
        }
        cancelDaily(context);
        Log.i(TAG, "dropped a daily alarm that expired during reboot");
    }

    static void onAlarm(Context context, Intent intent) {
        boolean test = intent != null && intent.getBooleanExtra("test", false);
        String title = extra(intent, "title", "Kaleido Klear");
        String body = extra(intent, "body", "");
        long now = System.currentTimeMillis();
        if (!test && !shouldShow(context, now)) {
            cancelDaily(context);
            Log.i(TAG, "suppressed; streak or today's daily no longer qualifies");
            return;
        }
        int streak = ReminderRules.displayStreak(ReminderRules.utcDate(now), progressText(context));
        if (test) {
            streak = Math.max(streak, 1);
        }
        post(context, test ? REQ_TEST : REQ_DAILY, title, ReminderRules.fill(body, streak));
        if (!test) {
            prefs(context).edit().putBoolean("daily_armed", false).remove("daily_trigger").apply();
        }
    }

    static boolean consumeOpenDaily(Context context) {
        SharedPreferences prefs = prefs(context);
        boolean open = prefs.getBoolean("open_daily", false);
        if (open) {
            prefs.edit().putBoolean("open_daily", false).apply();
        }
        return open;
    }

    static void markOpenDaily(Context context) {
        prefs(context).edit().putBoolean("open_daily", true).apply();
    }

    private static boolean shouldShow(Context context, long now) {
        String settings = read(new File(context.getFilesDir(), "settings.cfg"));
        String progress = read(new File(context.getFilesDir(), "progress.json"));
        return ReminderRules.shouldNotify(ReminderRules.remindersEnabled(settings), progress, now);
    }

    private static String progressText(Context context) {
        return read(new File(context.getFilesDir(), "progress.json"));
    }

    private static void post(Context context, int id, String title, String body) {
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null) {
            return;
        }
        String settings = read(new File(context.getFilesDir(), "settings.cfg"));
        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= 26) {
            OreoNotes.ensureChannel(manager, ReminderRules.channelName(settings));
            builder = OreoNotes.builder(context);
        } else {
            builder = new Notification.Builder(context);
        }
        int icon = context.getResources().getIdentifier(
            "ic_stat_daily_reminder", "drawable", context.getPackageName()
        );
        if (icon == 0) {
            icon = context.getApplicationInfo().icon;
        }
        if (icon == 0) {
            icon = android.R.drawable.ic_dialog_info;
        }
        builder.setSmallIcon(icon)
            .setContentTitle(title == null || title.length() == 0 ? "Kaleido Klear" : title)
            .setContentText(body)
            .setStyle(new Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setContentIntent(openIntent(context))
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true);
        manager.notify(id, builder.build());
        Log.i(TAG, "posted " + id);
    }

    private static void arm(Context context, int requestCode, long whenMillis, String title, String body, boolean test) {
        AlarmManager manager = alarms(context);
        if (manager == null) {
            return;
        }
        PendingIntent intent = pending(context, requestCode, title, body, test);
        // Inexact on purpose. SCHEDULE_EXACT_ALARM is not requested.
        // API 23+ can still deliver while idle. Older platforms get a 15-minute window.
        if (Build.VERSION.SDK_INT >= 23) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, intent);
            return;
        }
        manager.setWindow(AlarmManager.RTC_WAKEUP, whenMillis, WINDOW_MS, intent);
    }

    private static PendingIntent pending(Context context, int requestCode, String title, String body, boolean test) {
        Intent intent = new Intent(context, ReminderReceiver.class);
        intent.putExtra("test", test);
        intent.putExtra("title", title);
        intent.putExtra("body", body);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE;
        return PendingIntent.getBroadcast(context, requestCode, intent, flags);
    }

    private static PendingIntent openIntent(Context context) {
        Intent intent = new Intent(context, ReminderOpenReceiver.class);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE;
        return PendingIntent.getBroadcast(context, REQ_OPEN, intent, flags);
    }

    private static AlarmManager alarms(Context context) {
        return (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
    }

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static String extra(Intent intent, String key, String fallback) {
        if (intent == null) {
            return fallback;
        }
        String value = intent.getStringExtra(key);
        return value == null ? fallback : value;
    }

    private static String read(File file) {
        if (file == null || !file.isFile()) {
            return "";
        }
        FileInputStream in = null;
        try {
            in = new FileInputStream(file);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[4096];
            int n;
            while ((n = in.read(buf)) >= 0) {
                out.write(buf, 0, n);
            }
            return new String(out.toByteArray(), "UTF-8");
        } catch (IOException error) {
            Log.w(TAG, "unreadable " + file.getName());
            return "";
        } finally {
            if (in != null) {
                try {
                    in.close();
                } catch (IOException ignored) {
                    // The caller treats an empty read as "no streak".
                }
            }
        }
    }
}
