# Ads and "Remove ads" (1.0.41)

Implements `/home/box/shared/veilmoth-monetisation/ADS-BRIEF.md`. **Uses Google test IDs only.**

## Pinned plugins
| Plugin | Version | Source | sha256 of release zip |
|---|---|---|---|
| Poing godot-admob-plugin (GDScript, Android) | v5.1.0 (GMA Next-Gen SDK `ads-mobile-sdk:1.4.0`, UMP) | github.com/poingstudios/godot-admob-plugin releases: `poing-godot-admob-v5.1.0.zip` + `android-template-v4.7.2.zip` | 8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f / f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee |
| godot-google-play-billing | 3.3.0 (Play Billing `billing-ktx:9.1.0`) | github.com/godot-sdk-integrations/godot-google-play-billing releases | 20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568 |

The Android `.aar` binaries are committed (`addons/admob/android/bin/`, `addons/GodotGooglePlayBilling/bin/`), so exports are reproducible without network access to the plugin releases. The C# part of Poing was left out. Poing downloads iOS binaries itself on headless runs; `addons/admob/ios/bin/` is git-ignored because the project is Android-only.

## Export requirements
- **Gradle build is on** (`gradle_build/use_gradle_build=true`). Install the build template once per clone: in the Editor, use Project → Install Android Build Template. Or by hand: unzip `export_templates/4.7.2.stable/android_source.zip` into `android/build/`, write `4.7.2.stable` to `android/.build_version`, and touch `android/build/.gdignore`. `/android/` is git-ignored.
- The first Gradle export needs network access for Maven (GMA SDK, billing).
- The 1.0.41 box export was signed with `/workspace/android/neil-laptop-debug.keystore`. It used env overrides, so the laptop path in the committed preset still works:
  `GODOT_ANDROID_KEYSTORE_DEBUG_PATH=... GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android godot --headless --path . --export-debug Android out.apk`
- A Gradle debug APK is about 110 MB versus about 35 MB before. Most of that is the uncompressed, page-aligned debug `libgodot_android.so` that Gradle stores, plus the GMA and billing dex. A release AAB will be far smaller.

## Configuration
- `config/ads.cfg` holds the ad unit IDs (test and live), `force_test_ids`, the UMP debug geography, test devices and `max_ad_content_rating=G`. Debug builds always use the test IDs. Release builds also use them while `force_test_ids=true`. If the live interstitial ID is empty, release builds show no ads.
- The **manifest app ID** comes from the project setting `admob/general/android/app_id` in project.godot, which Poing's exporter reads. It is currently absent from project.godot: Godot drops settings that equal their default, and Poing's default is the test app ID `ca-app-pub-3940256099942544~3347511713`. The 1.0.41 manifest was checked and contains that ID. Set the setting explicitly, in the Editor or in project.godot, when going live. Keep it in sync with `config/ads.cfg`.
- Billing product: non-consumable `remove_ads` (`[billing] remove_ads_product_id`).

## Behaviour
- **Consent:** on every launch, the `Ads` autoload (`scritps/ads/AdsManager.gd`) runs the UMP consent-info update and shows the form if required, then initialises AdMob only if consent status is OBTAINED or NOT_REQUIRED. Poing 5.1.0 has no `canRequestAds()`, so this is the equivalent check. Settings → Ads → "Privacy settings" appears only when UMP says privacy options are required.
- **Interstitials only.** No banners or rewarded ads. They show only when you tap Next after a cleared level, or return to the menu after a cleared level. The rules are in `scritps/ads/AdCapPolicy.gd`:
  - Never during play, in tutorial levels, in daily puzzles, in playtest or audit mode, or after Remove ads.
  - First session (launch_count == 1): none in the first 5 minutes.
  - None before 3 cleared levels.
  - After each ad: at least 3 levels **and** 3 minutes before the next.
  - Ads are preloaded. If none is ready, the game carries on silently. A 6 s watchdog continues the game if the SDK never reports the ad as shown.
- **Remove ads** (`scritps/ads/RemoveAdsStore.gd`):
  - Buttons: the level-complete overlay, Settings → Ads → Remove ads / Restore purchases, and a gentle prompt after an interstitial (at most once per session).
  - A PURCHASED item grants the entitlement and is acknowledged. PENDING is not granted.
  - Every launch and reconnect runs a purchases query. A successful query without the item revokes the entitlement. A failed query never revokes.
  - The local flag `ads_removed` is saved in `user://ads.cfg`. Setting it destroys the preloaded ad, and no more ads load.
- **No plugin** (desktop, editor, headless): everything is a silent no-op.

## Checks
- `godot --headless --path . -s res://scritps/tools/ads_checks.gd`: caps, gates, purchase evaluation, and the no-plugin smoke test.
- `godot --headless --path . -s res://scritps/tools/daily_checks.gd`

## Before going live (not done)
- Create the AdMob app and interstitial unit. Put the IDs in `[ids_live]` and in `admob/general/android/app_id`, then set `force_test_ids=false`.
- Create the `remove_ads` in-app product in Play Console and test with licence testers on an internal track.
- Configure the UMP / GDPR message in AdMob → Privacy & messaging.
- Update the Play Data safety form (advertising ID, ads) and the "Contains ads" flag. Review the target-audience / Families settings: `max_ad_content_rating=G` is set, but the app is **not** tagged child-directed.
- There is no server-side purchase verification.
