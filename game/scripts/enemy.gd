extends CharacterBody3D
## Monstre de camp piloté par une machine à états LimboAI (LimboHSM).
## Garde -> alerte (rugit, prévient le camp) -> poursuite -> attaque annoncée au sol
## -> retour au camp si on l'entraîne trop loin ; le rôdeur fuit quand il est blessé.

const KINDS := {
	"brute": {
		"scene": "res://assets/monsters/brute.glb", "name": "Brute de lave", "scale": 1.45,
		"hp": 340.0, "dmg": 42.0, "speed": 3.3, "radius": 0.9, "aggro": 9.0,
		"range": 2.8, "windup": 0.95, "attack_anim_at": 0.45, "recover": 0.9,
		"poise": 110.0, "silver": [14, 22], "drop": "cendre", "flee_at": 0.0, "color": Color(1.0, 0.45, 0.15),
	},
	"rodeur": {
		"scene": "res://assets/monsters/rodeur.glb", "name": "Rôdeur aveugle", "scale": 1.12,
		"hp": 250.0, "dmg": 26.0, "speed": 6.2, "radius": 0.55, "aggro": 11.0,
		"range": 4.2, "windup": 0.6, "attack_anim_at": 0.35, "recover": 0.7,
		"poise": 70.0, "silver": [6, 11], "drop": "griffe", "flee_at": 0.3, "color": Color(0.7, 0.75, 0.95),
	},
	"boss": {
		"scene": "res://assets/monsters/brute.glb", "name": "Gardien de cendre", "scale": 2.3,
		"hp": 2200.0, "dmg": 62.0, "speed": 3.1, "radius": 1.5, "aggro": 10.0,
		"range": 4.4, "windup": 1.15, "attack_anim_at": 0.45, "recover": 0.85,
		"poise": 480.0, "silver": [110, 150], "drop": "coeur_ardent", "flee_at": 0.0, "color": Color(1.0, 0.35, 0.08),
		"tint": Color(1.25, 0.62, 0.45), "leash": 15.0, "respawn": 120.0,
	},
	"rejeton": {
		"scene": "res://assets/monsters/rodeur.glb", "name": "Rejeton de braise", "scale": 0.85,
		"hp": 110.0, "dmg": 16.0, "speed": 5.6, "radius": 0.45, "aggro": 14.0,
		"range": 3.6, "windup": 0.55, "attack_anim_at": 0.3, "recover": 0.6,
		"poise": 45.0, "silver": [2, 4], "drop": "", "flee_at": 0.0, "color": Color(1.0, 0.5, 0.2),
		"tint": Color(1.4, 0.55, 0.3), "leash": 22.0, "respawn": -1.0,
	},
	"araignee": {
		"scene": "res://assets/monsters/araignee.glb", "name": "Tisseuse de mousse", "scale": 0.4,
		"hp": 190.0, "dmg": 20.0, "speed": 5.4, "radius": 0.8, "aggro": 9.5,
		"range": 2.5, "windup": 0.5, "attack_anim_at": 0.28, "recover": 0.6,
		"poise": 60.0, "silver": [8, 14], "drop": "soie", "flee_at": 0.0, "color": Color(0.75, 0.95, 0.5),
		"leash": 18.0, "hang": 4.4, "bones": ["Body", "Thorax", "Head"], "down": [0.05, 0.9, 1.3],
		"anims": {"Idle": "SpiderArmature|Spider_Idle", "Walk": "SpiderArmature|Spider_Walk", "Run": "SpiderArmature|Spider_Walk",
			"Attack": "SpiderArmature|Spider_Attack", "Die": "SpiderArmature|Spider_Death", "Roar": "SpiderArmature|Spider_Attack",
			"Jump": "SpiderArmature|Spider_Jump"},
	},
}
const LEASH := 16.0
const RESPAWN := 25.0

var kind := "brute"
var data: Dictionary
var display_name := ""
var max_hp := 100.0
var hp := 100.0
var radius := 0.6
var dead := false
var home := Vector3.ZERO
var home_yaw := 0.0
var camp: Array = []          # alliés du même camp
var target: Node3D = null

var model: Node3D
var ap: AnimationPlayer
var hsm: LimboHSM
var _flash: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _push := Vector3.ZERO
var _stun_t := 0.0
var _tele: MeshInstance3D
var _atk_t := 0.0
var _atk_phase := 0
var _atk_dir := Vector3.FORWARD
var _fled := false
var _timer := 0.0
var _look_t := 0.0
var _col: CollisionShape3D
var _atk_cd := 0.0
var phase := 1               # boss : 1, 2 (renforts, pluie de cendres), 3 (enragé)
var _pattern := "slam"
var _special_cd := 6.0
var _adds: Array = []
var _rain: Array = []        # zones de la pluie de cendres
var _boss_aura: CPUParticles3D
var _vy := 0.0
var _dust_t := 0.0
var _detour_t := 0.0
var _detour_side := Vector3.ZERO
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _num_stack := 0
var _num_t := 0
# réactions aux coups : ressort du buste, équilibre (poise) qui se brise, titubement, chute
const HitReact := preload("res://scripts/hit_react.gd")
var react: HitReact
var poise := 100.0
var _poise_idle := 0.0
var _down_phase := 0
var _cue := false
# tisseuse : fil de soie (pendue dans les arbres), bond, crachat de toile
var _thread: MeshInstance3D
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _leaping := false
var _spit: MeshInstance3D

