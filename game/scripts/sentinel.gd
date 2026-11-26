extends Node
## La sentinelle : un bout de Claude dans le jeu. Elle inspecte le monde et signale chaque anomalie
## dans un code court (« CODE détails »), affiché en test et écrit dans user://sentinelle.log.
## Contrôles statiques au démarrage puis toutes les 2 minutes ; contrôles dynamiques en continu.

const STATIC_EVERY := 120.0
var _static_t := 2.0
var _seen := {}            # anomalie déjà signalée -> true (pas de doublons)
var _player_last := Vector3.ZERO
var _player_stuck := 0.0
var _enemy_last := {}
var _enemy_stuck := {}
var _frames := 0
var _slow_frames := 0
var _worst_ms := 0.0
var _log: FileAccess
var count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log = FileAccess.open("user://sentinelle.log", FileAccess.WRITE)

func report(code: String, details: String) -> void:
	var key := code + details
	if _seen.has(key): return
	_seen[key] = true
	count += 1
	var line := "SENTINELLE %s %s" % [code, details]
	print(line)
	if _log: _log.store_line(line)

func _process(delta: float) -> void:
	if G.player == null or G.world == null: return
	var real: float = G.real_dt
	_static_t -= real
	if _static_t <= 0.0:
		_static_t = STATIC_EVERY
		_check_static()
	_check_dynamic(real)

# --- Contrôles statiques : placement du décor, chemins, interface ------------
func _check_static() -> void:
	var space: PhysicsDirectSpaceState3D = G.world.get_world_3d().direct_space_state
	for d in G.decor:
		var n: Node3D = d.node
		if not is_instance_valid(n): continue
		var tilt := rad_to_deg(n.global_basis.y.normalized().angle_to(Vector3.UP))
		if tilt > 5.0:
			report("PENCHE", "%s x%.1f z%.1f %d°" % [d.name, n.global_position.x, n.global_position.z, roundi(tilt)])
		var q := PhysicsRayQueryParameters3D.create(n.global_position + Vector3.UP * 3.0, n.global_position + Vector3.DOWN * 5.0, 1)
		var hit := space.intersect_ray(q)
		if hit and hit.collider.name == "Sol":
			var gap: float = n.global_position.y - hit.position.y
			if absf(gap) > 0.2:
				report("FLOTTE" if gap > 0 else "ENTERRE", "%s x%.1f z%.1f %.2fm" % [d.name, n.global_position.x, n.global_position.z, gap])
	# objets solides qui se chevauchent
	for i in G.decor.size():
		var a: Dictionary = G.decor[i]
		if a.r <= 0.0: continue
		for j in range(i + 1, G.decor.size()):
			var b: Dictionary = G.decor[j]
			if b.r <= 0.0: continue
			var dist := Vector2(a.node.global_position.x - b.node.global_position.x, a.node.global_position.z - b.node.global_position.z).length()
			if dist < (a.r + b.r) * 0.7:
				report("CHEVAUCHE", "%s/%s x%.1f z%.1f" % [a.name, b.name, a.node.global_position.x, a.node.global_position.z])
	# chemins : aucun obstacle solide sur la bande de terre
	for s in G.world.PATHS:
		var p0 := Vector2(s[0], s[1])
		var p1 := Vector2(s[2], s[3])
		var w: float = s[4]
		for d in G.decor:
			if d.r <= 0.0: continue
			var c := Vector2(d.node.global_position.x, d.node.global_position.z)
			var t := clampf((c - p0).dot(p1 - p0) / maxf((p1 - p0).length_squared(), 0.001), 0.0, 1.0)
			if c.distance_to(p0.lerp(p1, t)) < w * 0.6 + d.r * 0.5:
				report("CHEMIN_BLOQUE", "%s x%.1f z%.1f" % [d.name, c.x, c.y])
		for hb in G.house_boxes:
			for k in range(1, 10):   # les extrémités peuvent toucher une porte
				var pt := p0.lerp(p1, k / 10.0)
				if hb.grow(-0.5).has_point(pt):
					report("CHEMIN_DANS_MAISON", "x%.1f z%.1f" % [pt.x, pt.y])
	# décor solide dans une maison
	for d in G.decor:
		for hb in G.house_boxes:
			var c := Vector2(d.node.global_position.x, d.node.global_position.z)
			if hb.grow(-0.3).has_point(c):
				report("DANS_MAISON", "%s x%.1f z%.1f" % [d.name, c.x, c.y])
	# ressources accessibles (pas enfermées dans un obstacle)
	for g in G.gather_nodes:
		for d in G.decor:
			if d.r <= 0.0: continue
			if Vector2(g.global_position.x - d.node.global_position.x, g.global_position.z - d.node.global_position.z).length() < d.r + 0.8:
				report("RESSOURCE_GENEE", "lin x%.1f z%.1f par %s" % [g.global_position.x, g.global_position.z, d.name])
	# interface : boutons qui se chevauchent
	var hud: Control = G.hud.get_child(0) if G.hud else null
	if hud and hud.has_method("_btn_layout"):
		var lay: Dictionary = hud._btn_layout()
		var keys := lay.keys()
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				var a: Array = lay[keys[i]]
				var b: Array = lay[keys[j]]
				if a[0].distance_to(b[0]) < a[1] + b[1] + 4.0:
					report("UI_CHEVAUCHE", "%s/%s" % [keys[i], keys[j]])
				for btn in [a, b]:
					if btn[0].x + btn[1] > hud.size.x or btn[0].y + btn[1] > hud.size.y:
						report("UI_HORS_ECRAN", str(keys[i]))

