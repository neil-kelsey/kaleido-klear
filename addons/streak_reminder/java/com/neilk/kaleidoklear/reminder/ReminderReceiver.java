package com.neilk.kaleidoklear.reminder;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.PowerManager;

/** Posts the midday reminder, or drops it when the UTC streak no longer qualifies. */
public final class ReminderReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        PowerManager power = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        PowerManager.WakeLock lock = null;
        if (power != null) {
            lock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "kaleidoklear:daily");
            lock.acquire(10_000L);
        }
        try {
            ReminderEngine.onAlarm(context.getApplicationContext(), intent);
        } finally {
            if (lock != null && lock.isHeld()) {
                lock.release();
            }
        }
    }
}
