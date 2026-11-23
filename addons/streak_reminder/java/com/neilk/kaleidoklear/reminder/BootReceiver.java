package com.neilk.kaleidoklear.reminder;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Restores the one pending midday alarm after the device finishes booting. */
public final class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            return;
        }
        ReminderEngine.restoreAfterBoot(context.getApplicationContext());
    }
}
