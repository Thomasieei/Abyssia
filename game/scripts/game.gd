extends Node
## État global léger + ressenti des coups (micro-gel, secousse, effets, chiffres).

signal silver_changed(v: int)
signal item_gained(id: String, amount: int)
signal target_changed(t)
signal announce(msg: String)
signal boss_defeated(boss)

var world: Node3D
var player: Node3D
var cam_rig: Node3D
var hud: CanvasLayer
var enemies: Array = []
var gather_nodes: Array = []
var stations: Array = []
var decor: Array = []         # {node, name, r} : tout le décor posé (pour la sentinelle)
var house_boxes: Array = []   # Rect2 au sol de chaque maison
var sentinel: Node

var silver := 0
var inventory := {}  # id -> quantité

const ITEMS := {
	"lin": {"name": "Fibre de lin", "color": Color(0.85, 0.82, 0.6), "price": 2},
	"tissu": {"name": "Tissu de lin", "color": Color(0.95, 0.93, 0.8), "price": 9},
	"cendre": {"name": "Cœur de cendre", "color": Color(1.0, 0.45, 0.15), "price": 16},
	"griffe": {"name": "Griffe de rôdeur", "color": Color(0.7, 0.75, 0.95), "price": 11},
	"coeur_ardent": {"name": "Cœur ardent", "color": Color(1.0, 0.3, 0.05), "price": 90},
}

## Équipement : chaque pièce donne le sort de son emplacement (« tu es ce que tu portes »).
## skill = index du sort dans player.SPELLS
const GEAR := {
	"casque_garde": {"name": "Heaume du gardien", "slot": "casque", "spell": "garde"},
	"capuche_lin": {"name": "Capuche de lin", "slot": "casque", "spell": "souffle"},
	"plastron_fureur": {"name": "Plastron du soldat", "slot": "plastron", "spell": "fureur"},
	"plastron_cendre": {"name": "Plastron de cendre", "slot": "plastron", "spell": "embrase"},
	"bottes_vent": {"name": "Bottes de voyage", "slot": "bottes", "spell": "vent"},
	"bottes_rodeur": {"name": "Bottes du rôdeur", "slot": "bottes", "spell": "roulade"},
}

## Recettes par poste de travail : produit, quantité, coût {objet: n}, argent, durée
const RECIPES := {
	"tisserand": [
		{"out": "tissu", "n": 1, "cost": {"lin": 3}, "silver": 0, "time": 1.2},
	],
	"forge": [
		{"out": "capuche_lin", "n": 1, "cost": {"tissu": 3}, "silver": 15, "time": 1.6},
		{"out": "plastron_cendre", "n": 1, "cost": {"tissu": 2, "cendre": 2}, "silver": 30, "time": 1.8},
		{"out": "bottes_rodeur", "n": 1, "cost": {"tissu": 2, "griffe": 2}, "silver": 20, "time": 1.6},
	],
}

var owned_gear := {"casque_garde": true, "plastron_fureur": true, "bottes_vent": true}
var equipped := {"casque": "casque_garde", "plastron": "plastron_fureur", "bottes": "bottes_vent"}
signal gear_changed

func item_name(id: String) -> String:
	if ITEMS.has(id): return ITEMS[id].name
	if GEAR.has(id): return GEAR[id].name
	return id

func can_craft(r: Dictionary) -> bool:
	if silver < r.silver: return false
	for k in r.cost:
		if inventory.get(k, 0) < r.cost[k]: return false
	if GEAR.has(r.out) and owned_gear.has(r.out): return false
	return true

func craft(r: Dictionary) -> bool:
	if not can_craft(r): return false
	silver -= r.silver
	silver_changed.emit(silver)
	for k in r.cost:
		inventory[k] -= r.cost[k]
		if inventory[k] <= 0: inventory.erase(k)
	if GEAR.has(r.out):
		owned_gear[r.out] = true
		equip(r.out)
		item_gained.emit(r.out, 1)
	else:
		give_item(r.out, r.n)
	return true

func equip(id: String) -> void:
	equipped[GEAR[id].slot] = id
	gear_changed.emit()

func sell_all(id: String) -> int:
	var n: int = inventory.get(id, 0)
	if n <= 0: return 0
	var v: int = n * ITEMS[id].price
	inventory.erase(id)
	give_silver(v)
	return v

var _stop_until := 0
var _trauma := 0.0
var _tele_shader: Shader
var _tex_cache := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tele_shader = load("res://scripts/telegraph.gdshader")

var real_dt := 0.016         # durée réelle de la dernière image (indépendante du micro-gel)
var _last_us := 0

