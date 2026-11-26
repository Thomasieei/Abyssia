extends Control
## Interface tactile : joystick flottant à gauche, attaque + 4 sorts en arc à droite,
## barres de vie, cadre de cible, butin, barres des monstres, barre de récolte.

var player: Node3D
var cam: Camera3D
var font: Font

# joystick flottant
var _joy_id := -1
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
const JOY_R := 92.0
# boutons
var _btn_ids := {}               # index tactile -> nom du bouton
var _pressed := {}               # nom -> bool
var _cd_total := [1.0, 1.0, 1.0, 1.0]
var _flash := [0.0, 0.0, 0.0, 0.0, 0.0]
var _toasts := []                # [texte, couleur, temps]
var _silver_shown := 0.0
var _target: Node3D = null
var _fps := 60.0
var show_debug := true

const SKILL_COL := [Color(0.42, 0.78, 1.0), Color(0.55, 0.95, 0.75), Color(1.0, 0.62, 0.3), Color(1.0, 0.85, 0.35)]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://assets/fonts/DejaVuSansCondensed-Bold.ttf")
	G.item_gained.connect(_on_item)
	G.silver_changed.connect(func(_v): pass)
	G.target_changed.connect(func(t): _target = t)
	player.cast.connect(func(slot, cd):
		_cd_total[slot] = cd
		_flash[slot + 1] = 1.0)

func _on_item(id: String, n: int) -> void:
	var it: Dictionary = G.ITEMS[id]
	_toasts.push_front([ "+%d  %s" % [n, it.name], it.color, 2.6])
	if _toasts.size() > 4: _toasts.pop_back()

# --- Disposition des boutons (dépend de la taille d'écran) -----------
func _btn_layout() -> Dictionary:
	var s := size
	var c := Vector2(s.x - 150, s.y - 140)  # bouton d'attaque
	var r := 152.0
	var out := {"attack": [c, 74.0]}
	# arc de 4 sorts autour de l'attaque : de gauche à haut
	var angs := [PI * 0.98, PI * 1.16, PI * 1.34, PI * 1.52]
	for i in 4:
		out["s%d" % i] = [c + Vector2(cos(angs[i]), sin(angs[i])) * r, 42.0]
	out["gather"] = [c + Vector2(-20, -205), 46.0]
	return out

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed:
			var b := _btn_at(t.position)
			if b != "":
				_btn_ids[t.index] = b
				_press(b, true)
			elif t.position.x < size.x * 0.5 and _joy_id == -1:
				_joy_id = t.index
				_joy_center = t.position
				_joy_pos = t.position
		else:
			if t.index == _joy_id:
				_joy_id = -1
				player.move_input = Vector2.ZERO
			if _btn_ids.has(t.index):
				_press(_btn_ids[t.index], false)
				_btn_ids.erase(t.index)
	elif ev is InputEventScreenDrag:
		var d := ev as InputEventScreenDrag
		if d.index == _joy_id:
			_joy_pos = d.position
			var v := _joy_pos - _joy_center
			if v.length() > JOY_R:
				# le socle suit le pouce : pas besoin de revenir au centre
				_joy_center = _joy_pos - v.normalized() * JOY_R
				v = _joy_pos - _joy_center
			var o := v / JOY_R
			player.move_input = o if o.length() > 0.12 else Vector2.ZERO
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_1: player.try_skill(0)
			KEY_2: player.try_skill(1)
			KEY_3: player.try_skill(2)
			KEY_4: player.try_skill(3)
			KEY_F:
				var n: Node3D = player.nearest_gather()
				if n: player.start_gather(n)
			KEY_SPACE: player.attack_held = true
	elif ev is InputEventKey and not ev.pressed and ev.keycode == KEY_SPACE:
		player.attack_held = false

func _btn_at(p: Vector2) -> String:
	var lay := _btn_layout()
	for k in lay:
		if k == "gather" and player.nearest_gather() == null: continue
		var c: Vector2 = lay[k][0]
		if p.distance_to(c) < lay[k][1] * 1.18: return k
	return ""

func _press(b: String, down: bool) -> void:
	_pressed[b] = down
	if b == "attack":
		player.attack_held = down
		if down: _flash[0] = 1.0
	elif down and b.begins_with("s"):
		var i := int(b.substr(1))
		if not player.try_skill(i): _flash[i + 1] = -1.0
	elif down and b == "gather":
		var n: Node3D = player.nearest_gather()
		if n: player.start_gather(n)