func setup(k: String, pos: Vector3, yaw: float) -> void:
	kind = k
	data = KINDS[k]
	display_name = data.name
	max_hp = data.hp
	hp = max_hp
	radius = data.radius
	home = pos
	home_yaw = yaw

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(48.0)
	global_position = home
	rotation.y = home_yaw
	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = 2.0 * data.scale
	_col.shape = cap
	_col.position.y = cap.height * 0.5
	add_child(_col)
	model = load(data.scene).instantiate()
	model.rotation.y = PI
	model.scale = Vector3.ONE * data.scale
	add_child(model)
	ap = model.find_child("AnimationPlayer")
	if data.has("tint"):
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			for si in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(si)
				if m is StandardMaterial3D:
					var t: StandardMaterial3D = m.duplicate()
					t.albedo_color = data.tint
					if kind == "boss":
						t.emission_enabled = true
						t.emission = Color(1.0, 0.3, 0.05)
						t.emission_energy_multiplier = 0.35
					mi.set_surface_override_material(si, t)
	# rendu soigné : contour, liseré, lave qui luit, peau humide du rôdeur
	match kind:
		"brute", "boss":
			G.character_look(model, {"lava": true, "rim_amount": 0.45, "thick": 0.014, "outline": Color(0.08, 0.03, 0.02)})
		"rodeur":
			G.character_look(model, {"tint": Color(0.8, 0.84, 0.95), "rough": 0.22, "rim_amount": 0.7, "thick": 0.016, "outline": Color(0.04, 0.05, 0.09)})
		"araignee":
			G.character_look(model, {"rim_amount": 0.5, "thick": 0.05, "outline": Color(0.03, 0.04, 0.02)})
		"rejeton":
			G.character_look(model, {"rough": 0.3, "rim_amount": 0.6, "thick": 0.018, "outline": Color(0.12, 0.03, 0.0)})
	if kind == "boss":
		_boss_aura = G.aura(self, "flame_02", Color(1.0, 0.35, 0.08, 0.6), 1.4)
		_boss_aura.emission_ring_radius = 1.6
		_boss_aura.amount = 24
	if kind == "araignee": _spider_look()
	for a in ["Idle", "Run", "Walk"]:
		ap.get_animation(_an(a)).loop_mode = Animation.LOOP_LINEAR
	ap.playback_default_blend_time = 0.18
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1, 1, 1, 0)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = _flash
		_meshes.append(m)
	poise = data.poise
	var sk: Skeleton3D = model.find_child("Skeleton3D")
	react = HitReact.new()
	sk.add_child(react)
	react.setup(sk, 0.45 if kind == "boss" else 1.0, data.get("bones", ["Spine", "Chest", "Head"]))
	if data.has("hang"): _hang(true)
	_build_hsm()
	ap.play(_an("Idle"))
	ap.seek(randf() * 2.0, true)

# --- Machine à états LimboAI -------------------------------------------
func _build_hsm() -> void:
	hsm = LimboHSM.new()
	hsm.name = "HSM"
	add_child(hsm)
	var s_guard := _state("Garde", _guard_enter, _guard_update)
	var s_alert := _state("Alerte", _alert_enter, _alert_update)
	var s_chase := _state("Poursuite", _chase_enter, _chase_update)
	var s_attack := _state("Attaque", _attack_enter, _attack_update, _attack_exit)
	var s_return := _state("Retour", _return_enter, _return_update)
	var s_flee := _state("Fuite", _flee_enter, _flee_update)
	var s_stun := _state("Etourdi", _stun_enter, _stun_update)
	var s_dead := _state("Mort", _dead_enter, _dead_update)
	var s_stag := _state("Titube", _stagger_enter, _stagger_update)
	var s_down := _state("Chute", _down_enter, _down_update, _down_exit)
	hsm.initial_state = s_guard
	hsm.add_transition(s_guard, s_alert, &"aggro")
	hsm.add_transition(s_return, s_alert, &"aggro")
	hsm.add_transition(s_alert, s_chase, &"done")
	hsm.add_transition(s_chase, s_attack, &"in_range")
	hsm.add_transition(s_attack, s_chase, &"done")
	hsm.add_transition(s_chase, s_return, &"leash")
	hsm.add_transition(s_attack, s_return, &"leash")
	hsm.add_transition(s_return, s_guard, &"home")
	hsm.add_transition(s_chase, s_flee, &"flee")
	hsm.add_transition(s_flee, s_chase, &"done")
	hsm.add_transition(s_stun, s_chase, &"done")
	hsm.add_transition(hsm.anystate(), s_stun, &"stun")
	hsm.add_transition(hsm.anystate(), s_stag, &"stagger")
	hsm.add_transition(hsm.anystate(), s_down, &"knockdown")
	hsm.add_transition(s_stag, s_chase, &"done")
	hsm.add_transition(s_down, s_chase, &"done")
	hsm.add_transition(hsm.anystate(), s_dead, &"die")
	hsm.add_transition(s_dead, s_guard, &"respawn")
	hsm.initialize(self)
	hsm.set_active(true)

func _state(n: String, enter: Callable, update: Callable, exit := Callable()) -> LimboState:
	var s := LimboState.new()
	s.name = n
	s.call_on_enter(enter)
	s.call_on_update(update)
	if exit.is_valid(): s.call_on_exit(exit)
	hsm.add_child(s)
	return s

func state_name() -> String:
	var s := hsm.get_active_state()
	return s.name if s else "?"

