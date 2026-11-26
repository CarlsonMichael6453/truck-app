class_name PlaySheet
extends VBoxContainer

signal start_run(track_id: String)
signal back_to_board

var track_id := "switchback"
var _mode := "lobby"


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	Game.changed.connect(func(): _on_game.call_deferred())
	show_lobby()


func _on_game() -> void:
	if _mode == "lobby":
		show_lobby()


func show_lobby() -> void:
	_mode = "lobby"
	_rebuild_lobby()


func show_result(payout: Dictionary, notes: Array) -> void:
	_mode = "result"
	for child in get_children():
		remove_child(child)
		child.free()
	var track := Catalog.track(str(payout.get("track_id", track_id)))
	var kicker := UiKit.label(str(track.get("name", "Trail")).to_upper(), 14, UiKit.COPPER)
	add_child(kicker)
	var title := "The wash got you"
	if bool(payout.get("clean", false)):
		title = "Clean line"
	elif bool(payout.get("finished", false)):
		title = "You made the end"
	elif str(payout.get("status", "")) == "bailed":
		title = "You pulled off"
	add_child(UiKit.label(title, 42, UiKit.CREAM, true))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for pair in [["Meters", Catalog.commas(int(payout.get("distance", 0)))], ["Hits", str(int(payout.get("hits", 0)))], ["Coins", Catalog.commas(int(payout.get("coins", 0)))]]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL2, 16))
		var col := VBoxContainer.new()
		var cap := UiKit.label(str(pair[0]).to_upper(), 12, UiKit.MUTED)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var val := UiKit.label(str(pair[1]), 28, UiKit.CREAM, true)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cap)
		col.add_child(val)
		card.add_child(col)
		stats.add_child(card)
	add_child(stats)
	if notes.size() > 0:
		for note in notes:
			var line := UiKit.label(str(note), 16, UiKit.MUTED)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(line)
	var again := UiKit.button("Ride again", "copper")
	again.pressed.connect(func(): start_run.emit(track_id))
	add_child(again)
	var board := UiKit.button("Trail board", "panel")
	board.pressed.connect(func():
		back_to_board.emit()
		show_lobby()
	)
	add_child(board)


func _rebuild_lobby() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	var today := Game.today()
	var streak := Game.preview_streak(today)
	var reward: Dictionary = Catalog.DAILY[(maxi(1, streak) - 1) % Catalog.DAILY.size()]
	var claimed := str(Game.stats.get("last_daily", "")) == today
	var daily := PanelContainer.new()
	daily.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 20, Color(UiKit.COPPER, 0.35)))
	var daily_row := HBoxContainer.new()
	daily_row.add_theme_constant_override("separation", 12)
	var daily_text := VBoxContainer.new()
	daily_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	daily_text.add_child(UiKit.label("DAILY BAY", 12, UiKit.COPPER))
	daily_text.add_child(UiKit.label(str(reward["label"]), 28, UiKit.CREAM, true))
	var shown_streak := int(Game.stats.get("streak", 0)) if claimed else streak
	var streak_line := "Streak %d. Come back tomorrow to keep it." % shown_streak
	var streak_label := UiKit.label(streak_line, 15, UiKit.MUTED)
	streak_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	daily_text.add_child(streak_label)
	daily_row.add_child(daily_text)
	var claim := UiKit.button("Claimed" if claimed else "Claim", "panel" if claimed else "copper")
	claim.disabled = claimed
	claim.pressed.connect(func(): Game.claim_daily(Game.today()))
	daily_row.add_child(claim)
	daily.add_child(daily_row)
	box.add_child(daily)
	var head := HBoxContainer.new()
	head.add_child(UiKit.label("Trails", 32, UiKit.CREAM, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var sound := UiKit.button("Sound %s" % ("on" if Game.sound else "off"), "ghost")
	sound.pressed.connect(func(): Game.toggle_sound())
	head.add_child(sound)
	box.add_child(head)
	box.add_child(UiKit.label("Best haul %s coins · %s m" % [Catalog.commas(int(Game.stats.get("best_coins", 0))), Catalog.commas(int(Game.stats.get("best_distance", 0)))], 15, UiKit.MUTED))
	for trail in Catalog.tracks():
		var id := str(trail["id"])
		var locked := int(Game.stats.get("finishes", 0)) < int(trail["unlock"])
		var selected := id == track_id
		var card := Button.new()
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.disabled = locked
		card.focus_mode = Control.FOCUS_NONE
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var border := UiKit.COPPER if selected else Color(1, 1, 1, 0.08)
		var bg := UiKit.PANEL if selected else UiKit.PANEL2
		card.add_theme_stylebox_override("normal", UiKit.box(bg, 18, border))
		card.add_theme_stylebox_override("hover", UiKit.box(bg, 18, border))
		card.add_theme_stylebox_override("disabled", UiKit.box(Color(UiKit.PANEL2, 0.55), 18))
		card.add_theme_stylebox_override("pressed", UiKit.box(bg, 18, UiKit.COPPER))
		card.text = "%s\n%s" % [trail["name"], "Finish Switchback once to open this wash." if locked else trail["blurb"]]
		card.pressed.connect(_pick_track.bind(id))
		box.add_child(card)
	var run := UiKit.button("Run %s" % str(Catalog.track(track_id).get("name", "Switchback")), "copper")
	run.pressed.connect(func(): start_run.emit(track_id))
	box.add_child(run)
	box.add_child(UiKit.label("Quests", 32, UiKit.CREAM, true))
	for quest in Game.quest_views():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 16))
		var col := VBoxContainer.new()
		var top := HBoxContainer.new()
		var qtitle := UiKit.label(str(quest["title"]), 18, UiKit.CREAM)
		qtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(qtitle)
		top.add_child(UiKit.label("Done" if quest["done"] else "%d/%d" % [int(quest["value"]), int(quest["goal"])], 14, UiKit.MUTED))
		col.add_child(top)
		var detail := UiKit.label(str(quest["detail"]), 15, UiKit.MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(detail)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bg := ColorRect.new()
		bg.color = UiKit.INK
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.color = UiKit.COPPER
		fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill.anchor_right = clampf(float(quest["value"]) / maxf(1.0, float(quest["goal"])), 0.0, 1.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(bg)
		bar.add_child(fill)
		col.add_child(bar)
		card.add_child(col)
		box.add_child(card)
	scroll.add_child(box)
	add_child(scroll)


func _pick_track(id: String) -> void:
	track_id = id
	show_lobby()
