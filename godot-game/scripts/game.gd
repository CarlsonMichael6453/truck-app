extends Node

## Local garage save. user://truck_bay.json survives an app restart.
## The web app keeps its own localStorage key and is not read or written here.

const SAVE_PATH := "user://truck_bay.json"

signal changed
signal toast_emitted(text: String)

var autosave := true
var coins := 750
var cores := 0
var owned: Array[String] = []
var truck_id := "ridgehaul-summit"
var loadouts := {}
var stats := {}
var quest_rewarded: Array[String] = []
var seen_intro := false
var sound := false


func _ready() -> void:
	_apply_default()
	load_save()


func truck() -> Dictionary:
	var spec := Catalog.truck(truck_id)
	return spec if not spec.is_empty() else Catalog.TRUCKS[0]


func loadout() -> Dictionary:
	if not loadouts.has(truck_id):
		loadouts[truck_id] = Catalog.starter_loadout(truck())
	return loadouts[truck_id]


func signature() -> String:
	return truck_id + "|" + JSON.stringify(loadout())


func metric(name: String) -> int:
	match name:
		"runs":
			return int(stats.get("runs", 0))
		"clean":
			return int(stats.get("clean_finishes", 0))
		"best_coins":
			return int(stats.get("best_coins", 0))
		"best_distance":
			return int(stats.get("best_distance", 0))
		"gulch":
			return int(stats.get("gulch_finishes", 0))
		"parts":
			return int(stats.get("parts_bought", 0))
		"dailies":
			return int(stats.get("dailies_claimed", 0))
	return 0


func quest_views() -> Array[Dictionary]:
	var views: Array[Dictionary] = []
	for quest in Catalog.QUESTS:
		var raw := metric(str(quest["metric"]))
		var goal := int(quest["goal"])
		views.append({
			"id": quest["id"],
			"title": quest["title"],
			"detail": quest["detail"],
			"goal": goal,
			"value": mini(raw, goal),
			"done": quest_rewarded.has(str(quest["id"])),
		})
	return views


func preview_streak(today: String) -> int:
	var last := str(stats.get("last_daily", ""))
	if last == today:
		return int(stats.get("streak", 0))
	if last != "" and last == Catalog.previous_day(today):
		return int(stats.get("streak", 0)) + 1
	return 1


func today() -> String:
	return Time.get_date_string_from_system()


func select_truck(id: String) -> void:
	if Catalog.truck(id).is_empty():
		_fail("That truck isn't in the bay.")
		return
	truck_id = id
	_commit([])


func set_paint(id: String) -> void:
	if Catalog.paint(id).is_empty():
		_fail("Unknown paint.")
		return
	loadout()["paint"] = id
	_commit([])


func set_finish(id: String) -> void:
	if Catalog.finish(id).is_empty():
		_fail("Unknown finish.")
		return
	loadout()["finish"] = id
	_commit([])


func equip(part_id: String) -> void:
	var item := Catalog.part(part_id)
	if item.is_empty():
		_fail("Unknown part.")
		return
	if not owned.has(part_id):
		_fail("You don't own that yet.")
		return
	loadout()[str(item["slot"])] = part_id
	_commit([])


func debug_own(part_id: String) -> void:
	if Catalog.part(part_id).is_empty():
		return
	if not owned.has(part_id):
		owned.append(part_id)
	_commit([])


func buy(part_id: String, currency: String) -> void:
	var item := Catalog.part(part_id)
	if item.is_empty():
		_fail("Unknown part.")
		return
	if owned.has(part_id):
		_fail("Already in the garage.")
		return
	var price := int(item["coins"] if currency == "coins" else item["cores"])
	var balance := coins if currency == "coins" else cores
	if price <= 0:
		_fail("That part is already included.")
		return
	if balance < price:
		_fail("Not enough coins yet." if currency == "coins" else "Not enough Cores.")
		return
	if currency == "coins":
		coins -= price
	else:
		cores -= price
	owned.append(part_id)
	stats["parts_bought"] = int(stats.get("parts_bought", 0)) + 1
	loadout()[str(item["slot"])] = part_id
	var notes: Array[String] = ["%s equipped." % item["name"]]
	notes.append_array(_grant_ready())
	_commit(notes)


