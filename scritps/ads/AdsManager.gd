extends Node

## Autoload "Ads": UMP consent -> AdMob init -> preloaded interstitials at natural breaks,
## plus the "Remove ads" entitlement (RemoveAdsStore). See docs/ads.md and
## /home/box/shared/veilmoth-monetisation/ADS-BRIEF.md.
##
## Degrades to a silent no-op when the Poing AdMob / Play Billing singletons are missing
## (desktop, editor, headless, or an export without Gradle build): never crashes, never blocks.

signal ads_removed_changed(removed: bool)
signal privacy_options_changed
## User-facing store/purchase status as a translation key.
signal store_status(message_key: String)

const CONFIG_PATH := "res://config/ads.cfg"
const STATE_PATH := "user://ads.cfg"
const ADMOB_SINGLETON := "PoingGodotAdMob"
const CONSENT_SINGLETON := "PoingGodotAdMobConsentInformation"
const PROMPT_SCENE := "res://scenes/ui/exit_confirm_modal.tscn"
## If the SDK never reports "showed" after show(), continue the game anyway.
const SHOW_WATCHDOG_SEC := 6.0
const RELOAD_BACKOFF_SEC := [15.0, 60.0, 180.0]

var ads_removed: bool = false
var policy := AdCapPolicy.new()
var store: RemoveAdsStore

var _launch_count := 0
var _session_start_ms := 0
var _use_test_ids := true
var _interstitial_unit := ""
var _cfg := ConfigFile.new()

var _admob_available := false
var _consent_started := false
var _consent_done := false
var _can_request_ads := false
var _ads_init_started := false
var _ads_initialized := false

var _interstitial: Object = null
var _loader: Object = null
var _loading := false
var _load_failures := 0
var _showing := false
var _ad_showed := false
var _after_ad: Callable = Callable()
var _prompted_this_session := false
var _prompt_layer: CanvasLayer = null
var _prompt_modal: Control = null
var _prompt_after: Callable = Callable()


func _ready() -> void:
	_session_start_ms = Time.get_ticks_msec()
	_load_config()
	_load_state()
	_launch_count += 1
	policy.is_first_session = _launch_count <= 1
	_save_state()

	store = RemoveAdsStore.new()
	store.name = "RemoveAdsStore"
	store.product_id = str(_cfg.get_value("billing", "remove_ads_product_id", "remove_ads"))
	add_child(store)
	store.entitlement_changed.connect(_on_entitlement_changed)
	store.status.connect(func(key: String) -> void: store_status.emit(key))
	store.start()

	_admob_available = (
		OS.get_name() == "Android"
		and Engine.has_singleton(ADMOB_SINGLETON)
		and Engine.has_singleton(CONSENT_SINGLETON)
		and not _interstitial_unit.is_empty()
	)
	if _admob_available:
		## Consent on every launch, before any ad SDK init.
		call_deferred("_start_consent_flow")


# --- public API -------------------------------------------------------------

func is_ads_supported() -> bool:
	return _admob_available


func is_store_available() -> bool:
	return store != null and store.is_available()


func is_showing_ad() -> bool:
	return _showing


func session_elapsed_sec() -> float:
	return float(Time.get_ticks_msec() - _session_start_ms) / 1000.0


## Call once per genuine level clear (not playtest / audit).
func notify_level_cleared() -> void:
	policy.record_level_cleared()
	_save_state()
	_preload()


## Why an interstitial would (not) show right now. "" = it would show.
func interstitial_block_reason(ctx: Dictionary = {}) -> String:
	var full := ctx.duplicate()
	full["ads_removed"] = ads_removed
	full["can_request_ads"] = _admob_available and _can_request_ads and _ads_initialized
	full["ad_ready"] = _interstitial != null and not _showing
	return policy.block_reason(Time.get_unix_time_from_system(), session_elapsed_sec(), full)


