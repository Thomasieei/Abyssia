extends Node3D
## Zone 1 « Clairière de Brumefeuille » : chaque élément est posé à la main (aucune génération).
## Sud : arrivée du joueur. Ouest : prairie de lin. Nord : camp des brutes. Est : tanière des rôdeurs.

const Player := preload("res://scripts/player.gd")
const Enemy := preload("res://scripts/enemy.gd")
const GatherNode := preload("res://scripts/gather_node.gd")
const Hud := preload("res://scripts/hud.gd")

const N := "res://assets/nature/%s.gltf"
const P := "res://assets/props/%s.gltf"
const HALF := 38.0
const Z_MAX := 86.0          # le bourg prolonge la carte vers le sud
const Town := preload("res://scripts/town.gd")
const Terrain := preload("res://scripts/terrain.gd")

func h(x: float, z: float) -> float:
	return Terrain.height(x, z, PATHS)

# Chemins de terre : segments (ax, az, bx, bz, demi-largeur)
const PATHS := [
	[0, 36, 1, 27, 1.5], [1, 27, -3, 18, 1.5], [-3, 18, -2, 10, 1.4], [-2, 10, 3, 3, 1.4],
	[3, 3, 4, -4, 1.4], [4, -4, 1, -12, 1.5], [1, -12, 0, -17, 1.7],
	[4, -4, 12, -6, 1.1], [12, -6, 18, -8, 1.0],
	[-2, 12, -9, 14, 0.8], [-9, 14, -13, 11, 0.7],
	# sentier du repaire du Gardien (depuis le camp des brutes)
	[-3, -24, -9, -25.5, 0.9], [-9, -25.5, -13, -27, 0.9],
	# sentier du bois des tisseuses (à l'est de la route)
	[1, 27, 7, 25.5, 1.0], [7, 25.5, 12.5, 23.5, 0.9], [12.5, 23.5, 16.5, 21.5, 0.85],
	# route du bourg et allées vers les portes
	[0, 36, 0.3, 45, 1.6], [0.3, 45, 0, 52, 1.8], [-6.3, 58, -2, 58.5, 1.1], [6.3, 60, 2, 60, 1.1], [0, 71.5, 0, 64, 1.3],
	[-8, 70, -4, 66, 0.8], [8, 72, 4, 66, 0.8], [-7, 47, -3, 50, 0.8], [7, 47, 3, 50, 0.8],
]