func claim_daily(day: String) -> void:
	if day.length() != 10:
		_fail("Bad date.")
		return
	if str(stats.get("last_daily", "")) == day:
		_fail("Already claimed today.")
		return
	var last := str(stats.get("last_daily", ""))
	var streak := 1
	if last != "" and last == Catalog.previous_day(day):
		streak = int(stats.get("streak", 0)) + 1
	var reward: Dictionary = Catalog.DAILY[(streak - 1) % Catalog.DAILY.size()]
	stats["streak"] = streak
	stats["last_daily"] = day
	stats["dailies_claimed"] = int(stats.get("dailies_claimed", 0)) + 1
	var notes: Array[String] = []
	var part_id := str(reward.get("part", ""))
	if part_id != "":
		var item := Catalog.part(part_id)
		if not item.is_empty() and not owned.has(part_id):
			owned.append(part_id)
			notes.append("%s is in the garage." % item["name"])
		else:
			var extra := int(reward.get("duplicate_coins", 0))
			coins += extra
			notes.append("You already had that part. +%s coins instead." % Catalog.commas(extra))
	var bonus := int(reward.get("coins", 0))
	if bonus > 0:
		coins += bonus
		notes.append("Daily bay: +%s coins." % Catalog.commas(bonus))
	notes.append_array(_grant_ready())
	_commit(notes)


func apply_run(payout: Dictionary) -> Dictionary:
	var counted := bool(payout.get("finished", false)) or int(payout.get("distance", 0)) >= 40
	coins += maxi(0, int(payout.get("coins", 0)))
	if counted:
		stats["runs"] = int(stats.get("runs", 0)) + 1
	if bool(payout.get("finished", false)):
		stats["finishes"] = int(stats.get("finishes", 0)) + 1
	if bool(payout.get("clean", false)):
		stats["clean_finishes"] = int(stats.get("clean_finishes", 0)) + 1
	if bool(payout.get("finished", false)) and str(payout.get("track_id", "")) == "gulch":
		stats["gulch_finishes"] = int(stats.get("gulch_finishes", 0)) + 1
	stats["best_distance"] = maxi(int(stats.get("best_distance", 0)), int(payout.get("distance", 0)))
	stats["best_coins"] = maxi(int(stats.get("best_coins", 0)), int(payout.get("coins", 0)))
	var notes: Array[String] = ["Banked %s coins from the trail." % Catalog.commas(int(payout.get("coins", 0)))]
	notes.append_array(_grant_ready())
	_commit(notes)
	return {"notes": notes}


func grant_product(product_id: String, transaction_id: String) -> Dictionary:
	var product := Catalog.product(product_id)
	if product.is_empty():
		return {"ok": false, "message": "Unknown product."}
	for receipt in stats.get("receipts", []):
		if str(receipt.get("id", "")) == transaction_id:
			return {"ok": false, "message": "That receipt was already applied."}
	var purchased: Array = stats.get("purchased_product_ids", [])
	if str(product["kind"]) == "nonconsumable" and product_id in purchased:
		return {"ok": false, "message": "You already own this kit."}
	cores += int(product.get("cores", 0))
	coins += int(product.get("coins", 0))
	if str(product["kind"]) == "nonconsumable" and not purchased.has(product_id):
		purchased.append(product_id)
		stats["purchased_product_ids"] = purchased
	var names: Array[String] = []
	for id in product.get("parts", []):
		var item := Catalog.part(str(id))
		if item.is_empty() or owned.has(str(id)):
			continue
		owned.append(str(id))
		names.append(str(item["name"]))
	var receipts: Array = stats.get("receipts", [])
	receipts.append({
		"id": transaction_id,
		"product_id": product_id,
		"at": Time.get_datetime_string_from_system(),
		"mode": "test",
	})
	if receipts.size() > 40:
		receipts = receipts.slice(receipts.size() - 40)
	stats["receipts"] = receipts
	var notes: Array[String] = []
	if int(product.get("cores", 0)) > 0:
		notes.append("%d Cores added. No charge was made." % int(product["cores"]))
	if int(product.get("coins", 0)) > 0:
		notes.append("%s coins added. No charge was made." % Catalog.commas(int(product["coins"])))
	if names.size() > 0:
		notes.append("%s landed in the garage." % ", ".join(names))
	if notes.is_empty():
		notes.append("Nothing new to add. No charge was made.")
	_grant_ready()
	_commit(notes)
	return {"ok": true, "message": " ".join(notes)}


