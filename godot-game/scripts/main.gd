extends Control

var _margin: MarginContainer
var _vbox: VBoxContainer
var _top: HBoxContainer
var _mid: Container
var _nav: HBoxContainer
var _coins_label: Label
var _cores_label: Label
var _view: Control
var _vp_host: SubViewportContainer
var _vp: SubViewport
var _sheet: PanelContainer
var _sheet_stack: Control
var _garage_sheet: GarageSheet
var _play_sheet: PlaySheet
var _store_sheet: StoreSheet
var _hud: Control
var _hud_title: Label
var _hud_meters: Label
var _hud_coins: Label
var _hud_hearts: Label
var _hud_flag: Label
var _intro: PanelContainer
var _toasts: VBoxContainer
var _modal: Control
var _modal_title: Label
var _modal_body: Label
var _modal_actions: VBoxContainer
var _garage: GarageWorld
var _trail: TrailWorld
var _tab := "garage"
var _phase := "lobby"
var _layout_key := ""
var _modal_product := ""
var _modal_phase := "confirm"
var _modal_message := ""
var _busy := false


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Game.changed.connect(_refresh_chrome)
	Game.toast_emitted.connect(_push_toast)
	_refresh_chrome()
	if "--self-check" in OS.get_cmdline_user_args():
		var code := SelfCheck.run()
		get_tree().quit(code)
		return
	var cap := _arg("--capture")
	if cap != "":
		_busy = true
		await _run_capture(cap)


func _process(_delta: float) -> void:
	_relayout()
	if _phase == "run" and _trail:
		_hud_title.text = str(Catalog.track(_trail.track_id).get("name", "Trail"))
		_hud_meters.text = "%s m" % Catalog.commas(_trail.meters())
		_hud_coins.text = "%s" % Catalog.commas(_trail.run_coins())
		_hud_hearts.text = _hearts(_trail.hits())
		_hud_flag.text = _trail.flag_text()


func _unhandled_input(event: InputEvent) -> void:
	if _tab == "play" and _phase == "run" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			_trail.nudge(-1)
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			_trail.nudge(1)
		elif event.keycode == KEY_ESCAPE:
			_bail()


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 0)
	_margin.add_child(_vbox)
	_top = HBoxContainer.new()
	_top.add_theme_constant_override("separation", 12)
	_top.custom_minimum_size.y = 72
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_child(UiKit.label("TRUCK APP", 28, UiKit.CREAM, true))
	brand.add_child(UiKit.label("OMNIPRESENT GAMES", 12, UiKit.MUTED))
	_top.add_child(brand)
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 8)
	_coins_label = UiKit.label("0", 16, UiKit.COPPER)
	_cores_label = UiKit.label("0 Cores", 16, UiKit.COPPER2)
	pills.add_child(_pill(_coins_label))
	pills.add_child(_pill(_cores_label))
	_top.add_child(pills)
	_vbox.add_child(_top)
	_mid = VBoxContainer.new()
	_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mid.set_meta("kind", "V")
	_vbox.add_child(_mid)
	_view = Control.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.clip_contents = true
	_vp_host = SubViewportContainer.new()
	_vp_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp_host.stretch = true
	_vp_host.mouse_filter = Control.MOUSE_FILTER_STOP
	_vp_host.gui_input.connect(_on_view_input)
	_view.add_child(_vp_host)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.positional_shadow_atlas_size = 1024
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.size = Vector2i(1080, 1200)
	_vp_host.add_child(_vp)
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ShaderMaterial.new()
	shade.shader = load("res://shaders/vignette.gdshader")
	vignette.material = shade
	_view.add_child(vignette)
	_hud = _build_hud()
	_view.add_child(_hud)
	_intro = _build_intro()
	_view.add_child(_intro)
	_garage = GarageWorld.new()
	_garage.name = "Garage"
	_vp.add_child(_garage)
	_trail = TrailWorld.new()
	_trail.name = "Trail"
	_trail.finished.connect(_on_finished)
	_vp.add_child(_trail)
	_sheet = PanelContainer.new()
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 0))
	_sheet_stack = Control.new()
	_sheet_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet_stack.clip_contents = true
	_sheet.add_child(_sheet_stack)
	_garage_sheet = GarageSheet.new()
	_play_sheet = PlaySheet.new()
	_store_sheet = StoreSheet.new()
	for sheet in [_garage_sheet, _play_sheet, _store_sheet]:
		sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
		sheet.offset_left = 14
		sheet.offset_top = 12
		sheet.offset_right = -14
		sheet.offset_bottom = -10
		_sheet_stack.add_child(sheet)
	_garage_sheet.open_store.connect(func(): _show_tab("store"))
	_play_sheet.start_run.connect(_start_run)
	_play_sheet.back_to_board.connect(func(): _phase = "lobby")
	_store_sheet.buy_pressed.connect(_open_purchase)
	_nav = HBoxContainer.new()
	_nav.custom_minimum_size.y = 76
	for id in ["garage", "play", "store"]:
		var btn := Button.new()
		btn.text = id.capitalize()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 64
		btn.set_meta("tab", id)
		btn.pressed.connect(_show_tab.bind(id))
		_nav.add_child(btn)
	_vbox.add_child(_nav)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_top = 12
	_toasts.offset_bottom = 200
	_toasts.offset_left = -220
	_toasts.offset_right = 220
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.z_index = 20
	add_child(_toasts)
	_build_modal()
	_show_tab("garage")


