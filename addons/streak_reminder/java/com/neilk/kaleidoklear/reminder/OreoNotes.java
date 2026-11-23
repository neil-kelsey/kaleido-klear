package com.neilk.kaleidoklear.reminder;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;

/** Loaded only on API 26+, where notification channels exist. */
final class OreoNotes {
    private OreoNotes() {}

    static void ensureChannel(NotificationManager manager, String name) {
        NotificationChannel channel = new NotificationChannel(
            ReminderEngine.CHANNEL_ID,
            name,
            NotificationManager.IMPORTANCE_DEFAULT
        );
        channel.setDescription(name);
        manager.createNotificationChannel(channel);
    }

    static Notification.Builder builder(Context context) {
        return new Notification.Builder(context, ReminderEngine.CHANNEL_ID);
    }
}
