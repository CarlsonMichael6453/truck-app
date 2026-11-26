class_name TruckBuilder
extends RefCounted

## Assembles a body GLB plus wheel and bumper GLBs on the anchors from src/content/fit.ts.
## Models stay in src/assets/models. Axis is the Blender export: Y-up, +Z forward, wheel axle +X.

const SPECS := {
	"ridgehaul-summit": {"wheelbase": 3.4, "track": 1.56, "front_over": 0.78, "rear_over": 0.78, "clearance": 0.26, "belt": 0.96, "roof": 1.58, "cab_front": 1.18, "width": 1.86},
	"veldt-meridian": {"wheelbase": 3.55, "track": 1.7, "front_over": 0.86, "rear_over": 1.15, "clearance": 0.32, "belt": 1.04, "roof": 1.7, "cab_front": 1.05, "width": 1.98},
	"northline-harbor": {"wheelbase": 3.2, "track": 1.52, "front_over": 0.7, "rear_over": 0.9, "clearance": 0.28, "belt": 1.0, "roof": 1.82, "cab_front": 0.92, "width": 1.82},
	"kestrel-talon": {"wheelbase": 3.15, "track": 1.66, "front_over": 0.95, "rear_over": 0.58, "clearance": 0.22, "belt": 0.9, "roof": 1.36, "cab_front": 0.95, "width": 1.94},
}


static func models_root() -> String:
	var project := ProjectSettings.globalize_path("res://")
	return project.path_join("../../src/assets/models").simplify_path()


static func build(loadout: Dictionary) -> Node3D:
	var spec: Dictionary = SPECS[str(loadout["truck"])]
	var radius := float(loadout.get("tireRadius", 0.38))
	var lift := maxf(0.0, radius - 0.38)
	var paint := MaterialsLib.paint(Color.html(str(loadout["paint"])), str(loadout.get("finish", "gloss")))
	var rim := MaterialsLib.rim(Color.html(str(loadout.get("rim", "#d5dde6"))), float(loadout.get("rimMetal", 1.0)), float(loadout.get("rimRough", 0.16)))
	var shared := {
		"paint": paint,
		"rim": rim,
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
	root.name = str(loadout["truck"])

	var body := Node3D.new()
	body.name = "Body"
	body.position.y = lift
	root.add_child(body)

	var body_glb := _load_glb(models_root().path_join("trucks/%s.glb" % loadout["truck"]))
	if body_glb:
		_assign(body_glb, shared, false)
		body.add_child(body_glb)

	var anchors := _anchors(spec)
	var bumper_id := str(loadout.get("bumper", ""))
	if bumper_id != "":
		var bumper_path := models_root().path_join("parts/%s.glb" % bumper_id)
		var front_bumper := _load_glb(bumper_path)
		var rear_bumper := _load_glb(bumper_path)
		if front_bumper and rear_bumper:
			_assign(front_bumper, shared, false)
			_assign(rear_bumper, shared, false)
			var front := Node3D.new()
			front.name = "BumperFront"
			front.position = anchors["bumper_front"]
			front.add_child(front_bumper)
			body.add_child(front)
			var rear := Node3D.new()
			rear.name = "BumperRear"
			rear.position = anchors["bumper_rear"]
			rear.rotation.y = PI
			rear.add_child(rear_bumper)
			body.add_child(rear)

	var spins: Array[Node3D] = []
	var wheels: Array = anchors["wheels"]
	for wheel_pos in wheels:
		var pos := wheel_pos as Vector3
		var pivot := Node3D.new()
		pivot.name = "Wheel"
		pivot.position = Vector3(pos.x, radius, pos.z)
		# Face points +X. Left hubs flip so the lip points outward.
		if pos.x < 0.0:
			pivot.rotation.y = PI
		var spin := Node3D.new()
		spin.name = "Spin"
		pivot.add_child(spin)
		var tire := _load_glb(models_root().path_join("parts/%s.glb" % loadout["tire"]))
		var rim_glb := _load_glb(models_root().path_join("parts/%s.glb" % loadout["wheel"]))
		if tire:
			_assign(tire, shared, true)
			spin.add_child(tire)
		if rim_glb:
			_assign(rim_glb, shared, true)
			spin.add_child(rim_glb)
		root.add_child(pivot)
		spins.append(spin)

	root.set_meta("spins", spins)
	root.set_meta("paint_name", str(loadout.get("paintName", "")))
	return root


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
	}


static func _load_glb(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		push_error("Missing GLB: %s" % path)
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_error("GLB %s failed: %s" % [path, error_string(err)])
		return null
	return doc.generate_scene(state) as Node3D


static func _assign(root: Node, slots: Dictionary, is_wheel: bool) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
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
					chosen = slots["rubber"]
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


static func _material_name(mat: Material) -> String:
	if mat == null:
		return ""
	if mat.resource_name != "":
		return mat.resource_name.to_lower()
	return str(mat.name).to_lower()


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
