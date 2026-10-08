shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D sprite_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 line_color : source_color = vec4(0.12, 0.13, 0.15, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 4.0;
uniform bool y_billboard = true;

void vertex() {
	if (y_billboard) {
		vec3 up = vec3(0.0, 1.0, 0.0);
		vec3 horizontal_right = vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z);
		vec3 right = length(horizontal_right) > 0.00001 ? normalize(horizontal_right) : vec3(1.0, 0.0, 0.0);
		vec3 front = normalize(cross(right, up));
		mat4 facing = MODEL_MATRIX;
		facing[0].xyz = right * length(MODEL_MATRIX[0].xyz);
		facing[1].xyz = up * length(MODEL_MATRIX[1].xyz);
		facing[2].xyz = front * length(MODEL_MATRIX[2].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	}
}

void fragment() {
	vec4 center = texture(sprite_texture, UV) * tint;
	vec2 screen_pixel_uv = vec2(length(vec2(dFdx(UV.x), dFdy(UV.x))), length(vec2(dFdx(UV.y), dFdy(UV.y))));
	vec2 delta_uv = screen_pixel_uv * outline_width;
	float edge_alpha = center.a;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 sample_uv = UV + vec2(float(x), float(y)) * delta_uv;
			if (all(greaterThanEqual(sample_uv, vec2(0.0))) && all(lessThanEqual(sample_uv, vec2(1.0)))) {
				edge_alpha = max(edge_alpha, texture(sprite_texture, sample_uv).a * tint.a);
			}
		}
	}
	ALBEDO = mix(line_color.rgb, center.rgb, step(0.5, center.a));
	ALPHA = edge_alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