# --- Contrôles dynamiques : blocages, fluidité ----------------------------------
func _check_dynamic(real: float) -> void:
	_frames += 1
	if _frames > 60:
		var ms: float = G.real_dt * 1000.0
		_worst_ms = maxf(_worst_ms, ms)
		if ms > 50.0: _slow_frames += 1
		if ms > 400.0:
			report("SACCADE", "%dms t=%.1fs x%.1f z%.1f" % [ms, Time.get_ticks_msec() / 1000.0, G.player.global_position.x, G.player.global_position.z])
	var p: Node3D = G.player
	var moving: bool = p.move_input.length() > 0.3 and not p.dead and p.gather_progress() < 0.0
	if moving and p.global_position.distance_to(_player_last) < 0.02:
		_player_stuck += real
		if _player_stuck > 1.5:
			report("JOUEUR_BLOQUE", "x%.1f z%.1f" % [p.global_position.x, p.global_position.z])
			_player_stuck = 0.0
	else:
		_player_stuck = 0.0
	_player_last = p.global_position
	for e in G.enemies:
		var id: int = e.get_instance_id()
		var st: String = e.state_name()
		if (st == "Poursuite" or st == "Retour") and e.global_position.distance_to(_enemy_last.get(id, Vector3.INF)) < 0.01:
			_enemy_stuck[id] = _enemy_stuck.get(id, 0.0) + real
			if _enemy_stuck[id] > 3.0:
				report("MONSTRE_BLOQUE", "%s %s x%.1f z%.1f" % [e.kind, st, e.global_position.x, e.global_position.z])
				_enemy_stuck[id] = 0.0
		else:
			_enemy_stuck[id] = 0.0
		_enemy_last[id] = e.global_position

func summary() -> String:
	return "anomalies=%d images_lentes=%d pire=%.0fms" % [count, _slow_frames, _worst_ms]

## Pixels magenta (texture manquante) dans une capture.
func check_image(img: Image, name: String) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var bad := 0
	var n := 0
	for y in range(0, h, 6):
		for x in range(0, w, 6):
			var c := img.get_pixel(x, y)
			n += 1
			if c.r > 0.8 and c.b > 0.8 and c.g < 0.25: bad += 1
	if bad > n * 0.002:
		report("TEXTURE_MANQUANTE", "%s %.1f%%" % [name, 100.0 * bad / n])