func _process(delta: float) -> void:
	size = get_viewport_rect().size
	_fps = lerpf(_fps, 1.0 / maxf(delta / maxf(Engine.time_scale, 0.01), 0.001), 0.05)
	for i in _flash.size():
		_flash[i] = move_toward(_flash[i], 0.0, delta * 3.0)
	for t in _toasts: t[2] -= delta
	_toasts = _toasts.filter(func(t): return t[2] > 0.0)
	_silver_shown = lerpf(_silver_shown, float(G.silver), minf(delta * 8.0, 1.0))
	queue_redraw()

# --- Dessin ---------------------------------------------------------------
func _draw() -> void:
	if cam == null: return
	_draw_enemy_bars()
	_draw_gather_bar()
	_draw_player_frame()
	_draw_target_frame()
	_draw_loot()
	_draw_buttons()
	_draw_joystick()
	if show_debug:
		draw_string(font, Vector2(size.x - 92, 22), "%d i/s" % roundi(_fps), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.5))

func _panel(r: Rect2, col := Color(0.05, 0.05, 0.07, 0.72)) -> void:
	draw_style_box(_sb(col), r)

var _sb_cache: StyleBoxFlat
func _sb(col: Color) -> StyleBoxFlat:
	if _sb_cache == null:
		_sb_cache = StyleBoxFlat.new()
		_sb_cache.set_corner_radius_all(8)
		_sb_cache.border_color = Color(1, 1, 1, 0.10)
		_sb_cache.set_border_width_all(1)
	_sb_cache.bg_color = col
	return _sb_cache

func _bar(r: Rect2, frac: float, col: Color, back := Color(0, 0, 0, 0.55)) -> void:
	draw_rect(r, back)
	var f := Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y))
	draw_rect(f, col)
	draw_rect(Rect2(f.position, Vector2(f.size.x, r.size.y * 0.4)), Color(1, 1, 1, 0.18))

func _draw_player_frame() -> void:
	var r := Rect2(18, 16, 300, 64)
	_panel(r)
	draw_string(font, Vector2(32, 40), "Aventurier", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.93, 0.8))
	draw_string(font, Vector2(196, 40), "Épée large", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.8, 0.9, 0.8))
	var hb := Rect2(32, 50, 272, 18)
	_bar(hb, player.hp / player.max_hp, Color(0.85, 0.2, 0.2))
	if player.shield > 0.0:
		_bar(Rect2(hb.position, Vector2(hb.size.x * minf(player.shield / player.max_hp, 1.0), 6)), 1.0, Color(1, 0.85, 0.35), Color(0, 0, 0, 0))
	draw_string(font, hb.position + Vector2(0, 14), "%d / %d" % [player.hp, player.max_hp], HORIZONTAL_ALIGNMENT_CENTER, hb.size.x, 13, Color(1, 1, 1, 0.95))

func _draw_target_frame() -> void:
	if _target == null or not is_instance_valid(_target) or _target.dead: return
	var w := 300.0
	var r := Rect2(size.x * 0.5 - w * 0.5, 14, w, 52)
	_panel(r)
	draw_string(font, r.position + Vector2(0, 20), _target.display_name, HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(1, 0.75, 0.6))
	_bar(Rect2(r.position + Vector2(14, 28), Vector2(w - 28, 14)), _target.hp / _target.max_hp, Color(0.9, 0.3, 0.2))

func _draw_loot() -> void:
	var s := "%d" % roundi(_silver_shown)
	var r := Rect2(size.x - 190, 16, 120, 40)
	_panel(r)
	draw_circle(r.position + Vector2(22, 20), 10, Color(0.82, 0.84, 0.9))
	draw_circle(r.position + Vector2(22, 20), 6, Color(0.62, 0.64, 0.7))
	draw_string(font, r.position + Vector2(40, 27), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.92, 0.94, 1.0))
	# sac
	var y := 64.0
	for id in G.inventory:
		var it: Dictionary = G.ITEMS[id]
		var rr := Rect2(size.x - 190, y, 170, 28)
		_panel(rr, Color(0.05, 0.05, 0.07, 0.55))
		draw_circle(rr.position + Vector2(14, 14), 7, it.color)
		draw_string(font, rr.position + Vector2(28, 19), "%s  x%d" % [it.name, G.inventory[id]], HORIZONTAL_ALIGNMENT_LEFT, 140, 13, Color(1, 1, 1, 0.9))
		y += 32
	# gains récents (à droite, au-dessus des sorts)
	var ty := size.y - 380.0
	for t in _toasts:
		var a := clampf(t[2] / 0.4, 0.0, 1.0)
		var rr := Rect2(size.x - 300, ty, 280, 34)
		_panel(rr, Color(0.05, 0.05, 0.07, 0.75 * a))
		draw_rect(Rect2(rr.position, Vector2(5, rr.size.y)), Color(t[1], a))
		draw_string(font, rr.position + Vector2(16, 23), t[0], HORIZONTAL_ALIGNMENT_LEFT, 260, 16, Color(t[1].lightened(0.4), a))
		ty -= 40

