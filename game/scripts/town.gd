extends Node3D
## Bourg de Brumefeuille : chaque maison est dessinée à la main (plan mur par mur) et posée à la main.
## Maisons modulaires du « Medieval Village MegaKit » (Quaternius) : murs de 2 m, profondeur 8 m.

const V := "res://assets/village/%s.gltf"
const N := "res://assets/nature/%s.gltf"
const P := "res://assets/fprops/%s.gltf"   # Fantasy Props MegaKit (Quaternius)
const CENTER := Vector3(0, 0, 60)      # place du bourg

## Plans : position, orientation (façade vers…), largeur (4 ou 6 m), style, façade / arrière / côtés.
## D = porte, W = grande fenêtre, T = fenêtre étroite, S = mur plein, G = colombage.
const HOUSES := [
	{"name": "Forge de Brumefeuille", "pos": Vector3(12, 0, 60), "yaw": -90, "w": 6, "style": "UnevenBrick",
		"front": "WDW", "back": "SSS", "left": "STTS", "right": "SWSS", "chimney": Vector2(1.6, -2.0)},
	{"name": "Atelier du tisserand", "pos": Vector3(-12, 0, 58), "yaw": 90, "w": 4, "style": "Plaster",
		"front": "DW", "back": "GS", "left": "SWGS", "right": "GTSS"},
	{"name": "Maison du conseil", "pos": Vector3(0, 0, 75.5), "yaw": 180, "w": 6, "style": "UnevenBrick",
		"front": "WDW", "back": "SWS", "left": "SWWS", "right": "SWWS", "chimney": Vector2(-1.8, 2.0)},
	{"name": "", "pos": Vector3(-12, 0, 70), "yaw": 90, "w": 4, "style": "Plaster",
		"front": "WD", "back": "SS", "left": "GTGS", "right": "SWSG", "chimney": Vector2(1.0, 2.5)},
	{"name": "", "pos": Vector3(12, 0, 72), "yaw": -90, "w": 4, "style": "Plaster",
		"front": "DT", "back": "GS", "left": "SWSS", "right": "STGS"},
	{"name": "", "pos": Vector3(-11, 0, 47), "yaw": 90, "w": 4, "style": "UnevenBrick",
		"front": "TD", "back": "SS", "left": "SWSS", "right": "SSWS", "chimney": Vector2(-1.0, -2.5)},
	{"name": "", "pos": Vector3(11, 0, 47), "yaw": -90, "w": 4, "style": "Plaster",
		"front": "DW", "back": "SG", "left": "GWGS", "right": "SWSS"},
]

