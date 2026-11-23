package com.neilk.kaleidoklear.reminder;

import java.util.Calendar;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.TimeZone;

/**
 * UTC streak gate shared with scritps/StreakReminder.gd.
 *
 * Kaleido Klear daily days are UTC calendar dates, same as the in-game
 * Daily puzzle. A date counts when the best of daily / easy / medium / hard
 * stars is at least 1. Display streak prefers progress.json fields
 * daily_streak_current and daily_streak_last_date (alive only when last_date
 * is today or yesterday); otherwise it walks consecutive counted days.
 */
public final class ReminderRules {
    private ReminderRules() {}

    private static final String[] STAR_SLOTS = {"daily", "easy", "medium", "hard"};

    public static String utcDate(long epochMillis) {
        Calendar calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
        calendar.setTimeInMillis(epochMillis);
        return format(calendar);
    }

    public static String addDays(String iso, int days) {
        String[] parts = iso.split("-");
        Calendar calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
        calendar.set(Calendar.YEAR, Integer.parseInt(parts[0]));
        calendar.set(Calendar.MONTH, Integer.parseInt(parts[1]) - 1);
        calendar.set(Calendar.DAY_OF_MONTH, Integer.parseInt(parts[2]));
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        calendar.add(Calendar.DATE, days);
        return format(calendar);
    }

    public static int currentStreak(String today, Set<String> countedDays) {
        String cursor = today;
        if (!countedDays.contains(cursor)) {
            cursor = addDays(cursor, -1);
        }
        int run = 0;
        while (countedDays.contains(cursor)) {
            run++;
            cursor = addDays(cursor, -1);
            if (run > 4000) {
                break;
            }
        }
        return run;
    }

    /**
     * Streak shown in the game: stored fields when present, else a walk of counted days.
     */
    public static int displayStreak(String today, String progressJson) {
        Set<String> days = countedDays(progressJson);
        String last = jsonString(progressJson, "daily_streak_last_date");
        Integer stored = jsonInt(progressJson, "daily_streak_current");
        if (last != null && stored != null) {
            if (stored <= 0) {
                return 0;
            }
            if (last.equals(today) || last.equals(addDays(today, -1))) {
                return stored;
            }
            return 0;
        }
        return currentStreak(today, days);
    }

    public static boolean shouldNotify(boolean remindersEnabled, String progressJson, long nowMillis) {
        if (!remindersEnabled) {
            return false;
        }
        String today = utcDate(nowMillis);
        if (countedDays(progressJson).contains(today)) {
            return false;
        }
        return displayStreak(today, progressJson) > 0;
    }

    /** Godot ConfigFile text. Missing key means reminders stay on. */
    public static boolean remindersEnabled(String settingsText) {
        return !"false".equals(configValue(settingsText, "notifications", "daily_reminders", "true"));
    }

    public static String locale(String settingsText) {
        String code = configValue(settingsText, "i18n", "locale", "en");
        if ("fr".equals(code) || "pirate".equals(code) || "en".equals(code)) {
            return code;
        }
        return "en";
    }

    public static String channelName(String settingsText) {
        String code = locale(settingsText);
        if ("fr".equals(code)) {
            return "Rappels du jour";
        }
        if ("pirate".equals(code)) {
            return "Noon hail";
        }
        return "Daily reminders";
    }

    public static String fill(String template, int streak) {
        if (template == null) {
            return "";
        }
        int mark = template.indexOf("%d");
        if (mark < 0) {
            return template;
        }
        return template.substring(0, mark) + streak + template.substring(mark + 2);
    }

    /**
     * Dates in progress.json whose daily_completed object has a best star
     * count above 0 across the daily slot or legacy easy/medium/hard keys.
     */
    public static Set<String> countedDays(String progressJson) {
        Set<String> days = new HashSet<String>();
        if (progressJson == null || progressJson.isEmpty()) {
            return days;
        }
        int key = progressJson.indexOf("\"daily_completed\"");
        if (key < 0) {
            return days;
        }
        int start = progressJson.indexOf('{', key + "\"daily_completed\"".length());
        if (start < 0) {
            return days;
        }
        int end = matchBrace(progressJson, start);
        if (end < 0) {
            return days;
        }
        String body = progressJson.substring(start + 1, end);
        int index = 0;
        while (index < body.length()) {
            int openQuote = body.indexOf('"', index);
            if (openQuote < 0) {
                break;
            }
            int closeQuote = body.indexOf('"', openQuote + 1);
            if (closeQuote < 0) {
                break;
            }
            String date = body.substring(openQuote + 1, closeQuote);
            int colon = body.indexOf(':', closeQuote + 1);
            if (colon < 0) {
                break;
            }
            int brace = body.indexOf('{', colon + 1);
            if (brace < 0) {
                break;
            }
            int close = matchBrace(body, brace);
            if (close < 0) {
                break;
            }
            if (dayHasStars(body.substring(brace + 1, close))) {
                days.add(date);
            }
            index = close + 1;
        }
        return days;
    }