# Décor posé à la main : [modèle, x, z, angle°, échelle, collision(rayon, 0 = aucune)]
const DECOR := [
	# --- lisière nord (derrière le camp) ---
	["Pine_1", -26, -33, 0, 1.15, 0.6], ["Pine_3", -19, -35, 40, 1.3, 0.6], ["Pine_2", -12, -34, 75, 1.2, 0.6],
	["Pine_4", -6, -36, 10, 1.4, 0.6], ["Pine_1", 2, -35, 120, 1.25, 0.6], ["Pine_5", 9, -34, 200, 1.3, 0.6],
	["Pine_2", 15, -36, 15, 1.15, 0.6], ["Pine_3", 22, -34, 90, 1.35, 0.6], ["Pine_4", 29, -32, 300, 1.2, 0.6],
	["CommonTree_2", -9, -30, 0, 1.0, 0.5], ["CommonTree_4", 7, -30, 60, 1.05, 0.5], ["Pine_5", -2, -31, 250, 0.95, 0.5],
	# --- lisière ouest ---
	["Pine_2", -34, -26, 0, 1.3, 0.6], ["Pine_4", -35, -18, 140, 1.2, 0.6], ["CommonTree_1", -33, -10, 30, 1.15, 0.5],
	["Pine_1", -36, -2, 200, 1.35, 0.6], ["CommonTree_5", -34, 6, 80, 1.1, 0.5], ["Pine_3", -35, 14, 10, 1.25, 0.6],
	["CommonTree_3", -33, 22, 160, 1.1, 0.5], ["Pine_5", -35, 29, 270, 1.2, 0.6], ["Pine_2", -29, 34, 45, 1.15, 0.6],
	# --- lisière est ---
	["Pine_3", 34, -24, 30, 1.25, 0.6], ["DeadTree_2", 35, -19, 0, 1.2, 0.4], ["Pine_1", 35, -8, 110, 1.3, 0.6],
	["Pine_4", 34, 1, 220, 1.2, 0.6], ["CommonTree_2", 33, 9, 15, 1.15, 0.5], ["Pine_2", 35, 17, 300, 1.3, 0.6],
	["CommonTree_4", 33, 25, 75, 1.1, 0.5], ["Pine_5", 30, 33, 190, 1.25, 0.6],
	# --- lisière sud (arrivée) : on laisse l'entrée du chemin libre ---
	["Pine_1", -22, 35, 60, 1.2, 0.6], ["CommonTree_1", -14, 36, 0, 1.1, 0.5], ["Pine_3", -7, 37, 130, 1.3, 0.6],
	["Pine_4", 8, 37, 20, 1.25, 0.6], ["CommonTree_3", 15, 35, 250, 1.1, 0.5], ["Pine_2", 23, 36, 90, 1.2, 0.6],
	# --- bosquets intérieurs (ils cadrent le chemin) ---
	["CommonTree_1", -9, 26, 20, 1.0, 0.5], ["CommonTree_5", 8, 22, 140, 0.95, 0.5], ["Bush_Common", 6, 24, 0, 1.1, 0.0],
	["CommonTree_3", -20, 4, 60, 1.1, 0.5], ["CommonTree_2", -24, -1, 200, 1.0, 0.5], ["Pine_4", -17.5, -1, 0, 1.0, 0.5],
	["CommonTree_4", 13, 13, 90, 1.05, 0.5], ["CommonTree_1", 18, 17, 310, 1.0, 0.5], ["Pine_1", 10.5, 30.0, 30, 0.9, 0.5],
	["TwistedTree_1", -15, -5, 30, 0.72, 0.4], ["CommonTree_5", -15, -14, 100, 1.05, 0.5],
	["TwistedTree_3", 14, -20, 210, 0.75, 0.4], ["Pine_3", -24, -20, 50, 1.05, 0.5], ["CommonTree_2", 22, -24, 150, 1.0, 0.5],
	# --- étang (ouest) : roseaux, pierres de berge ---
	["Grass_Wispy_Tall", -19.6, -9.5, 0, 1.4, 0.0], ["Grass_Wispy_Tall", -20.2, -12.8, 60, 1.3, 0.0], ["Plant_7", -21.5, -15.2, 0, 1.3, 0.0],
	["Grass_Wispy_Tall", -25.5, -15.6, 120, 1.5, 0.0], ["Plant_7_Big", -29.8, -12.5, 30, 1.0, 0.0], ["Grass_Wispy_Tall", -30.2, -8.2, 200, 1.4, 0.0],
	["Grass_Wispy_Tall", -27.6, -4.8, 90, 1.3, 0.0], ["Plant_7", -22.4, -5.0, 300, 1.2, 0.0], ["Fern_1", -19.0, -7.0, 40, 1.2, 0.0],
	["Rock_Medium_2", -20.4, -14.6, 30, 0.6, 0.6], ["Rock_Medium_3", -29.6, -6.4, 200, 0.7, 0.7], ["Pebble_Round_3", -21.2, -7.4, 0, 2.0, 0.0],
	["Pebble_Round_1", -26.8, -15.4, 0, 2.2, 0.0], ["Pebble_Square_2", -30.4, -10.6, 0, 2.0, 0.0],
	# --- falaises : gros rochers au pied des crêtes (tanière des rôdeurs, crête nord) ---
	["Rock_Medium_1", 29.5, -15.5, 20, 2.6, 0.85], ["Rock_Medium_3", 28.0, -9.5, 140, 2.4, 0.85], ["Rock_Medium_2", 26.6, -18.8, 260, 2.2, 0.85],
	["Rock_Medium_1", 31.0, -4.0, 90, 2.0, 0.85], ["Rock_Medium_3", 25.0, 0.8, 300, 1.6, 0.85],
	 ["Rock_Medium_1", 15.0, -31.0, 200, 2.2, 0.85], ["Rock_Medium_3", 22.0, -28.5, 30, 1.8, 0.85],
	["Rock_Medium_1", -29.5, 0.5, 160, 1.8, 0.85], ["Rock_Medium_2", -28.0, 18.0, 40, 1.9, 0.85],
	# --- repaire du Gardien de cendre : cuvette dans la crête, cerclée de rochers ---
	["Rock_Medium_1", -23.5, -26.0, 30, 2.2, 0.85], ["Rock_Medium_3", -22.0, -32.0, 120, 2.4, 0.85], ["Rock_Medium_2", -16.0, -34.0, 200, 2.0, 0.85],
	["Rock_Medium_1", -10.5, -31.5, 290, 1.9, 0.85], ["Rock_Medium_3", -22.5, -21.5, 70, 1.6, 0.85],
	["DeadTree_2", -13.5, -32.5, 210, 1.1, 0.4],
	["Pebble_Round_3", -15.0, -24.5, 0, 2.2, 0.0], ["Pebble_Round_1", -19.5, -31.0, 0, 2.4, 0.0], ["Pebble_Square_2", -12.5, -28.5, 0, 2.0, 0.0],
	# --- bois des tisseuses : arbres qui portent les araignées, souche morte ---
	["CommonTree_2", 23.5, 21.5, 200, 1.1, 0.5], ["DeadTree_2", 22.4, 15.4, 120, 0.9, 0.4], ["CommonTree_3", 25.8, 18.0, 60, 0.9, 0.5],
	["Fern_1", 19.0, 21.6, 30, 1.2, 0.0], ["Fern_1", 24.6, 15.6, 200, 1.1, 0.0], ["Mushroom_Common", 21.2, 20.6, 0, 1.4, 0.0],
	["Mushroom_Common", 17.4, 18.4, 90, 1.2, 0.0], ["Pebble_Round_3", 20.0, 15.2, 0, 1.6, 0.0],
	# --- rochers ---
	["Rock_Medium_1", 9, 6, 30, 1.0, 1.2], ["Rock_Medium_3", -17, 21, 200, 0.9, 1.0], ["Rock_Medium_2", 15, 4, 90, 0.7, 0.8],
	["Rock_Medium_2", -7, -4, 300, 0.8, 0.9], ["Rock_Medium_1", -27, 12, 120, 1.1, 1.2], ["Rock_Medium_3", 26, 14, 10, 1.0, 1.1],
	# tanière des rôdeurs : cercle de rochers et arbres morts
	["Rock_Medium_1", 26, -13, 40, 1.3, 1.5], ["Rock_Medium_3", 18, -14, 160, 1.15, 1.3], ["Rock_Medium_2", 27, -5, 250, 1.2, 1.3],
	["Rock_Medium_1", 22, -16, 300, 0.9, 1.1], ["DeadTree_2", 24, -3, 80, 1.1, 0.4], ["DeadTree_2", 17, -11, 200, 0.9, 0.4],
	["Mushroom_Common", 21, -13, 0, 1.6, 0.0], ["Mushroom_Common", 25, -9, 70, 1.3, 0.0], ["Mushroom_Common", 19, -6, 140, 1.4, 0.0],
	["Fern_1", 23, -14, 0, 1.3, 0.0], ["Fern_1", 28, -9, 90, 1.2, 0.0], ["Fern_1", 18, -9, 200, 1.1, 0.0],
	# --- buissons, fougères, fleurs : bords de chemin ---
	["Bush_Common", -4, 22, 30, 0.9, 0.0], ["Bush_Common", 4, 15, 120, 0.8, 0.0], ["Bush_Common", -6, 4, 0, 1.0, 0.0],
	["Bush_Common", 8, -2, 200, 0.9, 0.0], ["Bush_Common", -3, -9, 60, 0.85, 0.0], ["Bush_Common", 6, -11, 300, 0.9, 0.0],
	["Fern_1", -5, 16, 0, 1.2, 0.0], ["Fern_1", 2, 8, 100, 1.1, 0.0], ["Fern_1", 7, 1, 40, 1.0, 0.0], ["Fern_1", -1, -6, 250, 1.1, 0.0],
	["Plant_7_Big", -8, 28, 0, 1.0, 0.0], ["Plant_1_Big", 9, 18, 60, 1.0, 0.0], ["Plant_7", -18, -12, 0, 1.2, 0.0],
	["Flower_3_Group", -3, 25, 0, 1.0, 0.0], ["Flower_4_Group", 3, 21, 80, 1.0, 0.0], ["Flower_3_Group", -6, 12, 200, 1.0, 0.0],
	["Flower_4_Group", 5, 6, 30, 1.0, 0.0], ["Flower_3_Group", -11, 18, 120, 1.1, 0.0], ["Flower_4_Group", -16, 12, 10, 1.1, 0.0],
	["Flower_3_Group", -13, 6, 300, 1.0, 0.0], ["Flower_4_Group", 11, 10, 170, 1.0, 0.0],
]

