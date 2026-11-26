class_name MaterialsLib
extends RefCounted

## PBR slots shared with the web garage: clearcoat paint, chrome, rubber, tinted glass.
## Glass is a fixed-exposure shader. Clearcoat on a transparent StandardMaterial3D
## is what blew the windshield out in the earlier showroom.

const GLASS_SHADER := preload("res://shaders/windshield.gdshader")


static func paint(color: Color, finish_id: String) -> StandardMaterial3D:
	var finish: Dictionary = Catalog.finish(finish_id)
	if finish.is_empty():
		finish = Catalog.FINISHES[0]
	var mat := _pbr(color, float(finish["metal"]), float(finish["rough"]), float(finish["coat"]), float(finish["coat_rough"]))
	mat.resource_name = "Paint"
	if float(finish.get("iridescence", 0.0)) > 0.5:
		mat.rim_enabled = true
		mat.rim = 0.32
		mat.rim_tint = 0.55
	return mat


static func chrome() -> StandardMaterial3D:
	var mat := _pbr(Color.html("#d5dde6"), 1.0, 0.16, 0.35, 0.12)
	mat.resource_name = "Chrome"
	return mat


static func rim(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var coat := 0.4 if metal > 0.8 else 0.1
	var mat := _pbr(color, metal, rough, coat, 0.12)
	mat.resource_name = "Rim"
	return mat


static func rubber() -> StandardMaterial3D:
	var mat := _pbr(Color.html("#16171a"), 0.04, 0.94, 0.0, 0.5)
	mat.resource_name = "Rubber"
	return mat


static func plastic() -> StandardMaterial3D:
	var mat := _pbr(Color.html("#23262c"), 0.18, 0.62, 0.08, 0.4)
	mat.resource_name = "Plastic"
	return mat


static func glass() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GLASS_SHADER
	mat.resource_name = "Glass"
	mat.render_priority = 2
	return mat


static func interior() -> StandardMaterial3D:
	return _pbr(Color.html("#1a120e"), 0.04, 0.78, 0.0, 0.5)


static func plate() -> StandardMaterial3D:
	return _pbr(Color.html("#d8c99e"), 0.0, 0.45, 0.15, 0.3)


static func rotor() -> StandardMaterial3D:
	return _pbr(Color.html("#8d9298"), 0.85, 0.42, 0.1, 0.3)


static func caliper() -> StandardMaterial3D:
	return _pbr(Color.html("#7a2420"), 0.25, 0.48, 0.15, 0.35)


static func lamp() -> StandardMaterial3D:
	var mat := _pbr(Color.html("#fff8ee"), 0.0, 0.28, 0.2, 0.15)
	mat.emission_enabled = true
	mat.emission = Color.html("#ffe6bf")
	mat.emission_energy_multiplier = 1.6
	return mat


static func tail() -> StandardMaterial3D:
	var mat := _pbr(Color.html("#ff4a4a"), 0.0, 0.36, 0.15, 0.2)
	mat.emission_enabled = true
	mat.emission = Color.html("#ff2424")
	mat.emission_energy_multiplier = 1.35
	return mat


static func concrete(tex: Texture2D, rough: float, metal: float, tint: Color) -> StandardMaterial3D:
	var mat := _pbr(tint, metal, rough, 0.0, 0.5)
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(6, 6, 1)
		mat.uv1_triplanar = true
		mat.uv1_triplanar_sharpness = 1.1
	return mat


static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var mat := _pbr(color, 0.0, 0.4, 0.0, 0.5)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


static func compatibility_renderer() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


static func _pbr(color: Color, metal: float, rough: float, coat: float, coat_rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
	mat.metallic = metal
	mat.roughness = rough
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if coat > 0.02 and not compatibility_renderer():
		mat.clearcoat_enabled = true
		mat.clearcoat = coat
		mat.clearcoat_roughness = coat_rough
	elif coat > 0.02:
		# Compatibility has no clearcoat lobe. A tighter roughness and a short
		# rim keep gloss, metallic, and satin from going flat on the web build.
		mat.roughness = clampf(rough * (1.0 - 0.28 * coat), 0.05, 0.95)
		mat.metallic_specular = clampf(0.5 + coat * (0.35 if metal >= 0.5 else 0.16), 0.0, 1.0)
		mat.rim_enabled = true
		mat.rim = clampf(0.08 + coat * 0.22, 0.0, 0.32)
		mat.rim_tint = 0.22
	return mat
