shader_type spatial;
render_mode cull_back, specular_disabled, ambient_light_disabled;

uniform vec4 base_color : source_color = vec4(0.85, 0.5, 0.3, 1.0);
uniform float light_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_band : hint_range(0.0, 1.0) = 0.22;
uniform float lit_band : hint_range(0.0, 1.0) = 0.78;
uniform float ambient_floor : hint_range(0.0, 1.0) = 0.18;
uniform bool plain_unlit = false;

void fragment() {
	ALBEDO = plain_unlit ? vec3(0.0) : base_color.rgb;
	EMISSION = base_color.rgb * (plain_unlit ? 1.0 : ambient_floor);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float band = mix(shadow_band, lit_band, step(light_threshold, dot(NORMAL, LIGHT)));
	DIFFUSE_LIGHT += (LIGHT_COLOR / PI) * ATTENUATION * band;
}
