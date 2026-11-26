class_name Billing
extends RefCounted

## The game talks to a provider. The default is a test register: it never
## charges a card and never contacts Apple or Google.
##
## Project setting truck/billing/provider:
##   test      Mock register. This is the build that ships here.
##   storekit  Godot iOS plugin singleton "InAppStore". Fails closed until wired.
##   play      Godot Google Play Billing singleton "GodotGooglePlayBilling". Fails closed until wired.

static var _current: Provider


class Provider extends RefCounted:
	var mode := "test"

	func purchase(_product_id: String, _outcome := "success") -> Dictionary:
		return {"ok": false, "code": "failed", "message": "This register cannot complete a purchase."}

	func restore() -> Dictionary:
		return {"ok": true}


class Mock extends Provider:
	var _sequence := 0

	func _init() -> void:
		mode = "test"

	func purchase(product_id: String, outcome := "success") -> Dictionary:
		if Catalog.product(product_id).is_empty():
			return {"ok": false, "code": "unknown_product", "message": "That product is not in the test catalog."}
		if outcome == "cancel":
			return {"ok": false, "code": "cancelled", "message": "Test purchase cancelled."}
		if outcome == "fail":
			return {"ok": false, "code": "failed", "message": "The test charge didn't go through. Nothing was added."}
		_sequence += 1
		return {"ok": true, "product_id": product_id, "transaction_id": "test_%s_%d" % [product_id, _sequence]}


class StoreKit extends Provider:
	func _init() -> void:
		mode = "storekit"

	func purchase(_product_id: String, _outcome := "success") -> Dictionary:
		if not Engine.has_singleton("InAppStore"):
			return {"ok": false, "code": "unavailable", "message": "StoreKit is not in this build. Test mode is the only register that can complete a purchase."}
		return {"ok": false, "code": "not_wired", "message": "The StoreKit plugin is present, but purchases are not connected. Nothing was charged."}

	func restore() -> Dictionary:
		if not Engine.has_singleton("InAppStore"):
			return {"ok": false, "code": "unavailable", "message": "StoreKit is not in this build."}
		return {"ok": false, "code": "not_wired", "message": "StoreKit restore is not connected. Nothing changed."}

	## Not called. The sequence for the official Godot iOS plugin, when a
	## sandbox build should talk to StoreKit for real:
	##
	##   var store = Engine.get_singleton("InAppStore")
	##   store.set_auto_finish_transaction(true)
	##   store.request_product_info({"product_ids": [product_id]})
	##   store.purchase({"product_id": product_id})
	##   # product_purchased(product) -> Game.grant_product(product_id, transaction_id)
	##   # product_purchase_failed(product, error) -> show the error, grant nothing
	##   # restore_purchases() replays non-consumable kits only
	## Coin packs and Core packs are consumable. Kits are non-consumable.
	func integration_notes() -> String:
		return "InAppStore.request_product_info / purchase / restore_purchases"


class PlayBilling extends Provider:
	func _init() -> void:
		mode = "play"

	func purchase(_product_id: String, _outcome := "success") -> Dictionary:
		if not Engine.has_singleton("GodotGooglePlayBilling"):
			return {"ok": false, "code": "unavailable", "message": "Google Play Billing is not in this build. Test mode is the only register that can complete a purchase."}
		return {"ok": false, "code": "not_wired", "message": "The Play Billing plugin is present, but purchases are not connected. Nothing was charged."}

	func restore() -> Dictionary:
		if not Engine.has_singleton("GodotGooglePlayBilling"):
			return {"ok": false, "code": "unavailable", "message": "Google Play Billing is not in this build."}
		return {"ok": false, "code": "not_wired", "message": "Play Billing restore is not connected. Nothing changed."}

	## Not called. The sequence for godot-google-play-billing:
	##
	##   var billing = Engine.get_singleton("GodotGooglePlayBilling")
	##   billing.startConnection()
	##   # signal connected -> billing.queryProductDetails([product_id], "inapp")
	##   # signal product_details_query_completed -> billing.purchase(product_id)
	##   # signal purchases_updated:
	##   #   consumable (coins, cores) -> billing.consumePurchase(token)
	##   #   kit -> billing.acknowledgePurchase(token)
	##   #   then Game.grant_product(product_id, order_id)
	func integration_notes() -> String:
		return "GodotGooglePlayBilling.startConnection / queryProductDetails / purchase"


class Closed extends Provider:
	func _init(bad_mode: String) -> void:
		mode = bad_mode

	func purchase(_product_id: String, _outcome := "success") -> Dictionary:
		return {"ok": false, "code": "refused", "message": "Billing provider \"%s\" is not connected. Nothing was charged." % mode}

	func restore() -> Dictionary:
		return {"ok": false, "code": "refused", "message": "Billing provider \"%s\" cannot restore purchases." % mode}


static func create(which: String) -> Provider:
	match which:
		"test", "mock", "":
			return Mock.new()
		"storekit":
			return StoreKit.new()
		"play", "google":
			return PlayBilling.new()
		_:
			return Closed.new(which)


static func current() -> Provider:
	if _current == null:
		var which := str(ProjectSettings.get_setting("truck/billing/provider", "test"))
		_current = create(which)
	return _current


static func reset_for_tests() -> void:
	_current = null