func restore_purchases() -> Dictionary:
	var gained: Array[String] = []
	var purchased: Array = stats.get("purchased_product_ids", [])
	for receipt in stats.get("receipts", []):
		var product := Catalog.product(str(receipt.get("product_id", "")))
		if product.is_empty() or str(product.get("kind", "")) != "nonconsumable":
			continue
		for id in product.get("parts", []):
			var item := Catalog.part(str(id))
			if item.is_empty() or owned.has(str(id)):
				continue
			owned.append(str(id))
			gained.append(str(item["name"]))
		if not purchased.has(product["id"]):
			purchased.append(product["id"])
	stats["purchased_product_ids"] = purchased
	var message := "Restored %s." % ", ".join(gained) if gained.size() else "Nothing to restore."
	_commit([message])
	return {"ok": true, "message": message}


func reset_progress() -> void:
	_apply_default()
	_commit(["This device was reset. No charge was involved."])


func dismiss_intro() -> void:
	seen_intro = true
	_commit([])


func toggle_sound() -> void:
	sound = not sound
	_commit([])


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"coins": coins,
		"cores": cores,
		"owned": owned.duplicate(),
		"truck_id": truck_id,
		"loadouts": loadouts.duplicate(true),
		"stats": stats.duplicate(true),
		"quest_rewarded": quest_rewarded.duplicate(),
		"seen_intro": seen_intro,
		"sound": sound,
	}


func save_save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(to_dict(), "\t"))


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_apply_dict(parsed)


func _apply_default() -> void:
	coins = 750
	cores = 0
	owned = []
	for item in Catalog.PARTS:
		if Catalog.is_free(item):
			owned.append(str(item["id"]))
	truck_id = "ridgehaul-summit"
	loadouts = {}
	for spec in Catalog.TRUCKS:
		loadouts[str(spec["id"])] = Catalog.starter_loadout(spec)
	stats = {
		"runs": 0,
		"finishes": 0,
		"clean_finishes": 0,
		"best_distance": 0,
		"best_coins": 0,
		"gulch_finishes": 0,
		"parts_bought": 0,
		"dailies_claimed": 0,
		"streak": 0,
		"last_daily": "",
		"purchased_product_ids": [],
		"receipts": [],
	}
	quest_rewarded = []
	seen_intro = false
	sound = false


func _apply_dict(data: Dictionary) -> void:
	_apply_default()
	var keep: Array[String] = owned.duplicate()
	if data.get("owned") is Array:
		for id in data["owned"]:
			var text := str(id)
			if not Catalog.part(text).is_empty() and not keep.has(text):
				keep.append(text)
	owned = keep
	var wanted := str(data.get("truck_id", truck_id))
	truck_id = wanted if not Catalog.truck(wanted).is_empty() else truck_id
	if data.get("loadouts") is Dictionary:
		for spec in Catalog.TRUCKS:
			var candidate = data["loadouts"].get(spec["id"], {})
			loadouts[str(spec["id"])] = _clean_loadout(candidate, Catalog.starter_loadout(spec))
	coins = _count(data.get("coins"), coins)
	cores = _count(data.get("cores"), cores)
	if data.get("stats") is Dictionary:
		stats = _clean_stats(data["stats"])
	quest_rewarded = []
	if data.get("quest_rewarded") is Array:
		for id in data["quest_rewarded"]:
			var text := str(id)
			for quest in Catalog.QUESTS:
				if quest["id"] == text and not quest_rewarded.has(text):
					quest_rewarded.append(text)
	seen_intro = data.get("seen_intro") == true
	sound = data.get("sound") == true


