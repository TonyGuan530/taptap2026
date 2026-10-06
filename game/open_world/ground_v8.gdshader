shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec2 world_origin = vec2(0.0);
varying vec2 ground_position;
float terrain_hash(vec2 point) {
	vec3 value = fract(vec3(point.xyx) * 0.1031);
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}
float terrain_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	// Quintic interpolation joins random cell values with continuous first derivatives.
	vec2 blend = local * local * local * (local * (local * 6.0 - 15.0) + 10.0);
	return mix(mix(terrain_hash(cell), terrain_hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(terrain_hash(cell + vec2(0.0, 1.0)), terrain_hash(cell + vec2(1.0)), blend.x), blend.y);
}
void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz + world_origin;
}
void fragment() {
	// Quiet organic metre-scale patches, with no periodic lines or checker product.
	vec2 p = ground_position;
	float broad = terrain_noise(p * 0.26) * 2.0 - 1.0;
	float detail = terrain_noise(p * 0.83 + vec2(17.31, 43.17)) * 2.0 - 1.0;
	// Screen derivatives fade the smaller patches before they become sub-pixel detail.
	float detail_visibility = 1.0 - smoothstep(0.10, 0.45, max(length(dFdx(p)), length(dFdy(p))));
	vec3 surface_color = COLOR.rgb;
	// Mesh colors are linear. Compatibility/WebGL lighting expects sRGB ALBEDO.
	if (OUTPUT_IS_SRGB) {
		surface_color = mix(vec3(1.055) * pow(max(surface_color, vec3(0.0)), vec3(1.0 / 2.4)) - vec3(0.055),
			vec3(12.92) * surface_color, lessThan(surface_color, vec3(0.0031308)));
	}
	ALBEDO = surface_color * (1.0 + broad * 0.014 + detail * 0.004 * detail_visibility);
	ROUGHNESS = 1.0;
}
