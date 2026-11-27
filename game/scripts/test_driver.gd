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
var _last_e: Node = null

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
	if OS.get_environment("ABY_TEST") == "contre":
		steps = [["tp", Vector3(0.5, 0, -15.5)], ["wait", 0.8], ["walk", Vector3(0.5, 0, -19.5)],
			["parry", 0.09], ["wait", 0.04], ["shot", "contre_parfait"], ["wait", 0.3], ["shot", "riposte"],
			["wait", 0.5], ["shot", "chute"], ["wait", 0.9], ["shot", "a_terre"], ["wait", 1.6], ["shot", "releve"],
			["parry", 0.27], ["wait", 0.03], ["shot", "contre"], ["wait", 0.35], ["shot", "titube"],
			["equip", "bottes_rodeur"], ["roll", 0.1], ["wait", 0.12], ["shot", "esquive_parfaite"],
			["attack", 0.55], ["shot", "recul"], ["attack", 0.3], ["shot", "recul2"],
			["tp", Vector3(20.5, 0, -3.5)], ["wait", 0.5], ["walk", Vector3(21.5, 0, -7.0)], ["parry", 0.1], ["wait", 0.05], ["shot", "contre_rodeur"], ["state"],
			["wait", 1.6], ["state"], ["shot", "rodeur_chute"],
			["tp", Vector3(-14, 0, -26)], ["wait", 0.5], ["walk", Vector3(-15.5, 0, -27.0)], ["parry", 0.1], ["wait", 0.05], ["shot", "contre_boss"], ["state"],
			["wait", 1.0], ["state"], ["shot", "boss_chute"], ["slow"], ["wait", 0.1], ["shot", "ralenti_bord"], ["report"]]
		_next()
		return
	if OS.get_environment("ABY_TEST") == "bourg":
		steps = [["wait", 2.0], ["shot", "place"], ["tp", Vector3(6.0, 0, 63.5)], ["wait", 1.2], ["shot", "forgeron"], ["wait", 3.0], ["shot", "forgeron2"], ["face"], ["tp", Vector3(5.4, 0, 60.0)], ["wait", 1.4], ["shot", "forgeron_face"], ["unface"],
			["tp", Vector3(3.5, 0, 52.5)], ["wait", 1.0], ["shot", "marchande"], ["tp", Vector3(-4.0, 0, 58.5)], ["wait", 1.0], ["shot", "tisserande"],
			["tp", Vector3(-2.0, 0, 64.8)], ["wait", 1.0], ["shot", "vieux_banc"], ["tp", Vector3(1.0, 0, 60.5)], ["wait", 4.0], ["shot", "promeneurs"],
			["tp", Vector3(1.0, 0, 70.0)], ["boss_tue"], ["tp", Vector3(5.5, 0, 63.6)], ["wait", 1.0], ["shot", "rumeur_forgeron"], ["report"]]
		_next()
		return
	if OS.get_environment("ABY_TEST") == "statut":
		steps = [["wait", 1.0], ["exploits"], ["tp", Vector3(-2.4, 0, 64.9)], ["wait", 1.4], ["shot", "aldric_appelle"],
			["panel", 3], ["wait", 0.2], ["shot", "registre_avant"], ["statup"], ["wait", 0.6], ["shot", "registre_inscription"], ["wait", 2.0], ["shot", "registre_techniques"],
			["close"], ["grand_exploit"], ["panel", 3], ["wait", 0.2], ["shot", "niveau_pret"], ["statup"], ["wait", 0.9], ["shot", "niveau_compte"], ["wait", 1.6], ["shot", "niveau_2"], ["close"], ["wait", 0.3], ["shot", "niveau_2_bourg"],
			["tp", Vector3(0.5, 0, -15.5)], ["wait", 0.8], ["walk", Vector3(0.5, 0, -19.5)], ["parry", 0.09], ["callout", "Dernier instant !"], ["wait", 0.08], ["shot", "dernier_instant"],
			["wait", 1.5], ["equip", "bottes_rodeur"], ["roll", 0.1], ["wait", 0.7], ["shot", "pas_ombre"], ["report"]]
		_next()
		return
	if OS.get_environment("ABY_TEST") == "tisseuse_proche":
		steps = [["tp", Vector3(18.0, 0, 22.0)], ["wait", 0.5], ["shot", "tisseuse_descend"], ["wait", 1.6], ["shot", "tisseuse_proche"], ["face"], ["wait", 0.2], ["shot", "tisseuse_face"]]
		_next()
		return
	if OS.get_environment("ABY_TEST") == "tisseuse":
		steps = [["tp", Vector3(11.5, 0, 24.0)], ["wait", 1.0], ["shot", "nid_tisseuses"], ["walk", Vector3(15.0, 0, 22.0)], ["wait", 0.35], ["shot", "descente"],
			["wait", 1.2], ["shot", "au_sol"], ["walk", Vector3(11.0, 0, 24.5)], ["pat", "bond"], ["shot", "bond"], ["walk", Vector3(11.0, 0, 24.5)], ["pat", "toile"], ["shot", "toile_crachat"], ["wait", 0.5], ["shot", "toile_sol"],
			["pat", "morsure"], ["shot", "morsure"], ["parry", 0.12], ["wait", 0.05], ["shot", "contre_tisseuse"], ["wait", 0.9], ["shot", "tisseuse_renversee"],
			["fight", 25.0], ["shot", "apres_combat"],
			["ownequip", "capuche_soie"], ["tp", Vector3(0.5, 0, -15.5)], ["wait", 0.5], ["walk", Vector3(0.5, 0, -18.5)], ["skill", 3], ["wait", 0.45], ["shot", "sort_toile"],
			["wait", 1.0], ["shot", "brutes_engluees"], ["report"]]
		_next()
		return
	if OS.get_environment("ABY_TEST") == "close":
		steps = [["wait", 1.0], ["shot", "gros_plan_repos"], ["face"], ["wait", 0.3], ["shot", "gros_plan_face"],
			["equip", "capuche_lin"], ["wait", 0.3], ["shot", "gros_plan_capuche"], ["equip", "casque_garde"], ["unface"], ["tp", Vector3(0.5, 0, -15.5)], ["wait", 0.6], ["shot", "gros_plan_brutes"],
			["tp", Vector3(20.5, 0, -3.5)], ["wait", 0.6], ["shot", "gros_plan_rodeurs"], ["tp", Vector3(-17.5, 0, -24.0)], ["wait", 0.6], ["shot", "gros_plan_boss"],
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
		["wait", 1.0], ["shot", "fin"],
		# retour au bourg : Aldric inscrit ce que la partie a vraiment donné
		["tp", Vector3(-2.4, 0, 64.9)], ["wait", 1.2], ["shot", "retour_aldric"], ["panel", 3], ["wait", 0.2], ["shot", "registre_partie"],
		["statup"], ["wait", 2.2], ["shot", "registre_partie_inscrit"], ["close"], ["report"],
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
		"face":
			G.cam_rig.rotation.y = PI
			_next()
		"unface":
			G.cam_rig.rotation.y = 0.0
			_next()
		"slow":
			G.slowmo(0.3, 3000)
			G.callout.emit("Contre parfait !", Color(1.0, 0.85, 0.35))
			_next()
		"boss_tue":
			G.stats.gardien = true
			for v in get_tree().root.find_children("*", "Node3D", true, false):
				if v.get_script() == preload("res://scripts/villager.gd"):
					print("TEST habitant ", v.name, " cd=", snappedf(v._talk_cd, 0.1))
					v._talk_cd = 0.0
			_next()
		"exploits":
			# ce qu'une vraie sortie aurait donné (contres, esquives, chutes, coups portés et reçus, sorts)
			G.stats.contres_parfaits = 3; G.stats.contres = 7; G.stats.esquives_parfaites = 3; G.stats.chutes = 4
			for a in [["force", 95.0], ["endurance", 60.0], ["dexterite", 70.0], ["agilite", 48.0], ["magie", 30.0]]: G.status.gain(a[0], a[1])
			print("TEST statut en attente ", G.status.pending)
			_next()
		"grand_exploit":
			G.stats.gardien = true
			G.stats.chutes = 6
			G.status.gain("force", 900.0)
			print("TEST niveau possible=", G.status.can_level())
			_next()
		"statup":
			G.hud.get_child(0).do_action(["status_update"])
			print("TEST statut niveau=", G.status.level, " val=", G.status.val, " techs=", G.status.techs.keys(), " pv_max=", _p().max_hp)
			_next()
		"ownequip":
			G.owned_gear[s[1]] = true
			G.equip(s[1])
			_next()
		"state":
			if is_instance_valid(_last_e): print("TEST etat ", _last_e.kind, " = ", _last_e.state_name(), " hp=", int(_last_e.hp), " dist=", snappedf(_last_e.global_position.distance_to(_p().global_position), 0.1))
			_next()
		"equip":
			G.equip(s[1])
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
			print("TEST stats ", G.stats)
			print("TEST statut niveau=", G.status.level, " val=", G.status.val, " attente=", G.status.pending, " techs=", G.status.techs.keys())
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
		"parry", "roll":
			# attend que le coup ennemi soit à « s[1] » secondes de partir, puis contre (ou roule)
			for e in G.enemies:
				var w: float = e.counter_window()
				if w >= 0.0 and w <= s[1] and e.global_position.distance_to(p.global_position) < 8.0:
					if _mode == "parry":
						print("TEST contre fenetre=", snappedf(w, 0.01), " ok=", p.try_counter(), " ", e.kind)
						_last_e = e
					else:
						for k in p.skills.size():
							if p.skills[k]["id"] == "roulade":
								p.move_input = Vector2(1, 0)
								print("TEST roulade fenetre=", snappedf(w, 0.01), " ok=", p.try_skill(k))
								p.move_input = Vector2.ZERO
					_next()
					return
			if _t > 10.0:
				print("TEST ", _mode, " timeout")
				_next()
		"pat":
			# attend qu'une tisseuse prépare l'attaque demandée, juste avant l'impact
			for e in G.enemies:
				if e.kind == "araignee" and not e.dead and e.state_name() == "Attaque" and e._pattern == s[1] and e._atk_phase == 0 and e._atk_t < 0.22:
					print("TEST attaque ", s[1], " t=", snappedf(e._atk_t, 0.01))
					_next()
					return
			if _t > 14.0:
				print("TEST pat ", s[1], " timeout")
				_next()
		"callout":
			if G.hud.get_child(0)._callout[0] == s[1] or _t > 6.0:
				if _t > 6.0: print("TEST callout timeout ", s[1])
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