func _pill(text: Label) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL2, 16))
	panel.add_child(text)
	return panel


func _build_hud() -> Control:
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	_hud_title = UiKit.label("Switchback", 28, UiKit.CREAM, true)
	_hud_title.position = Vector2(20, 16)
	_hud_meters = UiKit.label("0 m", 18, UiKit.CREAM)
	_hud_meters.position = Vector2(20, 52)
	_hud_coins = UiKit.label("0", 22, UiKit.COPPER, true)
	_hud_coins.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud_coins.offset_left = -160
	_hud_coins.offset_right = -20
	_hud_coins.offset_top = 18
	_hud_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_hearts = UiKit.label("●●●", 22, UiKit.CREAM)
	_hud_hearts.position = Vector2(20, 84)
	_hud_flag = UiKit.label("", 20, UiKit.COPPER2)
	_hud_flag.position = Vector2(20, 116)
	for node in [_hud_title, _hud_meters, _hud_coins, _hud_hearts, _hud_flag]:
		node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		node.add_theme_constant_override("shadow_offset_x", 1)
		node.add_theme_constant_override("shadow_offset_y", 1)
		hud.add_child(node)
	var left := UiKit.label("‹", 64, Color(1, 1, 1, 0.35), true)
	left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left.offset_left = 12
	left.offset_top = -40
	left.offset_bottom = 40
	var right := UiKit.label("›", 64, Color(1, 1, 1, 0.35), true)
	right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right.offset_right = -12
	right.offset_left = -48
	right.offset_top = -40
	right.offset_bottom = 40
	hud.add_child(left)
	hud.add_child(right)
	var bail := UiKit.button("Pull off", "panel")
	bail.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bail.offset_right = -16
	bail.offset_bottom = -16
	bail.offset_left = -150
	bail.offset_top = -68
	bail.mouse_filter = Control.MOUSE_FILTER_STOP
	bail.pressed.connect(_bail)
	hud.add_child(bail)
	var hint := UiKit.label("Tap the sides to change lanes", 14, Color(1, 1, 1, 0.7))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 16
	hint.offset_bottom = -24
	hint.offset_top = -48
	hud.add_child(hint)
	return hud


