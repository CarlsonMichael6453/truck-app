class_name TruckBuilder
extends RefCounted

## Body plus bolt-on GLBs. Axes stay Y-up and +Z forward, wheel axle along +X.
## Models live in res://models so an iOS or Android export packs them.

static var _cache := {}


static func build(truck_id: String, loadout: Dictionary) -> Node3D:
	var spec := Catalog.truck(truck_id)
	if spec.is_empty():
		spec = Catalog.TRUCKS[0]
	var tire := Catalog.part(str(loadout.get("tire", "ti-hwy")))
	var radius := float(tire.get("look", {}).get("radius", 0.38))
	var lift_part := Catalog.part(str(loadout.get("lift", "lf-0")))
	var lift := float(lift_part.get("look", {}).get("amount", 0.0))
	var body_lift := lift + maxf(0.0, radius - 0.38)
	var paint_info := Catalog.paint(str(loadout.get("paint", spec["paint"])))
	var color := Color.html(str(paint_info.get("hex", "#c4622d")))
	var wheel := Catalog.part(str(loadout.get("wheel", "wh-five")))
	var look: Dictionary = wheel.get("look", {})
	var slots := {
		"paint": MaterialsLib.paint(color, str(loadout.get("finish", "gloss"))),
		"rim": MaterialsLib.rim(Color.html(str(look.get("color", "#d5dde6"))), float(look.get("metal", 1.0)), float(look.get("rough", 0.16))),
		"chrome": MaterialsLib.chrome(),
		"rubber": MaterialsLib.rubber(),
		"plastic": MaterialsLib.plastic(),
		"glass": MaterialsLib.glass(),
		"interior": MaterialsLib.interior(),
		"plate": MaterialsLib.plate(),
		"rotor": MaterialsLib.rotor(),
		"caliper": MaterialsLib.caliper(),
		"lamp": MaterialsLib.lamp(),
		"tail": MaterialsLib.tail(),
	}
	var root := Node3D.new()
	root.name = "Truck"
	var body := Node3D.new()
	body.name = "Body"
	body.position.y = body_lift
	root.add_child(body)
	var body_glb := _spawn("res://models/trucks/%s.glb" % spec["id"])
	if body_glb:
		_assign(body_glb, slots, false)
		body.add_child(body_glb)
	var anchors := _anchors(spec)
	_mount(body, "BumperFront", anchors["bumper_front"], str(loadout.get("bumper", "")), slots, false, 0.0)
	_mount(body, "BumperRear", anchors["bumper_rear"], str(loadout.get("bumper", "")), slots, false, PI)
	_mount(body, "Lights", anchors["lightbar"], str(loadout.get("light", "")), slots, false, 0.0)
	_mount(body, "Exhaust", anchors["exhaust"], str(loadout.get("exhaust", "")), slots, false, 0.0)
	var spoiler := Catalog.part(str(loadout.get("spoiler", "sp-none")))
	if str(spoiler.get("look", {}).get("kind", "none")) != "none":
		_mount(body, "Spoiler", anchors["spoiler"], str(spoiler.get("id", "")), slots, false, 0.0)
	_wrap(body, spec, anchors, loadout)
	var spins: Array[Node3D] = []
	for pos in anchors["wheels"]:
		var wheel_pos: Vector3 = pos
		var pivot := Node3D.new()
		pivot.name = "Wheel"
		pivot.position = Vector3(wheel_pos.x, radius, wheel_pos.z)
		if wheel_pos.x < 0.0:
			pivot.rotation.y = PI
		var spin := Node3D.new()
		spin.name = "Spin"
		pivot.add_child(spin)
		var tire_node := _spawn("res://models/parts/%s.glb" % str(loadout.get("tire", "ti-hwy")))
		var rim_node := _spawn("res://models/parts/%s.glb" % str(loadout.get("wheel", "wh-five")))
		if tire_node:
			_assign(tire_node, slots, true)
			spin.add_child(tire_node)
		if rim_node:
			_assign(rim_node, slots, true)
			spin.add_child(rim_node)
		root.add_child(pivot)
		spins.append(spin)
	root.set_meta("spins", spins)
	root.set_meta("tire_radius", radius)
	return root


static func _mount(body: Node3D, node_name: String, pos: Vector3, part_id: String, slots: Dictionary, is_wheel: bool, yaw: float) -> void:
	if part_id == "" or not Catalog.mesh_part(part_id):
		return
	var glb := _spawn("res://models/parts/%s.glb" % part_id)
	if glb == null:
		return
	_assign(glb, slots, is_wheel)
	var mount := Node3D.new()
	mount.name = node_name
	mount.position = pos
	mount.rotation.y = yaw
	mount.add_child(glb)
	body.add_child(mount)


