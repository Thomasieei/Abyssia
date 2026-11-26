extends Node
## Test joué automatiquement (ABY_TEST=proto) : on joue vraiment et on prend des captures.
var steps: Array = []
var _i := -1
var _t := 0.0
var _goal := Vector3.ZERO
var _mode := ""
var _shot_n := 0
var _frames := 0
var _fps_acc := 0.0
var _fps_n := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	if OS.get_environment("ABY_TEST") == "close":
		steps = [["wait", 1.0], ["shot", "gros_plan_repos"],
			]
		_next()
		return
	steps = [
		["wait", 1.5], ["shot", "depart"],
		["walk", Vector3(-3, 0, 18)], ["shot", "chemin"],
		["walk", Vector3(-10.5, 0, 13.6)], ["gather"], ["wait", 1.0], ["shot", "recolte"], ["wait", 1.6], ["shot", "recolte_fin"],
		["walk", Vector3(-1, 0, 4)], ["walk", Vector3(2, 0, -11)], ["shot", "vers_camp"],
		["walk", Vector3(0.5, 0, -14.5)], ["wait", 0.6], ["shot", "alerte"],
		["attack", 1.2], ["shot", "combat"],
		["skill", 0], ["wait", 0.32], ["shot", "entaille"],
		["attack", 1.0], ["wait_tele"], ["shot", "zone_ennemie"],
		["skill", 2], ["wait", 0.53], ["shot", "fracas"], ["wait", 1.4],
		["skill", 3], ["wait", 0.3], ["shot", "garde"],
		["attack", 2.0], ["skill", 1], ["wait", 0.35], ["shot", "charge"],
		["fight", 14.0], ["shot", "apres_combat"],
		["walk", Vector3(4, 0, -4)], ["walk", Vector3(15, 0, -7)], ["wait", 0.8], ["shot", "rodeurs"],
		["fight", 12.0], ["shot", "rodeurs_combat"],
		["wait", 1.0], ["shot", "fin"], ["report"],
	]
	_next()

func _p() -> Node: return G.player

func _next() -> void:
	_i += 1
	_t = 0.0
	if _i >= steps.size():
		get_tree().quit()
		return
	var s: Array = steps[_i]
	_mode = s[0]
	match _mode:
		"walk": _goal = s[1]
		"gather":
			var n = _p().nearest_gather()
			print("TEST gather node=", n != null)
			if n: _p().start_gather(n)
			_next()
		"skill":
			var ok = _p().try_skill(s[1])
			print("TEST skill ", s[1], " ok=", ok)
			_next()
		"shot": _shot(s[1]); _next()
		"report":
			print("TEST report silver=", G.silver, " inv=", G.inventory, " hp=", _p().hp, " fps_moy=", _fps_acc / maxf(_fps_n, 1))
			for e in G.enemies: print("TEST enemy ", e.kind, " etat=", e.state_name(), " hp=", int(e.hp))
			_next()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot_n += 1
	var path := "/tmp/shots/%02d_%s.png" % [_shot_n, name]
	img.save_png(path)
	print("SHOT ", path)

func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	_frames += 1
	if _frames > 30:
		_fps_acc += 1.0 / maxf(real, 0.0001)
		_fps_n += 1
	if _i < 0 or _i >= steps.size(): return
	_t += real
	var s: Array = steps[_i]
	var p = _p()
	match _mode:
		"wait":
			if _t >= s[1]: _next()
		"walk":
			var to: Vector3 = _goal - p.global_position
			to.y = 0
			if to.length() < 0.8 or _t > 12.0:
				p.move_input = Vector2.ZERO
				if _t > 12.0: print("TEST walk timeout at ", p.global_position)
				_next()
			else:
				var d := to.normalized()
				p.move_input = Vector2(d.x, d.z)
		"attack":
			p.attack_held = true
			if _t >= s[1]:
				p.attack_held = false
				_next()
		"wait_tele":
			p.attack_held = true
			var found := false
			for e in G.enemies:
				if e.state_name() == "Attaque": found = true
			if (found and _t > 0.3) or _t > 5.0:
				p.attack_held = false
				_next()
		"fight":
			p.attack_held = true
			var alive := false
			for e in G.enemies:
				if not e.dead and e.global_position.distance_to(p.global_position) < 14.0: alive = true
			if int(_t * 10) % 25 == 0:
				for k in 3: p.try_skill(k)
			if not alive or _t >= s[1]:
				p.attack_held = false
				print("TEST fight end t=", snappedf(_t, 0.1))
				_next()
