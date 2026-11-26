shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;
// Eau de l'étang : vagues qui glissent, reflets du soleil, bord transparent et écume au rivage.
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 center;
uniform float shore = 5.0;
uniform vec4 deep : source_color = vec4(0.06, 0.2, 0.26, 1.0);
uniform vec4 shallow : source_color = vec4(0.2, 0.45, 0.42, 1.0);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.3 + wpos.x * 0.8) * 0.015 + cos(TIME * 1.1 + wpos.z * 0.9) * 0.015;
}

void fragment() {
	vec2 rel = wpos.xz - center;
	float ang = atan(rel.y, rel.x);
	float r = length(rel) / (1.0 + 0.17 * sin(2.0 * ang + 0.7) + 0.09 * sin(3.0 * ang + 2.1));
	if (r > shore + 0.6) discard;
	vec2 uv = wpos.xz * 0.11;
	float n1 = texture(noise_tex, uv + TIME * vec2(0.020, 0.013)).r;
	float n2 = texture(noise_tex, uv * 1.9 - TIME * vec2(0.016, 0.022)).r;
	vec3 nrm = normalize(vec3((n1 - 0.5) * 0.55, 1.0, (n2 - 0.5) * 0.55));
	NORMAL = (VIEW_MATRIX * vec4(nrm, 0.0)).xyz;
	float depthf = smoothstep(shore, shore * 0.25, r);
	vec3 col = mix(shallow.rgb, deep.rgb, depthf);
	// écume qui ondule le long du rivage
	float foam = smoothstep(0.55, 0.0, abs(r - shore + 0.35 + (n1 - 0.5) * 0.5)) * (0.6 + 0.4 * sin(TIME * 2.0 + n2 * 6.0));
	col = mix(col, vec3(0.92, 0.96, 0.95), clamp(foam, 0.0, 1.0) * 0.75);
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALPHA = clamp(mix(0.55, 0.92, depthf) + fres * 0.2 + foam * 0.3, 0.0, 1.0);
}