# Camp des brutes (nord) : accessoires du village Quaternius
const CAMP := [
	["Prop_Wagon", -7.5, -19.5, 35, 1.0, 1.4], ["Prop_Crate", 5, -26, 10, 1.0, 0.7], ["Prop_Crate", 6.3, -25, 50, 0.85, 0.6],
	["Prop_Crate", 5.6, -26.2, 25, 0.7, 0.0],
	["Prop_WoodenFence_Single", -4, -28, 0, 1.0, 0.0], ["Prop_WoodenFence_Single", -1.5, -28.6, 5, 1.0, 0.0],
	["Prop_WoodenFence_Single", 1.2, -28.6, -5, 1.0, 0.0], ["Prop_WoodenFence_Single", 3.8, -28, -12, 1.0, 0.0],
	["Prop_Support", -3, -26, 0, 1.0, 0.0], ["Prop_Support", 3, -26.5, 0, 1.0, 0.0],
]

## Fantasy Props MegaKit hors du bourg : butin des brutes, trésor du Gardien
const FPROPS := [
	# camp des brutes : chaudron près du feu, tonneaux, râtelier pillé
	["Cauldron", 1.8, -22.6, 20, 0.9, 0.45], ["Barrel", 6.6, -23.6, 0, 0.9, 0.4], ["Barrel", 7.2, -24.6, 40, 0.8, 0.0],
	["WeaponStand", -4.8, -26.8, 10, 0.9, 0.0], ["Bucket_Wooden_1", -1.6, -21.8, 0, 1.0, 0.0],
	# repaire du Gardien : coffre et pièces au fond de la cuvette
	["Chest_Wood", -19.8, -30.2, 30, 0.9, 0.5], ["Coin_Pile", -18.6, -30.8, 0, 1.6, 0.0], ["Coin_Pile", -20.7, -29.0, 70, 1.3, 0.0],
]