## Décor du bourg posé à la main : [modèle, x, z, angle°, échelle, rayon de collision]
const PROPS := [
	# étals du marché (nord de la place)
	["V:Prop_Crate", -5.8, 52.2, 20, 0.9, 0.6], ["V:Prop_Crate", -5.2, 53.2, 55, 0.7, 0.0], ["V:Prop_Crate", 6.0, 52.8, 10, 0.9, 0.6],
	# cour de la forge
	["V:Prop_Crate", 7.6, 64.2, 15, 0.85, 0.55], ["V:Prop_Crate", 8.3, 65.0, 40, 0.65, 0.0], ["V:Prop_Crate", 7.5, 55.3, 70, 0.8, 0.5],
	["V:Prop_WoodenFence_Single", 7.0, 53.6, 90, 1.0, 0.0], ["V:Prop_WoodenFence_Single", 7.0, 66.4, 90, 1.0, 0.0],
	# atelier : caisses de lin
	["V:Prop_Crate", -7.4, 54.6, 30, 0.8, 0.5], ["V:Prop_Crate", -7.2, 61.4, 0, 0.75, 0.45],
	# clôtures des jardins
	["V:Prop_WoodenFence_Single", -15.5, 64.0, 0, 1.0, 0.0], ["V:Prop_WoodenFence_Single", -13.4, 64.0, 0, 1.0, 0.0],
	["V:Prop_WoodenFence_Single", 13.5, 66.6, 0, 1.0, 0.0], ["V:Prop_WoodenFence_Single", 15.6, 66.6, 0, 1.0, 0.0],
	["V:Prop_MetalFence_Ornament", -5.0, 71.0, 0, 1.0, 0.0], ["V:Prop_MetalFence_Ornament", 5.0, 71.0, 0, 1.0, 0.0],
	# verdure autour de la place
	["N:Bush_Common_Flowers", -6.5, 66.5, 0, 0.8, 0.0], ["N:Bush_Common_Flowers", 6.5, 67.0, 90, 0.75, 0.0],
	["N:Bush_Common", -6.8, 51.0, 40, 0.8, 0.0], ["N:Flower_3_Group", -4.0, 67.5, 0, 1.0, 0.0], ["N:Flower_4_Group", 4.5, 67.8, 60, 1.0, 0.0],
	["N:Flower_3_Group", -9.0, 63.5, 120, 1.0, 0.0], ["N:Flower_4_Group", 9.5, 52.0, 200, 1.0, 0.0],
	["N:CommonTree_3", -6.5, 78.5, 30, 0.8, 0.45], ["N:CommonTree_1", 6.5, 79.0, 200, 0.75, 0.45],
	# ceinture boisée du bourg
	["N:Pine_2", -20, 44, 0, 1.2, 0.6], ["N:Pine_4", -22, 52, 80, 1.3, 0.6], ["N:CommonTree_2", -21, 60, 30, 1.1, 0.5],
	["N:Pine_1", -22, 68, 140, 1.25, 0.6], ["N:Pine_3", -20, 76, 0, 1.2, 0.6], ["N:CommonTree_4", -15, 81, 60, 1.1, 0.5],
	["N:Pine_5", -6, 83, 10, 1.3, 0.6], ["N:Pine_2", 6, 83, 200, 1.25, 0.6], ["N:CommonTree_5", 15, 81, 90, 1.1, 0.5],
	["N:Pine_4", 21, 75, 30, 1.2, 0.6], ["N:Pine_1", 22, 66, 300, 1.3, 0.6], ["N:CommonTree_1", 21, 57, 120, 1.1, 0.5],
	["N:Pine_3", 22, 49, 45, 1.25, 0.6], ["N:Pine_5", 19, 42, 260, 1.15, 0.6],
	["N:Rock_Medium_2", -17, 63, 30, 0.8, 0.9], ["N:Rock_Medium_3", 17, 79, 200, 0.8, 0.9],
	# --- Fantasy Props MegaKit ---
	# forge : enclume sur billot, pierre à aiguiser, râtelier d'armes, seau d'eau, tonneau
	["P:Anvil_Log", 5.0, 62.0, 75, 1.0, 0.5], ["P:Bucket_Wooden_1", 5.9, 63.0, 20, 1.0, 0.0],
	["P:Whetstone", 7.9, 63.2, -90, 0.95, 0.55], ["P:WeaponStand", 8.0, 57.4, -90, 1.0, 0.6],
	["P:Barrel", 4.6, 57.2, 30, 0.95, 0.4],
	# tisserand : établi, tabouret, rouleau de corde, pot
	["P:Workbench", -4.4, 55.2, 0, 0.95, 0.85], ["P:Stool", -4.6, 54.2, 15, 1.0, 0.0],
	["P:Rope_1", -7.0, 60.4, 40, 1.0, 0.0], ["P:Pot_1", -7.9, 60.0, 0, 1.0, 0.0],
	# marché : tonneau de pommes, cageots, tonneau, charrette d'étal
	["P:Barrel_Apples", -2.3, 49.2, 10, 0.95, 0.4], ["P:FarmCrate_Carrot", 2.4, 49.5, -15, 1.0, 0.35],
	["P:FarmCrate_Apple", -2.4, 50.4, 70, 1.0, 0.0], ["P:Barrel", 6.3, 51.2, 0, 0.9, 0.4],
	["P:Stall_Cart_Empty", 3.4, 43.6, 95, 0.9, 0.9],
	# place : bancs autour de l'arbre, mannequin d'entraînement, coffre devant le conseil
	["P:Bench", -3.7, 63.0, 35, 0.75, 0.0], ["P:Bench", 3.7, 63.0, -35, 0.75, 0.0],
	["P:Dummy", -8.6, 65.2, 40, 1.0, 0.4], ["P:Chest_Wood", 2.6, 70.0, 180, 0.8, 0.45],
]