func _send(ev: StringName) -> void:
	hsm.dispatch(ev)

## Appelé par un allié du camp qui vient de repérer le joueur.
func call_for_help(p: Node3D) -> void:
	if dead: return
	var st := state_name()
	if st == "Garde" or st == "Retour":
		target = p
		_send(&"aggro")

# Garde : immobile au camp, regarde autour, repère le joueur
func _guard_enter() -> void:
	target = null
	_play("Idle")
	if data.has("hang") and not dead and model.position.y < 0.1: _hang(true, 1.4)
	_look_t = randf_range(2.0, 5.0)

func _guard_update(delta: float) -> void:
	_settle(delta)
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = randf_range(3.0, 6.0)
		home_yaw += randf_range(-0.8, 0.8)
	rotation.y = lerp_angle(rotation.y, home_yaw, delta * 2.0)
	var p: Node3D = G.player
	if p and not p.dead and p.global_position.distance_to(global_position) < data.aggro:
		target = p
		_send(&"aggro")

# Alerte : rugit et prévient le reste du camp
func _alert_enter() -> void:
	_play("Roar", 0.1, 1.6)
	_timer = 0.85
	if data.has("hang") and model.position.y > 0.1:
		_hang(false)
		_timer = 0.9
	if kind == "araignee": _special_cd = 0.6 + randf() * 1.2
	for a in camp:
		if a != self: a.call_for_help(target)

func _alert_update(delta: float) -> void:
	_settle(delta)
	if target: _turn_to(target.global_position, delta, 8.0)
	_timer -= delta
	if _timer <= 0.0: _send(&"done")

# Poursuite
func _chase_enter() -> void:
	_play("Run", 0.15, 1.0 if kind == "brute" else 1.2)

func _chase_update(delta: float) -> void:
	if not _target_ok():
		_send(&"leash")
		return
	if global_position.distance_to(home) > data.get("leash", LEASH):
		_send(&"leash")
		return
	if data.flee_at > 0.0 and not _fled and hp < max_hp * data.flee_at:
		_send(&"flee")
		return
	var to := target.global_position - global_position
	to.y = 0
	_atk_cd -= delta
	_special_cd -= delta
	# le boss lance la pluie de cendres même à distance
	if kind == "boss" and phase >= 2 and _special_cd <= 0.0 and _atk_cd <= 0.0:
		_send(&"in_range")
		return
	# la tisseuse bondit ou crache sa toile à distance
	if kind == "araignee" and _special_cd <= 0.0 and _atk_cd <= 0.0 and to.length() > 3.4 and to.length() < 8.5:
		_send(&"in_range")
		return
	if to.length() <= data.range:
		if _atk_cd <= 0.0:
			_send(&"in_range")
			return
		# en attendant de pouvoir frapper : tourner autour de la cible au lieu de se coller
		var side := Vector3(-to.z, 0, to.x).normalized() * (1.0 if get_instance_id() % 2 == 0 else -1.0)
		_move(side * data.speed * 0.35, delta)
		_turn_to(target.global_position, delta, 10.0)
		_play("Walk", 0.2)
		return
	_play("Run", 0.15, 1.0 if kind == "brute" else 1.2)
	var dir := to.normalized()
	_dust_t -= delta
	if _dust_t <= 0.0:
		_dust_t = 0.32 if kind != "rodeur" else 0.22
		G.burst(global_position + Vector3.UP * 0.1, "smoke_04", Color(0.62, 0.55, 0.45, 0.35), 2, 0.8, 0.5 * data.scale, 0.5, 0.3)
		if kind == "brute" or kind == "boss": Sfx.play_at("step", global_position, -10.0, 0.6)
	_move(dir * data.speed, delta)
	_turn_to(global_position + dir, delta, 10.0)

# Attaque annoncée : zone rouge au sol, puis frappe, puis récupération
func _attack_enter() -> void:
	_cue = false
	_atk_phase = 0
	_atk_t = _windup()
	var to := target.global_position - global_position
	to.y = 0
	_atk_dir = to.normalized() if to.length() > 0.01 else -global_transform.basis.z
	rotation.y = atan2(_atk_dir.x, _atk_dir.z) + PI
	var col := Color(1.0, 0.18, 0.1, 0.9)
	if kind == "boss":
		_boss_attack_enter(col)
		return
	if kind == "araignee":
		_spider_attack_enter(col)
		return
	if kind == "brute":
		_tele = G.telegraph(global_position + _atk_dir * 1.8, 0.0, 0, Vector2(6.4, 6.4), col)
	else:
		_tele = G.telegraph(global_position, rotation.y, 2, Vector2(1.6, 5.2), col)
	# pose de préparation figée, puis le coup part pour toucher pile à la fin de la zone
	_play("Attack", 0.1, 1.0)
	ap.seek(0.0, true)
	ap.pause()

