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
	if OS.get_environment("ABY_TEST") == "relief":
		steps = [["tp", Vector3(18, 0, -25)], ["wait", 1.5], ["shot", "crete_nord"], ["tp", Vector3(20, 0, -6)], ["wait", 1.0], ["shot", "falaises_est"],
			["tp", Vector3(-24, 0, 12)], ["wait", 1.0], ["shot", "collines_ouest"], ["tp", Vector3(-21, 0, -4)], ["wait", 1.0], ["shot", "etang_proche"]]
		_next()
		return
	if OS.get_environment("ABY_TEST") == "perf":
		steps = [["wait", 4.0], ["report"], ["walk", Vector3(0.5, 0, 34)], ["walk", Vector3(-3, 0, 18)], ["wait", 4.0], ["report"]]
		_next()
		return
	if OS.get_environment("ABY_TEST") == "carte":
		_render_map()
		return
	if OS.get_environment("ABY_TEST") == "close":
		steps = [["wait", 1.0], ["shot", "gros_plan_repos"],
			]
		_next()
		return
	steps = [
		["wait", 1.5], ["shot", "bourg"],
		["walk", Vector3(-3.5, 0, 62.5)], ["walk", Vector3(-5.6, 0, 58)], ["wait", 0.3], ["shot", "poste_tisser"],
		["give"], ["panel", 0], ["shot", "panneau_tisser"],
		["act", 0], ["craftwait"], ["act", 0], ["craftwait"], ["act", 0], ["craftwait"], ["act", 0], ["craftwait"], ["act", 0], ["craftwait"], ["shot", "tissu_fait"], ["close"],
		["walk", Vector3(4.6, 0, 61.5)], ["walk", Vector3(5.6, 0, 60)], ["panel", 1], ["shot", "panneau_forge"],
		["actid", "plastron_cendre"], ["craftwait"], ["actid", "bottes_rodeur"], ["craftwait"], ["shot", "forge_faite"], ["close"],
		["wait", 0.3], ["shot", "nouveaux_sorts"],
		["walk", Vector3(0, 0, 52.5)], ["panel", 2], ["shot", "panneau_marche"], ["act", 0], ["wait", 0.3], ["close"],
		["walk", Vector3(0.3, 0, 45)], ["shot", "sortie_bourg"], ["walk", Vector3(0.5, 0, 34)],
		["walk", Vector3(-3, 0, 18)], ["shot", "chemin"],
		["walk", Vector3(-10.5, 0, 13.6)], ["wait", 0.3], ["shot", "bouton_recolte"], ["gather"], ["wait", 1.0], ["shot", "recolte"], ["wait", 1.6], ["shot", "recolte_fin"],
		["walk", Vector3(-14, 0, 2)], ["walk", Vector3(-18, 0, -8)], ["wait", 0.5], ["shot", "etang"],
		["walk", Vector3(-8, 0, -6)], ["walk", Vector3(2, 0, -11)], ["shot", "vers_camp"],
		["walk", Vector3(0.5, 0, -14.5)], ["wait", 0.6], ["shot", "alerte"],
		["attack", 1.2], ["shot", "combat"],
		["skill", 0], ["wait", 0.32], ["shot", "entaille"],
		["attack", 1.0], ["wait_tele"], ["shot", "zone_ennemie"],
		["skill", 2], ["wait", 0.53], ["shot", "fracas"], ["wait", 1.4],
		["skill", 3], ["skill", 4], ["wait", 0.3], ["shot", "garde_embrasement"],
		["attack", 2.0], ["skill", 1], ["wait", 0.35], ["shot", "charge"],
		["fight", 14.0], ["shot", "apres_combat"],
		["walk", Vector3(4, 0, -4)], ["walk", Vector3(15, 0, -7)], ["wait", 0.8], ["shot", "rodeurs_falaises"],
		["fight", 12.0], ["shot", "rodeurs_combat"],
		["tp", Vector3(-10, 0, -26)], ["wait", 1.0], ["shot", "repaire"],
		["walk", Vector3(-14, 0, -27)], ["fight", 6.0], ["shot", "boss_phase1"],
		["bosshp", 0.55], ["wait", 1.2], ["shot", "boss_phase2"], ["fight", 10.0], ["shot", "boss_pluie"],
		["bosshp", 0.2], ["wait", 1.0], ["fight", 12.0], ["shot", "boss_fureur"],
		["bosshp", 0.01], ["fight", 4.0], ["wait", 1.0], ["shot", "boss_vaincu"],
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
		"bosshp":
			for e in G.enemies:
				if e.kind == "boss" and not e.dead:
					e.hp = e.max_hp * s[1] + 1.0
					e.take_hit(1.0, _p().global_position, 0.0)
			_next()
		"tp":
			var v: Vector3 = s[1]
			_p().global_position = Vector3(v.x, G.world.h(v.x, v.z) + 0.2, v.z)
			_next()
		"give":
			G.give_item("lin", 15); G.give_item("cendre", 2); G.give_item("griffe", 2); G.give_silver(80)
			_next()
		"panel":
			G.hud.get_child(0).open_panel(G.stations[s[1]])
			_next()
		"close":
			G.hud.get_child(0).do_action(["close"])
			_next()
		"act":
			var rows: Array = G.hud.get_child(0)._panel_rows()
			print("TEST act ", rows[s[1]][0], " actif=", rows[s[1]][4])
			G.hud.get_child(0).do_action(rows[s[1]][5])
			_next()
		"actid":
			for r in G.RECIPES.forge:
				if r.out == s[1]:
					print("TEST forge ", s[1], " possible=", G.can_craft(r))
					G.hud.get_child(0).do_action(["craft", r])
			_next()
		"skill":
			var ok = _p().try_skill(s[1])
			print("TEST skill ", s[1], " ok=", ok)
			_next()
		"shot":
			await _shot(s[1])
			_next()
		"report":
			print("TEST sentinelle ", G.sentinel.summary())
			print("TEST equipement ", G.equipped)
			print("TEST report silver=", G.silver, " inv=", G.inventory, " hp=", _p().hp, " fps_moy=", _fps_acc / maxf(_fps_n, 1))
			for e in G.enemies: print("TEST enemy ", e.kind, " etat=", e.state_name(), " hp=", int(e.hp))
			_next()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot_n += 1
	var path := "/tmp/shots/%02d_%s.png" % [_shot_n, name]
	img.save_png(path)
	G.sentinel.check_image(img, name)
	print("SHOT ", path)

func _process(delta: float) -> void:
	var real: float = G.real_dt
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
		"craftwait":
			if G.hud.get_child(0)._craft_t <= 0.0 and _t > 0.2: _next()
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

## Vue du dessus de toute la carte (caméra orthographique dans un rendu séparé).
func _render_map() -> void:
	await get_tree().create_timer(1.0).timeout
	var half: float = G.world.HALF
	var zmax: float = G.world.Z_MAX
	var w := 1000
	var h := int(w * (zmax + half) / (2.0 * half))
	var sv := SubViewport.new()
	sv.size = Vector2i(w, h)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = zmax + half
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 1.0
	cam.far = 200.0
	sv.add_child(cam)
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(0, 80, (zmax - half) * 0.5))
	cam.current = true
	for i in 4: await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	img.save_png("/tmp/shots/carte_vue_dessus.png")
	print("SHOT /tmp/shots/carte_vue_dessus.png")
	await get_tree().create_timer(3.0).timeout   # laisse la sentinelle faire son premier contrôle
	print("TEST sentinelle ", G.sentinel.summary())
	get_tree().quit()
