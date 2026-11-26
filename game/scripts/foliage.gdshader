shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// Feuillage : balancement au vent (plus fort au sommet, rafales lentes), ombres de nuages,
// tramage près de la caméra pour ne jamais cacher le héros.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float scissor = 0.5;
uniform float sway = 0.06;
uniform float sway_h = 5.0;
uniform float fade_min = 0.0;
uniform float fade_max = 0.0;
uniform sampler2D cloud_tex : repeat_enable, filter_linear;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y / sway_h, 0.0, 1.5);
	float t = TIME * 1.7 + wpos.x * 0.31 + wpos.z * 0.23;
	float gust = 0.55 + 0.45 * sin(TIME * 0.5 + wpos.x * 0.04 + wpos.z * 0.03);
	VERTEX.x += sin(t) * sway * h * h * gust;
	VERTEX.z += cos(t * 0.83) * sway * 0.7 * h * h * gust;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo;
	if (c.a < scissor) discard;
	if (fade_max > 0.0) {
		float f = clamp((-VERTEX.z - fade_min) / (fade_max - fade_min), 0.0, 1.0);
		ivec2 q = ivec2(FRAGCOORD.xy) % 4;
		int i = q.x + q.y * 4;
		float bayer[16] = {0.0,8.0,2.0,10.0,12.0,4.0,14.0,6.0,3.0,11.0,1.0,9.0,15.0,7.0,13.0,5.0};
		if (f < (bayer[i] + 0.5) / 16.0) discard;
	}
	float cl = texture(cloud_tex, wpos.xz * 0.012 + TIME * vec2(0.010, 0.005)).r;
	ALBEDO = c.rgb * mix(1.0, 0.8, smoothstep(0.52, 0.7, cl));
}