func _attack_update(delta: float) -> void:
	_atk_t -= delta
	match _atk_phase:
		0:
			_settle(delta)
			if is_instance_valid(_tele):
				_tele.material_override.set_shader_parameter("progress", 1.0 - _atk_t / _windup())
				# signal de contre : la zone blanchit quand il est temps de parer
				if _atk_t <= 0.32 and not _cue:
					_cue = true
					_tele.material_override.set_shader_parameter("color", Color(1.0, 0.93, 0.7, 0.95))
					if not G.tip_contre and target == G.player:
						G.tip_contre = true
						G.announce.emit("Zone blanche : touche l'attaque pour contrer !")
			for r in _rain:
				if is_instance_valid(r): r.material_override.set_shader_parameter("progress", 1.0 - _atk_t / _windup())
			if kind == "araignee": _spider_windup(delta)
			if _atk_t <= data.attack_anim_at and not ap.is_playing():
				ap.play()
			if _atk_t <= 0.0:
				_strike()
				_atk_phase = 1
				_atk_t = data.recover
		1:
			_settle(delta)
			if _atk_t <= 0.0: _send(&"done")

func _strike() -> void:
	if is_instance_valid(_tele): _tele.queue_free()
	if kind == "boss":
		_boss_strike()
		return
	if kind == "araignee":
		_spider_strike()
		return
	var p: Node3D = G.player
	var hit := false
	if kind == "brute":
		var c := global_position + _atk_dir * 1.8
		Sfx.play_at("slam", c, 0.0, 0.7)
		G.burst(c + Vector3.UP * 0.2, "dirt_02", Color(0.55, 0.4, 0.3, 0.95), 22, 6.0, 0.9, 0.55, -9.0)
		G.burst(c + Vector3.UP * 0.3, "spark_05", Color(1.0, 0.5, 0.15, 1.0), 16, 5.0, 0.45, 0.5)
		G.shake(0.3)
		if p and not p.dead and Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() < 3.2 + 0.3:
			hit = true
	else:
		var start := global_position
		_push = _atk_dir * 15.0
		Sfx.play_at("swing", start, -2.0, 0.7)
		if p and not p.dead:
			var rel := p.global_position - start
			rel.y = 0
			var along := rel.dot(_atk_dir)
			var side := (rel - _atk_dir * along).length()
			if along > -0.5 and along < 5.4 and side < 1.1: hit = true
	if hit:
		p.take_hit(data.dmg * randf_range(0.9, 1.1), global_position, 2.5 if kind == "brute" else 1.2)
		G.hitstop(60)

func _attack_exit() -> void:
	_atk_cd = (1.3 if kind == "brute" else 1.0) + randf() * 0.9
	if kind == "boss": _atk_cd = (1.2 if phase < 3 else 0.6) + randf() * 0.5
	for r in _rain:
		if is_instance_valid(r): r.queue_free()
	_rain.clear()
	if is_instance_valid(_tele): _tele.queue_free()
	if is_instance_valid(_spit): _spit.queue_free()
	_leaping = false
	if kind == "araignee": model.position.y = 0.0
	if not ap.is_playing(): ap.play()

# Retour au camp : se régénère, ignore les coups un instant
func _return_enter() -> void:
	target = null
	if kind == "boss":
		phase = 1
		if _boss_aura: _boss_aura.emitting = false
		for a in _adds:
			if is_instance_valid(a) and not a.dead: a.take_hit(9999.0, global_position)
		_adds.clear()
	_play("Walk", 0.2, 1.3)

func _return_update(delta: float) -> void:
	hp = minf(hp + max_hp * 0.25 * delta, max_hp)
	var to := home - global_position
	to.y = 0
	if to.length() < 0.6:
		_send(&"home")
		return
	_move(to.normalized() * data.speed * 0.9, delta)
	_turn_to(home, delta, 6.0)
	var p: Node3D = G.player
	if p and not p.dead and p.global_position.distance_to(global_position) < data.aggro * 0.5 and global_position.distance_to(home) < LEASH * 0.5:
		target = p
		_send(&"aggro")

# Fuite (rôdeur blessé) : s'éloigne, puis revient à la charge
func _flee_enter() -> void:
	_fled = true
	_timer = 2.4
	_play("Run", 0.1, 1.3)

func _flee_update(delta: float) -> void:
	_timer -= delta
	if _target_ok():
		var away := global_position - target.global_position
		away.y = 0
		var dir := away.normalized()
		# rester près du camp
		if global_position.distance_to(home) > LEASH * 0.7:
			dir = (dir + (home - global_position).normalized()).normalized()
		_move(dir * data.speed * 1.05, delta)
		_turn_to(global_position + dir, delta, 10.0)
	if _timer <= 0.0: _send(&"done")

func _stun_enter() -> void:
	_play("Idle", 0.05, 0.3)
	G.burst(global_position + Vector3.UP * (2.2 * data.scale), "star_06", Color(1, 0.95, 0.5, 1), 6, 1.0, 0.35, 0.6, 0.0)

func _stun_update(delta: float) -> void:
	_settle(delta)
	_stun_t -= delta
	if _stun_t <= 0.0: _send(&"done")

func _dead_enter() -> void:
	dead = true
	G.stats.kills[kind] = G.stats.kills.get(kind, 0) + 1
	if kind == "boss": G.stats.gardien = true
	if kind == "boss":
		for a in _adds:
			if is_instance_valid(a) and not a.dead: a.take_hit(9999.0, global_position)
		_boss_aura.emitting = false
		G.boss_defeated.emit(self)
	_col.disabled = true
	_play("Die", 0.08)
	_timer = data.get("respawn", RESPAWN) if data.get("respawn", RESPAWN) > 0.0 else 3.0
	target = null

func _dead_update(delta: float) -> void:
	_settle(delta)
	_timer -= delta
	if _timer < 2.0 and model.visible:
		model.scale = model.scale.lerp(Vector3.ONE * 0.01, delta * 4.0)
		if model.scale.x < 0.05: model.visible = false
	if _timer <= 0.0:
		if data.get("respawn", RESPAWN) < 0.0:
			G.enemies.erase(self)
			queue_free()
			return
		_respawn()