func _build_intro() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_bottom = -16
	panel.offset_top = -168
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.92), 22))
	panel.visible = not Game.seen_intro
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(UiKit.label("PROTOTYPE BAY", 12, UiKit.COPPER))
	var copy := UiKit.label("Fictional trucks, a trail that pays coins, and a test register. Nothing here charges a card.", 16, UiKit.CREAM)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(copy)
	var roll := UiKit.button("Roll in", "copper")
	roll.pressed.connect(func(): Game.dismiss_intro())
	box.add_child(roll)
	panel.add_child(box)
	return panel


func _build_modal() -> void:
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.visible = false
	_modal.z_index = 30
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and _modal_phase != "pending":
			_modal.visible = false
	)
	_modal.add_child(dim)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -240
	card.offset_right = 240
	card.offset_top = -180
	card.offset_bottom = 180
	card.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 22))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(UiKit.label("TEST PURCHASE · NO CHARGE", 12, UiKit.COPPER))
	_modal_title = UiKit.label("", 30, UiKit.CREAM, true)
	_modal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_body = UiKit.label("", 16, UiKit.MUTED)
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_modal_title)
	box.add_child(_modal_body)
	_modal_actions = VBoxContainer.new()
	_modal_actions.add_theme_constant_override("separation", 8)
	box.add_child(_modal_actions)
	card.add_child(box)
	_modal.add_child(card)
	add_child(_modal)


func _show_tab(id: String) -> void:
	if _phase == "run" and id != "play":
		_bail()
	_tab = id
	if id != "play":
		_phase = "lobby"
	_layout_key = ""
	_relayout()
	_refresh_chrome()


func _start_run(id: String) -> void:
	if not _trail.start(id):
		Game.toast_emitted.emit("Finish Switchback once to open this wash.")
		return
	_phase = "run"
	_layout_key = ""
	_relayout()


func _bail() -> void:
	if _phase != "run":
		return
	_trail.bail()


func _on_finished(payout: Dictionary) -> void:
	if _busy:
		return
	var result: Dictionary = Game.apply_run(payout)
	_phase = "result"
	_play_sheet.show_result(payout, result.get("notes", []))
	_layout_key = ""
	_relayout()


func _relayout() -> void:
	var landscape := size.x > size.y + 40.0
	var running := _tab == "play" and _phase == "run"
	var key := "%s|%s|%s|%d|%d" % [_tab, _phase, landscape, int(size.x), int(size.y)]
	if key == _layout_key:
		_sync_vp()
		return
	_layout_key = key
	var insets := _insets()
	_margin.add_theme_constant_override("margin_left", int(insets.x) + 8)
	_margin.add_theme_constant_override("margin_right", int(insets.z) + 8)
	_margin.add_theme_constant_override("margin_top", int(insets.y) + 6)
	_margin.add_theme_constant_override("margin_bottom", int(insets.w) + 4)
	_top.visible = not running
	_nav.visible = not running
	_hud.visible = running
	_intro.visible = not Game.seen_intro and _tab == "garage" and not running
	_garage_sheet.visible = _tab == "garage"
	_play_sheet.visible = _tab == "play" and not running
	_store_sheet.visible = _tab == "store"
	_garage.set_active(_tab == "garage")
	_trail.set_active(_tab == "play")
	if _tab == "play" and _phase == "lobby":
		_trail.preview(_play_sheet.track_id)
	_park(_view)
	_park(_sheet)
	var horizontal := landscape and _tab != "store" and not running
	var want := "H" if horizontal else "V"
	if str(_mid.get_meta("kind", "")) != want:
		var fresh: Container = HBoxContainer.new() if horizontal else VBoxContainer.new()
		fresh.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fresh.set_meta("kind", want)
		_vbox.add_child(fresh)
		_vbox.move_child(fresh, 1)
		_mid.free()
		_mid = fresh
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if running or _tab == "store":
		_mid.add_child(_sheet if _tab == "store" else _view)
		_sheet.visible = _tab == "store"
		_view.visible = running or _tab != "store"
		if _tab == "store":
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		else:
			_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_view.visible = true
		_sheet.visible = true
		if horizontal:
			_sheet.custom_minimum_size = Vector2(minf(460.0, size.x * 0.4), 0)
			_view.custom_minimum_size = Vector2(0, 0)
			_mid.add_child(_view)
			_mid.add_child(_sheet)
		else:
			var sheet_h := clampf(size.y * 0.4, 340.0, 540.0)
			_sheet.custom_minimum_size = Vector2(0, sheet_h)
			_view.custom_minimum_size = Vector2(0, 280)
			_mid.add_child(_view)
			_mid.add_child(_sheet)
	for child in _nav.get_children():
		var on := str(child.get_meta("tab", "")) == _tab
		child.add_theme_color_override("font_color", UiKit.COPPER if on else UiKit.MUTED)
		child.add_theme_stylebox_override("normal", UiKit.box(Color(0, 0, 0, 0), 0))
		child.add_theme_stylebox_override("hover", UiKit.box(Color(0, 0, 0, 0), 0))
		child.add_theme_stylebox_override("pressed", UiKit.box(Color(0, 0, 0, 0), 0))
	_sync_vp()