    /** True when max(daily, easy, medium, hard) is at least 1. */
    public static boolean dayHasStars(String dayObjectBody) {
        int best = 0;
        for (int i = 0; i < STAR_SLOTS.length; i++) {
            int value = slotStars(dayObjectBody, STAR_SLOTS[i]);
            if (value > best) {
                best = value;
            }
        }
        return best > 0;
    }

    private static int slotStars(String body, String slot) {
        String needle = "\"" + slot + "\"";
        int at = 0;
        while (true) {
            int key = body.indexOf(needle, at);
            if (key < 0) {
                return 0;
            }
            int colon = body.indexOf(':', key + needle.length());
            if (colon < 0) {
                return 0;
            }
            int i = colon + 1;
            while (i < body.length() && Character.isWhitespace(body.charAt(i))) {
                i++;
            }
            int start = i;
            if (i < body.length() && body.charAt(i) == '-') {
                i++;
            }
            while (i < body.length() && Character.isDigit(body.charAt(i))) {
                i++;
            }
            if (i == start || (i == start + 1 && body.charAt(start) == '-')) {
                at = key + 1;
                continue;
            }
            try {
                return Integer.parseInt(body.substring(start, i));
            } catch (NumberFormatException error) {
                return 0;
            }
        }
    }

    private static String jsonString(String json, String key) {
        if (json == null) {
            return null;
        }
        String needle = "\"" + key + "\"";
        int at = json.indexOf(needle);
        if (at < 0) {
            return null;
        }
        int colon = json.indexOf(':', at + needle.length());
        if (colon < 0) {
            return null;
        }
        int i = colon + 1;
        while (i < json.length() && Character.isWhitespace(json.charAt(i))) {
            i++;
        }
        if (i >= json.length()) {
            return null;
        }
        if (json.startsWith("null", i)) {
            return null;
        }
        if (json.charAt(i) != '"') {
            return null;
        }
        int end = json.indexOf('"', i + 1);
        if (end < 0) {
            return null;
        }
        return json.substring(i + 1, end);
    }

    private static Integer jsonInt(String json, String key) {
        if (json == null) {
            return null;
        }
        String needle = "\"" + key + "\"";
        int at = json.indexOf(needle);
        if (at < 0) {
            return null;
        }
        int colon = json.indexOf(':', at + needle.length());
        if (colon < 0) {
            return null;
        }
        int i = colon + 1;
        while (i < json.length() && Character.isWhitespace(json.charAt(i))) {
            i++;
        }
        int start = i;
        if (i < json.length() && json.charAt(i) == '-') {
            i++;
        }
        while (i < json.length() && Character.isDigit(json.charAt(i))) {
            i++;
        }
        if (i == start || (i == start + 1 && json.charAt(start) == '-')) {
            return null;
        }
        try {
            return Integer.valueOf(Integer.parseInt(json.substring(start, i)));
        } catch (NumberFormatException error) {
            return null;
        }
    }

    private static String configValue(String text, String section, String key, String fallback) {
        if (text == null) {
            return fallback;
        }
        String current = "";
        String[] lines = text.split("\n");
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i].trim();
            if (line.endsWith("\r")) {
                line = line.substring(0, line.length() - 1).trim();
            }
            if (line.isEmpty() || line.startsWith(";") || line.startsWith("#")) {
                continue;
            }
            if (line.startsWith("[") && line.endsWith("]") && line.length() >= 2) {
                current = line.substring(1, line.length() - 1).trim();
                continue;
            }
            if (!section.equals(current)) {
                continue;
            }
            int eq = line.indexOf('=');
            if (eq <= 0) {
                continue;
            }
            if (!key.equals(line.substring(0, eq).trim())) {
                continue;
            }
            return line.substring(eq + 1).trim().toLowerCase(Locale.US);
        }
        return fallback;
    }

    private static int matchBrace(String text, int open) {
        int depth = 0;
        boolean inString = false;
        for (int i = open; i < text.length(); i++) {
            char c = text.charAt(i);
            if (inString) {
                if (c == '\\') {
                    i++;
                    continue;
                }
                if (c == '"') {
                    inString = false;
                }
                continue;
            }
            if (c == '"') {
                inString = true;
                continue;
            }
            if (c == '{') {
                depth++;
            } else if (c == '}') {
                depth--;
                if (depth == 0) {
                    return i;
                }
            }
        }
        return -1;
    }

    private static String format(Calendar calendar) {
        return String.format(
            Locale.US,
            "%04d-%02d-%02d",
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH)
        );
    }
}