func _respawn() -> void:
	phase = 1
	_special_cd = 6.0
	if _boss_aura: _boss_aura.emitting = false
	global_position = home
	rotation.y = home_yaw
	hp = max_hp
	_fled = false
	dead = false
	_col.disabled = false
	model.visible = true
	if data.has("hang"): _hang(true)
	model.scale = Vector3.ONE * data.scale * 0.2
	model.create_tween().tween_property(model, "scale", Vector3.ONE * data.scale, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	G.burst(global_position + Vector3.UP * 0.5, "smoke_04", Color(0.4, 0.35, 0.45, 0.7), 14, 2.5, 1.2, 0.8, 0.5)
	_send(&"respawn")

func _physics_process(delta: float) -> void:
	if react.active(): react.step(delta)
	if poise < data.poise:
		_poise_idle -= delta
		if _poise_idle <= 0.0: poise = minf(poise + data.poise * 0.35 * delta, data.poise)

# Titubement : l'équilibre est brisé, le monstre recule en vacillant (attaque annulée)
func _stagger_enter() -> void:
	_timer = 1.5 if kind == "boss" else 1.15
	_play("Walk", 0.1, 0.45)
	react.stagger(0.32)
	G.burst(global_position + Vector3.UP * (2.2 * data.scale), "star_06", Color(1, 0.95, 0.6, 1), 5, 1.2, 0.4, 0.5, 0.0)

func _stagger_update(delta: float) -> void:
	_settle(delta)
	_timer -= delta
	if _timer <= 0.0: _send(&"done")

# Chute : il tombe (début de l'animation de mort), reste à terre, puis se relève (la même, à l'envers)
func _down_enter() -> void:
	_down_phase = 0
	_timer = 0.0
	var dn: Array = data.get("down", [0.55, 1.42, 1.5])
	_play("Die", 0.08, dn[2])
	ap.seek(dn[0], true)
	_leaping = false
	model.position.y = 0.0
	Sfx.play_at("slam", global_position, -4.0, 0.8)

func _down_update(delta: float) -> void:
	_settle(delta)
	_timer += delta
	match _down_phase:
		0:
			if ap.current_animation_position >= data.get("down", [0.55, 1.42])[1]:
				ap.pause()
				_down_phase = 1
				_timer = 0.0
				G.burst(global_position + Vector3.UP * 0.2, "dirt_02", Color(0.55, 0.45, 0.35, 0.9), 16, 3.5, 0.8, 0.6, -6.0)
				G.shake(0.2)
		1:
			if _timer >= (2.2 if kind == "boss" else 1.4):
				_down_phase = 2
				ap.speed_scale = -1.25
				ap.play()
		2:
			if ap.current_animation_position <= data.get("down", [0.55])[0] + 0.05:
				_send(&"done")

func _down_exit() -> void:
	ap.speed_scale = 1.0
	_play("Idle", 0.25)

## Fenêtre de contre : temps restant avant que le coup parte (−1 si rien à contrer).
func counter_window() -> float:
	if dead or state_name() != "Attaque" or _atk_phase != 0: return -1.0
	if kind == "boss" and _pattern == "pluie": return -1.0
	if kind == "araignee" and _pattern == "toile": return -1.0
	return _atk_t

## Le joueur a paré : le coup ne part pas.
func countered(perfect: bool) -> void:
	if is_instance_valid(_tele): _tele.queue_free()
	for r in _rain:
		if is_instance_valid(r): r.queue_free()
	_rain.clear()
	poise = 0.0
	_poise_idle = 3.0
	if perfect or kind == "rodeur" or kind == "rejeton":
		_send(&"knockdown")
	else:
		_send(&"stagger")

# --- Tisseuse de mousse -------------------------------------------------
static var _spider_mat: StandardMaterial3D
static var _eye_mat: StandardMaterial3D
static var _thread_mat: StandardMaterial3D

## Carapace sombre couverte de mousse (texture peinte par script, projection triplanaire :
## le modèle n'a pas d'UV) et huit yeux vert-jaune qui luisent.
func _spider_look() -> void:
	if _spider_mat == null:
		_spider_mat = StandardMaterial3D.new()
		_spider_mat.albedo_texture = load("res://assets/monsters/araignee_mousse.png")
		_spider_mat.uv1_triplanar = true
		_spider_mat.uv1_scale = Vector3.ONE * 14.0
		_spider_mat.roughness = 0.75
		_spider_mat.resource_name = "Tisseuse"
		_eye_mat = StandardMaterial3D.new()
		_eye_mat.albedo_color = Color(0.75, 1.0, 0.3)
		_eye_mat.emission_enabled = true
		_eye_mat.emission = Color(0.7, 1.0, 0.25)
		_eye_mat.emission_energy_multiplier = 1.6
		_eye_mat.resource_name = "Eye_Tisseuse"
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.set_surface_override_material(0, _spider_mat)
		if mi.mesh.get_surface_count() > 1: mi.set_surface_override_material(1, _eye_mat)

## Pendue à son fil dans les arbres (true) ou au sol (false).
func _hang(up: bool, dur := 0.0) -> void:
	var hy: float = data.hang
	if _thread == null:
		_thread = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.012
		cm.bottom_radius = 0.012
		cm.height = 1.0
		cm.radial_segments = 4
		cm.rings = 1
		_thread.mesh = cm
		if _thread_mat == null:
			_thread_mat = StandardMaterial3D.new()
			_thread_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_thread_mat.albedo_color = Color(0.92, 0.95, 0.9)
		_thread.material_override = _thread_mat
		_thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_thread)
	var top := hy + 6.0
	var y0 := model.position.y
	var y1 := hy if up else 0.0
	if dur <= 0.0 and up:
		model.position.y = y1
		_set_thread(top, y1)
		return
	var tw := create_tween()
	tw.tween_method(func(y: float):
		model.position.y = y
		_set_thread(top, y), y0, y1, dur if dur > 0.0 else 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if not up else Tween.EASE_IN_OUT)
	if not up:
		tw.tween_callback(func():
			# le fil se détache et remonte dans l'arbre
			var t2 := create_tween()
			t2.tween_method(func(k: float): _set_thread(top, lerpf(0.0, top - 0.3, k)), 0.0, 1.0, 0.5)
			G.burst(global_position + Vector3.UP * 0.1, "dirt_02", Color(0.5, 0.45, 0.35, 0.8), 10, 2.5, 0.6, 0.45, -6.0)
			Sfx.play_at("step", global_position, -4.0, 0.7))