## Petits objets posés sur les étals (hauteur fixe au-dessus du sol) : [modèle, x, y, z, angle°, échelle]
const ON_STALLS := [
	["FarmCrate_Apple", -4.5, 0.93, 49.8, 5, 0.8], ["FarmCrate_Carrot", -3.8, 0.93, 49.4, -10, 0.7],
	["Coin_Pile", 4.1, 0.93, 49.9, 30, 1.2], ["Pot_1", 4.8, 0.93, 50.2, 0, 0.7],
]

## Postes de travail : interaction quand on s'en approche
const STATIONS := [
	{"id": "tisserand", "label": "Tisser", "title": "Atelier du tisserand", "pos": Vector3(-6.3, 0, 58)},
	{"id": "forge", "label": "Forger", "title": "Forge de Brumefeuille", "pos": Vector3(6.3, 0, 60)},
	{"id": "marche", "label": "Vendre", "title": "Marché du bourg", "pos": Vector3(0, 0, 51.5)},
]

var main: Node3D

func build(m: Node3D) -> void:
	main = m
	for h in HOUSES: _house(h)
	for p in PROPS:
		var path: String = {"V": V, "N": N, "P": P}[p[0][0]] % p[0].substr(2)
		main._place(path, [p[0].substr(2), p[1], p[2], p[3], p[4], p[5]])
	_forge_fire(Vector3(5.6, 0, 55.4))
	_stall(Vector3(-4.2, 0, 49.6), 8)
	_stall(Vector3(4.4, 0, 49.9), -10)
	_square_tree()
	_station_marks()
	for o in ON_STALLS:
		var n: Node3D = load(P % o[0]).instantiate()
		n.position = Vector3(o[1], main.h(o[1], o[3]) + o[2], o[3])
		n.rotation_degrees.y = o[4]
		n.scale = Vector3.ONE * o[5]
		main.add_child(n)
		main._tint_soft(n)

func _put(name: String, local: Vector3, yaw_deg: float, parent: Node3D) -> Node3D:
	var n: Node3D = load(V % name).instantiate()
	n.position = local
	n.rotation_degrees.y = yaw_deg
	parent.add_child(n)
	return n

## Une maison : 4 façades mur par mur selon le plan, poteaux d'angle, toit, pignons, cheminée.
func _house(h: Dictionary) -> void:
	var root := Node3D.new()
	root.position = h.pos
	root.rotation_degrees.y = h.yaw
	main.add_child(root)
	var w: int = h.w
	var hw := w * 0.5
	var st: String = h.style
	_wall_run(root, h.front, Vector3(-hw + 1, 0, 4), Vector3(2, 0, 0), 0, st)
	_wall_run(root, h.back, Vector3(hw - 1, 0, -4), Vector3(-2, 0, 0), 180, st)
	_wall_run(root, h.right, Vector3(hw, 0, 3), Vector3(0, 0, -2), 90, st)
	_wall_run(root, h.left, Vector3(-hw, 0, -3), Vector3(0, 0, 2), -90, st)
	for c in [Vector3(hw, 0, 4), Vector3(-hw, 0, 4), Vector3(hw, 0, -4), Vector3(-hw, 0, -4)]:
		_put("Corner_Exterior_Wood", c, 0, root)
	_put("Roof_RoundTiles_%dx8" % w, Vector3(0, 3.12, 0), 0, root)
	_put("Roof_Front_Brick%d" % w, Vector3(0, 3.12, 4), 0, root)
	_put("Roof_Front_Brick%d" % w, Vector3(0, 3.12, -4), 180, root)
	if h.has("chimney"):
		var ch: Vector2 = h.chimney
		_put("Prop_Chimney", Vector3(ch.x, 2.9, ch.y), 0, root)
	var ext := Vector2(w * 0.5, 4.0) if absi(int(h.yaw)) % 180 == 0 else Vector2(4.0, w * 0.5)
	G.house_boxes.append(Rect2(Vector2(h.pos.x, h.pos.z) - ext, ext * 2.0))
	main._dither_tree(root, 8.5, 11.5)   # toits et murs s'effacent seulement s'ils cachent le héros
	# collision : un bloc par maison
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w + 0.4, 4.0, 8.4)
	cs.shape = box
	cs.position.y = 2.0
	body.add_child(cs)
	root.add_child(body)
	# enseigne
	if h.name != "":
		var l := Label3D.new()
		l.text = h.name
		l.font = load("res://assets/fonts/DejaVuSansCondensed-Bold.ttf")
		l.font_size = 36
		l.fixed_size = true
		l.pixel_size = 0.0011
		l.outline_size = 10
		l.no_depth_test = true
		l.modulate = Color(1, 0.92, 0.75)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(0, 7.6 if w == 6 else 6.6, 3.0)
		root.add_child(l)

