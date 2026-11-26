extends Node3D

## Garage showroom and the two-truck lot. Capture mode reads engine-demos/shots.json
## and writes PNGs. Interactive mode orbits, and C / R / B / F swap paint, rim, bumper, finish.
## On the lot, WASD drives the Ridgehaul. H hosts a meetup and J joins one.

@export var mode := "showroom"

const PAINTS: Array[Dictionary] = [
	{"name": "Kiln Copper", "hex": "#c4622d"},
	{"name": "Bone Ivory", "hex": "#e6e0d4"},
	{"name": "Night Ink", "hex": "#1b1e26"},
	{"name": "Harbor Teal", "hex": "#1d6e76"},
	{"name": "Dune Sand", "hex": "#c4a56d"},
	{"name": "Signal Violet", "hex": "#3d2b58"},
	{"name": "Brake Crimson", "hex": "#8d2e2e"},
	{"name": "Glacier", "hex": "#c5d0dc"},
]
const RIM_IDS: Array[String] = ["wh-five", "wh-aero", "wh-blade", "wh-split", "wh-turbine", "wh-mesh", "wh-deep"]
const RIM_LOOK: Dictionary = {
	"wh-five": {"name": "Five-Spoke", "hex": "#d5dde6", "metal": 0.95, "rough": 0.18},
	"wh-aero": {"name": "Aero Lattice", "hex": "#d7dee6", "metal": 1.0, "rough": 0.10},
	"wh-blade": {"name": "Vector Blade", "hex": "#e8eef5", "metal": 1.0, "rough": 0.10},
	"wh-split": {"name": "Split Dish", "hex": "#f2f5f8", "metal": 1.0, "rough": 0.07},
	"wh-turbine": {"name": "Solar Turbine", "hex": "#e3c07a", "metal": 1.0, "rough": 0.14},
	"wh-mesh": {"name": "Forged Mesh", "hex": "#c9d2dc", "metal": 1.0, "rough": 0.12},
	"wh-deep": {"name": "Deep Lip", "hex": "#e7edf4", "metal": 1.0, "rough": 0.08},
}
const BUMPERS: Array[String] = ["bp-factory", "bp-tube", "bp-winch", "bp-pre"]
const BUMPER_NAMES := {"bp-factory": "Factory Bar", "bp-tube": "Tube Guard", "bp-winch": "Winch Plate", "bp-pre": "Prerunner Hoop"}
const FINISH_IDS: Array[String] = ["gloss", "metallic", "satin", "matte"]

var _camera: Camera3D
var _trucks: Node3D
var _label: Label
var _shot_file: Dictionary = {}
var _capturing := false
var _orbit_yaw := 0.62
var _orbit_hold := 0.0
var _drive_speed := 0.0
var _paint_i := 0
var _rim_i := 0
var _bumper_i := 0
var _finish_i := 0
var _loadout: Dictionary = {}


func _ready() -> void:
	_shot_file = _read_shots()
	_capturing = _has_flag("--capture")
	_trucks = Node3D.new()
	_trucks.name = "Trucks"
	add_child(_trucks)
	_build_world(mode)
	_build_camera()
	if not _capturing:
		_build_ui()
		_loadout = _default_loadout()
		_spawn_mode()
		_frame_orbit(true)
	else:
		await _run_capture()


func _process(delta: float) -> void:
	if _capturing or _camera == null:
		return
	_orbit_hold = maxf(0.0, _orbit_hold - delta)
	if mode == "lot":
		_drive(delta)
	if _orbit_hold <= 0.0 and _drive_speed < 0.15:
		_orbit_yaw += delta * 0.16
		_frame_orbit(false)
	_spin_wheels(delta)
	_refresh_label()


