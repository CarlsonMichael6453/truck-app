class_name TrailWorld
extends Node3D

## Switchback and Gulch. The truck is the real garage model. Hazards are the
## same list the web runner uses, placed in three lanes.

const LANE := 2.55

signal finished(payout: Dictionary)

var phase := "lobby"
var track_id := "switchback"
var run: TrailRun
var _track: Dictionary = {}
var _truck: Node3D
var _camera: Camera3D
var _env: Environment
var _ground: Node3D
var _entities: Node3D
var _move := 0
var _active := false
var _signature := ""


func _ready() -> void:
	_build_desert()
	preview("switchback")
	Game.changed.connect(_sync_truck)


func set_active(active: bool) -> void:
	_active = active
	visible = active
	set_process(active)
	if _camera:
		_camera.current = active
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node:
		env_node.environment = _env if active else null


func preview(id: String) -> void:
	phase = "lobby"
	run = null
	_load(id)
	_sync_truck()
	_place(18.0, 1.0)
	_snap_camera()


func start(id: String) -> bool:
	var track := Catalog.track(id)
	if track.is_empty():
		return false
	if int(Game.stats.get("finishes", 0)) < int(track["unlock"]):
		return false
	_load(id)
	_sync_truck()
	run = TrailRun.new()
	phase = "run"
	_move = 0
	_place(0.0, 1.0)
	_snap_camera()
	return true


func pose_run(id: String, at_z: float) -> void:
	_load(id)
	_sync_truck()
	run = TrailRun.new()
	phase = "frozen"
	var guard := 0
	while run.z < at_z and run.status == "running" and guard < 5000:
		run.step(_track, 0, 0.05)
		guard += 1
	_place(run.z, run.lane_pos)
	_snap_camera()


func nudge(dir: int) -> void:
	if phase == "run":
		_move = dir


func bail() -> void:
	if phase != "run" or run == null:
		return
	run.bail()
	phase = "done"
	finished.emit(run.settle(_track))


func meters() -> int:
	return int(floor(run.z)) if run else 0


func run_coins() -> int:
	if run == null:
		return 0
	return run.coins * 10 + int(floor(run.z * 0.28))


func hits() -> int:
	return run.hits if run else 0


func flag_text() -> String:
	if run == null:
		return ""
	if run.boost > 0.0:
		return "BOOST"
	if run.mud > 0.0:
		return "MUD"
	return ""


func _process(delta: float) -> void:
	if not _active:
		return
	if phase == "run" and run != null:
		var move := _move
		_move = 0
		run.step(_track, move, delta)
		_place(run.z, run.lane_pos)
		_spin(delta)
		if run.status != "running":
			phase = "done"
			finished.emit(run.settle(_track))
			return
	_chase(delta)


func _load(id: String) -> void:
	var track := Catalog.track(id)
	if track.is_empty():
		track = Catalog.tracks()[0]
	track_id = str(track["id"])
	_track = track
	if _entities:
		_entities.free()
	_entities = Node3D.new()
	_entities.name = "Entities"
	add_child(_entities)
	for entity in track["entities"]:
		var node := _entity_mesh(str(entity["kind"]))
		node.position = Vector3((int(entity["lane"]) - 1) * LANE, 0.0, float(entity["z"]))
		node.name = str(entity["id"])
		_entities.add_child(node)


func _sync_truck() -> void:
	var sig := Game.signature()
	if _truck != null and sig == _signature:
		return
	_signature = sig
	if _truck:
		_truck.free()
	_truck = TruckBuilder.build(Game.truck_id, Game.loadout())
	_truck.name = "Truck"
	add_child(_truck)


func _place(z: float, lane_pos: float) -> void:
	if _truck == null:
		return
	var x := (lane_pos - 1.0) * LANE
	_truck.position = Vector3(x, 0.0, z)
	_truck.rotation = Vector3(0.0, 0.0, 0.0)
	if _ground:
		_ground.position.z = z


func _spin(delta: float) -> void:
	if _truck == null or not _truck.has_meta("spins"):
		return
	var radius := float(_truck.get_meta("tire_radius", 0.38))
	var speed := float(_track.get("speed", 8.0)) if phase == "run" else 4.0
	if run and phase == "run":
		speed = float(_track.get("speed", 30.0))
		if run.boost > 0.0:
			speed *= 1.45
		if run.mud > 0.0:
			speed *= 0.6
	for spin in _truck.get_meta("spins"):
		(spin as Node3D).rotate_x(speed / radius * delta)


func _snap_camera() -> void:
	_chase(1.0)


func _chase(delta: float) -> void:
	if _camera == null or _truck == null or not is_inside_tree() or not _truck.is_inside_tree():
		return
	var focus := _truck.global_position + Vector3(0.2, 1.15, 7.5)
	var want := _truck.global_position + Vector3(-2.3, 3.6, -8.8)
	var blend := 1.0 if delta >= 1.0 else minf(1.0, delta * 3.2)
	_camera.global_position = _camera.global_position.lerp(want, blend)
	_camera.look_at(focus, Vector3.UP)


