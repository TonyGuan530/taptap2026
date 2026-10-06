shader_type spatial;
render_mode unshaded, cull_front;
void vertex(){ VERTEX+=NORMAL*0.009; }
void fragment(){ ALBEDO=vec3(0.16,0.22,0.27); }