# Herbes : touffes posées à la main (centre x, z, nombre de brins)
const GRASS := [
	[-6, 30, 6], [5, 31, 5], [-12, 24, 7], [11, 26, 6], [-15, 16, 8], [-8, 8, 6], [10, 14, 6], [14, 8, 5],
	[-14, 1, 7], [-9, -2, 5], [9, -6, 5], [-5, -14, 6], [8, -18, 5], [-11, -20, 6], [14, -22, 6], [-18, -26, 7],
	[18, -28, 6], [-26, 4, 8], [-24, 18, 7], [24, 6, 7], [20, 12, 6], [28, -18, 6], [-28, -12, 7], [0, 16, 3],
	[-20, 28, 6], [18, 30, 6], [26, 22, 6], [-28, 26, 6], [12, -1, 4], [-4, 1, 4],
]

# Lin sauvage (ressource) : prairie ouest
const FLAX := [[-11, 15, 0, 1.0], [-15, 10, 70, 0.9], [-9, 21, 140, 1.05], [-16, 17, 220, 0.95], [-12, 7, 300, 0.9]]

# Monstres : [type, x, z, angle°]
const MONSTERS := {
	"brutes": [["brute", -2.5, -21, 200], ["brute", 3.0, -22.5, 160]],
	"rodeurs": [["rodeur", 21, -8, 250], ["rodeur", 23.5, -10.5, 220], ["rodeur", 20, -11.5, 280]],
	"repaire": [["boss", -18, -28.5, 140]],
	"tisseuses": [["araignee", 18.6, 17.6, 200], ["araignee", 23.0, 20.8, 230], ["araignee", 21.9, 16.0, 180]],
}

var cam: Camera3D
var rig: Node3D
var player: CharacterBody3D
var _mm_cache := {}
var _dither_mats := {}
var _wind_mats := {}
var cloud_tex: NoiseTexture2D
const FOLIAGE := preload("res://scripts/foliage.gdshader")

## Remplace un matériau de feuillage par la version « vent » (mise en cache, partagée).
func wind_mat(src: StandardMaterial3D, sway: float, sway_h: float, dmin := 0.0, dmax := 0.0) -> Material:
	if OS.get_environment("ABY_NOWIND") != "": return src
	var key := [src, sway, sway_h, dmin]
	if _wind_mats.has(key): return _wind_mats[key]
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("albedo", src.albedo_color)
	m.set_shader_parameter("scissor", 0.5 if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED else 0.0)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("sway_h", sway_h)
	m.set_shader_parameter("fade_min", dmin)
	m.set_shader_parameter("fade_max", dmax)
	m.set_shader_parameter("cloud_tex", cloud_tex)
	_wind_mats[key] = m
	return m

func _is_foliage(src: Material) -> bool:
	var n := src.resource_name
	return "Leaves" in n or "Grass" in n or "Flowers" in n or "Leaf" in n

## Petite végétation (buissons, fougères, fleurs) : vent sans tramage.
func _wind_small(n: Node3D, sway: float, h: float) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(si)
			if src is StandardMaterial3D and _is_foliage(src):
				mi.set_surface_override_material(si, wind_mat(src, sway, h))          # matériau d'origine -> copie qui s'efface près de la caméra