func _park(node: Node) -> void:
	if node.get_parent():
		node.get_parent().remove_child(node)


func _sync_vp() -> void:
	var s := _vp_host.size
	if s.x < 2.0 or s.y < 2.0:
		return
	var want := Vector2i(int(s.x), int(s.y))
	if _vp.size != want:
		_vp.size = want


func _insets() -> Vector4:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if safe.size.x < 2 or safe.size.y < 2:
		return Vector4.ZERO
	return Vector4(
		clampf(safe.position.x, 0, 64),
		clampf(safe.position.y, 0, 64),
		clampf(win.x - safe.end.x, 0, 64),
		clampf(win.y - safe.end.y, 0, 64)
	)


func _refresh_chrome() -> void:
	_coins_label.text = Catalog.commas(Game.coins)
	_cores_label.text = "%s Cores" % Catalog.commas(Game.cores)
	_intro.visible = not Game.seen_intro and _tab == "garage" and _phase != "run"


func _on_view_input(event: InputEvent) -> void:
	if _tab == "garage":
		_garage.handle(event)
	elif _tab == "play" and _phase == "run":
		var pressed := false
		var at := Vector2.ZERO
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed = true
			at = event.position
		elif event is InputEventScreenTouch and event.pressed:
			pressed = true
			at = event.position
		if pressed:
			_trail.nudge(-1 if at.x < _vp_host.size.x * 0.5 else 1)


func _open_purchase(product_id: String) -> void:
	_modal_product = product_id
	_modal_phase = "confirm"
	_modal_message = ""
	_modal.visible = true
	_fill_modal()


func _fill_modal() -> void:
	for child in _modal_actions.get_children():
		child.free()
	var product := Catalog.product(_modal_product)
	_modal_title.text = str(product.get("title", "Test purchase"))
	if _modal_phase == "pending":
		_modal_body.text = "Talking to the test register…"
		return
	if _modal_phase == "confirm":
		_modal_body.text = "%s. %s" % [product.get("price", ""), product.get("detail", "")]
		var ok := UiKit.button("Confirm test purchase", "copper")
		ok.pressed.connect(_confirm_purchase.bind("success"))
		var cancel := UiKit.button("Cancel", "panel")
		cancel.pressed.connect(func(): _modal.visible = false)
		var fail := UiKit.button("Simulate a failed charge", "ghost")
		fail.pressed.connect(_confirm_purchase.bind("fail"))
		_modal_actions.add_child(ok)
		_modal_actions.add_child(cancel)
		_modal_actions.add_child(fail)
		return
	_modal_body.text = _modal_message
	var close := UiKit.button("Close", "copper")
	close.pressed.connect(func(): _modal.visible = false)
	_modal_actions.add_child(close)


