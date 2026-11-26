class_name UiKit
extends RefCounted

const INK := Color("0c0e12")
const PANEL := Color("161a21")
const PANEL2 := Color("222833")
const CREAM := Color("f3efe6")
const MUTED := Color("b7b0a4")
const COPPER := Color("ff8a3d")
const COPPER2 := Color("ffb088")
const DANGER := Color("ff6b6b")

static var _theme: Theme
static var display_font: Font
static var body_font: Font
static var body_strong: Font


static func theme() -> Theme:
	if _theme != null:
		return _theme
	display_font = load("res://fonts/Oswald.ttf")
	body_font = load("res://fonts/Figtree.ttf")
	body_strong = load("res://fonts/Figtree-SemiBold.ttf")
	if display_font == null:
		display_font = SystemFont.new()
	if body_font == null:
		body_font = SystemFont.new()
	if body_strong == null:
		body_strong = body_font
	var made := Theme.new()
	made.default_font = body_font
	made.default_font_size = 20
	made.set_color("font_color", "Label", CREAM)
	made.set_color("font_color", "Button", CREAM)
	made.set_color("font_disabled_color", "Button", Color(MUTED, 0.7))
	var normal := box(PANEL2, 18)
	var hover := box(Color("2c3442"), 18)
	var pressed := box(COPPER, 18)
	var disabled := box(Color(PANEL2, 0.55), 18)
	made.set_stylebox("normal", "Button", normal)
	made.set_stylebox("hover", "Button", hover)
	made.set_stylebox("pressed", "Button", pressed)
	made.set_stylebox("disabled", "Button", disabled)
	made.set_stylebox("focus", "Button", normal)
	made.set_color("font_hover_color", "Button", CREAM)
	made.set_color("font_pressed_color", "Button", INK)
	made.set_font_size("font_size", "Button", 18)
	var scroll := StyleBoxEmpty.new()
	made.set_stylebox("panel", "ScrollContainer", scroll)
	_theme = made
	return made


static func box(color: Color, radius: int, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	if border.a > 0.0:
		style.border_color = border
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	return style


static func button(text: String, kind := "panel") -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 48)
	btn.focus_mode = Control.FOCUS_NONE
	if kind == "copper":
		btn.add_theme_stylebox_override("normal", box(COPPER, 18))
		btn.add_theme_stylebox_override("hover", box(Color("ffb088"), 18))
		btn.add_theme_stylebox_override("pressed", box(Color("e07028"), 18))
		btn.add_theme_color_override("font_color", INK)
		btn.add_theme_color_override("font_hover_color", INK)
		btn.add_theme_color_override("font_pressed_color", INK)
	elif kind == "ghost":
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 8
		empty.content_margin_right = 8
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", empty)
		btn.add_theme_stylebox_override("pressed", empty)
		btn.add_theme_color_override("font_color", MUTED)
	return btn


static func label(text: String, size: int, color: Color, display := false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if display and display_font:
		node.add_theme_font_override("font", display_font)
	elif body_font:
		node.add_theme_font_override("font", body_strong if size >= 22 else body_font)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
