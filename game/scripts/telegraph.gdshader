shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform int shape = 0;          // 0 cercle, 1 cône, 2 rectangle
uniform float half_angle = 0.8; // cône
uniform float progress = 0.0;   // 0 -> 1 : remplissage jusqu'à l'impact
uniform float aspect = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;           // -1..1, p.y = +Z
	float a = 0.0;
	float edge = 0.0;
	float fill = 0.0;
	if (shape == 2) {
		float along = 1.0 - UV.y;        // 0 au départ, 1 au bout
		float side = abs(p.x);
		float border = max(smoothstep(0.86, 0.97, side), smoothstep(0.93, 0.99, along));
		edge = border;
		fill = step(along, progress) * 0.38;
		a = 0.16 + max(edge, fill);
		a *= 1.0 - smoothstep(0.985, 1.0, side);
	} else {
		float r = length(p);
		if (r > 1.0) discard;
		if (shape == 1) {
			float ang = abs(atan(p.x, -p.y));
			if (ang > half_angle) discard;
			float ae = smoothstep(half_angle - 0.06, half_angle, ang);
			edge = max(ae, smoothstep(0.92, 0.99, r));
		} else {
			edge = smoothstep(0.90, 0.985, r);
		}
		fill = step(r, progress) * 0.38;
		// anneau qui avance
		float ring = 1.0 - smoothstep(0.0, 0.05, abs(r - progress));
		a = 0.15 + max(max(edge, fill), ring * 0.7);
	}
	ALBEDO = color.rgb * (1.0 + edge * 0.6);
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
