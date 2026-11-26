extends CharacterBody3D
## Héros : déplacement au joystick, attaque assistée, 3 sorts d'arme + 1 sort de plastron, récolte.

signal hp_changed(hp: float, max_hp: float, shield: float)
signal cast(slot: int, cd: float)

const SPEED := 5.6
const ATTACK_RANGE := 2.3
const ASSIST_RANGE := 8.0
const BASE_DMG := 30.0

var max_hp := 420.0
var hp := 420.0
var shield := 0.0
var dead := false
var move_input := Vector2.ZERO          # fourni par le HUD (joystick) ou le clavier
var attack_held := false
var target: Node3D = null

## Sorts : nom, recharge, animation
## Emplacements façon Albion : 3 sorts d'arme (Q W E), casque (R), plastron (D), bottes (F)
const SPELLS := {
	"entaille": {"name": "Entaille", "cd": 4.0, "cost": 14.0},
	"charge": {"name": "Charge", "cd": 9.0, "cost": 22.0},
	"fracas": {"name": "Fracas", "cd": 16.0, "cost": 38.0},
	"garde": {"name": "Garde du gardien", "cd": 22.0, "cost": 30.0},
	"souffle": {"name": "Souffle clair", "cd": 18.0, "cost": 26.0},
	"fureur": {"name": "Fureur", "cd": 26.0, "cost": 30.0},
	"embrase": {"name": "Embrasement", "cd": 20.0, "cost": 32.0},
	"vent": {"name": "Pas de vent", "cd": 14.0, "cost": 18.0},
	"roulade": {"name": "Roulade", "cd": 6.0, "cost": 12.0},
}
var skills: Array = []
var cd_left := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var max_energy := 200.0
var energy := 200.0
var _fury_t := 0.0
var _haste_t := 0.0
var _aura: CPUParticles3D
var _wind: CPUParticles3D
var _rune: MeshInstance3D

var model: Node3D
var ap: AnimationPlayer
var _action_t := 0.0          # temps restant d'une action qui bloque le déplacement
var _action := ""
var _combo := 0
var _combo_t := 0.0
var _hit_pending := []        # [temps, callable]
var _step_t := 0.0
var _last_hurt := -99.0
var _dash_vel := Vector3.ZERO
var _dash_t := 0.0
var _shield_t := 0.0
var _bubble: MeshInstance3D
var _gather_node: Node3D = null
var _gather_t := 0.0
var _spawn := Vector3.ZERO
var _anim_cur := ""

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	_spawn = global_position
	_build_model()
	_build_bubble()
	_rebuild_skills()
	G.gear_changed.connect(_rebuild_skills)
	_aura = G.aura(self, "flame_02", Color(1.0, 0.28, 0.12, 0.55), 0.9)
	_wind = G.aura(self, "smoke_04", Color(0.75, 1.0, 0.85, 0.35), 0.5)
	_rune = G.ground_quad(self, "magic_03", Color(1.0, 0.82, 0.4, 0.0), 3.2)