func _unhandled_input(event: InputEvent) -> void:
	if _capturing:
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_orbit_yaw -= event.relative.x * 0.005
		_orbit_hold = 1.4
		_frame_orbit(false)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.fov = clampf(_camera.fov - 1.5, 18.0, 55.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.fov = clampf(_camera.fov + 1.5, 18.0, 55.0)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_paint_i = (_paint_i + 1) % PAINTS.size()
				_apply_cycle()
			KEY_R:
				_rim_i = (_rim_i + 1) % RIM_IDS.size()
				_apply_cycle()
			KEY_B:
				_bumper_i = (_bumper_i + 1) % BUMPERS.size()
				_apply_cycle()
			KEY_F:
				_finish_i = (_finish_i + 1) % FINISH_IDS.size()
				_apply_cycle()
			KEY_L:
				var next := "res://scenes/lot.tscn" if mode == "showroom" else "res://scenes/showroom.tscn"
				get_tree().change_scene_to_file(next)
			KEY_ESCAPE:
				get_tree().quit()


func _run_capture() -> void:
	var out := _out_dir()
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	var size := Vector2i(int(_shot_file.get("width", 1600)), int(_shot_file.get("height", 900)))
	DisplayServer.window_set_size(size)
	var only := _arg("--only")
	var index := 0
	for raw in _shot_file.get("shots", []):
		var shot: Dictionary = raw
		if only != "" and shot["id"] != only:
			continue
		_clear_trucks()
		var scene_mode := str(shot.get("scene", "showroom"))
		if scene_mode != mode:
			mode = scene_mode
			_rebuild_world()
		if scene_mode == "lot":
			_spawn_lot()
		else:
			var truck := TruckBuilder.build(shot)
			truck.position = Vector3.ZERO
			_trucks.add_child(truck)
		_aim(_camera, _vec(shot["eye"]), _vec(shot["target"]), float(shot["fov"]))
		var frames := 28 if index == 0 else 8
		for _i in frames:
			await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		var path := out.path_join("%s.png" % shot["id"])
		var err := image.save_png(path)
		print("captured %s (%s, %dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
		index += 1
	get_tree().quit()


func _spawn_mode() -> void:
	_clear_trucks()
	if mode == "lot":
		_spawn_lot()
	else:
		var truck := TruckBuilder.build(_loadout)
		truck.name = "Hero"
		_trucks.add_child(truck)


func _spawn_lot() -> void:
	var entries: Array = _shot_file.get("lot", [])
	var first := true
	for raw in entries:
		var entry: Dictionary = raw
		var truck := TruckBuilder.build(entry)
		truck.position = _vec(entry["position"])
		truck.rotation.y = float(entry["yaw"])
		truck.name = "Player" if first else "Talon"
		_trucks.add_child(truck)
		first = false


func _apply_cycle() -> void:
	var paint: Dictionary = PAINTS[_paint_i]
	var rim_id := RIM_IDS[_rim_i]
	var look: Dictionary = RIM_LOOK[rim_id]
	_loadout["paint"] = paint["hex"]
	_loadout["paintName"] = paint["name"]
	_loadout["finish"] = FINISH_IDS[_finish_i]
	_loadout["wheel"] = rim_id
	_loadout["rim"] = look["hex"]
	_loadout["rimMetal"] = look["metal"]
	_loadout["rimRough"] = look["rough"]
	_loadout["bumper"] = BUMPERS[_bumper_i]
	if mode == "lot":
		var player := _trucks.get_node_or_null("Player") as Node3D
		var kept_pos := Vector3.ZERO
		var kept_yaw := 0.0
		_loadout["truck"] = "ridgehaul-summit"
		if player:
			kept_pos = player.global_position
			kept_yaw = player.rotation.y
			player.free()
		var truck := TruckBuilder.build(_loadout)
		truck.name = "Player"
		truck.position = kept_pos
		truck.rotation.y = kept_yaw
		_trucks.add_child(truck)
	else:
		_loadout["truck"] = "ridgehaul-summit"
		_spawn_mode()


func _default_loadout() -> Dictionary:
	var hero: Dictionary = _shot_file["shots"][0]
	return hero.duplicate(true)


func _drive(delta: float) -> void:
	var player := _trucks.get_node_or_null("Player") as Node3D
	if player == null:
		return
	var throttle := 0.0
	if Input.is_physical_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		throttle -= 1.0
	var steer := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		steer += 1.0
	if Input.is_physical_key_pressed(KEY_D):
		steer -= 1.0
	_drive_speed = move_toward(_drive_speed, throttle * 5.2, delta * 6.0)
	if absf(_drive_speed) > 0.08:
		player.rotation.y += steer * delta * 0.9 * signf(_drive_speed)
	var forward := Vector3(sin(player.rotation.y), 0.0, cos(player.rotation.y))
	player.position += forward * _drive_speed * delta
	player.position.x = clampf(player.position.x, -16.0, 16.0)
	player.position.z = clampf(player.position.z, -16.0, 16.0)
	if absf(_drive_speed) > 0.2:
		var back := forward * -6.2 + Vector3(0, 2.3, 0)
		var want := player.global_position + back
		_camera.global_position = _camera.global_position.lerp(want, minf(1.0, delta * 3.0))
		_camera.look_at(player.global_position + Vector3(0, 0.8, 0), Vector3.UP)


func _spin_wheels(delta: float) -> void:
	for truck in _trucks.get_children():
		if not truck.has_meta("spins"):
			continue
		var rate := 0.0
		if mode == "lot" and truck.name == "Player":
			rate = _drive_speed / 0.38
		for spin in truck.get_meta("spins"):
			(spin as Node3D).rotate_x(-rate * delta)


func _frame_orbit(snap: bool) -> void:
	var target := Vector3(0, 0.9, 0.1) if mode == "showroom" else Vector3(0.1, 0.85, 0.1)
	var dist := 7.4 if mode == "showroom" else 12.5
	var height := 1.85 if mode == "showroom" else 2.6
	var eye := target + Vector3(sin(_orbit_yaw) * dist, height, cos(_orbit_yaw) * dist)
	if snap or absf(_drive_speed) < 0.15:
		_aim(_camera, eye, target, 32.0 if mode == "showroom" else 36.0)


func _aim(camera: Camera3D, eye: Vector3, target: Vector3, fov: float) -> void:
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)
	camera.fov = fov


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.current = true
	_camera.near = 0.06
	_camera.far = 80.0
	_camera.fov = 32.0
	add_child(_camera)


func _build_world(kind: String) -> void:
	var doomed: Array[Node] = []
	for child in get_children():
		if child.name == "World" or child.name == "Vignette":
			doomed.append(child)
	for child in doomed:
		remove_child(child)
		child.free()
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.18
	env.glow_strength = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.25
	env.ssao_enabled = true
	env.ssao_radius = 0.45
	env.ssao_intensity = 1.35
	env.ssao_power = 1.4
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.08
	env.ssr_fade_out = 1.4
	env.ssr_depth_tolerance = 0.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.05
	var sky := Sky.new()
	if kind == "lot":
		var proc := ProceduralSkyMaterial.new()
		proc.sky_top_color = Color(0.28, 0.46, 0.74)
		proc.sky_horizon_color = Color(0.95, 0.68, 0.42)
		proc.ground_horizon_color = Color(0.55, 0.44, 0.32)
		proc.ground_bottom_color = Color(0.22, 0.18, 0.14)
		proc.sun_angle_max = 14.0
		sky.sky_material = proc
		env.ambient_light_energy = 0.72
		env.tonemap_exposure = 1.05
		env.ssr_enabled = false
		env.background_energy_multiplier = 1.0
	else:
		var panorama := PanoramaSkyMaterial.new()
		var hdr := _load_tex("res://environment/studio.hdr")
		if hdr:
			panorama.panorama = hdr
		panorama.energy_multiplier = 0.55
		sky.sky_material = panorama
		env.ambient_light_energy = 0.5
		env.tonemap_exposure = 0.82
		env.background_energy_multiplier = 0.45
	env.sky = sky
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)

	if kind == "lot":
		_lot_set(world)
		_sun(world, Vector3(18, 11, 8), Vector3(0, 0.6, 0), Color(1.0, 0.86, 0.68), 1.55, true)
		_sun(world, Vector3(-10, 6, -6), Vector3(0, 1, 0), Color(0.55, 0.68, 1.0), 0.4, false)
	else:
		_showroom_set(world)
		_sun(world, Vector3(6.2, 8.4, 4.6), Vector3(0, 0.7, 0.2), Color(1.0, 0.95, 0.86), 1.15, true)
		_sun(world, Vector3(-6.5, 3.4, -2.2), Vector3(0, 0.8, 0), Color(0.62, 0.74, 1.0), 0.42, false)
		_spot(world, Vector3(1.2, 4.2, 2.6), Vector3(0, 0.7, 0.4), Color(1, 0.97, 0.92), 1.6)
		var probe := ReflectionProbe.new()
		probe.name = "Probe"
		probe.size = Vector3(14, 7, 14)
		probe.origin_offset = Vector3(0, 1.6, 0)
		probe.intensity = 1.15
		probe.interior = true
		probe.box_projection = true
		probe.enable_shadows = false
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.max_distance = 18.0
		world.add_child(probe)
	_vignette()