func _ready() -> void:
	G.world = self
	_build_environment()
	_build_ground()
	_build_bounds()
	for d in DECOR: _place(N % d[0], d)
	for d in CAMP: _place(P % d[0], d)
	for d in FPROPS: _place("res://assets/fprops/%s.gltf" % d[0], d)
	_build_campfire(Vector3(0, 0, -24))
	_lair_embers()
	_spider_nest()
	var town: Node = Town.new()
	add_child(town)
	town.build(self)
	_build_grass()
	for f in FLAX:
		var g: Node3D = GatherNode.new()
		g.setup(Vector3(f[0], h(f[0], f[1]), f[1]), deg_to_rad(f[2]), f[3])
		add_child(g)
		G.gather_nodes.append(g)
	var fauna: Node = load("res://scripts/fauna.gd").new()
	add_child(fauna)
	_spawn_player()
	_spawn_monsters()
	_build_camera()
	_build_hud()
	G.warmup(player.global_position)
	G.sentinel = load("res://scripts/sentinel.gd").new()
	add_child(G.sentinel)
	if OS.get_environment("ABY_TEST") != "":
		var td: Node = load("res://scripts/test_driver.gd").new()
		add_child(td)

# --- Ambiance ------------------------------------------------------------
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var ps := ProceduralSkyMaterial.new()
	ps.sky_top_color = Color(0.36, 0.55, 0.78)
	ps.sky_horizon_color = Color(0.78, 0.82, 0.78)
	ps.ground_horizon_color = Color(0.5, 0.55, 0.45)
	ps.ground_bottom_color = Color(0.2, 0.24, 0.16)
	sky.sky_material = ps
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.78, 0.72)
	env.fog_density = 0.0025
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 42.0
	sun.shadow_blur = 1.5
	add_child(sun)

func _build_ground() -> void:
	var m := MeshInstance3D.new()
	m.mesh = _terrain_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/ground.gdshader")
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 3
	nt.noise = fn
	mat.set_shader_parameter("noise_tex", nt)
	cloud_tex = nt
	var segs := PackedVector4Array()
	var ws := PackedFloat32Array()
	for s in PATHS:
		segs.append(Vector4(s[0], s[1], s[2], s[3]))
		ws.append(s[4])
	mat.set_shader_parameter("segs", segs)
	mat.set_shader_parameter("seg_w", ws)
	mat.set_shader_parameter("seg_n", PATHS.size())
	mat.set_shader_parameter("ash_center", Vector3(0, -23, 6.5))
	mat.set_shader_parameter("ash2", Vector3(-17, -28, 5.5))
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	add_child(_terrain_body())
	_build_water()

# Maillage du relief : grille régulière, normales calculées depuis la hauteur.
const GRID := 1.25
const X0 := -58.0
const X1 := 58.0
const Z0 := -58.0
const Z1 := 106.0

func _terrain_mesh() -> ArrayMesh:
	var nx := int((X1 - X0) / GRID) + 1
	var nz := int((Z1 - Z0) / GRID) + 1
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			hs[j * nx + i] = h(X0 + i * GRID, Z0 + j * GRID)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	for j in nz:
		for i in nx:
			var k := j * nx + i
			verts[k] = Vector3(X0 + i * GRID, hs[k], Z0 + j * GRID)
			var hl: float = hs[k - 1] if i > 0 else hs[k]
			var hr: float = hs[k + 1] if i < nx - 1 else hs[k]
			var hd: float = hs[k - nx] if j > 0 else hs[k]
			var hu: float = hs[k + nx] if j < nz - 1 else hs[k]
			norms[k] = Vector3(hl - hr, 2.0 * GRID, hd - hu).normalized()
	var idx := PackedInt32Array()
	idx.resize((nx - 1) * (nz - 1) * 6)
	var c := 0
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			idx[c] = a; idx[c + 1] = a + 1; idx[c + 2] = a + nx
			idx[c + 3] = a + 1; idx[c + 4] = a + nx + 1; idx[c + 5] = a + nx
			c += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

## Collision du relief (grille de 1 m).
func _terrain_body() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Sol"
	var w := int(X1 - X0) + 1
	var d := int(Z1 - Z0) + 1
	var data := PackedFloat32Array()
	data.resize(w * d)
	for j in d:
		for i in w:
			data[j * w + i] = h(X0 + i, Z0 + j)
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = d
	shape.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = Vector3((X0 + X1) * 0.5, 0, (Z0 + Z1) * 0.5)
	return body