func _wall_run(root: Node3D, plan: String, start: Vector3, step: Vector3, yaw: float, st: String) -> void:
	for i in plan.length():
		var p := start + step * i
		match plan[i]:
			"D":
				_put("Wall_%s_Door_Round" % st, p, yaw, root)
				_put("Door_1_Round" if st == "Plaster" else "Door_2_Round", p, yaw, root)
				_put("DoorFrame_Round_WoodDark" if st == "Plaster" else "DoorFrame_Round_Brick", p, yaw, root)
			"W":
				_put("Wall_%s_Window_Wide_Round" % st, p, yaw, root)
				_put("Window_Wide_Round1", p, yaw, root)
				_put("WindowShutters_Wide_Round_Open" if i % 2 == 0 else "WindowShutters_Wide_Round_Closed", p, yaw, root)
			"T":
				_put("Wall_%s_Window_Thin_Round" % st, p, yaw, root)
				_put("Window_Thin_Round1", p, yaw, root)
				_put("WindowShutters_Thin_Round_Open", p, yaw, root)
			"G":
				_put("Wall_Plaster_WoodGrid", p, yaw, root)
			_:
				_put("Wall_%s_Straight" % st, p, yaw, root)

## Braises de la forge (lumière vacillante + flammes).
func _forge_fire(pos: Vector3) -> void:
	main._build_campfire(pos)

## Anneau doré au sol devant chaque poste de travail.
func _station_marks() -> void:
	for s in STATIONS:
		var m := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(3.0, 3.0)
		m.mesh = pm
		var mat := ShaderMaterial.new()
		mat.shader = load("res://scripts/telegraph.gdshader")
		mat.set_shader_parameter("color", Color(1.0, 0.85, 0.45, 0.6))
		mat.set_shader_parameter("shape", 0)
		mat.set_shader_parameter("progress", 0.0)
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.add_child(m)
		m.global_position = s.pos + Vector3(0, 0.05, 0)
		G.stations.append({"id": s.id, "label": s.label, "title": s.title, "pos": s.pos, "mark": m})

## Étal de marché : 4 poteaux de bois, un petit toit de tuiles, des caisses dessous.
func _stall(pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw
	main.add_child(root)
	for c in [Vector3(-0.95, 0, -1.1), Vector3(0.95, 0, -1.1), Vector3(-0.95, 0, 1.1), Vector3(0.95, 0, 1.1)]:
		_put("Corner_Exterior_Wood", c, 0, root).scale = Vector3(1, 0.85, 1)
	_put("Roof_Dormer_RoundTile", Vector3(0, 2.55, 0), 0, root)
	_put("Floor_WoodDark", Vector3(0, 0.9, 0.2), 0, root).scale = Vector3(0.8, 1, 0.55)
	_put("Prop_Crate", Vector3(-0.4, 0, 0.3), 15, root).scale = Vector3.ONE * 0.8
	_put("Prop_Crate", Vector3(0.45, 0, 0.1), -20, root).scale = Vector3.ONE * 0.7
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.0, 2.6)
	cs.shape = box
	cs.position.y = 1.0
	body.add_child(cs)
	root.add_child(body)
	main._dither_tree(root, 6.5, 9.5)

## Arbre central de la place, entouré d'une bordure de pierre.
func _square_tree() -> void:
	main._place(N % "CommonTree_2", ["CommonTree_2", 0, 59.5, 40, 1.05, 0.7])
	for i in 8:
		var a := TAU * i / 8.0
		var b: Node3D = load(V % "Prop_ExteriorBorder_Straight1").instantiate()
		b.position = Vector3(cos(a) * 2.3, 0, 59.5 + sin(a) * 2.3)
		b.rotation.y = -a - PI * 0.5
		b.scale = Vector3(0.95, 1.6, 1.0)
		main.add_child(b)
		main._tint(b, Color(0.62, 0.58, 0.52))
	for f in [[-1.2, 58.6], [1.1, 60.6], [0.6, 58.2]]:
		main._place(N % "Flower_3_Group", ["Flower_3_Group", f[0], f[1], f[0] * 50.0, 0.8, 0.0])
