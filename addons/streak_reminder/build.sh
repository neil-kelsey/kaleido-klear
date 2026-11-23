#!/bin/sh
# Rebuilds addons/streak_reminder/StreakReminder.release.aar
# Requires javac 17+, ANDROID_JAR (API 34+) and GODOT_JAR (Godot 4.7.2 classes).
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/addons/streak_reminder/java/com/neilk/kaleidoklear/reminder"
TEST="$ROOT/addons/streak_reminder/java/test"
RES="$ROOT/addons/streak_reminder/res"
OUT="${TMPDIR:-/tmp}/streak-reminder-build"
if [ -z "${JAVA_HOME:-}" ]; then
  for candidate in /workspace/android/jdk /usr/lib/jvm/java-17-openjdk; do
    if [ -x "$candidate/bin/javac" ]; then
      JAVA_HOME="$candidate"
      break
    fi
  done
fi
if [ -n "${JAVA_HOME:-}" ]; then
  PATH="$JAVA_HOME/bin:$PATH"
fi
ANDROID_JAR="${ANDROID_JAR:-}"
if [ -z "$ANDROID_JAR" ]; then
  for jar in \
      /workspace/android/sdk/platforms/android-36/android.jar \
      /workspace/android/sdk/platforms/android-35/android.jar \
      /workspace/android/sdk/platforms/android-34/android.jar \
      /tmp/streak-build/android-34/android.jar; do
    if [ -f "$jar" ]; then
      ANDROID_JAR="$jar"
      break
    fi
  done
fi
GODOT_JAR="${GODOT_JAR:-}"
if [ -z "$GODOT_JAR" ]; then
  for jar in \
      /tmp/streak-build/godot-classes.jar \
      /workspace/android/xdg-cache/godot-classes.jar; do
    if [ -f "$jar" ]; then
      GODOT_JAR="$jar"
      break
    fi
  done
fi
if [ -z "$GODOT_JAR" ]; then
  for aar in \
      /workspace/grokbot-kk-tmp/build73/android/build/libs/debug/godot-lib.template_debug.aar \
      /workspace/grokbot-kk-tmp/build72/android/build/libs/debug/godot-lib.template_debug.aar; do
    if [ -f "$aar" ]; then
      mkdir -p "$OUT/godot"
      unzip -qo "$aar" classes.jar -d "$OUT/godot"
      GODOT_JAR="$OUT/godot/classes.jar"
      break
    fi
  done
fi
if [ ! -f "${ANDROID_JAR:-}" ]; then
  echo "ANDROID_JAR is missing" >&2
  exit 1
fi
if [ ! -f "${GODOT_JAR:-}" ]; then
  echo "GODOT_JAR is missing" >&2
  exit 1
fi
rm -rf "$OUT/stubs" "$OUT/classes" "$OUT/aar" "$OUT/test"
mkdir -p "$OUT/stubs" "$OUT/classes" "$OUT/aar"
cat > "$OUT/stubs/Nullable.java" <<'STUB'
package androidx.annotation;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
@Retention(RetentionPolicy.CLASS)
public @interface Nullable {}
STUB
cat > "$OUT/stubs/NonNull.java" <<'STUB'
package androidx.annotation;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
@Retention(RetentionPolicy.CLASS)
public @interface NonNull {}
STUB
javac --release 17 -d "$OUT/stubs" "$OUT/stubs/Nullable.java" "$OUT/stubs/NonNull.java"
javac --release 17 -d "$OUT/classes" -classpath "$OUT/stubs:$ANDROID_JAR:$GODOT_JAR" "$SRC"/*.java
mkdir -p "$OUT/test"
javac --release 17 -d "$OUT/test" -classpath "$OUT/classes" "$TEST"/ReminderRulesTest.java
java -classpath "$OUT/classes:$OUT/test" com.neilk.kaleidoklear.reminder.ReminderRulesTest
# Package the AAR with Python so we do not depend on a zip binary.
python3 - "$OUT" "$ROOT" "$RES" <<'PY'
import sys, shutil
from pathlib import Path
import zipfile
out = Path(sys.argv[1])
root = Path(sys.argv[2])
res = Path(sys.argv[3])
aar_dir = out / "aar"
# classes.jar
classes_jar = aar_dir / "classes.jar"
# Recreate classes.jar from compiled classes
def write_jar(dest, source_dir, prefix=""):
    with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(source_dir.rglob("*")):
            if path.is_file():
                zf.write(path, path.relative_to(source_dir).as_posix())

write_jar(classes_jar, out / "classes")
shutil.copyfile(root / "addons/streak_reminder/AndroidManifest.xml", aar_dir / "AndroidManifest.xml")
(aar_dir / "proguard.txt").write_text(
    "-keepattributes *Annotation*\n-keep class com.neilk.kaleidoklear.reminder.** { *; }\n"
)
meta = aar_dir / "META-INF/com/android/build/gradle"
meta.mkdir(parents=True, exist_ok=True)
(meta / "aar-metadata.properties").write_text(
    "aarFormatVersion=1.0\n"
    "aarMetadataVersion=1.0\n"
    "minCompileSdk=24\n"
    "minCompileSdkExtension=0\n"
    "minAndroidGradlePluginVersion=8.0.0\n"
    "coreLibraryDesugaringEnabled=false\n"
)
# R.txt for the status-bar icon
r_lines = ["int drawable ic_stat_daily_reminder 0x7f010000\n"]
(aar_dir / "R.txt").write_text("".join(r_lines))
# Copy res/ density buckets
if res.is_dir():
    dest_res = aar_dir / "res"
    if dest_res.exists():
        shutil.rmtree(dest_res)
    shutil.copytree(res, dest_res)

aar_path = root / "addons/streak_reminder/StreakReminder.release.aar"
if aar_path.exists():
    aar_path.unlink()
with zipfile.ZipFile(aar_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for path in sorted(aar_dir.rglob("*")):
        if path.is_file():
            zf.write(path, path.relative_to(aar_dir).as_posix())
print("AAR", aar_path, "bytes", aar_path.stat().st_size)
PY
echo "AAR_OK"
