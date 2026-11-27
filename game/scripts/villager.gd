extends Node3D
## Habitant du bourg. Routine posée à la main : gestes de métier en boucle (forger, tisser, vendre,
## se reposer) ou promenade entre des points précis. Il regarde le joueur qui s'approche, le salue,
## et parle de ce qu'il a entendu : ce que le joueur a VRAIMENT fait (G.stats), première graine
## des rumeurs vivantes. Hors de vue, il s'arrête complètement (aucun coût).

const CB := preload("res://scripts/character_builder.gd")
const WALK_SPEED := 1.25

var cfg: Dictionary
var model: Node3D
var ap: AnimationPlayer
var _seq_i := 0
var _seq_t := 0.0
var _route_i := 0
var _wait_t := 0.0
var _talk_cd := 0.0
var _greet_t := 0.0
var _bubble: Label3D
var _far := false
var _far_t := 0.0
var _strike_done := false
var _line_i := 0
var _yaw_goal := 0.0
var _said := {}
static var by_name := {}
static var _speaker = null    # un seul habitant parle à la fois (sinon les bulles se chevauchent)
var _tw: Tween

func setup(c: Dictionary) -> void:
	cfg = c

func _ready() -> void:
	by_name[cfg.get("name", "")] = self
	var p: Vector3 = cfg.pos
	position = Vector3(p.x, G.world.h(p.x, p.z), p.z)
	_yaw_goal = deg_to_rad(cfg.get("dir", 0.0)) + PI
	rotation.y = _yaw_goal
	model = CB.build(cfg.look)
	model.rotation.y = PI
	add_child(model)
	for it in cfg.get("hold", []):
		CB.hold(model, it[0], it[1], it[2], it[3], it[4])
	G.character_look(model, {"rim_amount": 0.5, "thick": 0.011, "outline": Color(0.05, 0.035, 0.025)})
	ap = AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("v", load("res://assets/anims/villager_anims.res"))
	ap.playback_default_blend_time = 0.3
	for a in ["Idle", "Walk", "Walk_Formal", "Counter_Idle", "Sitting_Idle", "Idle_FoldArms", "Mining", "Idle_LookAround"]:
		var an := ap.get_animation("v/" + a)
		if an: an.loop_mode = Animation.LOOP_LINEAR
	if not cfg.has("route"):
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.7
		cs.shape = cap
		cs.position.y = 0.85
		body.add_child(cs)
		add_child(body)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.fixed_size = true
	_bubble.pixel_size = 0.0009
	_bubble.font_size = 30
	_bubble.outline_size = 10
	_bubble.outline_modulate = Color(0.08, 0.05, 0.03, 0.9)
	_bubble.modulate = Color(1.0, 0.95, 0.82, 0.0)
	_bubble.width = 440.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bubble.font = load("res://assets/fonts/DejaVuSansCondensed-Bold.ttf")
	_bubble.position.y = 2.35
	add_child(_bubble)
	_bubble_alpha(0.0)
	_seq_t = randf() * 1.5
	_play(_seq_anim())

func _play(a: String, speed := 1.0) -> void:
	var n := "v/" + a
	if ap.current_animation == n and ap.is_playing(): return
	ap.play(n, -1.0, speed)

func _seq_anim() -> String:
	var seq: Array = cfg.get("seq", [["Idle", 4.0]])
	return seq[_seq_i % seq.size()][0]

func _process(delta: float) -> void:
	# hors de vue : tout s'arrête (vérifié deux fois par seconde)
	_far_t -= delta
	if _far_t <= 0.0:
		_far_t = 0.5
		var far := G.cam_rig == null or global_position.distance_to(G.cam_rig.global_position) > 30.0
		if far != _far:
			_far = far
			ap.active = not far
	if _far: return
	_talk_cd -= delta
	var p: Node3D = G.player
	var d := INF
	if p and not p.dead: d = p.global_position.distance_to(global_position)
	# le joueur approche : il le regarde, le salue et parle
	if d < 2.6 and _talk_cd <= 0.0 and _floor_free():
		_talk_cd = 22.0
		_greet_t = 2.6
		_say(_line())
		if not cfg.get("seated", false): _play(cfg.get("greet", "Yes"))
	if _greet_t > 0.0:
		_greet_t -= delta
		if not cfg.get("seated", false) and p:
			var to := p.global_position - global_position
			_yaw_goal = atan2(to.x, to.z) + PI
		rotation.y = lerp_angle(rotation.y, _yaw_goal, minf(delta * 5.0, 1.0))
		if _greet_t <= 0.0:
			_yaw_goal = deg_to_rad(cfg.get("dir", 0.0)) + PI
			_play(_seq_anim())
		return
	if cfg.has("route"):
		_walk(delta, d)
	else:
		_routine(delta)
	rotation.y = lerp_angle(rotation.y, _yaw_goal, minf(delta * 4.0, 1.0))