func _draw_enemy_bars() -> void:
	for e in G.enemies:
		if e.dead or e.hp >= e.max_hp and e.state_name() == "Garde": continue
		var top: Vector3 = e.global_position + Vector3.UP * (2.35 * e.data.scale)
		if cam.is_position_behind(top): continue
		var p := cam.unproject_position(top)
		var w := 70.0 if e.kind == "brute" else 54.0
		var r := Rect2(p - Vector2(w * 0.5, 0), Vector2(w, 8))
		draw_rect(r.grow(2), Color(0, 0, 0, 0.7))
		_bar(r, e.hp / e.max_hp, Color(0.92, 0.25, 0.18) if e == _target else Color(0.78, 0.3, 0.22), Color(0.15, 0.05, 0.05, 0.9))

func _draw_gather_bar() -> void:
	var g: float = player.gather_progress()
	var n: Node3D = player.nearest_gather()
	var top: Vector3 = player.global_position + Vector3.UP * 2.4
	var p := cam.unproject_position(top)
	if g >= 0.0:
		var r := Rect2(p - Vector2(70, 0), Vector2(140, 14))
		draw_rect(r.grow(3), Color(0, 0, 0, 0.7))
		_bar(r, g, Color(0.75, 0.9, 0.45))
		draw_string(font, p + Vector2(-70, -8), "Récolte du lin…", HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color(1, 1, 0.9))

func _draw_buttons() -> void:
	var lay := _btn_layout()
	var t := Time.get_ticks_msec() / 1000.0
	# attaque
	var ac: Vector2 = lay["attack"][0]
	var ar: float = lay["attack"][1]
	var down: bool = _pressed.get("attack", false)
	draw_circle(ac, ar + 4, Color(0, 0, 0, 0.45))
	draw_circle(ac, ar, Color(0.55, 0.16, 0.12, 0.92) if not down else Color(0.75, 0.25, 0.18, 0.95))
	draw_circle(ac, ar * 0.86, Color(0.68, 0.22, 0.16, 0.9) if not down else Color(0.85, 0.32, 0.22))
	draw_arc(ac, ar, 0, TAU, 48, Color(1, 0.8, 0.6, 0.5 + _flash[0] * 0.5), 3.0)
	_icon_sword(ac, ar * 0.55, Color(1, 0.95, 0.88))
	# sorts
	for i in 4:
		var c: Vector2 = lay["s%d" % i][0]
		var r: float = lay["s%d" % i][1]
		var cdl: float = player.cd_left[i]
		var ready := cdl <= 0.0
		var col: Color = SKILL_COL[i]
		draw_circle(c, r + 3, Color(0, 0, 0, 0.5))
		draw_circle(c, r, Color(0.09, 0.1, 0.13, 0.92))
		draw_circle(c, r * 0.9, col.darkened(0.55) if ready else Color(0.12, 0.12, 0.14))
		_skill_icon(i, c, r * 0.55, col.lightened(0.3) if ready else Color(0.45, 0.45, 0.5))
		if not ready:
			var frac: float = cdl / _cd_total[i]
			draw_arc(c, r * 0.45, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, Color(0, 0, 0, 0.55), r * 0.9)
			draw_string(font, c + Vector2(-r, 7), "%.0f" % ceil(cdl), HORIZONTAL_ALIGNMENT_CENTER, r * 2, 20, Color(1, 1, 1, 0.95))
		var f: float = _flash[i + 1]
		var ring := col if f >= 0.0 else Color(1, 0.2, 0.2)
		draw_arc(c, r, 0, TAU, 40, Color(ring, 0.35 + absf(f) * 0.65) if ready or f != 0 else Color(1, 1, 1, 0.12), 2.5 + absf(f) * 3.0)
		if ready and f <= 0.0 and fmod(t + i * 0.2, 3.0) < 0.12:
			draw_arc(c, r + 2, 0, TAU, 40, Color(col, 0.4), 2.0)
	# récolte contextuelle
	if player.nearest_gather() != null and player.gather_progress() < 0.0:
		var gc: Vector2 = lay["gather"][0]
		var gr: float = lay["gather"][1]
		var pulse := 1.0 + sin(t * 5.0) * 0.04
		draw_circle(gc, gr * pulse + 3, Color(0, 0, 0, 0.5))
		draw_circle(gc, gr * pulse, Color(0.32, 0.5, 0.2, 0.95))
		_icon_leaf(gc, gr * 0.5, Color(0.92, 1.0, 0.75))
		draw_string(font, gc + Vector2(-60, gr + 20), "Récolter", HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color(0.92, 1, 0.8))