func _rebuild_world() -> void:
	_build_world(mode)


func _showroom_set(world: Node3D) -> void:
	var concrete := MaterialsLib.concrete(_load_tex("res://environment/concrete.png"), 0.62, 0.06)
	concrete.albedo_color = Color(1.7, 1.7, 1.75)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(22, 22)
	floor.mesh = plane
	floor.material_override = concrete
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(floor)

	var pad_mat := MaterialsLib.concrete(null, 0.32, 0.18)
	pad_mat.albedo_color = Color(0.42, 0.43, 0.46)
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.6
	disc.bottom_radius = 3.6
	disc.height = 0.025
	disc.radial_segments = 72
	pad.mesh = disc
	pad.position = Vector3(0, 0.02, 0.15)
	pad.material_override = pad_mat
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(pad)

	var wall_mat := MaterialsLib.concrete(null, 0.78, 0.04)
	wall_mat.albedo_color = Color(0.18, 0.185, 0.2)
	_slab(world, Vector3(16, 4.6, 0.16), Vector3(0, 2.3, -6.2), wall_mat)
	_slab(world, Vector3(0.16, 4.6, 14), Vector3(-7.2, 2.3, -1.2), wall_mat)
	_slab(world, Vector3(0.16, 4.6, 14), Vector3(7.2, 2.3, -1.2), wall_mat)
	_slab(world, Vector3(16, 0.16, 14), Vector3(0, 4.6, -1.2), wall_mat)

	_panel(world, Vector3(3.2, 0.1, 0.18), Vector3(0.0, 3.35, -6.02), Color(1, 0.96, 0.9), 2.2)

	var sign := _textured_quad("res://environment/sign.png", Vector2(3.4, 0.85))
	sign.position = Vector3(0, 2.55, -6.05)
	world.add_child(sign)

	var cabinet := MeshInstance3D.new()
	var cab := BoxMesh.new()
	cab.size = Vector3(0.7, 1.05, 0.42)
	cabinet.mesh = cab
	cabinet.position = Vector3(-4.6, 0.52, -1.4)
	var cab_mat := MaterialsLib.plastic()
	cab_mat.albedo_color = Color.html("#2a241e")
	cabinet.material_override = cab_mat
	world.add_child(cabinet)


