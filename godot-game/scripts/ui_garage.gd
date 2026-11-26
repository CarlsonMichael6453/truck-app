class_name GarageSheet
extends VBoxContainer

signal open_store

var _category := "paint"
var _scroll_px := 0
var _scroller: ScrollContainer


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	Game.changed.connect(func(): refresh.call_deferred())
	refresh()


func refresh() -> void:
	if _scroller:
		_scroll_px = _scroller.scroll_horizontal
	for child in get_children():
		remove_child(child)
		child.free()
	_scroller = null
	var spec := Game.truck()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev := UiKit.button("‹", "panel")
	prev.custom_minimum_size = Vector2(52, 52)
	var index := 0
	for i in Catalog.TRUCKS.size():
		if Catalog.TRUCKS[i]["id"] == spec["id"]:
			index = i
	prev.pressed.connect(func(): Game.select_truck(str(Catalog.TRUCKS[(index + Catalog.TRUCKS.size() - 1) % Catalog.TRUCKS.size()]["id"])))
	var nxt := UiKit.button("›", "panel")
	nxt.custom_minimum_size = Vector2(52, 52)
	nxt.pressed.connect(func(): Game.select_truck(str(Catalog.TRUCKS[(index + 1) % Catalog.TRUCKS.size()]["id"])))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var brand := UiKit.label(str(spec["brand"]).to_upper(), 14, UiKit.MUTED)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var model := UiKit.label(str(spec["model"]), 36, UiKit.CREAM, true)
	model.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var role := UiKit.label(str(spec["role"]), 16, UiKit.COPPER)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(brand)
	title_box.add_child(model)
	title_box.add_child(role)
	row.add_child(prev)
	row.add_child(title_box)
	row.add_child(nxt)
	add_child(row)
	var blurb := UiKit.label(str(spec["blurb"]), 16, UiKit.MUTED)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(blurb)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	for cat in Catalog.CATEGORIES:
		var id := str(cat["id"])
		var chip := UiKit.button(str(cat["label"]), "copper" if id == _category else "panel")
		chip.pressed.connect(_pick_category.bind(id))
		chips.add_child(chip)
	var chip_scroll := ScrollContainer.new()
	chip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chip_scroll.custom_minimum_size = Vector2(0, 64)
	chip_scroll.add_child(chips)
	add_child(chip_scroll)
	if _category == "paint":
		add_child(_paint_block())
	else:
		add_child(_part_row())
	var count := UiKit.label("%d of %d parts in the bay" % [Game.owned.size(), Catalog.PARTS.size()], 14, UiKit.MUTED)
	add_child(count)
	if _scroller:
		_scroller.scroll_horizontal = _scroll_px


func _pick_category(id: String) -> void:
	_category = id
	_scroll_px = 0
	refresh()


func _paint_block() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var current := str(Game.loadout().get("paint", ""))
	for paint in Catalog.PAINTS:
		var id := str(paint["id"])
		var swatch := Button.new()
		swatch.text = ""
		swatch.custom_minimum_size = Vector2(0, 58)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.focus_mode = Control.FOCUS_NONE
		var border := UiKit.COPPER if id == current else Color(1, 1, 1, 0.08)
		swatch.add_theme_stylebox_override("normal", UiKit.box(Color.html(str(paint["hex"])), 16, border))
		swatch.add_theme_stylebox_override("hover", UiKit.box(Color.html(str(paint["hex"])), 16, border))
		swatch.add_theme_stylebox_override("pressed", UiKit.box(Color.html(str(paint["hex"])), 16, UiKit.COPPER))
		swatch.pressed.connect(Game.set_paint.bind(id))
		grid.add_child(swatch)
	box.add_child(grid)
	var name := UiKit.label(str(Catalog.paint(current).get("name", "")), 18, UiKit.CREAM)
	box.add_child(name)
	var finishes := HBoxContainer.new()
	finishes.add_theme_constant_override("separation", 8)
	var finish_id := str(Game.loadout().get("finish", "gloss"))
	for finish in Catalog.FINISHES:
		var id := str(finish["id"])
		var chip := UiKit.button(str(finish["name"]), "copper" if id == finish_id else "panel")
		chip.pressed.connect(Game.set_finish.bind(id))
		finishes.add_child(chip)
	var finish_scroll := ScrollContainer.new()
	finish_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	finish_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	finish_scroll.custom_minimum_size = Vector2(0, 64)
	finish_scroll.add_child(finishes)
	box.add_child(finish_scroll)
	return box


func _part_row() -> Control:
	_scroller = ScrollContainer.new()
	_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var equipped := str(Game.loadout().get(_category, ""))
	for part in Catalog.parts_for(_category):
		row.add_child(_card(part, equipped))
	_scroller.add_child(row)
	return _scroller


func _card(part: Dictionary, equipped: String) -> Control:
	var id := str(part["id"])
	var rarity := str(part["rarity"])
	var on := id == equipped
	var border := Color(1, 1, 1, 0.08)
	if on:
		border = UiKit.COPPER
	elif rarity == "legendary":
		border = Color.html(str(Catalog.RARITY_COLOR["legendary"]))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(230, 0)
	panel.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL2, 18, border))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var tag := UiKit.label(Catalog.rarity_label(rarity).to_upper(), 12, Color.html(str(Catalog.RARITY_COLOR.get(rarity, "#b7c0cc"))))
	var title := UiKit.label(str(part["name"]), 26, UiKit.CREAM, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var blurb := UiKit.label(str(part["blurb"]), 14, UiKit.MUTED)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(200, 52)
	box.add_child(tag)
	box.add_child(title)
	box.add_child(blurb)
	if Game.owned.has(id):
		var btn := UiKit.button("Equipped" if on else "Equip", "panel" if on else "copper")
		btn.pressed.connect(Game.equip.bind(id))
		box.add_child(btn)
	else:
		var coins := UiKit.button("%s coins" % Catalog.commas(int(part["coins"])), "copper")
		coins.disabled = Game.coins < int(part["coins"])
		coins.pressed.connect(Game.buy.bind(id, "coins"))
		var cores := UiKit.button("%d Cores" % int(part["cores"]), "panel")
		cores.disabled = Game.cores < int(part["cores"])
		cores.pressed.connect(Game.buy.bind(id, "cores"))
		box.add_child(coins)
		box.add_child(cores)
		if Game.cores < int(part["cores"]):
			var link := UiKit.button("Get Cores", "ghost")
			link.custom_minimum_size.y = 32
			link.pressed.connect(open_store.emit)
			box.add_child(link)
	panel.add_child(box)
	return panel