## Only call at a natural break (level-complete screen / returning to the menu).
## Returns true if an ad is being shown: `after` is then called once it is dismissed
## (and after the optional remove-ads prompt). Returns false (and does NOT call `after`)
## when no ad is shown; the caller just carries on.
func try_show_interstitial(ctx: Dictionary, after: Callable) -> bool:
	if _showing:
		return false
	var reason := interstitial_block_reason(ctx)
	if not reason.is_empty():
		if reason == "not_ready":
			_preload()
		return false
	_showing = true
	_ad_showed = false
	_after_ad = after
	policy.record_ad_shown(Time.get_unix_time_from_system())
	_save_state()
	var ad: Object = _interstitial
	_interstitial = null
	var cb: Object = ad.full_screen_content_callback
	cb.on_ad_showed_full_screen_content = func() -> void: _ad_showed = true
	cb.on_ad_dismissed_full_screen_content = func() -> void: _finish_ad(ad, true)
	cb.on_ad_failed_to_show_full_screen_content = func(_err) -> void: _finish_ad(ad, false)
	ad.show()
	get_tree().create_timer(SHOW_WATCHDOG_SEC).timeout.connect(func() -> void:
		if _showing and not _ad_showed:
			_finish_ad(ad, false)
	)
	return true


func purchase_remove_ads() -> void:
	if ads_removed:
		store_status.emit("UI_ADS_REMOVED")
		return
	store.purchase()


func restore_purchases() -> void:
	store.restore()


func is_privacy_options_required() -> bool:
	if not _admob_available:
		return false
	return (
		UserMessagingPlatform.consent_information.get_privacy_options_requirement_status()
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
	)


func show_privacy_options() -> void:
	if not _admob_available:
		return
	UserMessagingPlatform.show_privacy_options_form(func(_err) -> void:
		_refresh_can_request()
		privacy_options_changed.emit()
		_ensure_ads_started()
	)


## Back button while the remove-ads prompt is open closes it. Returns true if consumed.
func handle_back() -> bool:
	if _prompt_modal != null and _prompt_modal.visible:
		_prompt_modal.hide_modal()
		_on_prompt_closed(false)
		return true
	return false


# --- consent / init ------------------------------------------------------------

func _start_consent_flow() -> void:
	if not _admob_available or _consent_started:
		return
	_consent_started = true
	var params := ConsentRequestParameters.new()
	if OS.is_debug_build():
		var geo := str(_cfg.get_value("ads", "ump_debug_geography", ""))
		if not geo.is_empty():
			var dbg := ConsentDebugSettings.new()
			dbg.debug_geography = (
				DebugGeography.Values.EEA if geo == "EEA" else DebugGeography.Values.NOT_EEA
			)
			var hashed: Array[String] = []
			for h in _cfg.get_value("ads", "ump_test_device_hashed_ids", PackedStringArray()):
				hashed.append(str(h))
			dbg.test_device_hashed_ids = hashed
			params.consent_debug_settings = dbg
	UserMessagingPlatform.consent_information.update(
		params, _on_consent_info_updated, func(_err) -> void: _after_consent()
	)


func _on_consent_info_updated() -> void:
	privacy_options_changed.emit()
	if ads_removed:
		## No ads will be requested, so don't interrupt the player with the form.
		_after_consent()
		return
	var info := UserMessagingPlatform.consent_information
	if (
		info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED
		and info.get_is_consent_form_available()
	):
		UserMessagingPlatform.load_consent_form(
			func(form) -> void:
				form.show(func(_err) -> void: _after_consent()),
			func(_err) -> void: _after_consent()
		)
	else:
		_after_consent()


func _refresh_can_request() -> void:
	if not _admob_available:
		_can_request_ads = false
		return
	var s := UserMessagingPlatform.consent_information.get_consent_status()
	## Equivalent of ConsentInformation.canRequestAds() (not exposed by Poing v5.1.0).
	_can_request_ads = (
		s == ConsentInformation.ConsentStatus.OBTAINED
		or s == ConsentInformation.ConsentStatus.NOT_REQUIRED
	)


func _after_consent() -> void:
	_consent_done = true
	_refresh_can_request()
	privacy_options_changed.emit()
	_ensure_ads_started()


func _ensure_ads_started() -> void:
	if not _admob_available or ads_removed:
		return
	if not _consent_done:
		_start_consent_flow()
		return
	if not _can_request_ads or _ads_init_started:
		if _ads_initialized:
			_preload()
		return
	_ads_init_started = true
	var rc := RequestConfiguration.new()
	rc.max_ad_content_rating = str(_cfg.get_value("ads", "max_ad_content_rating", "G"))
	var test_ids: Array[String] = []
	for id in _cfg.get_value("ads", "admob_test_device_ids", PackedStringArray()):
		test_ids.append(str(id))
	rc.test_device_ids = test_ids
	MobileAds.set_request_configuration(rc)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status) -> void:
		_ads_initialized = true
		_preload()
	MobileAds.initialize(listener)