func _build_desert() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.ambient_light_energy = 0.62
	env.ssr_enabled = false
	env.ssao_enabled = false
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0045
	env.fog_light_color = Color(0.86, 0.72, 0.55)
	env.fog_aerial_perspective = 0.25
	var sky := Sky.new()
	var proc := ProceduralSkyMaterial.new()
	proc.sky_top_color = Color(0.24, 0.42, 0.68)
	proc.sky_horizon_color = Color(0.95, 0.64, 0.38)
	proc.ground_horizon_color = Color(0.62, 0.46, 0.32)
	proc.ground_bottom_color = Color(0.32, 0.24, 0.18)
	proc.sun_angle_max = 10.0
	sky.sky_material = proc
	env.sky = sky
	_env = env
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	_ground = Node3D.new()
	_ground.name = "Ground"
	add_child(_ground)
	var sand := MeshInstance3D.new()
	var sand_mesh := PlaneMesh.new()
	sand_mesh.size = Vector2(80, 160)
	sand.mesh = sand_mesh
	var asphalt := load("res://environment/asphalt.png") as Texture2D
	sand.material_override = MaterialsLib.concrete(asphalt, 0.92, 0.02, Color(0.72, 0.55, 0.36))
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground.add_child(sand)
	var bed := MeshInstance3D.new()
	var bed_mesh := BoxMesh.new()
	bed_mesh.size = Vector3(LANE * 3.15, 0.04, 150)
	bed.mesh = bed_mesh
	bed.position.y = 0.02
	bed.material_override = MaterialsLib.concrete(asphalt, 0.88, 0.02, Color(0.45, 0.36, 0.28))
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground.add_child(bed)
	for side in [-1.0, 1.0]:
		var line := MeshInstance3D.new()
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(0.08, 0.02, 150)
		line.mesh = line_mesh
		line.position = Vector3(side * LANE * 1.5, 0.05, 0)
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(0.86, 0.78, 0.62)
		paint.roughness = 0.7
		line.material_override = paint
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ground.add_child(line)

	for i in 8:
		var rock := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.8 + float(i % 3) * 0.4
		mesh.height = mesh.radius * 1.6
		mesh.radial_segments = 8
		mesh.rings = 4
		rock.mesh = mesh
		var side := -1.0 if i % 2 == 0 else 1.0
		rock.position = Vector3(side * (9.0 + float(i % 4)), mesh.radius * 0.4, float(i) * 22.0)
		rock.material_override = MaterialsLib.concrete(null, 0.9, 0.02, Color(0.45, 0.34, 0.26))
		add_child(rock)
	for i in 4:
		var mesa := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 3.2 + float(i)
		mesh.bottom_radius = 5.0 + float(i)
		mesh.height = 8.0 + float(i) * 2.2
		mesa.mesh = mesh
		var side := -1.0 if i % 2 == 0 else 1.0
		mesa.position = Vector3(side * 24.0, mesh.height * 0.32, 20.0 + float(i) * 40.0)
		mesa.material_override = MaterialsLib.concrete(null, 0.94, 0.0, Color(0.58, 0.4, 0.28))
		add_child(mesa)

	_sun(Vector3(-10, 12, 8), Vector3(0, 0.6, 0), Color(1.0, 0.9, 0.74), 1.45, true)
	_sun(Vector3(8, 4, -6), Vector3(0, 1, 0), Color(0.5, 0.62, 0.95), 0.28, false)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 38.0
	_camera.near = 0.1
	_camera.far = 180.0
	add_child(_camera)


func _entity_mesh(kind: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.6
	match kind:
		"coin":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.28
			mesh.bottom_radius = 0.28
			mesh.height = 0.08
			node.mesh = mesh
			node.rotation.x = PI * 0.5
			node.position.y = 0.85
			mat.albedo_color = Color.html("#f2c56e")
			mat.metallic = 0.8
			mat.roughness = 0.28
			mat.emission_enabled = true
			mat.emission = Color.html("#f2c56e")
			mat.emission_energy_multiplier = 0.45
		"rock":
			var mesh := SphereMesh.new()
			mesh.radius = 0.55
			mesh.height = 0.9
			mesh.radial_segments = 7
			mesh.rings = 4
			node.mesh = mesh
			node.position.y = 0.4
			mat.albedo_color = Color(0.42, 0.36, 0.32)
			mat.roughness = 0.92
		"barrier":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.35, 0.85, 0.38)
			node.mesh = mesh
			node.position.y = 0.48
			mat.albedo_color = Color.html("#ff8a3d")
			mat.roughness = 0.55
		"mud":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.7, 0.04, 1.7)
			node.mesh = mesh
			node.position.y = 0.06
			mat.albedo_color = Color(0.18, 0.14, 0.1)
			mat.roughness = 1.0
		"boost":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.7, 0.08, 0.35)
			node.mesh = mesh
			node.position.y = 0.1
			mat.albedo_color = Color.html("#7ee0ff")
			mat.emission_enabled = true
			mat.emission = Color.html("#7ee0ff")
			mat.emission_energy_multiplier = 1.4
			mat.roughness = 0.3
		_:
			node.mesh = BoxMesh.new()
	node.material_override = mat
	return node


func _sun(from: Vector3, to: Vector3, color: Color, energy: float, shadows: bool) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = shadows
	if shadows:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		light.directional_shadow_max_distance = 48.0
		light.directional_shadow_blend_splits = true
		light.shadow_bias = 0.05
		light.shadow_normal_bias = 1.4
	add_child(light)
	light.look_at_from_position(from, to, Vector3.UP)
