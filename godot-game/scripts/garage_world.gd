class_name GarageWorld
extends Node3D

## Studio bay. The truck sits on a turntable. One finger orbits, a pinch zooms.
## Lighting stays in a fixed exposure: no auto-exposure, no SSR, glass is unshaded.

var yaw := 0.82
var pitch := 0.26
var distance := 6.4
var _target := Vector3(0.0, 0.86, 0.05)
var _camera: Camera3D
var _env: Environment
var _table: Node3D
var _truck: Node3D
var _signature := ""
var _spin := true
var _hold := 0.0
var _active := true
var _touches := {}
var _touch_block_until := 0


func _ready() -> void:
	_build_room()
	_rebuild()
	Game.changed.connect(_rebuild)
	set_process(true)


func set_active(active: bool) -> void:
	_active = active
	visible = active
	set_process(active)
	if _camera:
		_camera.current = active
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node:
		env_node.environment = _env if active else null


func pose(yaw_value: float, pitch_value: float, dist: float, table_yaw := 0.15) -> void:
	yaw = yaw_value
	pitch = pitch_value
	distance = dist
	_spin = false
	_hold = 999.0
	if _table:
		_table.rotation.y = table_yaw
	_apply_camera()


func handle(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_hold = 1.3
		else:
			_touches.erase(event.index)
		# The browser also emits a pointermove for the same finger. Orbit once.
		_touch_block_until = Time.get_ticks_msec() + 120
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			_touches[event.index] = event.position
		_touch_block_until = Time.get_ticks_msec() + 120
		if _touches.size() >= 2:
			var before := _span()
			_touches[event.index] = event.position
			var after := _span()
			if before > 8.0 and after > 8.0:
				distance = clampf(distance * before / after, 3.3, 9.4)
		else:
			var rel: Vector2 = event.position - _touches[event.index]
			_touches[event.index] = event.position
			yaw -= rel.x * 0.007
			pitch = clampf(pitch - rel.y * 0.004, 0.08, 0.68)
		_hold = 1.3
		_apply_camera()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if OS.has_feature("web") and (not _touches.is_empty() or Time.get_ticks_msec() < _touch_block_until):
			return
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch - event.relative.y * 0.0035, 0.08, 0.68)
		_hold = 1.3
		_apply_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.34, 3.3, 9.4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.34, 3.3, 9.4)
		_apply_camera()


func _process(delta: float) -> void:
	if not _active:
		return
	_hold = maxf(0.0, _hold - delta)
	if _spin and _hold <= 0.0 and _table:
		_table.rotation.y += delta * 0.22
	_fit_fov()
	_apply_camera()


func _rebuild() -> void:
	var sig := Game.signature()
	if sig == _signature and _truck != null:
		return
	_signature = sig
	if _table == null:
		return
	var existing := _table.get_node_or_null("Truck")
	if existing:
		_table.remove_child(existing)
		existing.free()
	_truck = TruckBuilder.build(Game.truck_id, Game.loadout())
	_truck.name = "Truck"
	_table.add_child(_truck)


