class_name StoreSheet
extends VBoxContainer

signal buy_pressed(product_id: String)


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	Game.changed.connect(func(): refresh.call_deferred())
	refresh()


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var scroll := DragScroll.new()
	scroll.name = "SheetScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.COPPER, 0.14), 20, UiKit.COPPER))
	var banner_box := VBoxContainer.new()
	banner_box.add_child(UiKit.label("TEST MODE", 13, UiKit.COPPER))
	var copy := UiKit.label("Confirming a purchase does not charge a card and does not contact Apple or Google. These are fixed lists. There are no paid loot boxes.", 16, UiKit.CREAM)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_box.add_child(copy)
	banner.add_child(banner_box)
	box.add_child(banner)
	var balance := UiKit.label("%s coins in the garage · %s Cores. Every part can also be bought with coins you earn on the trail." % [Catalog.commas(Game.coins), Catalog.commas(Game.cores)], 15, UiKit.MUTED)
	balance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(balance)
	_section(box, "Coin packs", "consumable", true)
	_section(box, "Rare kits", "nonconsumable", false)
	_section(box, "Cores", "consumable", false)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var restore := UiKit.button("Restore test purchases", "panel")
	restore.pressed.connect(func():
		var provider := Billing.current()
		var result := provider.restore()
		if not bool(result.get("ok", false)):
			Game.toast_emitted.emit(str(result.get("message", "Restore failed.")))
			return
		Game.restore_purchases()
	)
	var reset := UiKit.button("Reset this device", "ghost")
	reset.pressed.connect(func(): Game.reset_progress())
	actions.add_child(restore)
	actions.add_child(reset)
	box.add_child(actions)
	var provider_line := UiKit.label("Register: %s. StoreKit and Play Billing stay disconnected until truck/billing/provider is changed." % Billing.current().mode, 13, UiKit.MUTED)
	provider_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(provider_line)
	scroll.add_child(box)
	add_child(scroll)


func _section(box: VBoxContainer, title: String, kind: String, coins_only: bool) -> void:
	box.add_child(UiKit.label(title, 32, UiKit.CREAM, true))
	for product in Catalog.PRODUCTS:
		if str(product["kind"]) != kind:
			continue
		var is_coins := int(product.get("coins", 0)) > 0
		if kind == "consumable" and is_coins != coins_only:
			continue
		box.add_child(_product_card(product))


func _product_card(product: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UiKit.label(str(product["title"]), 26, UiKit.CREAM, true))
	var detail := UiKit.label(str(product["detail"]), 15, UiKit.MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(detail)
	var parts: Array = product.get("parts", [])
	if parts.size() > 0:
		var lines := ""
		for id in parts:
			var item := Catalog.part(str(id))
			var name := str(item.get("name", id))
			if Game.owned.has(str(id)):
				name += " · owned"
			lines += name + "\n"
		var list := UiKit.label(lines.strip_edges(), 15, UiKit.CREAM)
		text.add_child(list)
	row.add_child(text)
	var owned_all := true
	for id in parts:
		if not Game.owned.has(str(id)):
			owned_all = false
	var purchased: Array = Game.stats.get("purchased_product_ids", [])
	var have := false
	if str(product["kind"]) == "nonconsumable":
		have = product["id"] in purchased or (parts.size() > 0 and owned_all)
	var btn := UiKit.button("In the garage" if have else str(product["price"]), "panel" if have else "copper")
	btn.disabled = have
	var product_id := str(product["id"])
	btn.pressed.connect(buy_pressed.emit.bind(product_id))
	row.add_child(btn)
	card.add_child(row)
	return card
