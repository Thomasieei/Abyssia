extends CharacterBody3D
## Monstre de camp piloté par une machine à états LimboAI (LimboHSM).
## Garde -> alerte (rugit, prévient le camp) -> poursuite -> attaque annoncée au sol
## -> retour au camp si on l'entraîne trop loin ; le rôdeur fuit quand il est blessé.

const KINDS := {
	"brute": {
		"scene": "res://assets/monsters/brute.glb", "name": "Brute de lave", "scale": 1.45,
		"hp": 340.0, "dmg": 42.0, "speed": 3.3, "radius": 0.9, "aggro": 9.0,
		"range": 2.8, "windup": 0.95, "attack_anim_at": 0.45, "recover": 0.9,
		"silver": [14, 22], "drop": "cendre", "flee_at": 0.0, "color": Color(1.0, 0.45, 0.15),
	},
	"rodeur": {
		"scene": "res://assets/monsters/rodeur.glb", "name": "Rôdeur aveugle", "scale": 1.12,
		"hp": 250.0, "dmg": 26.0, "speed": 6.2, "radius": 0.55, "aggro": 11.0,
		"range": 4.2, "windup": 0.6, "attack_anim_at": 0.35, "recover": 0.7,
		"silver": [6, 11], "drop": "griffe", "flee_at": 0.3, "color": Color(0.7, 0.75, 0.95),
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
var _vy := 0.0
var _num_stack := 0
var _num_t := 0

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
	for a in ["Idle", "Run", "Walk"]:
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	ap.playback_default_blend_time = 0.18
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1, 1, 1, 0)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = _flash
		_meshes.append(m)
	_build_hsm()
	ap.play("Idle")
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
	if global_position.distance_to(home) > LEASH:
		_send(&"leash")
		return
	if data.flee_at > 0.0 and not _fled and hp < max_hp * data.flee_at:
		_send(&"flee")
		return
	var to := target.global_position - global_position
	to.y = 0
	_atk_cd -= delta
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
	_move(to.normalized() * data.speed, delta)
	_turn_to(target.global_position, delta, 10.0)

# Attaque annoncée : zone rouge au sol, puis frappe, puis récupération
func _attack_enter() -> void:
	_atk_phase = 0
	_atk_t = data.windup
	var to := target.global_position - global_position
	to.y = 0
	_atk_dir = to.normalized() if to.length() > 0.01 else -global_transform.basis.z
	rotation.y = atan2(_atk_dir.x, _atk_dir.z) + PI
	var col := Color(1.0, 0.18, 0.1, 0.9)
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
				_tele.material_override.set_shader_parameter("progress", 1.0 - _atk_t / data.windup)
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
	if is_instance_valid(_tele): _tele.queue_free()
	if not ap.is_playing(): ap.play()

# Retour au camp : se régénère, ignore les coups un instant
func _return_enter() -> void:
	target = null
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
	_col.disabled = true
	_play("Die", 0.08)
	_timer = RESPAWN
	target = null

func _dead_update(delta: float) -> void:
	_settle(delta)
	_timer -= delta
	if _timer < 2.0 and model.visible:
		model.scale = model.scale.lerp(Vector3.ONE * 0.01, delta * 4.0)
		if model.scale.x < 0.05: model.visible = false
	if _timer <= 0.0: _respawn()

func _respawn() -> void:
	global_position = home
	rotation.y = home_yaw
	hp = max_hp
	_fled = false
	dead = false
	_col.disabled = false
	model.visible = true
	model.scale = Vector3.ONE * data.scale * 0.2
	model.create_tween().tween_property(model, "scale", Vector3.ONE * data.scale, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	G.burst(global_position + Vector3.UP * 0.5, "smoke_04", Color(0.4, 0.35, 0.45, 0.7), 14, 2.5, 1.2, 0.8, 0.5)
	_send(&"respawn")

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
	G.number(top, int(dmg), Color(1, 0.92, 0.55) if not heavy else Color(1, 0.7, 0.25), heavy)
	var d := global_position - from
	d.y = 0
	_push = d.normalized() * knock * (2.6 if kind == "rodeur" else 1.4)
	# flash blanc
	_flash.albedo_color.a = 0.75
	create_tween().tween_property(_flash, "albedo_color:a", 0.0, 0.14)
	G.burst(global_position + Vector3.UP * (1.1 * data.scale), "spark_04", data.color, 10 if heavy else 6, 4.5, 0.4, 0.3)
	Sfx.play_at("hit_heavy" if heavy else "hit", global_position, -2.0 if heavy else -5.0)
	if target == null and G.player: target = G.player
	if hp <= 0.0:
		hp = 0.0
		_drop_loot()
		_send(&"die")
		return
	if st == "Garde" or st == "Retour":
		_send(&"aggro")
	elif stun > 0.0 and st != "Mort":
		_stun_t = stun
		_send(&"stun")

func _drop_loot() -> void:
	var s: int = randi_range(data.silver[0], data.silver[1])
	var pos := global_position + Vector3.UP
	G.burst(pos, "star_06", Color(1, 0.85, 0.3, 1), 14, 4.0, 0.4, 0.6, -4.0)
	var drop := ""
	if randf() < 0.65: drop = data.drop
	# le butin vole vers le joueur (ramassage automatique)
	get_tree().create_timer(0.5, false).timeout.connect(func():
		Sfx.play("loot", -6.0)
		G.give_silver(s)
		if drop != "": G.give_item(drop, 1))

# --- Mouvement ---------------------------------------------------------
func _play(a: String, blend := -1.0, speed := 1.0) -> void:
	if ap.current_animation == a and ap.is_playing():
		ap.speed_scale = speed
		return
	ap.play(a, blend)
	ap.speed_scale = speed

func _target_ok() -> bool:
	return target != null and is_instance_valid(target) and not target.dead

func _move(v: Vector3, delta: float) -> void:
	_push = _push.move_toward(Vector3.ZERO, 30.0 * delta)
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