func _build_model() -> void:
	model = load("res://assets/hero/Superhero_Male_FullBody.gltf").instantiate()
	model.rotation.y = PI
	add_child(model)
	var sk: Skeleton3D = model.find_child("Skeleton3D")
	# Tenue : teinte cuir sombre, plus lisible en vue du dessus
	var body: MeshInstance3D = model.find_child("SuperHero_Male")
	if body:
		for s in body.mesh.get_surface_count():
			var m: StandardMaterial3D = body.mesh.surface_get_material(s).duplicate()
			# tenue de cuir provisoire peinte sur le modèle de base (en attendant le pack de tenues)
			m.albedo_texture = load("res://assets/hero/T_Hero_Leather.png")
			m.albedo_color = Color(1, 1, 1)
			m.normal_enabled = false   # pas de relief musculaire sous la tenue
			body.set_surface_override_material(s, m)
	# Cheveux et barbe attachés à la tête
	var head_rest := sk.get_bone_global_rest(sk.find_bone("Head"))
	for hp_path in ["res://assets/hero/Hair_SimpleParted.gltf", "res://assets/hero/Hair_Beard.gltf"]:
		var ba := BoneAttachment3D.new()
		ba.bone_name = "Head"
		sk.add_child(ba)
		var hair: Node3D = load(hp_path).instantiate()
		ba.add_child(hair)
		hair.transform = head_rest.affine_inverse()
		for hm in hair.find_children("*", "MeshInstance3D", true, false):
			var hmat: StandardMaterial3D = hm.mesh.surface_get_material(0).duplicate()
			hmat.albedo_color = Color(0.32, 0.2, 0.12)
			hm.set_surface_override_material(0, hmat)
	# Épée dans la main droite
	var hand := BoneAttachment3D.new()
	hand.bone_name = "hand_r"
	sk.add_child(hand)
	var sword: Node3D = load("res://assets/props/Human_Sword.fbx").instantiate()
	hand.add_child(sword)
	sword.position = Vector3(0.0, 0.05, 0.02)
	sword.rotation_degrees = Vector3(0, -90, -90)
	var sr := OS.get_environment("ABY_SWORD")
	if sr != "":
		var v := sr.split(",")
		sword.rotation_degrees = Vector3(float(v[0]), float(v[1]), float(v[2]))
	sword.scale = Vector3.ONE * 1.1
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.74, 0.78)
	steel.metallic = 0.85
	steel.roughness = 0.32
	for mi in sword.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = steel
	# Animations Quaternius (même squelette)
	ap = AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("h", load("res://assets/anims/hero_anims.res"))
	ap.playback_default_blend_time = 0.15
	_play("Sword_Idle")

## Les 3 premiers sorts viennent de l'arme, les 3 suivants du casque, du plastron et des bottes portés.
func _rebuild_skills() -> void:
	var ids := ["entaille", "charge", "fracas"]
	for slot in ["casque", "plastron", "bottes"]:
		ids.append(G.GEAR[G.equipped[slot]].spell)
	var old := skills.duplicate()
	skills = []
	for i in ids.size():
		var d: Dictionary = SPELLS[ids[i]].duplicate()
		d["id"] = ids[i]
		skills.append(d)
		if old.size() > i and old[i]["id"] != ids[i]: cd_left[i] = 0.0

func _build_bubble() -> void:
	_bubble = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.05
	s.height = 2.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.8, 0.35, 0.22)
	mat.rim_enabled = false
	s.material = mat
	_bubble.mesh = s
	_bubble.position.y = 1.0
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.visible = false
	add_child(_bubble)

func _play(anim: String, blend := -1.0, speed := 1.0) -> void:
	var full := "h/" + anim
	if _anim_cur == full and ap.is_playing(): return
	_anim_cur = full
	ap.play(full, blend, speed)

func _replay(anim: String, blend := 0.08, speed := 1.0) -> void:
	_anim_cur = "h/" + anim
	ap.play(_anim_cur, blend, speed)
	ap.seek(0.0, true)

# --------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	for i in cd_left.size(): cd_left[i] = maxf(cd_left[i] - delta, 0.0)
	energy = minf(energy + 7.0 * delta, max_energy)
	_tick_buffs(delta)
	_tick_pending(delta)
	if dead:
		velocity = Vector3.ZERO
		return
	_combo_t -= delta
	if _combo_t <= 0.0: _combo = 0
	_regen(delta)
	_tick_shield(delta)
	_validate_target()

	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var mv := move_input if move_input.length() > 0.05 else kb
	# vue du dessus : l'écran « haut » = -Z monde
	var dir := Vector3(mv.x, 0, mv.y)
	if dir.length() > 1.0: dir = dir.normalized()

	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _dash_vel
		move_and_slide()
		return

	if _action_t > 0.0:
		_action_t -= delta
		velocity = velocity.move_toward(Vector3.ZERO, 40.0 * delta)
		velocity.y = 0
		move_and_slide()
		if _action_t <= 0.0: _action = ""
		return

	if _gather_node:
		if dir.length() > 0.2 or not is_instance_valid(_gather_node):
			_stop_gather()
		else:
			_gather_t -= delta
			if _gather_t <= 0.0: _finish_gather()
			return

	if dir.length() > 0.08:
		velocity = dir * SPEED * speed_mult() * clampf(dir.length() * 1.15, 0.35, 1.0)
		_face(dir, delta, 14.0)
		_play("Sprint_Loop" if _haste_t > 0.0 else "Jog_Fwd_Loop", 0.12, 1.08)
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.31
			Sfx.play_at("step", global_position, -14.0)
	elif attack_held:
		_auto_attack(delta)
	else:
		velocity = Vector3.ZERO
		_play("Sword_Idle", 0.25)
	velocity.y = 0
	move_and_slide()

