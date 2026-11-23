package com.neilk.kaleidoklear.reminder;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** A notification tap remembers to open Daily Puzzles, then brings the game forward. */
public final class ReminderOpenReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        Context app = context.getApplicationContext();
        ReminderEngine.markOpenDaily(app);
        Intent launch = app.getPackageManager().getLaunchIntentForPackage(app.getPackageName());
        if (launch == null) {
            return;
        }
        launch.putExtra("open_daily", true);
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        app.startActivity(launch);
    }
}