func _lot_set(world: Node3D) -> void:
	var dirt := MaterialsLib.concrete(_load_tex("res://environment/asphalt.png"), 0.86, 0.02)
	dirt.uv1_scale = Vector3(14, 14, 1)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(48, 48)
	ground.mesh = plane
	ground.material_override = dirt
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ground)

	var pad_mat := MaterialsLib.concrete(_load_tex("res://environment/concrete.png"), 0.72, 0.04)
	pad_mat.uv1_scale = Vector3(4, 6, 1)
	var pad := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(12.5, 0.04, 8.5)
	pad.mesh = box
	pad.position = Vector3(0, 0.02, 0.2)
	pad.material_override = pad_mat
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(pad)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.92, 0.9, 0.84)
	paint.roughness = 0.6
	for x in [-1.7, 1.7]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.1, 0.012, 5.4)
		stripe.mesh = stripe_mesh
		stripe.position = Vector3(x, 0.05, 0.2)
		stripe.material_override = paint
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(stripe)

	for x in [-8.5, 8.5]:
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.06
		pole_mesh.bottom_radius = 0.08
		pole_mesh.height = 4.2
		pole.mesh = pole_mesh
		pole.position = Vector3(x, 2.1, -3.5)
		var metal := MaterialsLib.chrome()
		metal.roughness = 0.35
		metal.albedo_color = Color(0.35, 0.37, 0.4)
		pole.material_override = metal
		world.add_child(pole)
		_panel(world, Vector3(0.7, 0.08, 0.35), Vector3(x, 4.15, -3.5), Color(1, 0.93, 0.75), 5.0)

	var sign := _textured_quad("res://environment/lot-sign.png", Vector2(3.6, 0.9))
	sign.position = Vector3(0, 2.4, -5.6)
	world.add_child(sign)