func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 0.01: return
	var want := atan2(dir.x, dir.z)  # le modèle regarde +Z une fois retourné
	rotation.y = lerp_angle(rotation.y, want + PI, minf(rate * delta, 1.0))

func face_now(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() > 0.01: rotation.y = atan2(d.x, d.z) + PI

func forward() -> Vector3:
	return -global_transform.basis.z

# --- Cible et attaque assistée -----------------------------------------------
func _validate_target() -> void:
	if target and (not is_instance_valid(target) or target.dead or target.global_position.distance_to(global_position) > ASSIST_RANGE * 1.6):
		target = null
		G.target_changed.emit(null)

## Choisit l'ennemi devant soi en priorité (pas une cible lointaine).
func pick_target() -> Node3D:
	if target and is_instance_valid(target) and not target.dead and target.global_position.distance_to(global_position) < ASSIST_RANGE:
		return target
	var best: Node3D = null
	var best_score := INF
	var fwd := forward()
	for e in G.enemies:
		if e.dead: continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		var d := to.length()
		if d > ASSIST_RANGE: continue
		var facing := fwd.dot(to.normalized()) if d > 0.01 else 1.0
		var score := d - facing * 2.5
		if score < best_score:
			best_score = score
			best = e
	if best != target:
		target = best
		G.target_changed.emit(target)
	return target

func _auto_attack(delta: float) -> void:
	var t := pick_target()
	if t == null:
		velocity = Vector3.ZERO
		_play("Sword_Idle")
		return
	var to := t.global_position - global_position
	to.y = 0
	if to.length() > ATTACK_RANGE:
		velocity = to.normalized() * SPEED
		_face(to, delta, 16.0)
		_play("Jog_Fwd_Loop", 0.1, 1.08)
		return
	velocity = Vector3.ZERO
	face_now(t.global_position)
	_basic_attack(t)

func _basic_attack(t: Node3D) -> void:
	var names := ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_A"]
	var times := [0.42, 0.5, 0.42]
	var hit_at := [0.2, 0.24, 0.2]
	var i := _combo % 3
	_replay(names[i], 0.06, 1.15)
	_action = "atk"
	_action_t = times[i] / 1.15
	_combo += 1
	_combo_t = 1.1
	Sfx.play_at("swing", global_position, -6.0, 1.05)
	var yaw := rotation.y
	_later(hit_at[i] / 1.15, func():
		G.slash(global_position + forward() * 0.6, yaw, Color(1, 0.95, 0.8, 0.9), 1.6, i == 1)
		if is_instance_valid(t) and not t.dead and t.global_position.distance_to(global_position) < ATTACK_RANGE + 0.8:
			t.take_hit(BASE_DMG * dmg_mult() * randf_range(0.92, 1.08), global_position, 1.2, 0.0, i == 2)
			_land_hit(t, 0.055, 0.18))

func _land_hit(t: Node3D, stop := 0.05, shake := 0.2) -> void:
	G.hitstop(int(stop * 1000.0))
	G.shake(shake)

# --- Sorts ---------------------------------------------------------------
func try_skill(slot: int) -> bool:
	if not dead and energy < skills[slot]["cost"] and cd_left[slot] <= 0.0:
		return false
	if dead or cd_left[slot] > 0.0 or _dash_t > 0.0:
		if OS.get_environment("ABY_TEST") != "": print("TEST refus sort ", slot, " cd=", snappedf(cd_left[slot], 0.1), " dash=", _dash_t)
		return false
	if _action == "skill" and slot < 3:   # casque, plastron et bottes passent toujours
		if OS.get_environment("ABY_TEST") != "": print("TEST refus sort ", slot, " action=", _action, " t=", snappedf(_action_t, 0.01))
		return false
	_stop_gather()
	match slot:
		0: _skill_entaille()
		1:
			if not _skill_charge(): return false
		2: _skill_fracas()
		_:
			match skills[slot]["id"]:
				"garde": _skill_garde()
				"souffle": _skill_souffle()
				"fureur": _skill_fureur()
				"embrase": _skill_embrase()
				"vent": _skill_vent()
				"roulade":
					if not _skill_roulade(): return false
	energy -= skills[slot]["cost"]
	cd_left[slot] = skills[slot]["cd"]
	cast.emit(slot, skills[slot]["cd"])
	return true

func _skill_entaille() -> void:
	var t := pick_target()
	if t: face_now(t.global_position)
	_replay("Sword_Heavy_A", 0.05, 1.1)
	_action = "skill"
	_action_t = 0.62
	var yaw := rotation.y
	var tele := G.telegraph(global_position, yaw, 1, Vector2(7.0, 7.0), Color(0.45, 0.8, 1.0, 0.8), 110.0)
	tele.material_override.set_shader_parameter("progress", 1.0)
	_fade(tele, 0.35)
	Sfx.play_at("swing", global_position, -2.0, 0.85)
	_later(0.3, func():
		G.slash(global_position + forward() * 0.8, yaw, Color(1.0, 0.55, 0.25, 1.0), 2.8)
		G.slash(global_position + forward() * 1.0, yaw, Color(1.0, 0.9, 0.6, 0.9), 2.2, true)
		G.burst(global_position + forward() * 2.0 + Vector3.UP, "spark_05", Color(1, 0.7, 0.3, 1), 16, 6.0, 0.35, 0.35, -8.0)
		var n := _hit_cone(3.4, 55.0, BASE_DMG * dmg_mult() * 2.4, 3.0, 0.0)
		if n > 0: _land_hit(null, 0.075, 0.35))

func _skill_charge() -> bool:
	var t := pick_target()
	var dir := forward()
	var dist := 7.0
	if t:
		var to := t.global_position - global_position
		to.y = 0
		dist = clampf(to.length() - 1.0, 1.5, 8.0)
		dir = to.normalized()
		face_now(t.global_position)
	var tele := G.telegraph(global_position, rotation.y, 2, Vector2(1.6, dist + 1.0), Color(0.45, 0.8, 1.0, 0.8))
	tele.material_override.set_shader_parameter("progress", 1.0)
	_fade(tele, 0.4)
	_replay("Sword_Dash", 0.05, 1.6)
	_action = "skill"
	var dash_time := 0.28
	_later(0.12, func():
		_dash_vel = dir * (dist / dash_time)
		_dash_t = dash_time
		for k in 5:
			G.streak(global_position + dir * (dist * k / 5.0) + Vector3.UP * 1.0, atan2(dir.x, dir.z), Color(0.6, 1.0, 0.85, 0.55), 0.05 * k)
		G.burst(global_position + Vector3.UP * 0.3, "smoke_04", Color(0.8, 0.75, 0.65, 0.6), 10, 2.0, 0.9, 0.5, 0.0))
	_later(0.12 + dash_time, func():
		_action_t = 0.35
		G.ring(global_position, "circle_05", Color(0.6, 1.0, 0.85, 0.9), 0.6, 5.0, 0.35)
		G.burst(global_position + Vector3.UP * 0.3, "dirt_02", Color(0.7, 0.6, 0.45, 0.9), 14, 5.0, 0.7, 0.5, -9.0)
		var n := _hit_circle(global_position + dir * 0.8, 1.9, BASE_DMG * dmg_mult() * 1.7, 2.0, 1.3)
		if n > 0: _land_hit(null, 0.07, 0.4))
	return true

func _skill_fracas() -> void:
	_replay("Sword_GroundPound", 0.05, 1.15)
	_action = "skill"
	_action_t = 1.0
	var tele := G.telegraph(global_position, 0.0, 0, Vector2(8.4, 8.4), Color(0.45, 0.8, 1.0, 0.85))
	var tw := tele.create_tween()
	tw.tween_method(func(v): tele.material_override.set_shader_parameter("progress", v), 0.0, 1.0, 0.5)
	_fade(tele, 0.75)
	_later(0.5, func():
		Sfx.play_at("slam", global_position, 2.0, 0.8)
		G.burst(global_position + Vector3.UP * 0.2, "dirt_02", Color(0.75, 0.62, 0.45, 0.9), 26, 7.0, 0.9, 0.6, -9.0)
		G.ring(global_position, "magic_03", Color(1.0, 0.75, 0.3, 0.95), 2.0, 9.0, 0.7)
		G.ring(global_position, "circle_05", Color(1.0, 0.9, 0.6, 0.9), 1.0, 10.0, 0.4)
		G.burst(global_position + Vector3.UP * 0.5, "spark_05", Color(1.0, 0.75, 0.3, 1), 24, 7.0, 0.4, 0.6, -6.0)
		var n := _hit_circle(global_position, 4.2, BASE_DMG * dmg_mult() * 3.2, 6.0, 0.6)
		_land_hit(null, 0.09 if n > 0 else 0.0, 0.6))

func _skill_garde() -> void:
	_replay("Sword_Block", 0.08, 1.0)
	_action = "skill"
	_action_t = 0.45
	shield = max_hp * 0.35
	_shield_t = 5.0
	_bubble.visible = true
	_rune.visible = true
	G.ring(global_position, "circle_05", Color(1.0, 0.85, 0.4, 0.9), 0.5, 4.5, 0.35)
	_bubble.scale = Vector3.ONE * 0.4
	_bubble.create_tween().tween_property(_bubble, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	G.burst(global_position + Vector3.UP, "star_06", Color(1, 0.85, 0.4, 1), 18, 3.0, 0.5, 0.6, 0.0)
	Sfx.play_at("hit_heavy", global_position, -6.0, 1.4)
	hp_changed.emit(hp, max_hp, shield)

func dmg_mult() -> float:
	return 1.4 if _fury_t > 0.0 else 1.0

func speed_mult() -> float:
	return 1.6 if _haste_t > 0.0 else 1.0

func _skill_fureur() -> void:
	_fury_t = 6.0
	_aura.emitting = true
	G.ring(global_position, "circle_05", Color(1.0, 0.3, 0.12, 0.9), 0.5, 6.0, 0.45)
	G.burst(global_position + Vector3.UP, "flame_04", Color(1.0, 0.35, 0.1, 0.9), 22, 4.0, 0.7, 0.6, 2.0)
	Sfx.play_at("hit_heavy", global_position, -4.0, 0.7)
	G.shake(0.15)

func _skill_vent() -> void:
	_haste_t = 3.5
	_wind.emitting = true
	G.ring(global_position, "twirl_02", Color(0.7, 1.0, 0.85, 0.8), 0.8, 4.0, 0.4)
	G.burst(global_position + Vector3.UP * 0.4, "smoke_04", Color(0.85, 1.0, 0.9, 0.6), 14, 3.0, 0.8, 0.5, 0.0)
	Sfx.play_at("swing", global_position, -6.0, 1.4)

var _burn_t := 0.0
var _num_stack := 0
var _num_t := 0
var _burn_tick := 0.0
var _invuln_t := 0.0

func _skill_souffle() -> void:
	var heal := max_hp * 0.22
	hp = minf(hp + heal, max_hp)
	G.number(global_position + Vector3.UP * 2.3, int(heal), Color(0.5, 1.0, 0.55), true)
	G.ring(global_position, "magic_03", Color(0.45, 1.0, 0.6, 0.9), 1.0, 5.0, 0.6)
	G.burst(global_position + Vector3.UP * 0.5, "light_01", Color(0.6, 1.0, 0.7, 0.8), 18, 2.5, 0.6, 0.9, 2.5)
	Sfx.play_at("pickup", global_position, -2.0, 1.3)
	hp_changed.emit(hp, max_hp, shield)

func _skill_embrase() -> void:
	_burn_t = 5.0
	_burn_tick = 0.0
	_aura.emitting = true
	G.ring(global_position, "circle_05", Color(1.0, 0.45, 0.1, 0.9), 0.8, 7.0, 0.5)
	Sfx.play_at("slam", global_position, -6.0, 1.3)

func _skill_roulade() -> bool:
	var dir := Vector3(move_input.x, 0, move_input.y)
	if dir.length() < 0.2: dir = forward()
	dir = dir.normalized()
	face_now(global_position + dir)
	_replay("Roll", 0.05, 1.5)
	_dash_vel = dir * 11.0
	_dash_t = 0.45
	_invuln_t = 0.5
	G.burst(global_position + Vector3.UP * 0.3, "smoke_04", Color(0.85, 0.8, 0.7, 0.6), 10, 2.0, 0.8, 0.5, 0.0)
	Sfx.play_at("swing", global_position, -8.0, 0.8)
	return true

func _tick_buffs(delta: float) -> void:
	_invuln_t = maxf(_invuln_t - delta, 0.0)
	if _burn_t > 0.0:
		_burn_t -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			var n := _hit_circle(global_position, 3.2, BASE_DMG * 0.5, 0.2, 0.0)
			G.ring(global_position, "flame_04", Color(1.0, 0.4, 0.1, 0.55), 2.0, 6.5, 0.45)
			if n > 0: Sfx.play_at("hit", global_position, -10.0, 1.4)
		if _burn_t <= 0.0 and _fury_t <= 0.0: _aura.emitting = false
	if _fury_t > 0.0:
		_fury_t -= delta
		if _fury_t <= 0.0 and _burn_t <= 0.0: _aura.emitting = false
	if _haste_t > 0.0:
		_haste_t -= delta
		if _haste_t <= 0.0: _wind.emitting = false
	if _shield_t > 0.0:
		_rune.rotation.y += delta * 1.5
		var m: StandardMaterial3D = _rune.mesh.material
		m.albedo_color.a = minf(0.85, _shield_t)
	elif _rune.visible:
		_rune.visible = false

func buff_left(i: int) -> float:
	match skills[i]["id"]:
		"garde": return _shield_t
		"fureur": return _fury_t
		"embrase": return _burn_t
		"vent": return _haste_t
	return 0.0

func _tick_shield(delta: float) -> void:
	if _shield_t <= 0.0: return
	_shield_t -= delta
	if _shield_t <= 0.0 or shield <= 0.0:
		_shield_t = 0.0
		shield = 0.0
		_bubble.visible = false
		hp_changed.emit(hp, max_hp, shield)

func _hit_cone(radius: float, half_deg: float, dmg: float, knock: float, stun: float) -> int:
	var n := 0
	var fwd := forward()
	for e in G.enemies:
		if e.dead: continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		if to.length() > radius + e.radius: continue
		if to.length() > 0.5 and rad_to_deg(fwd.angle_to(to.normalized())) > half_deg: continue
		e.take_hit(dmg * randf_range(0.93, 1.07), global_position, knock, stun, true)
		n += 1
	return n

func _hit_circle(center: Vector3, radius: float, dmg: float, knock: float, stun: float) -> int:
	var n := 0
	for e in G.enemies:
		if e.dead: continue
		var to: Vector3 = e.global_position - center
		to.y = 0
		if to.length() > radius + e.radius: continue
		e.take_hit(dmg * randf_range(0.93, 1.07), center, knock, stun, true)
		n += 1
	return n

# --- Dégâts reçus --------------------------------------------------------
func take_hit(dmg: float, from: Vector3, knock := 0.0) -> void:
	if dead: return
	if _invuln_t > 0.0:
		G.burst(global_position + Vector3.UP, "smoke_04", Color(0.9, 0.9, 0.9, 0.5), 6, 2.0, 0.5, 0.3, 0.0)
		return
	_last_hurt = Time.get_ticks_msec() / 1000.0
	_stop_gather()
	var now := Time.get_ticks_msec()
	_num_stack = _num_stack + 1 if now - _num_t < 450 else 0
	_num_t = now
	var ny := 2.2 + 0.42 * (_num_stack % 4)
	if shield > 0.0:
		var absorbed := minf(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
		G.number(global_position + Vector3.UP * ny, int(absorbed), Color(1, 0.85, 0.4))
	if dmg > 0.0:
		hp = maxf(hp - dmg, 0.0)
		G.number(global_position + Vector3.UP * (ny + 0.42), int(dmg), Color(1, 0.3, 0.25), true)
	G.shake(0.35)
	Sfx.play_at("flesh", global_position, -2.0, 0.9)
	G.burst(global_position + Vector3.UP * 1.2, "spark_04", Color(1, 0.4, 0.3, 1), 8, 3.5, 0.35, 0.3)
	if knock > 0.0 and _dash_t <= 0.0:
		var d := global_position - from
		d.y = 0
		velocity = d.normalized() * knock * 3.0
	if _action == "" and _dash_t <= 0.0 and not _gather_node:
		_replay("Hit_Chest", 0.05, 1.0)
		_action = "hurt"
		_action_t = 0.25
	hp_changed.emit(hp, max_hp, shield)
	if hp <= 0.0: _die()

func _die() -> void:
	dead = true
	_bubble.visible = false
	_replay("Death01", 0.1)
	target = null
	G.target_changed.emit(null)
	_later(3.5, func():
		global_position = _spawn
		hp = max_hp
		shield = 0.0
		dead = false
		_action = ""
		_action_t = 0.0
		_play("Idle_Loop", 0.2)
		hp_changed.emit(hp, max_hp, shield))

func _regen(delta: float) -> void:
	if Time.get_ticks_msec() / 1000.0 - _last_hurt > 6.0 and hp < max_hp:
		hp = minf(hp + max_hp * 0.04 * delta, max_hp)
		hp_changed.emit(hp, max_hp, shield)

# --- Récolte ---------------------------------------------------------------
func nearest_gather() -> Node3D:
	for n in G.gather_nodes:
		if n.ready_to_gather() and n.global_position.distance_to(global_position) < 2.6:
			return n
	return null

func start_gather(n: Node3D) -> void:
	if dead or _action != "" or _gather_node: return
	_gather_node = n
	_gather_t = n.GATHER_TIME
	face_now(n.global_position)
	velocity = Vector3.ZERO
	_replay("Farm_Harvest", 0.15, 2.5 / n.GATHER_TIME)
	n.begin_gather(self)

func _stop_gather() -> void:
	if _gather_node:
		if is_instance_valid(_gather_node): _gather_node.cancel_gather()
		_gather_node = null
		_play("Idle_Loop", 0.2)

func _finish_gather() -> void:
	var n := _gather_node
	_gather_node = null
	n.complete_gather()
	_play("Idle_Loop", 0.25)

func gather_progress() -> float:
	if not _gather_node: return -1.0
	return 1.0 - _gather_t / _gather_node.GATHER_TIME

# --- Utilitaires ------------------------------------------------------------
func _later(t: float, f: Callable) -> void:
	_hit_pending.append([t, f])

func _tick_pending(delta: float) -> void:
	if _hit_pending.is_empty(): return
	var keep := []
	var run := []
	for p in _hit_pending:
		p[0] -= delta
		if p[0] <= 0.0: run.append(p[1])
		else: keep.append(p)
	_hit_pending = keep
	for f in run: f.call()

func _fade(n: Node3D, t: float) -> void:
	var tw := n.create_tween()
	tw.tween_interval(t)
	tw.tween_callback(n.queue_free)