func _draw_joystick() -> void:
	if _joy_id == -1:
		# indice discret de la zone du joystick
		var hint := Vector2(150, size.y - 140)
		draw_arc(hint, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.10), 2.0)
		draw_circle(hint, 30, Color(1, 1, 1, 0.07))
		return
	draw_circle(_joy_center, JOY_R, Color(0, 0, 0, 0.28))
	draw_arc(_joy_center, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.3), 2.5)
	var k := _joy_center + (_joy_pos - _joy_center).limit_length(JOY_R)
	draw_circle(k, 38, Color(1, 1, 1, 0.55))
	draw_circle(k, 30, Color(1, 1, 1, 0.75))

# --- Icônes vectorielles -------------------------------------------------
func _icon_sword(c: Vector2, s: float, col: Color) -> void:
	var a := Vector2(-0.7, 0.7) * s
	var b := Vector2(0.75, -0.75) * s
	draw_line(c + a, c + b, col, s * 0.22)
	draw_line(c + Vector2(-0.45, 0.05) * s, c + Vector2(-0.05, 0.45) * s, col, s * 0.18)
	draw_circle(c + a * 1.1, s * 0.13, col)

func _icon_leaf(c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var u := float(i) / 20.0
		var y := lerpf(-1.0, 1.0, u)
		pts.append(c + Vector2(sin(u * PI) * 0.55, y) * s)
	for i in range(20, -1, -1):
		var u := float(i) / 20.0
		var y := lerpf(-1.0, 1.0, u)
		pts.append(c + Vector2(-sin(u * PI) * 0.55, y) * s)
	draw_colored_polygon(pts, col)
	draw_line(c + Vector2(0, -0.9) * s, c + Vector2(0, 1.1) * s, col.darkened(0.5), 2.0)

func _skill_icon(i: int, c: Vector2, s: float, col: Color) -> void:
	match i:
		0: # Entaille : arc de lame
			draw_arc(c + Vector2(-0.2, 0.2) * s, s * 0.95, -PI * 0.95, -PI * 0.1, 20, col, s * 0.24)
			draw_line(c + Vector2(0.1, 0.7) * s, c + Vector2(0.75, 0.05) * s, col, s * 0.16)
		1: # Charge : flèches vers l'avant
			for k in 2:
				var o := Vector2(-0.45 + k * 0.55, 0) * s
				draw_polyline(PackedVector2Array([c + o + Vector2(-0.3, -0.6) * s, c + o + Vector2(0.25, 0) * s, c + o + Vector2(-0.3, 0.6) * s]), col, s * 0.2)
		2: # Fracas : impact au sol
			for k in 8:
				var a := TAU * k / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * s * 0.3, c + Vector2(cos(a), sin(a)) * s * (0.95 if k % 2 == 0 else 0.65), col, s * 0.14)
			draw_circle(c, s * 0.22, col)
		3: # Garde : bouclier
			var pts := PackedVector2Array([c + Vector2(0, -0.85) * s, c + Vector2(0.7, -0.55) * s, c + Vector2(0.6, 0.25) * s, c + Vector2(0, 0.9) * s, c + Vector2(-0.6, 0.25) * s, c + Vector2(-0.7, -0.55) * s])
			draw_colored_polygon(pts, col)
			draw_line(c + Vector2(0, -0.6) * s, c + Vector2(0, 0.6) * s, col.darkened(0.5), s * 0.12)
