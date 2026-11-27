class_name DragScroll
extends ScrollContainer

## Finger drag for lists. A short tap still reaches the button under the finger.
## Past a small threshold the drag scrolls 1:1, cancels that press, and flicks.
##
## ScrollContainer already drag-scrolls when `is_touchscreen_available()` and the
## event reaches it. Buttons and cards default to MOUSE_FILTER_STOP, so the drag
## dies on the control it started on. Children are set to MOUSE_FILTER_PASS so
## the gesture bubbles here. This node still owns the gesture: the engine's
## drag-and-drop probe (`get_drag_data`, 10px) returns null and must not take it,
## and web delivers a touch plus a synthesized mouse for the same finger.
## `emulate_mouse_from_touch` stays on so a tap presses the button. `emulate_touch_from_mouse`
## stays off so a mouse drag is not turned into a second touch.

const THRESHOLD := 18.0
const OVERSCROLL_LIMIT := 90.0
const FLICK_FRICTION := 2600.0
const MAX_FLICK := 4200.0

static var claim: DragScroll
static var _touch_block_until := 0

var _pointer := -2
var _start := Vector2.ZERO
var _scroll_start := Vector2.ZERO
var _axis := Vector2.ZERO
var _dragging := false
var _yielded := false
var _velocity := Vector2.ZERO
var _samples: Array[Vector3] = []


static func axis_for(delta: Vector2, can_h: bool, can_v: bool) -> Vector2:
	if delta.length() < THRESHOLD:
		return Vector2.ZERO
	var horizontal := absf(delta.x) >= absf(delta.y)
	if horizontal and can_h:
		return Vector2(1, 0)
	if not horizontal and can_v:
		return Vector2(0, 1)
	return Vector2.ZERO


static func rubber_limit(value: float, limit: float) -> float:
	var cap := float(OVERSCROLL_LIMIT)
	if value < 0.0:
		return -_rubber_abs(-value, cap)
	if value > limit:
		return limit + _rubber_abs(value - limit, cap)
	return value


static func _rubber_abs(amount: float, cap: float) -> float:
	if cap <= 0.0:
		return 0.0
	return cap * (1.0 - 1.0 / (1.0 + amount / cap))


func _ready() -> void:
	# Native touch-drag also runs unless the event is accepted. Keep its deadzone
	# past any real gesture so it cannot scroll a second time beside this helper.
	scroll_deadzone = 100000
	clip_contents = true
	_style_bars()
	for bar in [get_h_scroll_bar(), get_v_scroll_bar()]:
		bar.allow_greater = true
		bar.allow_lesser = true
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
	if not child_entered_tree.is_connected(_on_child_entered):
		child_entered_tree.connect(_on_child_entered)
	_arm(self)
	_apply_filter.call_deferred()
	set_process(true)


func _exit_tree() -> void:
	if claim == self:
		claim = null
	_pointer = -2
	_dragging = false


func _apply_filter() -> void:
	# Nested lists pass unclaimed drags (a vertical pull on a horizontal row)
	# to the parent list. The outermost list stops the gesture.
	mouse_filter = Control.MOUSE_FILTER_PASS if _drag_parent() != null else Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if _is_wheel(button):
			# Leave the wheel for ScrollContainer. Accepting it would swallow that.
			return
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if Time.get_ticks_msec() < _touch_block_until:
			return
		if button.pressed:
			_begin(-1, button.position)
		elif _pointer == -1:
			_end()
		return
	if event is InputEventMouseMotion:
		if Time.get_ticks_msec() < _touch_block_until or _pointer != -1:
			return
		_move((event as InputEventMouseMotion).position)
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_touch_block_until = Time.get_ticks_msec() + 500
		if touch.pressed:
			_begin(touch.index, touch.position)
		elif _pointer == touch.index:
			_end()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touch_block_until = Time.get_ticks_msec() + 500
		if _pointer == -1:
			_pointer = drag.index
		if _pointer == drag.index:
			_move(drag.position)


func _process(delta: float) -> void:
	if _dragging:
		return
	var limit_h := _max_h()
	var limit_v := _max_v()
	var pos := Vector2(scroll_horizontal, scroll_vertical)
	if _outside(pos, limit_h, limit_v):
		var dest := Vector2(clampf(pos.x, 0.0, limit_h), clampf(pos.y, 0.0, limit_v))
		pos = pos.lerp(dest, 1.0 - exp(-16.0 * delta))
		if pos.distance_to(dest) < 0.6:
			pos = dest
		_velocity = Vector2.ZERO
		scroll_horizontal = int(round(pos.x))
		scroll_vertical = int(round(pos.y))
		return
	if _velocity.length() < 36.0:
		_velocity = Vector2.ZERO
		return
	pos += _velocity * delta
	if pos.x < 0.0 or pos.x > limit_h:
		pos.x = clampf(pos.x, 0.0, limit_h)
		_velocity.x = 0.0
	if pos.y < 0.0 or pos.y > limit_v:
		pos.y = clampf(pos.y, 0.0, limit_v)
		_velocity.y = 0.0
	scroll_horizontal = int(round(pos.x))
	scroll_vertical = int(round(pos.y))
	_velocity = _velocity.move_toward(Vector2.ZERO, FLICK_FRICTION * delta)


func _begin(id: int, pos: Vector2) -> void:
	if claim != null and claim != self:
		return
	if _pointer == -2:
		_pointer = id
		_start = pos
		_scroll_start = Vector2(scroll_horizontal, scroll_vertical)
		_dragging = false
		_yielded = false
		_axis = Vector2.ZERO
		_velocity = Vector2.ZERO
		_samples.clear()
		return
	# The web shell turns one finger into a mouse event and a touch. Keep one gesture.
	if _pointer == -1 and id >= 0:
		_pointer = id