func _build_room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var compat := MaterialsLib.compatibility_renderer()
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# Compatibility is LDR and has no glow or clearcoat. Lift the studio so the
	# paint still has a highlight and chrome has something to reflect.
	env.tonemap_exposure = 1.08 if compat else 0.86
	env.ambient_light_energy = 0.78 if compat else 0.36
	env.background_energy_multiplier = 0.72 if compat else 0.42
	env.glow_enabled = not compat
	env.glow_intensity = 0.22
	env.glow_strength = 0.42
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.25
	env.ssr_enabled = false
	env.ssao_enabled = false
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08 if compat else 1.05
	env.adjustment_saturation = 1.08 if compat else 1.06
	var sky := Sky.new()
	var hdr := load("res://environment/studio.hdr")
	if hdr is Texture2D:
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = hdr
		panorama.energy_multiplier = 0.85 if compat else 0.4
		sky.sky_material = panorama
	else:
		var fallback := ProceduralSkyMaterial.new()
		fallback.sky_top_color = Color(0.07, 0.08, 0.1)
		fallback.sky_horizon_color = Color(0.16, 0.14, 0.12)
		fallback.ground_bottom_color = Color(0.04, 0.04, 0.05)
		sky.sky_material = fallback
	env.sky = sky
	_env = env
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var concrete := load("res://environment/concrete.png") as Texture2D
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	floor.mesh = plane
	floor.material_override = MaterialsLib.concrete(concrete, 0.72, 0.04, Color(0.72, 0.73, 0.76))
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor)

	_table = Node3D.new()
	_table.name = "Turntable"
	add_child(_table)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.05
	cyl.bottom_radius = 3.05
	cyl.height = 0.04
	cyl.radial_segments = 64
	disc.mesh = cyl
	disc.position.y = 0.02
	var disc_mat := MaterialsLib.concrete(null, 0.42, 0.22, Color(0.28, 0.29, 0.32))
	disc.material_override = disc_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_table.add_child(disc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.82
	torus.outer_radius = 3.02
	torus.rings = 48
	torus.ring_segments = 12
	ring.mesh = torus
	ring.position.y = 0.045
	var ring_mat := MaterialsLib.chrome()
	ring_mat.albedo_color = Color.html("#8a4a28")
	ring_mat.roughness = 0.32
	ring_mat.emission_enabled = true
	ring_mat.emission = Color.html("#ff8a3d")
	ring_mat.emission_energy_multiplier = 0.18
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_table.add_child(ring)
	var blob := MeshInstance3D.new()
	var blob_mesh := CylinderMesh.new()
	blob_mesh.top_radius = 2.1
	blob_mesh.bottom_radius = 2.1
	blob_mesh.height = 0.01
	blob.mesh = blob_mesh
	blob.position.y = 0.046
	var blob_mat := StandardMaterial3D.new()
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.albedo_color = Color(0, 0, 0, 0.28)
	blob_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	blob.material_override = blob_mat
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_table.add_child(blob)

	var wall := MaterialsLib.concrete(null, 0.84, 0.03, Color(0.16, 0.165, 0.18))
	# Nose of the imported truck points down -Z, so the front-view backdrop is +Z.
	_box(Vector3(16, 5.2, 0.18), Vector3(0, 2.6, 6.4), wall)
	_box(Vector3(16, 5.2, 0.18), Vector3(0, 2.6, -6.4), wall)
	_box(Vector3(0.18, 5.2, 14), Vector3(-7.4, 2.6, 0.0), wall)
	_box(Vector3(0.18, 5.2, 14), Vector3(7.4, 2.6, 0.0), wall)
	_box(Vector3(16, 0.18, 14), Vector3(0, 5.15, 0.0), wall)
	_light_panel(Vector3(3.6, 0.08, 1.1), Vector3(0.0, 4.85, -0.6), Color(1, 0.96, 0.9), 1.15)
	_light_panel(Vector3(1.5, 1.8, 0.06), Vector3(4.8, 2.5, 1.2), Color(1.0, 0.78, 0.62), 0.85)
	_light_panel(Vector3(1.3, 1.5, 0.06), Vector3(-4.9, 2.7, 0.4), Color(0.72, 0.8, 1.0), 0.7)

	var title := Label3D.new()
	title.text = "THE BAY"
	title.font = load("res://fonts/Oswald.ttf")
	title.font_size = 128
	title.pixel_size = 0.005
	title.modulate = Color.html("#f3efe6")
	title.outline_size = 0
	title.position = Vector3(0, 3.25, -6.18)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title)
	var sub := Label3D.new()
	sub.text = "OMNIPRESENT"
	sub.font = load("res://fonts/Figtree-SemiBold.ttf")
	sub.font_size = 64
	sub.pixel_size = 0.004
	sub.modulate = Color.html("#ff8a3d")
	sub.position = Vector3(0, 2.62, -6.18)
	sub.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sub)
	var poster := MeshInstance3D.new()
	var poster_mesh := QuadMesh.new()
	poster_mesh.size = Vector2(2.2, 0.62)
	poster.mesh = poster_mesh
	poster.position = Vector3(-4.6, 1.85, -6.18)
	var poster_mat := StandardMaterial3D.new()
	poster_mat.albedo_texture = load("res://environment/sign.png")
	poster_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	poster_mat.roughness = 0.6
	poster_mat.emission_enabled = true
	poster_mat.emission_texture = poster_mat.albedo_texture
	poster_mat.emission = Color(1, 1, 1)
	poster_mat.emission_energy_multiplier = 0.25
	poster.material_override = poster_mat
	poster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(poster)

	var cabinet := MeshInstance3D.new()
	var cab := BoxMesh.new()
	cab.size = Vector3(0.72, 1.05, 0.42)
	cabinet.mesh = cab
	cabinet.position = Vector3(-4.4, 0.52, -2.0)
	var cab_mat := MaterialsLib.plastic()
	cab_mat.albedo_color = Color.html("#2a241e")
	cabinet.material_override = cab_mat
	add_child(cabinet)

	# Key light is off to the side. A head-on key is what clipped the old windshield.
	_sun(Vector3(7.4, 6.8, -1.6), Vector3(0, 0.9, 0.2), Color(1.0, 0.95, 0.88), 1.45 if compat else 1.25, true)
	_sun(Vector3(-5.5, 3.2, 4.4), Vector3(0, 0.8, 0), Color(0.62, 0.74, 1.0), 0.55 if compat else 0.32, false)
	_spot(Vector3(0.2, 5.0, -1.4), Vector3(0, 0.7, 0.2), Color(1, 0.97, 0.93), 1.7 if compat else 2.4)

	var probe := ReflectionProbe.new()
	probe.size = Vector3(14, 7, 14)
	probe.origin_offset = Vector3(0, 1.8, 0)
	probe.intensity = 1.05 if compat else 0.85
	probe.interior = true
	probe.box_projection = true
	probe.enable_shadows = false
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.max_distance = 16.0
	add_child(probe)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.current = true
	_camera.fov = 33.0
	_camera.near = 0.08
	_camera.far = 50.0
	add_child(_camera)
	_apply_camera()


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	add_child(node)


func _light_panel(size: Vector3, pos: Vector3, color: Color, energy: float) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = MaterialsLib.emissive(color, energy)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _sun(from: Vector3, to: Vector3, color: Color, energy: float, shadows: bool) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = shadows
	if shadows:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		light.directional_shadow_max_distance = 18.0
		light.shadow_bias = 0.04
		light.shadow_normal_bias = 1.2
		light.light_angular_distance = 1.1
	add_child(light)
	light.look_at_from_position(from, to, Vector3.UP)


func _spot(from: Vector3, to: Vector3, color: Color, energy: float) -> void:
	var light := SpotLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.spot_range = 12.0
	light.spot_angle = 42.0
	light.spot_attenuation = 0.7
	light.shadow_enabled = false
	add_child(light)
	light.look_at_from_position(from, to, Vector3.UP)


func _fit_fov() -> void:
	if _camera == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.y < 2.0:
		return
	_camera.fov = 30.0 if vp.x > vp.y * 1.15 else 34.0


func _apply_camera() -> void:
	if _camera == null:
		return
	var planar := cos(pitch) * distance
	var eye := _target + Vector3(sin(yaw) * planar, sin(pitch) * distance, cos(yaw) * planar)
	_camera.global_position = eye
	_camera.look_at(_target, Vector3.UP)


func _span() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1])
