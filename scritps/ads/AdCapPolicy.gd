class_name AdCapPolicy
extends RefCounted

## Pure frequency-cap / grace-period rules for interstitials (ADS-BRIEF section 4).
## No engine singletons here, so it can be checked headless (scritps/tools/ads_checks.gd).

const FIRST_SESSION_GRACE_SEC := 300.0
const MIN_LEVELS_BEFORE_FIRST_AD := 3
const MIN_SECONDS_BETWEEN_ADS := 180.0
const MIN_LEVELS_BETWEEN_ADS := 3

var is_first_session: bool = true
## Levels cleared since the ads system was installed (persisted by Ads).
var total_levels_cleared: int = 0
## Levels cleared since the last interstitial was shown (persisted by Ads).
var levels_since_last_ad: int = 0
## Unix time of the last interstitial shown; 0 = never.
var last_ad_unix: float = 0.0


func record_level_cleared() -> void:
	total_levels_cleared += 1
	levels_since_last_ad += 1


func record_ad_shown(now_unix: float) -> void:
	last_ad_unix = now_unix
	levels_since_last_ad = 0


## Returns "" when an interstitial may be shown now, otherwise a short reason.
## ctx keys (all optional, default false): ads_removed, can_request_ads, tutorial, daily,
## in_play, ad_ready.
func block_reason(now_unix: float, session_elapsed_sec: float, ctx: Dictionary) -> String:
	if bool(ctx.get("ads_removed", false)):
		return "ads_removed"
	if not bool(ctx.get("can_request_ads", false)):
		return "no_consent_or_sdk"
	if bool(ctx.get("in_play", false)):
		return "in_play"
	if bool(ctx.get("tutorial", false)):
		return "tutorial"
	if bool(ctx.get("daily", false)):
		return "daily"
	if is_first_session and session_elapsed_sec < FIRST_SESSION_GRACE_SEC:
		return "first_session_grace"
	if total_levels_cleared < MIN_LEVELS_BEFORE_FIRST_AD:
		return "too_few_levels"
	if levels_since_last_ad < MIN_LEVELS_BETWEEN_ADS:
		return "level_cap"
	if last_ad_unix > 0.0:
		var since := now_unix - last_ad_unix
		## A clock moved backwards (since < 0) just re-arms the timer from now.
		if since >= 0.0 and since < MIN_SECONDS_BETWEEN_ADS:
			return "time_cap"
	if not bool(ctx.get("ad_ready", false)):
		return "not_ready"
	return ""


func to_dict() -> Dictionary:
	return {
		"total_levels_cleared": total_levels_cleared,
		"levels_since_last_ad": levels_since_last_ad,
		"last_ad_unix": last_ad_unix,
	}


func from_dict(d: Dictionary) -> void:
	total_levels_cleared = int(d.get("total_levels_cleared", 0))
	levels_since_last_ad = int(d.get("levels_since_last_ad", 0))
	last_ad_unix = float(d.get("last_ad_unix", 0.0))