func _confirm_purchase(outcome: String) -> void:
	if _modal_phase == "pending":
		return
	_modal_phase = "pending"
	_fill_modal()
	await get_tree().create_timer(0.45).timeout
	var result: Dictionary = Billing.current().purchase(_modal_product, outcome)
	if bool(result.get("ok", false)):
		var applied: Dictionary = Game.grant_product(_modal_product, str(result.get("transaction_id", "")))
		_modal_message = str(applied.get("message", ""))
		_modal_phase = "done" if bool(applied.get("ok", false)) else "error"
	else:
		_modal_message = str(result.get("message", "The test charge didn't go through."))
		_modal_phase = "error"
	_fill_modal()


func _push_toast(text: String) -> void:
	var btn := UiKit.button(text, "panel")
	btn.add_theme_color_override("font_color", UiKit.INK)
	btn.add_theme_stylebox_override("normal", UiKit.box(UiKit.CREAM, 20))
	btn.pressed.connect(btn.queue_free)
	_toasts.add_child(btn)
	var timer := get_tree().create_timer(3.4)
	timer.timeout.connect(func():
		if is_instance_valid(btn):
			btn.queue_free()
	)


func _hearts(hits: int) -> String:
	var left := clampi(3 - hits, 0, 3)
	var text := ""
	for i in 3:
		text += "●" if i < left else "○"
	return text


func _arg(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(flag)
	if index >= 0 and index + 1 < args.size():
		return str(args[index + 1])
	return ""


func _run_capture(dir: String) -> void:
	Game.autosave = false
	Game.reset_progress()
	Game.dismiss_intro()
	DirAccess.make_dir_recursive_absolute(dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("renderer ", RenderingServer.get_current_rendering_method())
	await _shot(dir.path_join("01-garage.png"), Vector2i(1080, 1920), func():
		_show_tab("garage")
		_garage.pose(0.82, 0.24, 6.3, 0.2)
	)
	await _shot(dir.path_join("02-custom-truck.png"), Vector2i(1080, 1920), func():
		_apply_show_loadout()
		_show_tab("garage")
		_garage.pose(0.46, 0.18, 5.35, 0.0)
	)
	await _shot(dir.path_join("03-store.png"), Vector2i(1080, 1920), func():
		_show_tab("store")
	)
	await _shot(dir.path_join("04-play.png"), Vector2i(1080, 1920), func():
		_show_tab("play")
		_phase = "run"
		_layout_key = ""
		_trail.pose_run("switchback", 175.0)
		_relayout()
	)
	await _shot(dir.path_join("05-garage-landscape.png"), Vector2i(1920, 1080), func():
		_phase = "lobby"
		_show_tab("garage")
		_garage.pose(0.7, 0.22, 7.1, 0.15)
	)
	get_tree().quit()


func _shot(path: String, window_size: Vector2i, setup: Callable) -> void:
	DisplayServer.window_set_size(window_size)
	for _i in 3:
		await RenderingServer.frame_post_draw
	setup.call()
	for child in _toasts.get_children():
		child.free()
	_layout_key = ""
	var frames := 40 if path.ends_with("01-garage.png") else 16
	for _i in frames:
		_relayout()
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var err := image.save_png(path)
	print("captured %s %s %dx%d" % [path, error_string(err), image.get_width(), image.get_height()])


func _apply_show_loadout() -> void:
	for part_id in ["wh-blade", "ti-mud", "lf-4", "bp-pre", "lt-dual", "ex-stack", "sp-wing", "wr-circuit"]:
		Game.debug_own(part_id)
	Game.select_truck("ridgehaul-summit")
	Game.set_paint("sea")
	Game.set_finish("metallic")
	for part_id in ["wh-blade", "ti-mud", "lf-4", "bp-pre", "lt-dual", "ex-stack", "sp-wing", "wr-circuit"]:
		Game.equip(part_id)