func _process(_d: float) -> void:
	_pulse_lava()
	var now := Time.get_ticks_usec()
	if _last_us > 0: real_dt = clampf((now - _last_us) / 1000000.0, 0.0, 0.25)
	_last_us = now
	if _stop_until > 0 and Time.get_ticks_msec() >= _stop_until:
		_stop_until = 0
		Engine.time_scale = 1.0

# --- Ressenti -------------------------------------------------------------
## Gèle tout le jeu (attaquant ET cible) quelques millisecondes à l'impact.
func hitstop(ms: int) -> void:
	Engine.time_scale = 0.04
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + ms)

func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func take_trauma(delta: float) -> float:
	var t := _trauma
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	return t * t

func give_silver(v: int) -> void:
	silver += v
	silver_changed.emit(silver)

func give_item(id: String, n: int) -> void:
	inventory[id] = inventory.get(id, 0) + n
	item_gained.emit(id, n)

# --- Effets ---------------------------------------------------------------
func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load("res://assets/fx/%s.png" % name)
	return _tex_cache[name]

## Gerbe de particules à usage unique (libérée automatiquement).
func burst(pos: Vector3, texname: String, color: Color, amount := 14, speed := 4.0, size := 0.5, life := 0.45, gravity := -6.0) -> void:
	var p := CPUParticles3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex(texname)
	mesh.material = mat
	p.mesh = mesh
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.2, false).timeout.connect(p.queue_free)

## Traînée de lame : un arc texturé qui s'efface.
func slash(origin: Vector3, yaw: float, color: Color, radius := 2.2, flip := false) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex("slash_02")
	mat.albedo_color = color
	q.material = mat
	m.mesh = q
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	m.global_position = origin + Vector3(0, 1.0, 0)
	m.rotation = Vector3(0, yaw + (PI if flip else 0.0), 0)
	m.scale = Vector3(0.6, 1, 0.6)
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3(1.15, 1, 1.15), 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.22).set_delay(0.06)
	tw.chain().tween_callback(m.queue_free)

## Chiffre de dégâts qui saute et s'efface.
func number(pos: Vector3, value: int, color: Color, big := false) -> void:
	var l := Label3D.new()
	l.text = str(value)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011 if big else 0.0008
	l.font_size = 44
	l.outline_size = 12
	l.modulate = color
	if color.a <= 0.0: l.outline_modulate = Color(0, 0, 0, 0)
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.font = load("res://assets/fonts/DejaVuSansCondensed-Bold.ttf")
	world.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.35, 0.35), 0.0, 0.0)
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "global_position:y", pos.y + 1.1, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_property(l, "scale", Vector3.ONE * (1.35 if big else 1.15), 0.08)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(l.queue_free)