func _slab(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)


func _panel(parent: Node, size: Vector3, pos: Vector3, color: Color, energy: float, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot_deg
	node.material_override = MaterialsLib.emissive_panel(color, energy)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


func _textured_quad(res_path: String, size: Vector2) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _load_tex(res_path)
	mat.roughness = 0.55
	mat.metallic = 0.05
	mat.emission_enabled = true
	mat.emission_texture = mat.albedo_texture
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 0.35
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _sun(parent: Node, from: Vector3, to: Vector3, color: Color, energy: float, shadows: bool) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = shadows
	if shadows:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		light.directional_shadow_max_distance = 36.0
		light.directional_shadow_blend_splits = true
		light.shadow_bias = 0.03
		light.shadow_normal_bias = 1.1
		light.light_angular_distance = 1.4
	parent.add_child(light)
	light.look_at_from_position(from, to, Vector3.UP)


func _spot(parent: Node, from: Vector3, to: Vector3, color: Color, energy: float) -> void:
	var light := SpotLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.spot_range = 14.0
	light.spot_angle = 38.0
	light.spot_attenuation = 0.6
	light.shadow_enabled = false
	parent.add_child(light)
	light.look_at_from_position(from, to, Vector3.UP)


func _vignette() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = 10
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 p = UV * 2.0 - 1.0;\n\tfloat v = smoothstep(0.45, 1.25, length(p * vec2(1.05, 1.0)));\n\tCOLOR = vec4(0.0, 0.0, 0.0, v * 0.42);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	_label = Label.new()
	_label.position = Vector2(28, 22)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_label)
	var hint := Label.new()
	hint.position = Vector2(28, 56)
	hint.text = "Drag to look   C paint   R rim   B bumper   F finish   L lot   WASD drive   H host   J join"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.82, 0.8, 0.74, 0.9))
	layer.add_child(hint)
	add_child(layer)
	var meetup := preload("res://scripts/meetup.gd").new()
	meetup.name = "Meetup"
	add_child(meetup)


func _refresh_label() -> void:
	if _label == null:
		return
	var paint := str(_loadout.get("paintName", ""))
	var finish := str(_loadout.get("finish", "gloss"))
	var rim: Dictionary = RIM_LOOK.get(str(_loadout.get("wheel", "wh-five")), {})
	var bumper := str(BUMPER_NAMES.get(str(_loadout.get("bumper", "")), ""))
	var where := "Showroom" if mode == "showroom" else "Meetup lot"
	var line := "%s    Ridgehaul Summit    %s %s    %s    %s" % [where, paint, finish, rim.get("name", ""), bumper]
	var meetup := get_node_or_null("Meetup")
	if meetup and meetup.has_method("status_line"):
		var extra := str(meetup.status_line())
		if extra != "":
			line += "    " + extra
	_label.text = line


func _clear_trucks() -> void:
	for child in _trucks.get_children():
		child.free()


func _load_tex(res_path: String) -> Texture2D:
	var absolute := ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(absolute) and not FileAccess.file_exists(res_path):
		return null
	if ResourceLoader.exists(res_path):
		var loaded := load(res_path)
		if loaded is Texture2D:
			return loaded
	var image := Image.load_from_file(absolute if FileAccess.file_exists(absolute) else res_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _read_shots() -> Dictionary:
	var path := ProjectSettings.globalize_path("res://").path_join("../shots.json").simplify_path()
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Could not read %s" % path)
		return {}
	return parsed


func _out_dir() -> String:
	var explicit := _arg("--capture")
	if explicit != "":
		return explicit
	return ProjectSettings.globalize_path("res://").path_join("../../renders/godot").simplify_path()


func _arg(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(flag)
	if index >= 0 and index + 1 < args.size() and not str(args[index + 1]).begins_with("--"):
		return str(args[index + 1])
	return ""


func _has_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args()


func _vec(value) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
