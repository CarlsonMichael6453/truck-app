shader_type canvas_item;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float v = smoothstep(0.52, 1.28, length(p * vec2(0.9, 1.0)));
	COLOR = vec4(0.0, 0.0, 0.0, v * 0.42);
}