## L'étang : eau animée (vagues, reflets, écume au rivage).
func _build_water() -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var r: float = (Terrain.POND[2] + 2.5) * 1.3
	pm.size = Vector2(r * 2, r * 2)
	pm.subdivide_width = 16
	pm.subdivide_depth = 16
	m.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/water.gdshader")
	mat.set_shader_parameter("noise_tex", cloud_tex)
	mat.set_shader_parameter("center", Vector2(Terrain.POND[0], Terrain.POND[1]))
	mat.set_shader_parameter("shore", Terrain.shore_radius())
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(Terrain.POND[0], Terrain.WATER_Y, Terrain.POND[1])
	add_child(m)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = Terrain.shore_radius() - 0.9
	cyl.height = 3.0
	cs.shape = cyl
	body.add_child(cs)
	body.position = Vector3(Terrain.POND[0], 0.5, Terrain.POND[1])
	add_child(body)

func _build_bounds() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var zc := (Z_MAX - HALF) * 0.5
	var zl := HALF + Z_MAX
	for w in [[Vector3(0, 3, -HALF * 0.92), Vector3(2 * HALF + 4, 6, 2)], [Vector3(0, 3, Z_MAX - 3.0), Vector3(2 * HALF + 4, 6, 2)],
			[Vector3(-HALF * 0.92, 3, zc), Vector3(2, 6, zl)], [Vector3(HALF * 0.92, 3, zc), Vector3(2, 6, zl)]]:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = w[1]
		cs.shape = b
		cs.position = w[0]
		body.add_child(cs)

# Pose d'un élément de décor (avec collision cylindrique éventuelle)
func _place(path: String, d: Array) -> void:
	var n: Node3D = load(path).instantiate()
	n.position = Vector3(d[1], h(d[1], d[2]) - 0.04, d[2])
	n.rotation.y = deg_to_rad(d[3])
	n.scale = Vector3.ONE * d[4]
	add_child(n)
	G.decor.append({"node": n, "name": d[0], "r": d[5] * d[4]})
	if "Tree" in path or "Pine" in path:
		_dither_tree(n)
	elif "Bush" in path or "Fern" in path or "Flower" in path or "Plant" in path or "Mushroom" in path:
		_wind_small(n, 0.05, 1.2)
	elif "Rock_" in path:
		_tint(n, Color(0.66, 0.63, 0.58))
		if d[4] >= 1.5: _dither_tree(n, 9.0, 11.5)   # gros rochers : s'effacent s'ils cachent le combat
	elif "Pebble" in path:
		_tint(n, Color(0.5, 0.47, 0.44))
	elif "fprops" in path:
		_tint_soft(n)
	if d[5] > 0.0:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = d[5] * d[4]
		sh.height = 3.0
		cs.shape = sh
		cs.position.y = 1.5
		body.add_child(cs)
		body.position = n.position
		add_child(body)

## Les feuillages proches de la caméra (donc entre elle et le héros) s'effacent en tramage :
## aucun calcul par image, aucun tri de transparence.
func _dither_tree(n: Node3D, dmin := 10.0, dmax := 12.5) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var src: Material = mi.get_surface_override_material(si) if mi.get_surface_override_material(si) else mi.mesh.surface_get_material(si)
			if not (src is StandardMaterial3D): continue
			if _is_foliage(src):
				var tree_h := 6.0 if not "Bush" in src.resource_name else 1.5
				if mi.get_aabb().size.y < 3.0: tree_h = 2.5
				mi.set_surface_override_material(si, wind_mat(src, 0.07, tree_h, dmin, dmax))
				continue
			var key := [src, dmin]
			if not _dither_mats.has(key):
				var m: StandardMaterial3D = src.duplicate()
				m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
				m.distance_fade_min_distance = dmin
				m.distance_fade_max_distance = dmax
				_dither_mats[key] = m
			mi.set_surface_override_material(si, _dither_mats[key])

var _tint_mats := {}
func _tint(n: Node3D, c: Color) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(si)
			if not (src is StandardMaterial3D): continue
			var key := [src, c]
			if not _tint_mats.has(key):
				var m: StandardMaterial3D = src.duplicate()
				m.albedo_color = c
				_tint_mats[key] = m
			mi.set_surface_override_material(si, _tint_mats[key])

## Objets du Fantasy Props MegaKit : texture gardée, juste assombrie (trop claire sous ce rendu).
func _tint_soft(n: Node3D, c := Color(0.8, 0.78, 0.74)) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(si)
			if not (src is StandardMaterial3D): continue
			var key := [src, c, "soft"]
			if not _tint_mats.has(key):
				var m: StandardMaterial3D = src.duplicate()
				m.albedo_color = src.albedo_color * c
				_tint_mats[key] = m
			mi.set_surface_override_material(si, _tint_mats[key])

