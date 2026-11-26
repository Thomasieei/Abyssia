shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
// Contour des personnages (coque inversée) : silhouette lisible en vue du dessus, comme dans Albion.
uniform vec4 color : source_color = vec4(0.06, 0.04, 0.03, 1.0);
uniform float thickness = 0.018;
void vertex() {
	VERTEX += NORMAL * thickness;
}
void fragment() {
	ALBEDO = color.rgb;
}
