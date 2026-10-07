shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 line_color : source_color = vec4(0.12, 0.13, 0.15, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 1.5;

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 projected_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	vec2 pixel_direction = projected_normal * VIEWPORT_SIZE;
	float direction_length = length(pixel_direction);
	if (direction_length > 0.00001) {
		clip_position.xy += (pixel_direction / direction_length) * (2.0 * outline_width / VIEWPORT_SIZE) * clip_position.w;
	}
	POSITION = clip_position;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