func _build_campfire(pos: Vector3) -> void:
	pos.y = h(pos.x, pos.z)
	# cercle de pierres
	for i in 8:
		var a := TAU * i / 8.0
		var s: Node3D = load(N % ("Pebble_Round_1" if i % 2 == 0 else "Pebble_Round_3")).instantiate()
		s.position = pos + Vector3(cos(a), 0, sin(a)) * 0.95
		s.position.y = h(s.position.x, s.position.z)
		s.rotation.y = a
		s.scale = Vector3.ONE * 2.2
		add_child(s)
		_tint(s, Color(0.45, 0.42, 0.4))
	var light := OmniLight3D.new()
	light.position = pos + Vector3.UP * 1.2
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 2.2
	light.omni_range = 7.0
	add_child(light)
	var fl := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = G.tex("flame_02")
	q.material = mat
	fl.mesh = q
	fl.amount = 14
	fl.lifetime = 0.8
	fl.position = pos + Vector3.UP * 0.2
	fl.direction = Vector3.UP
	fl.spread = 12
	fl.initial_velocity_min = 0.8
	fl.initial_velocity_max = 1.6
	fl.gravity = Vector3(0, 1.2, 0)
	fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fl.emission_sphere_radius = 0.25
	fl.scale_amount_min = 0.6
	fl.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.55, 0.18, 0.55))
	g.add_point(0.5, Color(0.9, 0.25, 0.06, 0.35))
	g.set_color(g.get_point_count() - 1, Color(0.3, 0.1, 0.05, 0))
	fl.color_ramp = g
	add_child(fl)
	var t := Timer.new()
	t.wait_time = 0.08
	t.autostart = true
	t.timeout.connect(func(): light.light_energy = 2.0 + randf() * 0.6)
	add_child(t)

## Braises qui couvent dans le repaire : lueurs orange et fumerolles.
## Bois des tisseuses : toiles tendues entre les troncs, toiles au sol, cocons de soie.
func _spider_nest() -> void:
	var web := StandardMaterial3D.new()
	web.albedo_texture = load("res://assets/fx/toile.png")
	web.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	web.cull_mode = BaseMaterial3D.CULL_DISABLED
	web.albedo_color = Color(1, 1, 1, 0.75)
	# toiles verticales : [x, z, hauteur, taille, angle°]
	for w in [[20.4, 16.0, 2.2, 2.6, 15], [24.9, 19.6, 2.0, 2.2, -65], [17.2, 20.4, 1.8, 2.0, 70], [22.6, 22.4, 2.4, 1.8, 10]]:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(w[3], w[3])
		m.mesh = q
		m.material_override = web
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		m.position = Vector3(w[0], h(w[0], w[1]) + w[2], w[1])
		m.rotation_degrees = Vector3(0, w[4], 0)
	# toiles au sol (décor)
	var flat := web.duplicate()
	flat.cull_mode = BaseMaterial3D.CULL_BACK
	flat.albedo_color = Color(1, 1, 1, 0.55)
	for g in [[20.6, 18.8, 3.0, 0], [23.6, 17.4, 2.0, 40], [18.4, 19.8, 1.8, 120]]:
		var m := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(g[2], g[2])
		m.mesh = pm
		m.material_override = flat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		m.position = Vector3(g[0], h(g[0], g[1]) + 0.05, g[1])
		m.rotation_degrees.y = g[3]
	# cocons de soie, posés en grappes
	var silk := StandardMaterial3D.new()
	silk.albedo_color = Color(0.86, 0.9, 0.8)
	silk.roughness = 0.9
	silk.rim_enabled = true
	silk.rim = 0.5
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 6
	for c in [[24.3, 16.7, 0.36], [24.8, 17.1, 0.28], [24.0, 17.3, 0.24], [17.6, 18.9, 0.3], [17.2, 18.5, 0.22], [22.0, 22.9, 0.26]]:
		var m := MeshInstance3D.new()
		m.mesh = sm
		m.material_override = silk
		add_child(m)
		m.position = Vector3(c[0], h(c[0], c[1]) + c[2] * 0.6, c[1])
		m.scale = Vector3(c[2] * 1.6, c[2] * 2.1, c[2] * 1.6)
		m.rotation_degrees = Vector3(randf_range(-12, 12), randf() * 360.0, randf_range(-12, 12))

