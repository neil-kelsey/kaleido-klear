class_name RemoveAdsStore
extends Node

## Google Play Billing wrapper for the single non-consumable "remove_ads" product.
## Uses the official GodotGooglePlayBilling plugin (addons/GodotGooglePlayBilling, v3.3.0).
## Without the Android singleton (desktop / editor / headless) every call is a no-op and
## is_available() is false. Client-side only (no backend verification): see docs/ads.md.

signal entitlement_changed(owned: bool)
## A user-facing status, as a translation key (UI_*).
signal status(message_key: String)

const SINGLETON := "GodotGooglePlayBilling"
const CLIENT_SCRIPT := "res://addons/GodotGooglePlayBilling/BillingClient.gd"

## Mirrors BillingClient enums (kept numeric so this file never needs the addon to parse).
const RC_OK := 0
const RC_USER_CANCELED := 1
const RC_ITEM_ALREADY_OWNED := 7
const PRODUCT_INAPP := 0
const STATE_PURCHASED := 1
const STATE_PENDING := 2
const MAX_RECONNECTS := 3

var product_id := "remove_ads"
var _client: Node = null
var _product_ready := false
var _purchase_after_details := false
var _user_restore := false
var _reconnects := 0


## Pure: decide what a purchases list means for product_id.
## Returns {owned: bool, pending: bool, to_acknowledge: PackedStringArray}.
static func evaluate_purchases(purchases: Array, pid: String) -> Dictionary:
	var owned := false
	var pending := false
	var to_ack := PackedStringArray()
	for p in purchases:
		if not (p is Dictionary):
			continue
		var ids = p.get("product_ids", [])
		var has_pid := false
		for id in ids:
			if str(id) == pid:
				has_pid = true
		if not has_pid:
			continue
		match int(p.get("purchase_state", 0)):
			STATE_PURCHASED:
				owned = true
				if not bool(p.get("is_acknowledged", false)):
					var token := str(p.get("purchase_token", ""))
					if not token.is_empty():
						to_ack.append(token)
			STATE_PENDING:
				pending = true
	return {"owned": owned, "pending": pending, "to_acknowledge": to_ack}


func is_available() -> bool:
	return _client != null


func start() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton(SINGLETON):
		return
	var script: Script = load(CLIENT_SCRIPT)
	if script == null:
		return
	_client = script.new()
	_client.name = "BillingClient"
	add_child(_client)
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_query_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.acknowledge_purchase_response.connect(_on_acknowledged)
	_client.start_connection()


func purchase() -> void:
	if _client == null:
		status.emit("UI_STORE_UNAVAILABLE")
		return
	if not _client.is_ready():
		_purchase_after_details = true
		_reconnect()
		return
	if not _product_ready:
		_purchase_after_details = true
		_client.query_product_details(PackedStringArray([product_id]), PRODUCT_INAPP)
		return
	_launch_purchase()


func restore() -> void:
	if _client == null:
		status.emit("UI_STORE_UNAVAILABLE")
		return
	_user_restore = true
	if not _client.is_ready():
		_reconnect()
		return
	_client.query_purchases(PRODUCT_INAPP)


func _launch_purchase() -> void:
	_purchase_after_details = false
	var res: Dictionary = _client.purchase(product_id)
	if int(res.get("response_code", -999)) != RC_OK:
		status.emit("UI_STORE_UNAVAILABLE")


func _reconnect() -> void:
	if _client != null and _client.get_connection_state() != 1:
		_client.start_connection()


func _on_connected() -> void:
	_reconnects = 0
	_client.query_product_details(PackedStringArray([product_id]), PRODUCT_INAPP)
	## Restore on every launch / reconnect.
	_client.query_purchases(PRODUCT_INAPP)


func _on_disconnected() -> void:
	if _reconnects < MAX_RECONNECTS:
		_reconnects += 1
		get_tree().create_timer(5.0 * _reconnects).timeout.connect(_reconnect)


func _on_connect_error(_code: int, _msg: String) -> void:
	if _purchase_after_details or _user_restore:
		_purchase_after_details = false
		_user_restore = false
		status.emit("UI_STORE_UNAVAILABLE")


func _on_product_details(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) != RC_OK:
		if _purchase_after_details:
			_purchase_after_details = false
			status.emit("UI_STORE_UNAVAILABLE")
		return
	for d in res.get("product_details", []):
		if d is Dictionary and str(d.get("product_id", "")) == product_id:
			_product_ready = true
	if _purchase_after_details:
		if _product_ready:
			_launch_purchase()
		else:
			_purchase_after_details = false
			status.emit("UI_STORE_UNAVAILABLE")


func _on_query_purchases(res: Dictionary) -> void:
	var was_user := _user_restore
	_user_restore = false
	if int(res.get("response_code", -1)) != RC_OK:
		## Never revoke on an error (offline etc.); keep the local flag.
		if was_user:
			status.emit("UI_STORE_UNAVAILABLE")
		return
	var r := _apply(res.get("purchases", []), true)
	if was_user:
		if r.owned:
			status.emit("UI_PURCHASES_RESTORED")
		elif r.pending:
			status.emit("UI_PURCHASE_PENDING")
		else:
			status.emit("UI_NOTHING_TO_RESTORE")


func _on_purchase_updated(res: Dictionary) -> void:
	var code := int(res.get("response_code", -1))
	match code:
		RC_OK:
			var r := _apply(res.get("purchases", []), false)
			if r.owned:
				status.emit("UI_ADS_REMOVED")
			elif r.pending:
				status.emit("UI_PURCHASE_PENDING")
		RC_USER_CANCELED:
			pass
		RC_ITEM_ALREADY_OWNED:
			_user_restore = true
			_client.query_purchases(PRODUCT_INAPP)
		_:
			status.emit("UI_PURCHASE_FAILED")


func _on_acknowledged(_res: Dictionary) -> void:
	## If acknowledging failed, the next launch's query re-sends it (still unacknowledged).
	pass


## authoritative = this is a full purchases query, so absence means "not owned" (refund/revoke).
func _apply(purchases: Array, authoritative: bool) -> Dictionary:
	var r := evaluate_purchases(purchases, product_id)
	for token in r.to_acknowledge:
		_client.acknowledge_purchase(token)
	if r.owned:
		entitlement_changed.emit(true)
	elif authoritative:
		entitlement_changed.emit(false)
	return r
