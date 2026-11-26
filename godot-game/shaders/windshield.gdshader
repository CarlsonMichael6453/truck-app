shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, fog_disabled, cull_back;

// Fixed exposure for the cab glass. The showroom demo's clearcoat glass turned
// white wherever the pane faced the key light. This shader ignores lights and
// keeps the tint under a hard cap so the windshield cannot blow out.
uniform vec4 tint : source_color = vec4(0.07, 0.13, 0.16, 1.0);
uniform float alpha : hint_range(0.05, 0.8) = 0.30;
uniform float fresnel_power : hint_range(0.5, 6.0) = 2.4;
uniform float edge : hint_range(0.0, 1.0) = 0.62;
uniform float cap : hint_range(0.05, 0.7) = 0.40;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, fresnel_power);
	vec3 body = tint.rgb;
	vec3 sheen = vec3(0.30, 0.36, 0.40);
	vec3 color = mix(body, sheen, fresnel * edge);
	color = min(color, vec3(cap));
	ALBEDO = color;
	ALPHA = clamp(mix(alpha, alpha + 0.18, fresnel), 0.12, 0.58);
}