func _set_thread(top: float, y: float) -> void:
	var len := maxf(top - y - 0.25, 0.01)
	_thread.visible = len > 0.05
	_thread.scale = Vector3(1, len, 1)
	_thread.position = Vector3(0, y + 0.25 + len * 0.5, 0)

func _spider_attack_enter(col: Color) -> void:
	var to := target.global_position - global_position
	to.y = 0
	var dist := to.length()
	if dist > 3.2:
		_pattern = "bond" if randf() < 0.55 else "toile"
		_special_cd = 3.5 + randf() * 2.0
	elif _special_cd <= 0.0 and randf() < 0.4:
		_pattern = "toile"      # au corps à corps, elle englue sa proie avant de mordre
		_special_cd = 4.0 + randf() * 2.0
	else:
		_pattern = "morsure"
	match _pattern:
		"morsure":
			_tele = G.telegraph(global_position, rotation.y, 2, Vector2(1.4, 3.0), col)
			_play("Attack", 0.1, 1.0)
		"bond":
			_leap_from = global_position
			_leap_to = global_position + to.normalized() * minf(dist, 8.0)
			_leap_to.y = G.world.h(_leap_to.x, _leap_to.z)
			_tele = G.telegraph(_leap_to, 0.0, 0, Vector2(4.4, 4.4), col)
			_play("Jump", 0.1, 1.0)
		"toile":
			var tp: Vector3 = target.global_position
			_leap_to = tp
			_tele = G.telegraph(tp, 0.0, 0, Vector2(4.8, 4.8), Color(0.85, 0.95, 0.8, 0.85))
			_play("Attack", 0.1, 0.8)
	ap.seek(0.0, true)
	ap.pause()
	_atk_t = _windup_len()

func _windup_len() -> float:
	return {"morsure": 0.5, "bond": 0.8, "toile": 0.95}.get(_pattern, data.windup)

## Pendant la préparation : le bond part 0,35 s avant l'impact (arc), le crachat vole vers sa cible.
func _spider_windup(delta: float) -> void:
	if _pattern == "bond" and _atk_t <= 0.35:
		if not _leaping:
			_leaping = true
			ap.play()
			Sfx.play_at("swing", global_position, -4.0, 0.6)
		var t := clampf(1.0 - _atk_t / 0.35, 0.0, 1.0)
		var p := _leap_from.lerp(_leap_to, t)
		global_position = Vector3(p.x, maxf(global_position.y, p.y), p.z)
		model.position.y = sin(t * PI) * 1.8
	elif _pattern == "toile" and _atk_t <= 0.3:
		if _spit == null:
			_spit = MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.18
			sm.height = 0.36
			sm.radial_segments = 8
			sm.rings = 4
			_spit.mesh = sm
			_spit.material_override = _thread_mat
			G.world.add_child(_spit)
			Sfx.play_at("swing", global_position, -6.0, 1.5)
		var t2 := clampf(1.0 - _atk_t / 0.3, 0.0, 1.0)
		var a := global_position + Vector3.UP * 0.6
		_spit.global_position = a.lerp(_leap_to, t2) + Vector3.UP * sin(t2 * PI) * 2.0

func _spider_strike() -> void:
	var p: Node3D = G.player
	var hit := false
	match _pattern:
		"morsure":
			Sfx.play_at("flesh", global_position, -4.0, 1.4)
			if p and not p.dead:
				var rel := p.global_position - global_position
				rel.y = 0
				var along := rel.dot(_atk_dir)
				if along > -0.3 and along < 3.1 and (rel - _atk_dir * along).length() < 0.9: hit = true
			if hit:
				p.take_hit(data.dmg * randf_range(0.9, 1.1), global_position, 1.0)
				p.poison(4.0)
		"bond":
			_leaping = false
			model.position.y = 0.0
			G.burst(global_position + Vector3.UP * 0.15, "dirt_02", Color(0.5, 0.42, 0.32, 0.9), 16, 4.5, 0.8, 0.5, -8.0)
			Sfx.play_at("slam", global_position, -3.0, 1.2)
			G.shake(0.2)
			if p and not p.dead and Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length() < 2.2 + 0.3: hit = true
			if hit: p.take_hit(data.dmg * 1.4 * randf_range(0.9, 1.1), global_position, 2.0)
		"toile":
			if is_instance_valid(_spit): _spit.queue_free()
			_spit = null
			G.web(_leap_to, 2.4, 5.0)
			Sfx.play_at("gather", _leap_to, 0.0, 0.7)
			if p and not p.dead and Vector2(p.global_position.x - _leap_to.x, p.global_position.z - _leap_to.z).length() < 2.4: hit = true
			if hit: p.take_hit(data.dmg * 0.4, _leap_to, 0.0)
	if hit: G.hitstop(50)

