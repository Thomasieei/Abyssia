extends RefCounted
## Relief de la clairière, dessiné à la main : chaque colline, crête et l'étang sont listés ici.
## Les chemins, les camps et le bourg restent plats (on y circule et on s'y bat).

# [x, z, rayon, hauteur, raideur]  (raideur > 1 = flancs plus abrupts, façon falaise)
const HILLS := [
	# crête nord, derrière le camp des brutes
	[-22, -34, 12, 5.5, 1.0], [-6, -38, 11, 4.5, 1.0], [10, -37, 12, 5.0, 1.0], [26, -33, 11, 5.5, 1.0],
	# falaises autour de la tanière des rôdeurs (est)
	[32, -13, 8, 6.0, 2.2], [29, -2, 6, 4.0, 2.0], [25, -20, 6.5, 4.5, 2.2], [34, 6, 7, 3.5, 1.4],
	# collines de l'ouest
	[-33, 2, 9, 4.0, 1.0], [-31, 20, 10, 4.5, 1.0], [-34, -20, 8, 3.5, 1.2],
	# ondulations douces dans la clairière
	[11, 15, 6, 1.3, 1.0], [-17, 25, 7, 1.1, 1.0], [15, -1, 5, 0.9, 1.0], [-9, -16, 5, 0.8, 1.0], [20, 26, 7, 1.6, 1.0],
	# lisière sud (entre la clairière et le bourg)
	[-20, 36, 9, 2.5, 1.0], [20, 37, 9, 2.8, 1.0],
]
const POND := [-25.0, -10.0, 6.0, 1.6]      # x, z, rayon, profondeur
const WATER_Y := -0.55
const FLAT_ZONES := [[0, -23, 7.5], [22, -9, 5.5], [-12, 13, 7.0], [-17, -27, 6.5]]   # camp, tanière, prairie du lin, repaire du boss

static func _bump(t: float, k: float) -> float:
	if t >= 1.0: return 0.0
	var b := (cos(PI * t) + 1.0) * 0.5
	return pow(b, 1.0 / k) if k > 1.0 else b

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Hauteur du sol en (x, z).
static func height(x: float, z: float, paths: Array) -> float:
	var p := Vector2(x, z)
	var h := 0.0
	for hl in HILLS:
		var d := p.distance_to(Vector2(hl[0], hl[1]))
		if d < hl[2]: h += hl[3] * _bump(d / hl[2], hl[4])
	# zones plates : chemins, camps, bourg
	var flat := 1.0
	for s in paths:
		var d := _seg_dist(p, Vector2(s[0], s[1]), Vector2(s[2], s[3]))
		flat = minf(flat, smoothstep(s[4] + 0.6, s[4] + 4.5, d))
	for f in FLAT_ZONES:
		flat = minf(flat, smoothstep(f[2], f[2] + 4.0, p.distance_to(Vector2(f[0], f[1]))))
	# bourg et route d'arrivée : plats, sauf la ceinture de collines sur les côtés
	if z > 31.0:
		flat = minf(flat, maxf(1.0 - smoothstep(31.0, 38.0, z), smoothstep(17.0, 25.0, absf(x))))
	h *= flat
	# l'étang
	var rel := p - Vector2(POND[0], POND[1])
	var dp := rel.length() / pond_shape(atan2(rel.y, rel.x))
	if dp < POND[2] + 2.0:
		h -= POND[3] * _bump(dp / (POND[2] + 2.0), 1.0) * 1.6
		h = maxf(h, -POND[3])
	return h

## Contour irrégulier de l'étang (facteur de rayon selon l'angle) — repris dans le shader de l'eau.
static func pond_shape(a: float) -> float:
	return 1.0 + 0.17 * sin(2.0 * a + 0.7) + 0.09 * sin(3.0 * a + 2.1)

## Rayon du rivage (là où le sol croise l'eau), pour l'écume.
static func shore_radius() -> float:
	var r := 0.0
	while r < POND[2] + 2.0:
		if height(POND[0] + r, POND[1], []) > WATER_Y: return r
		r += 0.05
	return POND[2]
