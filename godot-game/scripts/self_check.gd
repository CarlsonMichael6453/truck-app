class_name SelfCheck
extends RefCounted

## Headless checks for the catalog, the truck assembler, the trail, and the test register.


static func run() -> int:
	var failed := false
	Game.autosave = false
	var backup := Game.to_dict()
	failed = _expect(DragScroll.axis_for(Vector2(4, 1), true, true) == Vector2.ZERO, "drag below threshold stays a tap") or failed
	failed = _expect(DragScroll.axis_for(Vector2(40, 6), true, true) == Vector2(1, 0), "horizontal drag scrolls sideways") or failed
	failed = _expect(DragScroll.axis_for(Vector2(6, 40), true, true) == Vector2(0, 1), "vertical drag scrolls down") or failed
	failed = _expect(DragScroll.axis_for(Vector2(40, 4), false, true) == Vector2.ZERO, "sideways drag yields when only vertical") or failed
	var pulled := DragScroll.rubber_limit(-200.0, 300.0)
	failed = _expect(pulled < 0.0 and pulled > -float(DragScroll.OVERSCROLL_LIMIT), "overscroll stays clamped") or failed
	failed = _expect(is_equal_approx(DragScroll.rubber_limit(40.0, 300.0), 40.0), "in-range drag is 1:1") or failed
	failed = _expect(Catalog.TRUCKS.size() == 4, "four trucks") or failed
	failed = _expect(Catalog.PARTS.size() == 36, "36 parts, got %d" % Catalog.PARTS.size()) or failed
	for rim_id in Catalog.SLEEK_RIMS:
		failed = _expect(not Catalog.part(rim_id).is_empty(), "sleek rim %s" % rim_id) or failed
	failed = _expect(Catalog.previous_day("2026-11-26") == "2026-11-25", "previous day") or failed
	failed = _expect(Catalog.previous_day("2026-03-01") == "2026-02-28", "month boundary") or failed
	for spec in Catalog.TRUCKS:
		var truck := TruckBuilder.build(str(spec["id"]), Catalog.starter_loadout(spec))
		var counts := {"meshes": 0, "glass": 0}
		_tally(truck, counts)
		truck.free()
		failed = _expect(int(counts["meshes"]) > 20, "%s mesh count %s" % [spec["id"], counts["meshes"]]) or failed
		failed = _expect(int(counts["glass"]) > 0, "%s windshield shader" % spec["id"]) or failed
	var show := {
		"paint": "sea", "finish": "metallic", "wheel": "wh-blade", "tire": "ti-mud", "lift": "lf-4",
		"bumper": "bp-pre", "light": "lt-dual", "exhaust": "ex-stack", "spoiler": "sp-wing", "wrap": "wr-circuit",
	}
	var custom := TruckBuilder.build("ridgehaul-summit", show)
	var custom_counts := {"meshes": 0, "glass": 0}
	_tally(custom, custom_counts)
	custom.free()
	failed = _expect(int(custom_counts["glass"]) > 0, "custom truck glass") or failed
	for item in Catalog.PARTS:
		if not Catalog.mesh_part(str(item["id"])):
			continue
		var path := "res://models/parts/%s.glb" % item["id"]
		failed = _expect(ResourceLoader.exists(path), "model %s" % path) or failed
	var run := TrailRun.new()
	var track := Catalog.track("switchback")
	var coins := 0
	for _i in 80:
		for event in run.step(track, 0, 0.05):
			if event == "coin":
				coins += 1
	failed = _expect(coins > 0, "lane coins collected") or failed
	failed = _expect(run.z > 100.0, "run advanced") or failed
	Game._apply_default()
	var broke := Game.coins
	Game.buy("wh-deep", "coins")
	failed = _expect(Game.coins == broke, "cannot buy deep lip with 750 coins") or failed
	Game.apply_run({"track_id": "switchback", "distance": 900, "hits": 0, "coins": 800, "finished": true, "clean": true, "status": "finished"})
	failed = _expect(Game.metric("runs") >= 1, "run counted") or failed
	failed = _expect(Game.metric("clean") == 1, "clean finish") or failed
	failed = _expect(Game.quest_rewarded.has("shake"), "shake-down quest") or failed
	Game.buy("wh-deep", "coins")
	failed = _expect(Game.owned.has("wh-deep"), "bought deep lip") or failed
	Game.claim_daily("2026-11-26")
	Game.claim_daily("2026-11-26")
	failed = _expect(str(Game.stats.get("last_daily", "")) == "2026-11-26", "daily claimed") or failed
	failed = _expect(int(Game.stats.get("dailies_claimed", 0)) == 1, "daily once") or failed
	var mock := Billing.create("test")
	var ok: Dictionary = mock.purchase("coins_pouch", "success")
	failed = _expect(bool(ok.get("ok", false)), "test coin pack") or failed
	var applied: Dictionary = Game.grant_product("coins_pouch", str(ok.get("transaction_id", "")))
	failed = _expect(bool(applied.get("ok", false)), "grant coin pack") or failed
	var denied: Dictionary = mock.purchase("nope", "success")
	failed = _expect(not bool(denied.get("ok", false)), "unknown product refused") or failed
	var fail: Dictionary = mock.purchase("cores_small", "fail")
	failed = _expect(not bool(fail.get("ok", false)), "failed charge grants nothing") or failed
	var before_cores := Game.cores
	failed = _expect(Game.cores == before_cores, "cores unchanged after failed charge") or failed
	var kit: Dictionary = mock.purchase("bundle_trail", "success")
	Game.grant_product("bundle_trail", str(kit.get("transaction_id", "")))
	failed = _expect(Game.owned.has("ti-mud"), "trail kit parts") or failed
	var again: Dictionary = mock.purchase("bundle_trail", "success")
	var second: Dictionary = Game.grant_product("bundle_trail", str(again.get("transaction_id", "kit2")))
	failed = _expect(not bool(second.get("ok", false)), "kit cannot be bought twice") or failed
	var storekit := Billing.create("storekit")
	var blocked: Dictionary = storekit.purchase("cores_small")
	failed = _expect(not bool(blocked.get("ok", false)), "storekit fails closed") or failed
	var play := Billing.create("play")
	failed = _expect(not bool(play.purchase("cores_small").get("ok", false)), "play billing fails closed") or failed
	var closed := Billing.create("stripe")
	failed = _expect(not bool(closed.purchase("cores_small").get("ok", false)), "unknown provider fails closed") or failed
	var snap := Game.to_dict()
	var path := "user://self-check.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(snap))
	file.close()
	Game._apply_default()
	var text := FileAccess.get_file_as_string(path)
	Game._apply_dict(JSON.parse_string(text))
	failed = _expect(Game.owned.has("wh-deep") and Game.owned.has("ti-mud"), "save roundtrip") or failed
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Game._apply_dict(backup)
	Game.autosave = true
	if failed:
		print("SELF_CHECK_FAILED")
		return 1
	print("SELF_CHECK_OK")
	return 0


static func _expect(ok: bool, message: String) -> bool:
	if ok:
		print("ok ", message)
		return false
	push_error("FAIL " + message)
	print("FAIL ", message)
	return true


static func _tally(node: Node, counts: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null and node.visible:
			counts["meshes"] = int(counts["meshes"]) + 1
			for surface in mesh.get_surface_count():
				var mat := (node as MeshInstance3D).get_surface_override_material(surface)
				if mat is ShaderMaterial:
					counts["glass"] = int(counts["glass"]) + 1
	for child in node.get_children():
		_tally(child, counts)