## Zone au sol annonçant une attaque. shape: 0 cercle, 1 cône, 2 rectangle.
## Renvoie le nœud ; appeler set_progress via shader param "progress".
func telegraph(pos: Vector3, yaw: float, shape: int, size: Vector2, color: Color, cone_deg := 90.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	if shape == 2:
		pm.center_offset = Vector3(0, 0, -size.y * 0.5)
	m.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = _tele_shader
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("shape", shape)
	mat.set_shader_parameter("half_angle", deg_to_rad(cone_deg * 0.5))
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("aspect", size.x / maxf(size.y, 0.01))
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	m.global_position = Vector3(pos.x, world.h(pos.x, pos.z) + 0.07, pos.z)
	m.rotation.y = yaw
	return m

func _fx_mat(texname: String, color: Color, additive := true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive: mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex(texname)
	mat.albedo_color = color
	return mat

## Décalque lumineux au sol qui s'agrandit et s'efface (onde de choc, rune).
func ring(pos: Vector3, texname: String, color: Color, from_size: float, to_size: float, time: float) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2.ONE
	# mélange normal (pas additif) : les couleurs restent vives sur l'herbe claire
	var mat := _fx_mat(texname, Color(color.r * 1.2, color.g * 1.0, color.b * 0.9, color.a), false)
	q.material = mat
	m.mesh = q
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	m.global_position = Vector3(pos.x, world.h(pos.x, pos.z) + 0.09, pos.z)
	m.scale = Vector3(from_size, 1, from_size)
	m.rotation.y = randf() * TAU
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3(to_size, 1, to_size), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(m.queue_free)

## Image rémanente allongée (traînée de charge).
func streak(pos: Vector3, yaw: float, color: Color, delay: float) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(1.2, 2.4)
	var mat := _fx_mat("light_01", color)
	q.material = mat
	m.mesh = q
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	m.global_position = pos
	m.rotation.y = yaw
	mat.albedo_color.a = 0.0
	var tw := m.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(mat, "albedo_color:a", color.a, 0.05)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(m.queue_free)

## Particules continues attachées à un personnage (aura), éteintes par défaut.
func aura(parent: Node3D, texname: String, color: Color, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mat := _fx_mat(texname, Color.WHITE)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	p.mesh = q
	p.amount = 16
	p.lifetime = 0.7
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.6
	p.emission_ring_inner_radius = 0.3
	p.emission_ring_height = 0.2
	p.direction = Vector3.UP
	p.spread = 15
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, 1.0, 0)
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	p.emitting = false
	p.position.y = 0.2
	parent.add_child(p)
	return p

## Disque texturé au sol attaché à un personnage (rune de garde).
func ground_quad(parent: Node3D, texname: String, color: Color, size: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(size, size)
	q.material = _fx_mat(texname, color)
	m.mesh = q
	m.position.y = 0.07
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	parent.add_child(m)
	return m

## Préchauffage : chaque effet est dessiné une fois sous le sol au chargement, pour que le
## téléphone compile ses shaders tout de suite (sinon micro-gel au premier sort lancé).
func warmup(at: Vector3) -> void:
	var p := at + Vector3.DOWN * 2.5
	for t in ["spark_04", "spark_05", "smoke_04", "dirt_02", "star_06", "light_01", "flame_04", "circle_05"]:
		burst(p, t, Color.WHITE, 1, 0.1, 0.3, 0.3, 0.0)
	slash(p, 0.0, Color.WHITE)
	ring(p, "magic_03", Color.WHITE, 1.0, 1.1, 0.3)
	streak(p, 0.0, Color.WHITE, 0.0)
	number(p, 1, Color(1, 1, 1, 0.0))
	for sh in 3:
		var tl := telegraph(p, 0.0, sh, Vector2(2, 2), Color.WHITE)
		tl.global_position.y = p.y
		get_tree().create_timer(0.3, false).timeout.connect(tl.queue_free)

# --- Beauté des personnages -------------------------------------------------------
var _look_cache := {}
var _lava_mats: Array[StandardMaterial3D] = []

## Embellit un modèle : contour sombre, liseré de lumière sur les bords, teinte et brillance.
## opts : tint (Color), rim (Color), rim_amount, outline (Color), thick, rough, lava (bool)
func character_look(model: Node3D, opts: Dictionary) -> void:
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://scripts/outline.gdshader")
	outline.set_shader_parameter("color", opts.get("outline", Color(0.06, 0.04, 0.03)))
	outline.set_shader_parameter("thickness", opts.get("thick", 0.018))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var src: Material = mi.get_surface_override_material(si) if mi.get_surface_override_material(si) else mi.mesh.surface_get_material(si)
			if not (src is StandardMaterial3D): continue
			var key := [src, opts.hash()]
			if not _look_cache.has(key):
				var m: StandardMaterial3D = src.duplicate()
				if opts.has("tint") and not ("Glow" in src.resource_name):
					m.albedo_color = m.albedo_color * opts.tint
				m.rim_enabled = not ("Eye" in src.resource_name)
				m.rim = opts.get("rim_amount", 0.55)
				m.rim_tint = 0.35
				if opts.has("rough") and "Skin" in src.resource_name: m.roughness = opts.rough
				if opts.get("lava", false) and ("Lava" in src.resource_name):
					m.emission_enabled = true
					m.emission = Color(1.0, 0.38, 0.06)
					m.emission_energy_multiplier = 1.4 if "Glow" in src.resource_name else 0.9
					if m.emission_texture == null and m.albedo_texture and not ("Glow" in src.resource_name):
						m.emission_energy_multiplier = 0.25
					_lava_mats.append(m)
				# le contour suit la peau (squelette) grâce au passage suivant
				if not ("Eye" in src.resource_name or "Hair_1" in src.resource_name):
					m.next_pass = outline
				_look_cache[key] = m
			mi.set_surface_override_material(si, _look_cache[key])

## Les fissures de lave respirent (une seule mise à jour par matériau partagé).
func _pulse_lava() -> void:
	if _lava_mats.is_empty(): return
	var t := Time.get_ticks_msec() / 1000.0
	var k := 0.8 + 0.35 * sin(t * 2.2) + 0.15 * sin(t * 5.3)
	for m in _lava_mats:
		m.emission_energy_multiplier = (1.6 if "Glow" in m.resource_name else 0.9) * k