func _move(pos: Vector2) -> void:
	if _pointer == -2 or _yielded:
		return
	if claim != null and claim != self:
		_yielded = true
		_pointer = -2
		return
	if not _dragging:
		var delta := pos - _start
		var axis := axis_for(delta, _can_h(), _can_v())
		if axis == Vector2.ZERO:
			if delta.length() < THRESHOLD:
				return
			_yielded = true
			_pointer = -2
			if _drag_parent() == null and claim == null:
				propagate_notification(NOTIFICATION_SCROLL_BEGIN)
				accept_event()
			return
		var along := delta.dot(axis)
		var extra := along - signf(along) * THRESHOLD
		_axis = axis
		_start = pos
		_scroll_start = Vector2(scroll_horizontal, scroll_vertical) - axis * extra
		_claim()
	var delta_now := pos - _start
	var moved := Vector2(delta_now.x * _axis.x, delta_now.y * _axis.y)
	var target := _scroll_start - moved
	scroll_horizontal = int(round(rubber_limit(target.x, _max_h())))
	scroll_vertical = int(round(rubber_limit(target.y, _max_v())))
	_note_sample()
	accept_event()


func _end() -> void:
	var was := _dragging and claim == self
	_pointer = -2
	_dragging = false
	_yielded = false
	if not was:
		_samples.clear()
		return
	_flick()
	if _outside(Vector2(scroll_horizontal, scroll_vertical), _max_h(), _max_v()):
		_velocity = Vector2.ZERO
	if claim == self:
		claim = null
	_samples.clear()
	accept_event()


func _claim() -> void:
	if claim != null and claim != self:
		claim._abort()
	claim = self
	_dragging = true
	_yielded = false
	# BaseButton clears press_attempt on this, so the release does not fire pressed.
	propagate_notification(NOTIFICATION_SCROLL_BEGIN)


func _abort() -> void:
	_pointer = -2
	_dragging = false
	_yielded = false
	_velocity = Vector2.ZERO
	_samples.clear()
	if claim == self:
		claim = null


func _note_sample() -> void:
	var now := Time.get_ticks_msec() * 0.001
	_samples.append(Vector3(now, scroll_horizontal, scroll_vertical))
	var cut := now - 0.09
	while _samples.size() > 1 and _samples[0].x < cut:
		_samples.remove_at(0)


func _flick() -> void:
	_velocity = Vector2.ZERO
	if _samples.size() < 2:
		return
	var first := _samples[0]
	var last := _samples[_samples.size() - 1]
	var dt := last.x - first.x
	if dt <= 0.001 or dt > 0.12:
		return
	_velocity = Vector2(last.y - first.y, last.z - first.z) / dt
	_velocity *= _axis
	_velocity.x = clampf(_velocity.x, -MAX_FLICK, MAX_FLICK)
	_velocity.y = clampf(_velocity.y, -MAX_FLICK, MAX_FLICK)


func _can_h() -> bool:
	return horizontal_scroll_mode != SCROLL_MODE_DISABLED and _max_h() > 2.0


func _can_v() -> bool:
	return vertical_scroll_mode != SCROLL_MODE_DISABLED and _max_v() > 2.0


func _max_h() -> float:
	if horizontal_scroll_mode == SCROLL_MODE_DISABLED:
		return 0.0
	var bar := get_h_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


func _max_v() -> float:
	if vertical_scroll_mode == SCROLL_MODE_DISABLED:
		return 0.0
	var bar := get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


func _outside(pos: Vector2, limit_h: float, limit_v: float) -> bool:
	return pos.x < -0.5 or pos.y < -0.5 or pos.x > limit_h + 0.5 or pos.y > limit_v + 0.5


func _drag_parent() -> DragScroll:
	var parent := get_parent()
	while parent:
		if parent is DragScroll:
			return parent
		parent = parent.get_parent()
	return null


func _is_wheel(button: InputEventMouseButton) -> bool:
	return button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN or button.button_index == MOUSE_BUTTON_WHEEL_LEFT or button.button_index == MOUSE_BUTTON_WHEEL_RIGHT


func _on_child_entered(child: Node) -> void:
	_relax(child)
	_arm(child)


func _arm(node: Node) -> void:
	if node != self and not node.child_entered_tree.is_connected(_on_child_entered):
		node.child_entered_tree.connect(_on_child_entered)
	for child in node.get_children():
		_relax(child)
		_arm(child)


func _relax(node: Node) -> void:
	if node is DragScroll:
		return
	if node == get_h_scroll_bar() or node == get_v_scroll_bar():
		return
	if node is Control:
		# PASS lets the drag bubble. A button still sees the press; SCROLL_BEGIN
		# drops it once the finger has moved past the threshold.
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS


func _style_bars() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.08)
	track.content_margin_left = 2
	track.content_margin_right = 2
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.953, 0.937, 0.902, 0.55)
	grab.corner_radius_top_left = 2
	grab.corner_radius_top_right = 2
	grab.corner_radius_bottom_left = 2
	grab.corner_radius_bottom_right = 2
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	grab.content_margin_top = 2
	grab.content_margin_bottom = 2
	var hot := grab.duplicate() as StyleBoxFlat
	hot.bg_color = Color(1.0, 0.541, 0.239, 0.9)
	for bar in [get_v_scroll_bar(), get_h_scroll_bar()]:
		bar.add_theme_stylebox_override("scroll", track)
		bar.add_theme_stylebox_override("scroll_focus", track)
		bar.add_theme_stylebox_override("grabber", grab)
		bar.add_theme_stylebox_override("grabber_highlight", hot)
		bar.add_theme_stylebox_override("grabber_pressed", hot)