func _preload() -> void:
	if (
		not _ads_initialized
		or not _can_request_ads
		or ads_removed
		or _loading
		or _interstitial != null
	):
		return
	_loading = true
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad) -> void:
		_loading = false
		_load_failures = 0
		if ads_removed:
			ad.destroy()
			return
		_interstitial = ad
	cb.on_ad_failed_to_load = func(_err) -> void:
		_loading = false
		var wait: float = RELOAD_BACKOFF_SEC[mini(_load_failures, RELOAD_BACKOFF_SEC.size() - 1)]
		_load_failures += 1
		get_tree().create_timer(wait).timeout.connect(_preload)
	_loader = InterstitialAdLoader.new()
	_loader.load(_interstitial_unit, AdRequest.new(), cb)


func _finish_ad(ad: Object, _shown: bool) -> void:
	if not _showing:
		return
	_showing = false
	if ad != null:
		ad.destroy()
	_preload()
	var after := _after_ad
	_after_ad = Callable()
	if _ad_showed and _should_prompt():
		_show_prompt(after)
	elif after.is_valid():
		after.call()


# --- remove-ads prompt (at most once per session, after an interstitial) ---------

func _should_prompt() -> bool:
	return not _prompted_this_session and not ads_removed and is_store_available()


func _show_prompt(after: Callable) -> void:
	_prompted_this_session = true
	_prompt_after = after
	if _prompt_modal == null:
		var packed: PackedScene = load(PROMPT_SCENE)
		if packed == null:
			_on_prompt_closed(false)
			return
		_prompt_layer = CanvasLayer.new()
		_prompt_layer.layer = 120
		add_child(_prompt_layer)
		_prompt_modal = packed.instantiate()
		_prompt_layer.add_child(_prompt_modal)
		_prompt_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_prompt_modal.confirmed.connect(func() -> void: _on_prompt_closed(true))
		_prompt_modal.cancelled.connect(func() -> void: _on_prompt_closed(false))
	_prompt_modal.show_modal(
		"UI_REMOVE_ADS_PROMPT_TITLE", "UI_REMOVE_ADS_PROMPT_BODY", "UI_REMOVE_ADS", "UI_NOT_NOW"
	)


func _on_prompt_closed(buy: bool) -> void:
	var after := _prompt_after
	_prompt_after = Callable()
	if buy:
		purchase_remove_ads()
	if after.is_valid():
		after.call()


# --- entitlement --------------------------------------------------------------

func _on_entitlement_changed(owned: bool) -> void:
	if owned == ads_removed:
		return
	ads_removed = owned
	_save_state()
	if owned:
		## Stop ads instantly: drop the preloaded ad, never load another.
		if _interstitial != null:
			_interstitial.destroy()
			_interstitial = null
		if _prompt_modal != null and _prompt_modal.visible:
			_prompt_modal.hide_modal()
			_on_prompt_closed(false)
	else:
		_ensure_ads_started()
	ads_removed_changed.emit(ads_removed)


## Debug / tests only.
func _debug_set_ads_removed(owned: bool) -> void:
	_on_entitlement_changed(owned)


# --- config / persistence -----------------------------------------------------

func _load_config() -> void:
	if _cfg.load(CONFIG_PATH) != OK:
		push_warning("Ads: %s missing; ads disabled" % CONFIG_PATH)
		_interstitial_unit = ""
		return
	var force := bool(_cfg.get_value("ads", "force_test_ids", true))
	_use_test_ids = force or OS.is_debug_build()
	var section := "ids_test" if _use_test_ids else "ids_live"
	_interstitial_unit = str(_cfg.get_value(section, "interstitial", ""))


func _load_state() -> void:
	var f := ConfigFile.new()
	if f.load(STATE_PATH) != OK:
		return
	ads_removed = bool(f.get_value("ads", "ads_removed", false))
	_launch_count = int(f.get_value("ads", "launch_count", 0))
	policy.from_dict({
		"total_levels_cleared": f.get_value("ads", "total_levels_cleared", 0),
		"levels_since_last_ad": f.get_value("ads", "levels_since_last_ad", 0),
		"last_ad_unix": f.get_value("ads", "last_ad_unix", 0.0),
	})


func _save_state() -> void:
	var f := ConfigFile.new()
	f.set_value("ads", "ads_removed", ads_removed)
	f.set_value("ads", "launch_count", _launch_count)
	var d := policy.to_dict()
	for k in d:
		f.set_value("ads", k, d[k])
	f.save(STATE_PATH)
