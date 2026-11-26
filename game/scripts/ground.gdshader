shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 grass_a : source_color = vec4(0.22, 0.38, 0.15, 1.0);
uniform vec4 grass_b : source_color = vec4(0.33, 0.47, 0.19, 1.0);
uniform vec4 grass_dry : source_color = vec4(0.47, 0.47, 0.25, 1.0);
uniform vec4 dirt : source_color = vec4(0.42, 0.32, 0.22, 1.0);
uniform vec4 dirt_dark : source_color = vec4(0.36, 0.28, 0.19, 1.0);
uniform vec4 ash : source_color = vec4(0.25, 0.22, 0.21, 1.0);
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 segs[24];      // segments de chemin : (ax, az, bx, bz)
uniform float seg_w[24];    // demi-largeur de chaque segment
uniform int seg_n = 0;
uniform vec3 ash_center = vec3(0.0, 0.0, -22.0); // xz + rayon : sol piétiné du camp
uniform vec3 square = vec3(0.0, 60.0, 8.5);       // place pavée du bourg : xz + rayon
uniform vec4 stone_a : source_color = vec4(0.47, 0.43, 0.38, 1.0);
uniform vec4 stone_b : source_color = vec4(0.3, 0.28, 0.26, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = texture(noise_tex, p * 0.018).r;
	float n2 = texture(noise_tex, p * 0.09 + 0.37).r;
	float n3 = texture(noise_tex, p * 0.45).r;
	vec3 g = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.3, 0.7, n1));
	g = mix(g, grass_dry.rgb, smoothstep(0.62, 0.85, n2) * 0.45);
	g *= 0.9 + n3 * 0.2;
	// chemins
	float d = 1e5;
	float w = 1.0;
	for (int i = 0; i < seg_n; i++) {
		float di = seg_dist(p, segs[i].xy, segs[i].zw) - seg_w[i];
		if (di < d) { d = di; }
	}
	float edge = (n2 - 0.5) * 0.9 + (n3 - 0.5) * 0.35;
	float path = 1.0 - smoothstep(-0.25, 0.45, d + edge);
	vec3 dcol = mix(dirt.rgb, dirt_dark.rgb, smoothstep(0.35, 0.75, n3));
	vec3 col = mix(g, dcol, path);
	// sol piétiné et cendres autour du camp
	float cd = length(p - ash_center.xy) - ash_center.z;
	float camp = 1.0 - smoothstep(-1.5, 1.8, cd + edge * 2.0);
	col = mix(col, mix(dcol, ash.rgb, 0.35), camp * 0.85);
	// pavés de la place (et des allées) : rangées décalées, joints sombres
	float sq = length(p - square.xy) - square.z;
	float paved = max(1.0 - smoothstep(-0.6, 0.6, sq + edge * 1.2), path * step(48.0, p.y) * step(p.y, 76.0) * step(abs(p.x), 14.0));
	if (paved > 0.001) {
		vec2 sp = p * vec2(1.15, 1.5);
		sp.x += floor(sp.y) * 0.5;
		vec2 g = fract(sp);
		float e = min(min(g.x, 1.0 - g.x) * 1.3, min(g.y, 1.0 - g.y));
		float tile = texture(noise_tex, floor(sp) * 0.137).r;
		vec3 stone = mix(stone_b.rgb, stone_a.rgb, tile) * (0.8 + n3 * 0.3) * (0.85 + n2 * 0.25);
		stone = mix(stone * 0.55, stone, smoothstep(0.04, 0.12, e));
		col = mix(col, stone, paved);
	}
	// ombres de nuages qui glissent lentement sur le sol
	float cl = texture(noise_tex, p * 0.012 + TIME * vec2(0.010, 0.005)).r;
	col *= mix(1.0, 0.8, smoothstep(0.52, 0.7, cl));
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