static func _anchors(spec: Dictionary) -> Dictionary:
	var front := float(spec["wheelbase"]) * 0.5
	var rear := -front
	var half := float(spec["track"]) * 0.5
	var front_z := front + float(spec["front_over"])
	var rear_z := rear - float(spec["rear_over"])
	return {
		"wheels": [
			Vector3(-half, 0.38, front),
			Vector3(half, 0.38, front),
			Vector3(-half, 0.38, rear),
			Vector3(half, 0.38, rear),
		],
		"bumper_front": Vector3(0, float(spec["clearance"]) + 0.18, front_z - 0.02),
		"bumper_rear": Vector3(0, float(spec["clearance"]) + 0.2, rear_z + 0.04),
		"lightbar": Vector3(0, float(spec["roof"]) + 0.04, float(spec["cab_front"]) - 0.05),
		"exhaust": Vector3(float(spec["width"]) * 0.28, float(spec["clearance"]) + 0.08, rear_z + 0.12),
		"spoiler": Vector3(0, float(spec["belt"]) * 0.55 + 0.28, rear_z + 0.22),
	}


static func _wrap(body: Node3D, spec: Dictionary, anchors: Dictionary, loadout: Dictionary) -> void:
	var wrap := Catalog.part(str(loadout.get("wrap", "wr-clean")))
	var look: Dictionary = wrap.get("look", {})
	var kind := str(look.get("kind", "clean"))
	if kind == "clean" or kind == "":
		return
	var accent := Color.html(str(look.get("accent", "#ff8a3d")))
	var lightbar: Vector3 = anchors["lightbar"]
	var spoiler_at: Vector3 = anchors["spoiler"]
	var y := lightbar.y - 0.7
	var z := (lightbar.z + spoiler_at.z) * 0.5
	var side_x := float(spec["width"]) * 0.49
	var mat := StandardMaterial3D.new()
	mat.albedo_color = accent
	mat.roughness = 0.38
	mat.metallic = 0.22
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if kind == "circuit":
		mat.emission_enabled = true
		mat.emission = accent
		mat.emission_energy_multiplier = 1.8
	for side in [-1.0, 1.0]:
		if kind == "stripe" or kind == "circuit":
			_decal(body, Vector3(0.012, 0.045, 1.35), Vector3(side * side_x, y, z), Vector3.ZERO, mat)
		elif kind == "geo":
			for index in 3:
				_decal(body, Vector3(0.012, 0.16, 0.07), Vector3(side * side_x, y, z - 0.45 + float(index) * 0.38), Vector3(0, 0, side * 0.45), mat)
		elif kind == "sunset":
			var fade := mat.duplicate() as StandardMaterial3D
			fade.albedo_color = accent
			fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fade.albedo_color.a = 0.85
			_decal(body, Vector3(0.012, 0.42, 1.3), Vector3(side * (side_x + 0.01), y, z), Vector3.ZERO, fade)


static func _decal(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation = rot
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


static func _spawn(path: String) -> Node3D:
	if not _cache.has(path):
		_cache[path] = load(path)
	var packed = _cache[path]
	if packed == null or not (packed is PackedScene):
		push_error("Missing model %s" % path)
		return null
	return (packed as PackedScene).instantiate() as Node3D


static func _assign(root: Node, slots: Dictionary, is_wheel: bool) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect(root, meshes)
	for mesh_node in meshes:
		var node_name := mesh_node.name.to_lower()
		if "lod" in node_name:
			mesh_node.visible = false
			continue
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var source := mesh_node.mesh.surface_get_material(surface)
			var label := node_name + " " + _material_name(source)
			var role := _role(label)
			var chosen: Material = slots["plastic"]
			match role:
				"glass":
					chosen = slots["glass"]
					mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				"caliper":
					chosen = slots["caliper"]
				"rotor":
					chosen = slots["rotor"]
				"interior":
					chosen = slots["interior"]
				"rubber":
					chosen = _rubber_with_normal(slots["rubber"], source)
				"tail":
					chosen = slots["tail"]
				"light":
					chosen = slots["lamp"]
				"plate":
					chosen = slots["plate"]
				"chrome":
					chosen = slots["rim"] if is_wheel else slots["chrome"]
				"paint":
					chosen = slots["paint"]
				_:
					chosen = slots["rim"] if is_wheel else slots["plastic"]
			mesh_node.set_surface_override_material(surface, chosen)


static func _rubber_with_normal(base: Material, source: Material) -> Material:
	if source is StandardMaterial3D and (source as StandardMaterial3D).normal_texture != null:
		var copy := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
		copy.normal_enabled = true
		copy.normal_texture = (source as StandardMaterial3D).normal_texture
		copy.normal_scale = 0.85
		return copy
	return base


static func _collect(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node)
	for child in node.get_children():
		_collect(child, into)


static func _material_name(mat: Material) -> String:
	if mat == null:
		return ""
	if mat.resource_name != "":
		return mat.resource_name.to_lower()
	return str(mat.resource_path).get_file().to_lower()


static func _role(label: String) -> String:
	if "glass" in label:
		return "glass"
	if "caliper" in label:
		return "caliper"
	if "rotor" in label:
		return "rotor"
	if "interior" in label:
		return "interior"
	if "rubber" in label:
		return "rubber"
	if "tail" in label:
		return "tail"
	if "light" in label:
		return "light"
	if "plate" in label:
		return "plate"
	if "chrome" in label:
		return "chrome"
	if "paint" in label or "body" in label or "trim" in label:
		return "paint"
	if "plastic" in label:
		return "plastic"
	return "other"