func _clean_loadout(candidate, fallback: Dictionary) -> Dictionary:
	var source: Dictionary = candidate if candidate is Dictionary else {}
	var next := fallback.duplicate()
	if not Catalog.paint(str(source.get("paint", ""))).is_empty():
		next["paint"] = str(source["paint"])
	if not Catalog.finish(str(source.get("finish", ""))).is_empty():
		next["finish"] = str(source["finish"])
	for slot in ["wheel", "tire", "lift", "bumper", "light", "exhaust", "spoiler", "wrap"]:
		next[slot] = _owned_slot(source.get(slot), slot, str(fallback[slot]))
	return next


func _owned_slot(id, slot: String, fallback: String) -> String:
	var text := str(id)
	var item := Catalog.part(text)
	if item.is_empty() or str(item["slot"]) != slot or not owned.has(text):
		return fallback
	return text


func _clean_stats(raw: Dictionary) -> Dictionary:
	var next := stats.duplicate(true)
	for key in ["runs", "finishes", "clean_finishes", "best_distance", "best_coins", "gulch_finishes", "parts_bought", "dailies_claimed", "streak"]:
		next[key] = _count(raw.get(key), 0)
	var last := str(raw.get("last_daily", ""))
	next["last_daily"] = last if last.length() == 10 else ""
	var purchased: Array = []
	if raw.get("purchased_product_ids") is Array:
		for id in raw["purchased_product_ids"]:
			if not Catalog.product(str(id)).is_empty():
				purchased.append(str(id))
	next["purchased_product_ids"] = purchased
	var receipts: Array = []
	if raw.get("receipts") is Array:
		for receipt in raw["receipts"]:
			if not (receipt is Dictionary):
				continue
			if str(receipt.get("id", "")) == "" or Catalog.product(str(receipt.get("product_id", ""))).is_empty():
				continue
			receipts.append({
				"id": str(receipt["id"]),
				"product_id": str(receipt["product_id"]),
				"at": str(receipt.get("at", "")),
				"mode": "test",
			})
	if receipts.size() > 40:
		receipts = receipts.slice(receipts.size() - 40)
	next["receipts"] = receipts
	return next


func _count(value, fallback: int) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	return clampi(int(value), 0, 1000000)


func _grant_ready() -> Array[String]:
	var notes: Array[String] = []
	for quest in Catalog.QUESTS:
		var id := str(quest["id"])
		if quest_rewarded.has(id):
			continue
		if metric(str(quest["metric"])) < int(quest["goal"]):
			continue
		quest_rewarded.append(id)
		var bonus := int(quest.get("coins", 0))
		if bonus > 0:
			coins += bonus
			notes.append("%s: +%s coins." % [quest["title"], Catalog.commas(bonus)])
		var part_id := str(quest.get("part", ""))
		if part_id == "":
			continue
		var item := Catalog.part(part_id)
		if not item.is_empty() and not owned.has(part_id):
			owned.append(part_id)
			notes.append("%s unlocked. It's in the garage." % item["name"])
		else:
			var extra := int(quest.get("duplicate_coins", 0))
			coins += extra
			notes.append("%s: you already had that part. +%s coins." % [quest["title"], Catalog.commas(extra)])
	return notes


func _commit(notes: Array) -> void:
	if autosave:
		save_save()
	changed.emit()
	for note in notes:
		var text := str(note)
		if text != "":
			toast_emitted.emit(text)


func _fail(message: String) -> void:
	toast_emitted.emit(message)