func _lair_embers() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.15)
	light.light_energy = 2.0
	light.omni_range = 10.0
	light.position = Vector3(-17, h(-17, -28) + 1.5, -28)
	add_child(light)
	for e in [Vector3(-20.5, 0, -29.5), Vector3(-14.5, 0, -26.5), Vector3(-18.0, 0, -24.8), Vector3(-15.5, 0, -30.5)]:
		var p := CPUParticles3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.7, 0.7)
		q.material = G._fx_mat("smoke_04", Color.WHITE)
		(q.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		(q.material as StandardMaterial3D).vertex_color_use_as_albedo = true
		p.mesh = q
		p.amount = 6
		p.lifetime = 2.2
		p.direction = Vector3.UP
		p.spread = 10
		p.initial_velocity_min = 0.4
		p.initial_velocity_max = 0.9
		p.gravity = Vector3(0, 0.3, 0)
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.45, 0.12, 0.7))
		g.set_color(1, Color(0.25, 0.2, 0.2, 0.0))
		p.color_ramp = g
		p.position = Vector3(e.x, h(e.x, e.z) + 0.1, e.z)
		add_child(p)

## Herbe : une MultiMesh par type, touffes posées à la main (aucun coût par brin).
func _build_grass() -> void:
	var kinds := ["Grass_Common_Short", "Grass_Common_Tall", "Grass_Wispy_Short", "Grass_Wispy_Tall", "Clover_1"]
	var xf := {}
	for k in kinds: xf[k] = []
	for c in GRASS:
		# disposition fixe en pétale autour du centre (identique à chaque lancement)
		for i in c[2]:
			var a: float = float(i) * 2.399 + c[0] * 0.13
			var r: float = 0.35 + 0.42 * sqrt(float(i))
			var k: String = kinds[(i + int(c[0]) + int(c[1])) % kinds.size()]
			var gx: float = c[0] + cos(a) * r
			var gz: float = c[1] + sin(a) * r
			var t := Transform3D(Basis(Vector3.UP, a * 1.7).scaled(Vector3.ONE * (0.8 + 0.08 * (i % 4))), Vector3(gx, h(gx, gz) - 0.03, gz))
			xf[k].append(t)
	for k in kinds:
		if xf[k].is_empty(): continue
		var src: Node3D = load(N % k).instantiate()
		var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = xf[k].size()
		for i in xf[k].size(): mm.set_instance_transform(i, xf[k][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var gsrc: Material = mi.mesh.surface_get_material(0)
		if gsrc is StandardMaterial3D: mmi.material_override = wind_mat(gsrc, 0.12, 0.8)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		src.free()

# --- Personnages -----------------------------------------------------------
func _spawn_player() -> void:
	player = Player.new()
	player.position = Vector3(0, 0, 63.0)
	add_child(player)
	player.rotation.y = 0.0
	G.player = player

func _spawn_monsters() -> void:
	for camp_name in MONSTERS:
		var camp := []
		for m in MONSTERS[camp_name]:
			var e: CharacterBody3D = Enemy.new()
			e.setup(m[0], Vector3(m[1], h(m[1], m[2]), m[2]), deg_to_rad(m[3]))
			add_child(e)
			camp.append(e)
			G.enemies.append(e)
		for e in camp: e.camp = camp

# --- Caméra vue du dessus ----------------------------------------------
const CAM_PITCH := -58.0
const CAM_DIST := 16.0
var _cam_target := Vector3.ZERO

func _build_camera() -> void:
	rig = Node3D.new()
	add_child(rig)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.5
	cam.far = 120.0
	rig.add_child(cam)
	var dist := CAM_DIST
	var pitch := CAM_PITCH
	if OS.get_environment("ABY_CLOSE") != "":   # capture rapprochée pour vérifier les détails
		dist = 4.5
		pitch = -20.0
	cam.rotation_degrees = Vector3(pitch, 0, 0)
	cam.position = Vector3(0, 1.0 + sin(deg_to_rad(-pitch)) * dist, cos(deg_to_rad(-pitch)) * dist)
	cam.current = true
	_cam_target = player.global_position
	rig.global_position = _cam_target
	G.cam_rig = rig

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	var real: float = G.real_dt
	# la caméra anticipe un peu la direction du mouvement
	var lead: Vector3 = player.velocity * 0.18
	lead.y = 0
	_cam_target = _cam_target.lerp(player.global_position + lead, minf(real * 6.0, 1.0))
	var tr := G.take_trauma(real)
	var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * tr * 0.45
	rig.global_position = _cam_target + off


func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var h: Control = Hud.new()
	h.player = player
	h.cam = cam
	cl.add_child(h)
	G.hud = cl