## Gestes de métier : chaque geste dure le temps indiqué, puis le suivant.
func _routine(delta: float) -> void:
	var seq: Array = cfg.get("seq", [["Idle", 4.0]])
	_seq_t += delta
	var cur: Array = seq[_seq_i % seq.size()]
	_play(cur[0])
	# coups de marteau : étincelles et tintement sur l'enclume, à chaque frappe
	if cfg.has("anvil") and cur[0] == "Mining":
		var len := ap.current_animation_length
		var ph := fmod(ap.current_animation_position, len) / len
		if ph >= cfg.get("strike_at", 0.55) and not _strike_done:
			_strike_done = true
			var a: Vector3 = cfg.anvil
			G.burst(a, "spark_05", Color(1.0, 0.75, 0.35, 1.0), 7, 3.5, 0.3, 0.25, -6.0)
			Sfx.play_at("hit_heavy", a, -16.0, randf_range(1.4, 1.6))
		elif ph < 0.2:
			_strike_done = false
	if _seq_t >= cur[1]:
		_seq_t = 0.0
		_seq_i += 1
		_play(_seq_anim())

## Promenade : marche d'un point à l'autre, s'arrête un moment à certains points,
## et attend poliment si le joueur lui barre la route.
func _walk(delta: float, d_player: float) -> void:
	var route: Array = cfg.route
	if _wait_t > 0.0:
		_wait_t -= delta
		_play("Idle_LookAround")
		return
	var goal: Vector3 = route[_route_i % route.size()]
	var to := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	if to.length() < 0.25:
		var pauses: Dictionary = cfg.get("pauses", {})
		_wait_t = pauses.get(_route_i % route.size(), 0.0)
		_route_i += 1
		return
	var dir := to.normalized()
	var p: Node3D = G.player
	if p and d_player < 1.4 and dir.dot((p.global_position - global_position).normalized()) > 0.4:
		_play("Idle")
		return
	_yaw_goal = atan2(dir.x, dir.z) + PI
	_play(cfg.get("walk", "Walk"))
	var np := global_position + dir * WALK_SPEED * delta
	np.y = G.world.h(np.x, np.z)
	global_position = np

## Ce que l'habitant dit : d'abord ce qu'il sait des exploits du joueur, sinon une phrase de son métier.
func _line() -> String:
	var facts: Array = []
	var k: Dictionary = G.stats.get("kills", {})
	if G.stats.get("gardien", false): facts.append(cfg.get("on_boss", "Le Gardien de cendre… c'était donc toi ? Tout le bourg en parle !"))
	if G.stats.contres_parfaits >= 3: facts.append("On raconte que tu détournes les coups au tout dernier instant.")
	if k.get("araignee", 0) >= 1 and cfg.has("on_spider"): facts.append(cfg.on_spider)
	if k.get("brute", 0) >= 2: facts.append("Les brutes du camp ont trouvé plus fort qu'elles, il paraît.")
	# Aldric tient le registre : il appelle le joueur quand des exploits attendent d'être inscrits
	if cfg.has("on_pending") and G.status.has_news(): return cfg.on_pending
	var plain: Array = cfg.get("lines", ["Bonjour !"])
	# une nouvelle qu'il n'a pas encore racontée passe toujours en premier
	for f in facts:
		if not _said.has(f):
			_said[f] = true
			return f
	_line_i += 1
	# ce qu'on a entendu de toi passe avant le reste ; une fois sur deux ensuite
	if not facts.is_empty() and (_line_i % 2 == 1 or plain.is_empty()):
		return facts[(_line_i / 2) % facts.size()]
	return plain[_line_i % plain.size()]

## Réagit à une action du joueur (mise à jour de statut) : geste et phrase, tout de suite.
func react(anim: String, t: String) -> void:
	_greet_t = 3.2
	_play(anim)
	_talk_cd = 22.0
	_say(t)

## Personne d'autre ne parle (bulle encore visible) ?
func _floor_free() -> bool:
	if _speaker == null or _speaker == self or not is_instance_valid(_speaker) or _speaker._bubble.modulate.a < 0.05: return true
	# le joueur s'est éloigné de celui qui parle : le plus proche prend la parole
	return G.player != null and _speaker.global_position.distance_to(G.player.global_position) > 4.0

func _hush() -> void:
	if _tw: _tw.kill()
	_tw = _bubble.create_tween()
	_tw.tween_method(_bubble_alpha, _bubble.modulate.a, 0.0, 0.15)

## Le texte ET son contour s'effacent ensemble (sinon un fantôme de contour reste à l'écran).
func _bubble_alpha(a: float) -> void:
	_bubble.modulate.a = a
	_bubble.outline_modulate.a = a * 0.9
	_bubble.visible = a > 0.01

func _say(t: String) -> void:
	if _speaker != null and _speaker != self and is_instance_valid(_speaker): _speaker._hush()
	_speaker = self
	_bubble.text = t
	if _tw: _tw.kill()
	_tw = _bubble.create_tween()
	_tw.tween_method(_bubble_alpha, _bubble.modulate.a, 1.0, 0.2)
	_tw.tween_interval(3.4)
	_tw.tween_method(_bubble_alpha, 1.0, 0.0, 0.5)
