extends SceneTree

## Headless checks for the ad frequency caps and Remove-ads purchase logic. Run:
##   godot --headless --path . -s res://scritps/tools/ads_checks.gd
## Pure logic only (AdCapPolicy, RemoveAdsStore.evaluate_purchases) plus a smoke test that
## the Ads autoload degrades to a no-op without the Android plugins. (The autoload itself
## bumps launch_count in user://ads.cfg, as on any launch.)

var _fails := 0
var _passes := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS ", label)
	else:
		_fails += 1
		printerr("FAIL ", label)


func _ok_ctx(extra: Dictionary = {}) -> Dictionary:
	var c := {"can_request_ads": true, "ad_ready": true}
	c.merge(extra, true)
	return c


func _initialize() -> void:
	var T0 := 1_800_000_000.0
	var p := AdCapPolicy.new()

	# First session: grace period and 3-level minimum.
	p.is_first_session = true
	_check(p.block_reason(T0, 10.0, _ok_ctx()) == "first_session_grace", "first session 10s blocked")
	_check(p.block_reason(T0, 299.0, _ok_ctx()) == "first_session_grace", "first session 299s blocked")
	_check(p.block_reason(T0, 301.0, _ok_ctx()) == "too_few_levels", "0 levels blocked after grace")
	p.record_level_cleared()
	p.record_level_cleared()
	_check(p.block_reason(T0, 400.0, _ok_ctx()) == "too_few_levels", "2 levels blocked")
	p.record_level_cleared()
	_check(p.block_reason(T0, 400.0, _ok_ctx()) == "", "3 levels + 5 min allows")

	# Hard gates.
	_check(p.block_reason(T0, 400.0, _ok_ctx({"ads_removed": true})) == "ads_removed", "ads_removed blocks")
	_check(p.block_reason(T0, 400.0, _ok_ctx({"can_request_ads": false})) == "no_consent_or_sdk", "no consent blocks")
	_check(p.block_reason(T0, 400.0, _ok_ctx({"tutorial": true})) == "tutorial", "tutorial blocks")
	_check(p.block_reason(T0, 400.0, _ok_ctx({"daily": true})) == "daily", "daily blocks")
	_check(p.block_reason(T0, 400.0, _ok_ctx({"in_play": true})) == "in_play", "mid-level blocks")
	_check(p.block_reason(T0, 400.0, _ok_ctx({"ad_ready": false})) == "not_ready", "no preloaded ad skips")

	# Caps after an ad: 3 levels AND 3 minutes.
	p.record_ad_shown(T0)
	for i in 3:
		p.record_level_cleared()
	_check(p.block_reason(T0 + 60.0, 500.0, _ok_ctx()) == "time_cap", "3 levels but 60s blocked")
	_check(p.block_reason(T0 + 179.0, 500.0, _ok_ctx()) == "time_cap", "179s blocked")
	_check(p.block_reason(T0 + 181.0, 500.0, _ok_ctx()) == "", "3 levels + 181s allows")
	p.record_ad_shown(T0 + 181.0)
	p.record_level_cleared()
	p.record_level_cleared()
	_check(p.block_reason(T0 + 2000.0, 900.0, _ok_ctx()) == "level_cap", "2 levels after ad blocked even after long time")
	p.record_level_cleared()
	_check(p.block_reason(T0 + 2000.0, 900.0, _ok_ctx()) == "", "3rd level after ad allows")

	# Clock moved backwards does not lock ads out forever.
	_check(p.block_reason(T0 - 5000.0, 900.0, _ok_ctx()) == "", "clock rollback re-arms")

	# Later sessions: no 5-minute grace, but caps persist through to_dict/from_dict.
	var q := AdCapPolicy.new()
	q.from_dict(p.to_dict())
	q.is_first_session = false
	_check(q.block_reason(T0 + 2000.0, 1.0, _ok_ctx()) == "", "second session no grace")
	var fresh := AdCapPolicy.new()
	fresh.is_first_session = false
	_check(fresh.block_reason(T0, 1.0, _ok_ctx()) == "too_few_levels", "upgrade with no ad history still needs 3 levels")

	# Purchase evaluation.
	var pid := "remove_ads"
	var E := RemoveAdsStore.evaluate_purchases
	var r: Dictionary = E.call([], pid)
	_check(not r.owned and not r.pending and r.to_acknowledge.is_empty(), "no purchases")
	r = E.call([{"product_ids": PackedStringArray([pid]), "purchase_state": 1, "purchase_token": "t1", "is_acknowledged": false}], pid)
	_check(r.owned and r.to_acknowledge == PackedStringArray(["t1"]), "purchased unacked -> owned + ack")
	r = E.call([{"product_ids": [pid], "purchase_state": 1, "purchase_token": "t2", "is_acknowledged": true}], pid)
	_check(r.owned and r.to_acknowledge.is_empty(), "purchased acked -> owned, no ack")
	r = E.call([{"product_ids": [pid], "purchase_state": 2, "purchase_token": "t3", "is_acknowledged": false}], pid)
	_check(not r.owned and r.pending and r.to_acknowledge.is_empty(), "pending -> not owned, no ack")
	r = E.call([{"product_ids": ["other"], "purchase_state": 1, "purchase_token": "t4"}], pid)
	_check(not r.owned, "other product ignored")
	r = E.call(["junk", null, {}], pid)
	_check(not r.owned, "malformed entries ignored")


func _process(_delta: float) -> bool:
	# Autoloads are ready by the first frame.
	var ads: Node = root.get_node_or_null("Ads")
	_check(ads != null, "Ads autoload present")
	if ads != null:
		_check(not ads.is_ads_supported(), "no AdMob singleton on desktop -> unsupported")
		_check(not ads.is_store_available(), "no billing singleton on desktop -> store unavailable")
		var called := [false]
		var shown: bool = ads.try_show_interstitial({}, func() -> void: called[0] = true)
		_check(not shown and not called[0], "try_show_interstitial is a silent no-op")
		_check(not ads.is_privacy_options_required(), "privacy options hidden on desktop")
		ads.purchase_remove_ads()
		ads.restore_purchases()
		_check(true, "purchase/restore without plugin do not crash")
	print("ads_checks: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
	return true