# --- Coups reçus -------------------------------------------------------
func take_hit(dmg: float, from: Vector3, knock := 1.0, stun := 0.0, heavy := false) -> void:
	if dead: return
	var st := state_name()
	if st == "Retour": dmg *= 0.25
	hp -= dmg
	# chiffres empilés : jamais l'un sur l'autre
	var now := Time.get_ticks_msec()
	_num_stack = _num_stack + 1 if now - _num_t < 450 else 0
	_num_t = now
	var top: Vector3 = global_position + Vector3.UP * (2.1 * data.scale + 0.42 * (_num_stack % 4))
	if dmg < 9000.0: G.number(top, int(dmg), Color(1, 0.92, 0.55) if not heavy else Color(1, 0.7, 0.25), heavy)
	var d := global_position - from
	d.y = 0
	_push = d.normalized() * knock * (2.6 if kind == "rodeur" else 1.4)
	# le buste encaisse : il plie à l'opposé du coup puis revient
	var dl := model.global_transform.basis.inverse() * d.normalized()
	react.kick(dl, 0.55 if heavy else 0.3)
	# flash blanc
	_flash.albedo_color.a = 0.75
	create_tween().tween_property(_flash, "albedo_color:a", 0.0, 0.14)
	G.burst(global_position + Vector3.UP * (1.1 * data.scale), "spark_04", data.color, 10 if heavy else 6, 4.5, 0.4, 0.3)
	Sfx.play_at("hit_heavy" if heavy else "hit", global_position, -2.0 if heavy else -5.0)
	if target == null and G.player: target = G.player
	if kind == "boss" and hp > 0.0: _check_phase()
	if hp <= 0.0:
		hp = 0.0
		_drop_loot()
		_send(&"die")
		return
	if st == "Garde" or st == "Retour":
		_send(&"aggro")
		return
	# équilibre : les coups lourds le brisent plus vite ; brisé => titubement (ou chute)
	if st != "Chute" and st != "Titube":
		poise -= dmg * (0.9 if heavy else 0.45) * (1.0 if knock < 3.0 else 1.6)
		_poise_idle = 2.5
		if poise <= 0.0:
			poise = data.poise
			_send(&"knockdown" if heavy and kind != "boss" else &"stagger")
			return
	if stun > 0.0 and st != "Mort" and st != "Chute" and kind != "boss":
		_stun_t = stun
		_send(&"stun")

func _drop_loot() -> void:
	var s: int = randi_range(data.silver[0], data.silver[1])
	var pos := global_position + Vector3.UP
	G.burst(pos, "star_06", Color(1, 0.85, 0.3, 1), 14, 4.0, 0.4, 0.6, -4.0)
	var drop := ""
	if data.drop != "" and (randf() < 0.65 or kind == "boss"): drop = data.drop
	# le butin vole vers le joueur (ramassage automatique)
	get_tree().create_timer(0.5, false).timeout.connect(func():
		Sfx.play("loot", -6.0)
		G.give_silver(s)
		if drop != "": G.give_item(drop, 1))

# --- Mouvement ---------------------------------------------------------
func _an(a: String) -> String:
	return data.anims.get(a, a) if data.has("anims") else a

func _play(a: String, blend := -1.0, speed := 1.0) -> void:
	if kind == "araignee" and a == "Run": speed *= 1.8
	a = _an(a)
	if ap.current_animation == a and ap.is_playing():
		ap.speed_scale = speed
		return
	ap.play(a, blend)
	ap.speed_scale = speed

func _target_ok() -> bool:
	return target != null and is_instance_valid(target) and not target.dead

func _move(v: Vector3, delta: float) -> void:
	# contournement : bloqué par un rocher ou un arbre -> on longe l'obstacle un instant
	if v.length() > 0.5:
		if _detour_t > 0.0:
			_detour_t -= delta
			v = (v.normalized() * 0.35 + _detour_side).normalized() * v.length()
		elif global_position.distance_to(_last_pos) < v.length() * delta * 0.25:
			_stuck_t += delta
			if _stuck_t > 0.3:
				_stuck_t = 0.0
				_detour_t = 0.8
				var n := v.normalized()
				_detour_side = Vector3(-n.z, 0, n.x) * (1.0 if randf() < 0.5 else -1.0)
		else:
			_stuck_t = 0.0
	_last_pos = global_position
	_push = _push.move_toward(Vector3.ZERO, 30.0 * delta)
	if not G.webs.is_empty(): v *= G.web_slow(global_position, true)
	velocity = v + _push
	_vy = -1.0 if is_on_floor() else _vy - 28.0 * delta
	velocity.y = _vy
	move_and_slide()

func _settle(delta: float) -> void:
	_move(Vector3.ZERO, delta)

func _turn_to(p: Vector3, delta: float, rate: float) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() < 0.01: return
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z) + PI, minf(rate * delta, 1.0))

