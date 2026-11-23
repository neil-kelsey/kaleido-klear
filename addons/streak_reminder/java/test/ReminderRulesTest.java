package com.neilk.kaleidoklear.reminder;

import java.util.Calendar;
import java.util.Set;
import java.util.TimeZone;

public final class ReminderRulesTest {
    public static void main(String[] args) {
        expect(ReminderRules.addDays("2026-10-31", 1).equals("2026-11-01"), "month roll");
        expect(ReminderRules.addDays("2026-01-01", -1).equals("2025-12-31"), "year roll");

        String legacy = "{\"daily_completed\":{\"2026-10-21\":{\"easy\":1},\"2026-10-22\":{}}}";
        Set<String> days = ReminderRules.countedDays(legacy);
        expect(days.contains("2026-10-21") && !days.contains("2026-10-22"), "empty day object does not count");
        expect(ReminderRules.currentStreak("2026-10-22", days) == 1, "open today keeps yesterday");

        String dailySlot = "{\"daily_completed\":{\"2026-10-21\":{\"daily\":2}}}";
        expect(ReminderRules.countedDays(dailySlot).contains("2026-10-21"), "new daily slot counts");
        String zero = "{\"daily_completed\":{\"2026-10-21\":{\"daily\":0,\"easy\":0}}}";
        expect(!ReminderRules.countedDays(zero).contains("2026-10-21"), "zero stars do not count");
        String maxLegacy = "{\"daily_completed\":{\"2026-10-21\":{\"easy\":0,\"medium\":3,\"hard\":1}}}";
        expect(ReminderRules.countedDays(maxLegacy).contains("2026-10-21"), "legacy max of easy/medium/hard counts");
        String hardOnly = "{\"daily_completed\":{\"2026-10-21\":{\"hard\":2}}}";
        expect(ReminderRules.countedDays(hardOnly).contains("2026-10-21"), "a legacy hard clear still counts as done");

        long noon = utc(2026, 10, 22, 12, 0);
        long nextNoon = utc(2026, 10, 23, 12, 0);
        expect(ReminderRules.shouldNotify(true, legacy, noon), "open today with yesterday cleared should notify");
        expect(!ReminderRules.shouldNotify(true, legacy, nextNoon), "the next UTC day is a dead streak");
        String cleared = "{\"daily_completed\":{\"2026-10-22\":{\"daily\":2}},\"daily_streak_current\":1,\"daily_streak_last_date\":\"2026-10-22\"}";
        expect(!ReminderRules.shouldNotify(true, cleared, noon), "today cleared suppresses");
        expect(ReminderRules.shouldNotify(true, cleared, nextNoon), "tomorrow noon still has the streak");
        expect(!ReminderRules.shouldNotify(false, legacy, noon), "toggle off suppresses");

        String storedAlive = "{\"daily_completed\":{\"2026-10-21\":{\"daily\":2}},\"daily_streak_current\":4,\"daily_streak_last_date\":\"2026-10-21\"}";
        expect(ReminderRules.displayStreak("2026-10-22", storedAlive) == 4, "stored streak is used when last_date is yesterday");
        expect(ReminderRules.shouldNotify(true, storedAlive, noon), "stored streak still alive notifies");
        String storedDead = "{\"daily_completed\":{\"2026-10-19\":{\"daily\":2}},\"daily_streak_current\":4,\"daily_streak_last_date\":\"2026-10-19\"}";
        expect(ReminderRules.displayStreak("2026-10-22", storedDead) == 0, "stored streak dies after a missed UTC day");
        expect(!ReminderRules.shouldNotify(true, storedDead, noon), "dead stored streak stays quiet");

        String settings = "[audio]\nsfx_enabled=true\n\n[notifications]\n\ndaily_reminders=false\n";
        expect(!ReminderRules.remindersEnabled(settings), "saved off");
        expect(ReminderRules.remindersEnabled("[audio]\nsfx_enabled=true\n"), "missing key stays on");
        expect(ReminderRules.locale(settings).equals("en"), "missing locale is english");
        expect(ReminderRules.locale("[i18n]\nlocale=fr\n").equals("fr"), "french locale");
        expect(ReminderRules.channelName("[i18n]\nlocale=pirate\n").equals("Noon hail"), "pirate channel");
        expect(ReminderRules.fill("🔥 Your %d-day streak is waiting!", 4).equals("🔥 Your 4-day streak is waiting!"), "placeholder");
        expect(ReminderRules.countedDays("").isEmpty(), "missing progress");
        System.out.println("REMINDER_RULES_OK");
    }

    private static long utc(int year, int month, int day, int hour, int minute) {
        Calendar calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
        calendar.set(Calendar.YEAR, year);
        calendar.set(Calendar.MONTH, month - 1);
        calendar.set(Calendar.DAY_OF_MONTH, day);
        calendar.set(Calendar.HOUR_OF_DAY, hour);
        calendar.set(Calendar.MINUTE, minute);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        return calendar.getTimeInMillis();
    }

    private static void expect(boolean cond, String message) {
        if (!cond) {
            throw new RuntimeException(message);
        }
    }
}
