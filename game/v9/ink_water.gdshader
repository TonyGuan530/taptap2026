shader_type spatial;
render_mode unshaded;
void fragment() {
	float lines=sin(UV.y*72.0+sin(UV.x*12.0+TIME*0.55)*1.9-TIME*0.8);
	float fleck=smoothstep(0.87,0.98,lines)*0.17;
	ALBEDO=mix(vec3(0.12,0.43,0.49),vec3(0.36,0.72,0.71),UV.x*0.45+fleck);
}