# --- Boss : Gardien de cendre --------------------------------------------------
func _windup() -> float:
	if kind == "araignee": return _windup_len()
	return data.windup * (0.7 if phase == 3 else 1.0)

func _check_phase() -> void:
	var f := hp / max_hp
	if phase == 1 and f < 0.6:
		phase = 2
		_special_cd = 0.5
		_phase_fx("Le Gardien appelle ses rejetons !")
		for k in 3:
			var a := TAU * k / 3.0 + 0.4
			var pos := global_position + Vector3(cos(a), 0, sin(a)) * 3.5
			pos.y = G.world.h(pos.x, pos.z)
			var e = load("res://scripts/enemy.gd").new()
			e.setup("rejeton", pos, a)
			G.world.add_child(e)
			G.enemies.append(e)
			e.camp = [e]
			e.call_deferred("call_for_help", G.player)
			_adds.append(e)
			G.burst(pos + Vector3.UP * 0.5, "flame_04", Color(1, 0.4, 0.1, 0.9), 14, 3.0, 0.7, 0.6, 1.0)
	elif phase == 2 and f < 0.25:
		phase = 3
		_phase_fx("Le Gardien entre en fureur !")
		_boss_aura.emitting = true

func _phase_fx(msg: String) -> void:
	G.announce.emit(msg)
	if state_name() != "Chute": _play("Roar", 0.1, 1.0)
	G.shake(0.5)
	G.ring(global_position, "circle_05", Color(1.0, 0.35, 0.1, 0.9), 1.0, 14.0, 0.6)
	Sfx.play_at("slam", global_position, 4.0, 0.5)

func _boss_attack_enter(col: Color) -> void:
	var to := target.global_position - global_position
	to.y = 0
	if phase >= 2 and _special_cd <= 0.0:
		_pattern = "pluie"
		_special_cd = 9.0 if phase == 2 else 6.0
	elif to.length() > data.range:
		_pattern = "souffle"
	else:
		_pattern = "souffle" if randf() < 0.35 else "slam"
	match _pattern:
		"slam":
			_tele = G.telegraph(global_position + _atk_dir * 2.4, 0.0, 0, Vector2(8.0, 8.0), col)
		"souffle":
			_tele = G.telegraph(global_position, rotation.y, 1, Vector2(16.0, 16.0), col, 70.0)
		"pluie":
			_tele = null
			var tp: Vector3 = target.global_position
			var spots := [tp]
			for k in (5 if phase == 2 else 7):
				var a := randf() * TAU
				spots.append(tp + Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 6.0))
			for sp in spots:
				_rain.append(G.telegraph(sp, 0.0, 0, Vector2(4.4, 4.4), Color(1.0, 0.4, 0.05, 0.9)))
	_play("Attack" if _pattern != "pluie" else "Roar", 0.1, 1.0)
	ap.seek(0.0, true)
	ap.pause()

func _boss_strike() -> void:
	var p: Node3D = G.player
	var hit := false
	var dmg: float = data.dmg
	match _pattern:
		"slam":
			var c := global_position + _atk_dir * 2.4
			Sfx.play_at("slam", c, 3.0, 0.55)
			G.burst(c + Vector3.UP * 0.2, "dirt_02", Color(0.5, 0.35, 0.25, 0.95), 28, 7.0, 1.0, 0.6, -9.0)
			G.burst(c + Vector3.UP * 0.3, "flame_04", Color(1.0, 0.45, 0.1, 1.0), 20, 5.0, 0.7, 0.6, 1.0)
			G.ring(c, "circle_05", Color(1.0, 0.4, 0.1, 0.9), 1.0, 9.0, 0.4)
			G.shake(0.5)
			if p and not p.dead and Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() < 4.0 + 0.3: hit = true
		"souffle":
			Sfx.play_at("hit_heavy", global_position, 2.0, 0.5)
			for k in 7:
				var d := _atk_dir.rotated(Vector3.UP, deg_to_rad(-30.0 + k * 10.0))
				for j in 3:
					G.burst(global_position + d * (2.5 + j * 2.0) + Vector3.UP * 0.6, "flame_02", Color(1.0, 0.4, 0.08, 0.9), 6, 2.5, 1.0, 0.5, 2.0)
			G.shake(0.35)
			if p and not p.dead:
				var rel := p.global_position - global_position
				rel.y = 0
				if rel.length() < 8.0 and rad_to_deg(_atk_dir.angle_to(rel.normalized())) < 35.0: hit = true
			dmg *= 0.85
		"pluie":
			Sfx.play_at("slam", G.player.global_position, 0.0, 0.8)
			for r in _rain:
				if not is_instance_valid(r): continue
				var c: Vector3 = r.global_position
				G.burst(c + Vector3.UP * 0.4, "flame_04", Color(1.0, 0.45, 0.1, 1.0), 12, 4.0, 0.8, 0.5, 2.0)
				G.burst(c + Vector3.UP * 3.0, "smoke_04", Color(0.3, 0.25, 0.25, 0.7), 6, 1.0, 1.2, 0.8, -6.0)
				if p and not p.dead and Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() < 2.2 + 0.3: hit = true
				r.queue_free()
			_rain.clear()
			G.shake(0.3)
			dmg *= 0.7
	if hit:
		p.take_hit(dmg * randf_range(0.9, 1.1), global_position, 3.0)
		G.hitstop(70)
