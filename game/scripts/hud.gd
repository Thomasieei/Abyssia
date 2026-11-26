extends Control
## Interface tactile façon Albion :
## - en bas à droite, le « moyeu » de sorts : grosse attaque au centre, 3 sorts d'arme en arc à gauche,
##   casque en haut, plastron en haut à droite, bottes en bas ; récolte à gauche du moyeu ;
## - en haut à gauche, le portrait (vie + énergie) et le cadre de cible ;
## - en haut à droite, le nom de la zone, l'heure et la mini-carte en losange ;
## - à gauche, le joystick flottant.

var player: Node3D
var cam: Camera3D
var font: Font

var _joy_id := -1
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
const JOY_R := 92.0
var _btn_ids := {}
var _pressed := {}
var _cd_total := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
var _flash := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _toasts := []
var _silver_shown := 0.0
var _target: Node3D = null
var _fps := 60.0
var _sb_cache: StyleBoxFlat
var show_debug := true
var _announce := ["", 0.0]
var _callout := ["", 0.0, Color.WHITE]

# couleur et texture de fond de chaque sort (reconnaissable en un coup d'œil)
const SKILL_STYLE := {
	"entaille": {"col": Color(1.0, 0.42, 0.2), "tex": "slash_02"},
	"charge": {"col": Color(0.35, 0.95, 0.75), "tex": "light_01"},
	"fracas": {"col": Color(1.0, 0.72, 0.25), "tex": "magic_03"},
	"garde": {"col": Color(0.45, 0.7, 1.0), "tex": "circle_05"},
	"souffle": {"col": Color(0.45, 1.0, 0.6), "tex": "magic_03"},
	"fureur": {"col": Color(1.0, 0.25, 0.3), "tex": "flame_02"},
	"embrase": {"col": Color(1.0, 0.5, 0.1), "tex": "flame_04"},
	"vent": {"col": Color(0.65, 1.0, 0.55), "tex": "twirl_02"},
	"roulade": {"col": Color(0.9, 0.78, 0.55), "tex": "smoke_04"},
}
var panel := ""            # poste ouvert ("" = aucun)
var _panel_title := ""
var _craft_t := 0.0        # fabrication en cours
var _craft_r: Dictionary = {}
var _panel_btns := []      # [Rect2, action]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://assets/fonts/DejaVuSansCondensed-Bold.ttf")
	G.item_gained.connect(_on_item)
	G.target_changed.connect(func(t): _target = t)
	G.announce.connect(func(m): _announce = [m, 3.0])
	G.callout.connect(func(m, c): _callout = [m, 1.3, c])
	G.boss_defeated.connect(func(_b): _announce = ["Le Gardien de cendre est tombé !", 4.0])
	player.cast.connect(func(slot, cd):
		_cd_total[slot] = cd
		_flash[slot + 1] = 1.0)

func _on_item(id: String, n: int) -> void:
	var col: Color = G.ITEMS[id].color if G.ITEMS.has(id) else Color(1, 0.85, 0.4)
	_toasts.push_front(["+%d  %s" % [n, G.item_name(id)], col, 2.6])
	if _toasts.size() > 4: _toasts.pop_back()

# --- Disposition ---------------------------------------------------------------
func _hub_center() -> Vector2:
	return Vector2(size.x - 162, size.y - 170)

func _btn_layout() -> Dictionary:
	var c := _hub_center()
	var r := 142.0
	var out := {"attack": [c, 70.0]}
	# angles écran (0° = droite, 90° = bas) : arme à gauche, casque en haut, plastron en haut à droite, bottes en bas
	var angs := [158.0, 198.0, 238.0, 278.0, 318.0, 116.0]
	for i in 6:
		var a := deg_to_rad(angs[i])
		out["s%d" % i] = [c + Vector2(cos(a), sin(a)) * r, 40.0]
	# récolte : à gauche du moyeu, centrée sur sa hauteur
	out["gather"] = [c + Vector2(-268, -20), 44.0]
	return out

# --- Entrées -----------------------------------------------------------------------
func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch and panel != "" and ev.pressed and _panel_rect().has_point(ev.position):
		_panel_click(ev.position)
		return
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
				_joy_center = _joy_pos - v.normalized() * JOY_R
				v = _joy_pos - _joy_center
			var o := v / JOY_R
			player.move_input = o if o.length() > 0.12 else Vector2.ZERO
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var keys := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_D, KEY_F]
		if ev.keycode in keys: player.try_skill(keys.find(ev.keycode))
		elif ev.keycode == KEY_G:
			var n: Node3D = player.nearest_gather()
			if n: player.start_gather(n)
		elif ev.keycode == KEY_SPACE:
			if not player.attack_held: player.try_counter()
			player.attack_held = true
	elif ev is InputEventKey and not ev.pressed and ev.keycode == KEY_SPACE:
		player.attack_held = false

func _btn_at(p: Vector2) -> String:
	var lay := _btn_layout()
	var best := ""
	var bd := INF
	for k in lay:
		if k == "gather" and player.nearest_gather() == null and nearest_station().is_empty(): continue
		var d := p.distance_to(lay[k][0])
		if d < lay[k][1] * 1.15 and d < bd:
			bd = d
			best = k
	return best

func _press(b: String, down: bool) -> void:
	_pressed[b] = down
	if b == "attack":
		player.attack_held = down
		if down:
			_flash[0] = 1.0
			player.try_counter()
	elif down and b.begins_with("s"):
		var i := int(b.substr(1))
		if not player.try_skill(i): _flash[i + 1] = -1.0
	elif down and b == "gather":
		var st := nearest_station()
		if not st.is_empty():
			open_panel(st)
			return
		var n: Node3D = player.nearest_gather()
		if n: player.start_gather(n)

func nearest_station() -> Dictionary:
	for st in G.stations:
		if Vector2(st.pos.x - player.global_position.x, st.pos.z - player.global_position.z).length() < 2.4:
			return st
	return {}

func open_panel(st: Dictionary) -> void:
	panel = st.id
	_panel_title = st.title
	_craft_t = 0.0
	player.attack_held = false
	Sfx.play("ui", -6.0)

func _panel_rect() -> Rect2:
	var w := 660.0
	var h := 500.0
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5 - 10, w, h)

## Lignes du panneau : [titre, détail, couleur, libellé du bouton, actif, action]
func _panel_rows() -> Array:
	var rows := []
	match panel:
		"tisserand":
			for r in G.RECIPES.tisserand:
				rows.append([G.item_name(r.out), _cost_text(r), G.ITEMS[r.out].color, "Tisser", G.can_craft(r), ["craft", r]])
		"forge":
			var crafted := {}
			for r in G.RECIPES.forge: crafted[r.out] = r
			for id in G.GEAR:
				var gd: Dictionary = G.GEAR[id]
				var spell: String = player.SPELLS[gd.spell].name
				var detail := "%s — sort : %s" % [gd.slot.capitalize(), spell]
				var col: Color = SKILL_STYLE[gd.spell].col
				if G.owned_gear.has(id):
					var on: bool = G.equipped[gd.slot] == id
					rows.append([gd.name, detail, col, "Équipé" if on else "Équiper", not on, ["equip", id]])
				elif crafted.has(id):
					var r: Dictionary = crafted[id]
					rows.append([gd.name, detail + "\n" + _cost_text(r), col, "Forger", G.can_craft(r), ["craft", r]])
		"marche":
			for id in G.inventory:
				if not G.ITEMS.has(id): continue
				var n: int = G.inventory[id]
				var price: int = G.ITEMS[id].price
				rows.append(["%s  x%d" % [G.ITEMS[id].name, n], "%d argent pièce" % price, G.ITEMS[id].color, "Vendre +%d" % (n * price), true, ["sell", id]])
			if rows.is_empty():
				rows.append(["Rien à vendre", "Récolte du lin ou bats des monstres.", Color(0.6, 0.6, 0.6), "", false, []])
	return rows

func _cost_text(r: Dictionary) -> String:
	var parts := []
	for k in r.cost:
		parts.append("%d/%d %s" % [G.inventory.get(k, 0), r.cost[k], G.item_name(k)])
	if r.silver > 0: parts.append("%d argent" % r.silver)
	return ", ".join(parts)

func _panel_click(p: Vector2) -> void:
	for b in _panel_btns:
		if b[0].has_point(p):
			do_action(b[1])
			return

func do_action(a: Array) -> void:
	if a.is_empty(): return
	match a[0]:
		"close":
			panel = ""
			Sfx.play("ui", -8.0)
		"craft":
			if _craft_t <= 0.0 and G.can_craft(a[1]):
				_craft_r = a[1]
				_craft_t = a[1].time
				Sfx.play("gather", -4.0)
		"equip":
			G.equip(a[1])
			Sfx.play("pickup", -4.0)
		"sell":
			if G.sell_all(a[1]) > 0: Sfx.play("loot", -4.0)

func _process(delta: float) -> void:
	size = get_viewport_rect().size
	if panel != "":
		if nearest_station().is_empty(): panel = ""
		if _craft_t > 0.0:
			_craft_t -= delta
			if _craft_t <= 0.0:
				if G.craft(_craft_r):
					Sfx.play("loot", -2.0)
					G.burst(player.global_position + Vector3.UP * 1.5, "star_06", Color(1, 0.9, 0.5), 14, 3.0, 0.4, 0.6, -2.0)
	_fps = lerpf(_fps, 1.0 / maxf(G.real_dt, 0.001), 0.05)
	for i in _flash.size(): _flash[i] = move_toward(_flash[i], 0.0, delta * 3.0)
	_announce[1] = maxf(_announce[1] - delta, 0.0)
	_callout[1] = maxf(_callout[1] - G.real_dt, 0.0)
	for t in _toasts: t[2] -= delta
	_toasts = _toasts.filter(func(t): return t[2] > 0.0)
	_silver_shown = lerpf(_silver_shown, float(G.silver), minf(delta * 8.0, 1.0))
	queue_redraw()

# --- Outils de dessin ------------------------------------------------------------
func _sb(col: Color, radius := 8) -> StyleBoxFlat:
	if _sb_cache == null:
		_sb_cache = StyleBoxFlat.new()
		_sb_cache.border_color = Color(0.85, 0.75, 0.55, 0.35)
		_sb_cache.set_border_width_all(1)
	_sb_cache.set_corner_radius_all(radius)
	_sb_cache.bg_color = col
	return _sb_cache

func _panel(r: Rect2, col := Color(0.07, 0.06, 0.05, 0.78), radius := 8) -> void:
	draw_style_box(_sb(col, radius), r)

func _bar(r: Rect2, frac: float, col: Color, back := Color(0, 0, 0, 0.6)) -> void:
	draw_rect(r, back)
	var f := Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y))
	draw_rect(f, col)
	draw_rect(Rect2(f.position, Vector2(f.size.x, r.size.y * 0.42)), Color(1, 1, 1, 0.2))
	draw_rect(r, Color(0, 0, 0, 0.8), false, 1.0)

## Lunette métallique autour d'un bouton rond (dorée pour l'armure, argentée pour l'arme).
func _bezel(c: Vector2, r: float, glow := 0.0, gold := false) -> void:
	draw_circle(c, r + 6, Color(0, 0, 0, 0.55))
	var outer := Color(0.78, 0.66, 0.42) if gold else Color(0.62, 0.64, 0.68)
	draw_arc(c, r + 3, 0, TAU, 48, outer.darkened(0.35), 5.0, true)
	draw_arc(c, r + 3.5, PI * 1.05, PI * 1.95, 24, outer.lightened(0.25), 2.0, true)
	draw_arc(c, r, 0, TAU, 48, Color(0.05, 0.05, 0.06), 2.0, true)
	if glow > 0.0:
		draw_arc(c, r + 7, 0, TAU, 48, Color(1, 0.9, 0.6, glow * 0.8), 3.0, true)

## Disque à dégradé radial (relief) + texture d'effet teintée.
func _orb(c: Vector2, r: float, col: Color, texname: String, dim := false) -> void:
	var base := col.darkened(0.72) if not dim else Color(0.1, 0.1, 0.11)
	var top := col.darkened(0.15) if not dim else Color(0.2, 0.2, 0.22)
	for k in 6:
		var f := 1.0 - k / 6.0
		draw_circle(c + Vector2(0, -r * 0.12 * (1.0 - f)), r * f, base.lerp(top, 1.0 - f))
	var tex: Texture2D = G.tex(texname)
	draw_texture_rect(tex, Rect2(c - Vector2(r, r) * 0.95, Vector2(r, r) * 1.9), false, Color(col.lightened(0.35), 0.85) if not dim else Color(0.5, 0.5, 0.55, 0.4))
	draw_arc(c, r * 0.82, PI * 1.15, PI * 1.85, 16, Color(1, 1, 1, 0.22), r * 0.12, true)

func _txt(p: Vector2, s: String, sz: int, col: Color, w := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(font, p, s, align, w, sz, 4, Color(0, 0, 0, 0.85))
	draw_string(font, p, s, align, w, sz, col)

# --- Ralenti et exploits : bord d'écran doré + mot qui jaillit --------------------
func _draw_slowmo() -> void:
	var sl := G.slowmo_left()
	if sl > 0.0 or _callout[1] > 0.0:
		var a := clampf(sl / 0.15, 0.0, 1.0) * 0.4
		if a > 0.0:
			var c: Color = _callout[2]
			var o := Color(c.r, c.g, c.b, a)
			var i := Color(c.r, c.g, c.b, 0.0)
			var w := size.x
			var hh := size.y
			var m := 110.0
			var oo := PackedColorArray([o, o, i, i])
			var oi := PackedColorArray([o, i, i, o])
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - m, m), Vector2(m, m)]), oo)
			draw_polygon(PackedVector2Array([Vector2(0, hh), Vector2(m, hh - m), Vector2(w - m, hh - m), Vector2(w, hh)]), oi)
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(m, m), Vector2(m, hh - m), Vector2(0, hh)]), oi)
			draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, hh), Vector2(w - m, hh - m), Vector2(w - m, m)]), oo)
	if _callout[1] > 0.0:
		var t: float = 1.3 - _callout[1]
		var sc := 1.0 + 0.6 * maxf(0.0, 1.0 - t / 0.12) if t < 0.12 else 1.0
		var al := clampf(_callout[1] / 0.35, 0.0, 1.0)
		var col: Color = _callout[2]
		col.a = al
		var center := Vector2(size.x * 0.5, size.y * 0.66)
		draw_set_transform(center, 0.0, Vector2.ONE * sc)
		_txt(Vector2(-size.x * 0.5, 0), _callout[0], 38, col, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- Dessin ---------------------------------------------------------------------
func _draw() -> void:
	if cam == null: return
	_draw_enemy_bars()
	_draw_gather_bar()
	_draw_player_frame()
	_draw_target_frame()
	_draw_boss()
	_draw_minimap()
	_draw_loot()
	_draw_hub()
	_draw_joystick()
	_draw_slowmo()
	_draw_panel()
	if show_debug:
		_txt(Vector2(size.x - 70, size.y - 10), "%d i/s" % roundi(_fps), 12, Color(1, 1, 1, 0.45))

func _emblem(c: Vector2, r: float, col: Color, enemy := false) -> void:
	draw_circle(c, r + 4, Color(0, 0, 0, 0.6))
	draw_circle(c, r, col.darkened(0.6))
	draw_circle(c + Vector2(0, -r * 0.15), r * 0.78, col.darkened(0.3))
	if enemy:
		for k in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([c + Vector2(k * r * 0.35, -r * 0.1), c + Vector2(k * r * 0.15, -r * 0.1), c + Vector2(k * r * 0.25, r * 0.5)]), Color(1, 0.95, 0.85))
			draw_circle(c + Vector2(k * r * 0.3, -r * 0.35), r * 0.12, Color(1, 0.4, 0.2))
	else:
		_icon_sword(c, r * 0.55, Color(1, 0.95, 0.85))
	draw_arc(c, r + 2, 0, TAU, 40, Color(0.8, 0.68, 0.45), 3.0, true)

func _draw_player_frame() -> void:
	var c := Vector2(52, 50)
	_panel(Rect2(48, 22, 230, 58), Color(0.07, 0.06, 0.05, 0.78), 6)
	_emblem(c, 32, Color(0.75, 0.55, 0.35))
	_txt(Vector2(94, 40), "Aventurier", 15, Color(1, 0.94, 0.82))
	_bar(Rect2(94, 46, 172, 13), player.hp / player.max_hp, Color(0.86, 0.2, 0.2))
	if player.shield > 0.0:
		draw_rect(Rect2(94, 46, 172 * minf(player.shield / player.max_hp, 1.0), 4), Color(1, 0.85, 0.35))
	_txt(Vector2(94, 57), "%d / %d" % [player.hp, player.max_hp], 10, Color(1, 1, 1), 172, HORIZONTAL_ALIGNMENT_CENTER)
	_bar(Rect2(94, 62, 172, 10), player.energy / player.max_energy, Color(0.25, 0.55, 0.95))
	_txt(Vector2(94, 71), "%d / %d" % [player.energy, player.max_energy], 9, Color(0.85, 0.92, 1), 172, HORIZONTAL_ALIGNMENT_CENTER)
	# effets actifs sous le portrait
	var x := 92.0
	for i in [3, 4, 5]:
		var left: float = player.buff_left(i)
		if left <= 0.0: continue
		var st: Dictionary = SKILL_STYLE[player.skills[i]["id"]]
		var bc := Vector2(x, 100)
		_orb(bc, 13, st.col, st.tex)
		draw_arc(bc, 14, 0, TAU, 24, Color(0.8, 0.7, 0.5), 2.0, true)
		_txt(bc + Vector2(-14, 28), "%.0f" % ceil(left), 11, Color(1, 1, 1), 28, HORIZONTAL_ALIGNMENT_CENTER)
		x += 34

func _draw_target_frame() -> void:
	if _target == null or not is_instance_valid(_target) or _target.dead: return
	if _target.kind == "boss": return   # la grande barre du boss le remplace
	var c := Vector2(332, 50)
	_panel(Rect2(328, 22, 210, 46), Color(0.07, 0.06, 0.05, 0.78), 6)
	_emblem(c, 26, _target.data.color, true)
	_txt(Vector2(366, 40), _target.display_name, 14, Color(1, 0.8, 0.65))
	_bar(Rect2(366, 46, 160, 12), _target.hp / _target.max_hp, Color(0.86, 0.25, 0.18))
	_txt(Vector2(366, 56), "%d / %d" % [_target.hp, _target.max_hp], 10, Color(1, 1, 1), 160, HORIZONTAL_ALIGNMENT_CENTER)

## Mini-carte en losange, orientée comme la caméra (le nord en haut à droite).
func _map_pt(c: Vector2, w: float, h: float, p: Vector3) -> Vector2:
	var half: float = G.world.HALF
	var zmax: float = G.world.Z_MAX
	var u := p.x / half * 0.5
	var v := (p.z - (zmax - half) * 0.5) / ((zmax + half) * 0.5) * 0.5
	return c + Vector2((u - v) * w * 0.5, (u + v) * h * 0.5)

func _draw_minimap() -> void:
	var w := 200.0
	var h := 120.0
	var c := Vector2(size.x - 128, 122)
	var t := Time.get_time_dict_from_system()
	_panel(Rect2(c.x - 118, 10, 236, 34), Color(0.12, 0.1, 0.08, 0.88), 6)
	_txt(Vector2(c.x - 110, 32), "Bourg de Brumefeuille" if player.global_position.z > 40.0 else "Clairière de Brumefeuille", 13, Color(0.98, 0.92, 0.78))
	_txt(Vector2(c.x + 66, 32), "%02d:%02d" % [t.hour, t.minute], 13, Color(0.85, 0.85, 0.9), 44, HORIZONTAL_ALIGNMENT_RIGHT)
	var dia := PackedVector2Array([c + Vector2(0, -h * 0.5), c + Vector2(w * 0.5, 0), c + Vector2(0, h * 0.5), c + Vector2(-w * 0.5, 0)])
	var border := PackedVector2Array([dia[0] + Vector2(0, -5), dia[1] + Vector2(8, 0), dia[2] + Vector2(0, 5), dia[3] + Vector2(-8, 0)])
	draw_colored_polygon(border, Color(0.78, 0.66, 0.45))
	draw_colored_polygon(dia, Color(0.27, 0.42, 0.2))
	for s in G.world.PATHS:
		draw_line(_map_pt(c, w, h, Vector3(s[0], 0, s[1])), _map_pt(c, w, h, Vector3(s[2], 0, s[3])), Color(0.75, 0.62, 0.42), 3.0, true)
	for d in G.world.DECOR:
		if "Pine" in d[0] or "Tree" in d[0]:
			draw_circle(_map_pt(c, w, h, Vector3(d[1], 0, d[2])), 2.6, Color(0.15, 0.28, 0.12))
	for hs in G.world.Town.HOUSES:
		draw_circle(_map_pt(c, w, h, hs.pos), 4.5, Color(0.7, 0.35, 0.22))
	for st in G.stations:
		draw_circle(_map_pt(c, w, h, st.pos), 3.5, Color(1, 0.85, 0.35))
	for n in G.gather_nodes:
		if n.charges > 0: draw_circle(_map_pt(c, w, h, n.global_position), 3.0, Color(0.85, 0.95, 0.55))
	for e in G.enemies:
		if not e.dead: draw_circle(_map_pt(c, w, h, e.global_position), 5.5 if e.kind == "boss" else 3.2, Color(1.0, 0.45, 0.05) if e.kind == "boss" else Color(0.95, 0.25, 0.2))
	var pp := _map_pt(c, w, h, player.global_position)
	var dir := (_map_pt(c, w, h, player.global_position + player.forward()) - pp).normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([pp + dir * 8, pp - dir * 5 + side * 5, pp - dir * 5 - side * 5]), Color(1, 1, 1))
	draw_polyline(PackedVector2Array([dia[0], dia[1], dia[2], dia[3], dia[0]]), Color(0.3, 0.22, 0.12), 2.0, true)

func _draw_loot() -> void:
	var y := 198.0
	var r := Rect2(size.x - 186, y, 116, 30)
	_panel(r)
	draw_circle(r.position + Vector2(17, 15), 9, Color(0.82, 0.84, 0.9))
	draw_circle(r.position + Vector2(17, 15), 5, Color(0.6, 0.62, 0.68))
	_txt(r.position + Vector2(32, 21), "%d" % roundi(_silver_shown), 15, Color(0.92, 0.94, 1.0))
	y += 36
	for id in G.inventory:
		if not G.ITEMS.has(id): continue
		var it: Dictionary = G.ITEMS[id]
		var rr := Rect2(size.x - 216, y, 176, 26)
		_panel(rr, Color(0.07, 0.06, 0.05, 0.62))
		draw_circle(rr.position + Vector2(14, 13), 7, it.color)
		_txt(rr.position + Vector2(28, 18), "%s  x%d" % [it.name, G.inventory[id]], 12, Color(1, 1, 1, 0.92), 146)
		y += 30
	var ty := y + 12.0
	for t in _toasts:
		var a := clampf(t[2] / 0.4, 0.0, 1.0)
		var tr := Rect2(size.x - 286, ty, 246, 30)
		_panel(tr, Color(0.07, 0.06, 0.05, 0.8 * a))
		draw_rect(Rect2(tr.position, Vector2(5, tr.size.y)), Color(t[1], a))
		_txt(tr.position + Vector2(14, 21), t[0], 14, Color(t[1].lightened(0.4), a), 226)
		ty += 34

func _draw_enemy_bars() -> void:
	for e in G.enemies:
		if e.dead or e.hp >= e.max_hp and e.state_name() == "Garde": continue
		var top: Vector3 = e.global_position + Vector3.UP * (2.35 * e.data.scale)
		if cam.is_position_behind(top): continue
		var p := cam.unproject_position(top)
		var w := 70.0 if e.kind == "brute" else 54.0
		var r := Rect2(p - Vector2(w * 0.5, 0), Vector2(w, 7))
		draw_rect(r.grow(2), Color(0, 0, 0, 0.75))
		_bar(r, e.hp / e.max_hp, Color(0.92, 0.25, 0.18) if e == _target else Color(0.75, 0.28, 0.2), Color(0.15, 0.05, 0.05, 0.9))

func _draw_gather_bar() -> void:
	var g: float = player.gather_progress()
	if g < 0.0: return
	var p := cam.unproject_position(player.global_position + Vector3.UP * 2.4)
	var r := Rect2(p - Vector2(70, 0), Vector2(140, 12))
	draw_rect(r.grow(3), Color(0, 0, 0, 0.7))
	_bar(r, g, Color(0.75, 0.9, 0.45))
	_txt(p + Vector2(-70, -8), "Récolte du lin…", 13, Color(1, 1, 0.9), 140, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_hub() -> void:
	var lay := _btn_layout()
	var t := Time.get_ticks_msec() / 1000.0
	draw_circle(_hub_center(), 186, Color(0, 0, 0, 0.12))
	for i in 6:
		var c: Vector2 = lay["s%d" % i][0]
		var r: float = lay["s%d" % i][1]
		var st: Dictionary = SKILL_STYLE[player.skills[i]["id"]]
		var cdl: float = player.cd_left[i]
		var no_energy: bool = player.energy < player.skills[i]["cost"]
		var ready := cdl <= 0.0 and not no_energy
		_bezel(c, r, maxf(_flash[i + 1], 0.0), i >= 3)
		_orb(c, r, st.col, st.tex, not ready)
		_skill_glyph(player.skills[i]["id"], c, r * 0.5, Color(1, 1, 1, 0.95) if ready else Color(0.6, 0.6, 0.65, 0.8))
		if cdl > 0.0:
			var frac: float = cdl / _cd_total[i]
			draw_arc(c, r * 0.5, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, Color(0, 0, 0, 0.6), r, true)
			_txt(c + Vector2(-r, 8), "%.0f" % ceil(cdl), 21, Color(1, 1, 1), r * 2, HORIZONTAL_ALIGNMENT_CENTER)
		elif no_energy:
			draw_circle(c, r, Color(0.05, 0.1, 0.3, 0.45))
		if _flash[i + 1] < 0.0:
			draw_arc(c, r + 3, 0, TAU, 40, Color(1, 0.2, 0.2, -_flash[i + 1]), 4.0, true)
		if i >= 3:
			_slot_badge(i, c + Vector2(r * 0.72, r * 0.72))
		if ready and fmod(t + i * 0.37, 4.0) < 0.15:
			draw_arc(c, r + 1, 0, TAU, 40, Color(st.col.lightened(0.5), 0.6), 2.0, true)
	var ac: Vector2 = lay["attack"][0]
	var ar: float = lay["attack"][1]
	var down: bool = _pressed.get("attack", false)
	_bezel(ac, ar, _flash[0], true)
	for k in 7:
		var f := 1.0 - k / 7.0
		draw_circle(ac + Vector2(0, -ar * 0.1 * (1.0 - f)), ar * f, Color(0.16, 0.2, 0.3).lerp(Color(0.45, 0.55, 0.72) if not down else Color(0.6, 0.7, 0.9), 1.0 - f))
	draw_arc(ac, ar * 0.84, PI * 1.15, PI * 1.85, 20, Color(1, 1, 1, 0.25), ar * 0.1, true)
	_icon_sword(ac, ar * 0.58, Color(1, 0.96, 0.86))
	var stn := nearest_station()
	if not stn.is_empty() and panel == "":
		var gc: Vector2 = lay["gather"][0]
		var gr: float = lay["gather"][1] * (1.0 + sin(t * 5.0) * 0.04)
		_bezel(gc, gr, 0.3 + 0.3 * sin(t * 5.0), true)
		_orb(gc, gr, Color(0.95, 0.75, 0.35), "star_06")
		_icon_hammer(gc, gr * 0.5, Color(1, 0.97, 0.88))
		_txt(gc + Vector2(-60, gr + 24), stn.label, 14, Color(1, 0.92, 0.7), 120, HORIZONTAL_ALIGNMENT_CENTER)
	elif player.nearest_gather() != null and player.gather_progress() < 0.0:
		var gc: Vector2 = lay["gather"][0]
		var gr: float = lay["gather"][1] * (1.0 + sin(t * 5.0) * 0.04)
		_bezel(gc, gr, 0.3 + 0.3 * sin(t * 5.0), true)
		_orb(gc, gr, Color(0.55, 0.85, 0.3), "light_01")
		_icon_leaf(gc, gr * 0.5, Color(0.95, 1.0, 0.8))
		_txt(gc + Vector2(-60, gr + 24), "Récolter", 14, Color(0.92, 1, 0.8), 120, HORIZONTAL_ALIGNMENT_CENTER)

func _slot_badge(i: int, c: Vector2) -> void:
	draw_circle(c, 11, Color(0.08, 0.07, 0.06))
	draw_arc(c, 11, 0, TAU, 20, Color(0.8, 0.68, 0.45), 1.5, true)
	var col := Color(0.95, 0.88, 0.7)
	match i:
		3:
			draw_arc(c + Vector2(0, 2), 6, PI, TAU, 10, col, 3.0)
			draw_line(c + Vector2(-7, 2), c + Vector2(7, 2), col, 2.0)
		4:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -5), c + Vector2(6, -5), c + Vector2(4, 6), c + Vector2(-4, 6)]), col)
		5:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -6), c + Vector2(2, -6), c + Vector2(2, 2), c + Vector2(7, 3), c + Vector2(7, 6), c + Vector2(-3, 6)]), col)

func _draw_joystick() -> void:
	var active := _joy_id != -1
	var c := _joy_center if active else Vector2(150, size.y - 150)
	var a := 1.0 if active else 0.45
	draw_circle(c, JOY_R, Color(0, 0, 0, 0.22 * a))
	draw_arc(c, JOY_R, 0, TAU, 48, Color(0.85, 0.85, 0.9, 0.45 * a), 2.5, true)
	draw_arc(c, JOY_R * 0.62, 0, TAU, 40, Color(0.85, 0.85, 0.9, 0.2 * a), 1.5, true)
	for k in 4:
		var d := Vector2.from_angle(k * PI * 0.5)
		draw_colored_polygon(PackedVector2Array([c + d * (JOY_R - 4), c + d * (JOY_R - 14) + d.orthogonal() * 6, c + d * (JOY_R - 14) - d.orthogonal() * 6]), Color(0.9, 0.9, 0.95, 0.5 * a))
	var k := c + (_joy_pos - _joy_center).limit_length(JOY_R) if active else c
	draw_circle(k, 34, Color(0.25, 0.25, 0.3, 0.6 * a))
	draw_arc(k, 34, 0, TAU, 32, Color(0.9, 0.9, 0.95, 0.65 * a), 2.5, true)
	draw_circle(k, 14, Color(0.9, 0.9, 0.95, 0.35 * a))

# --- Icônes -------------------------------------------------------------------------
func _icon_sword(c: Vector2, s: float, col: Color) -> void:
	var tip := c + Vector2(0.72, -0.72) * s
	var base := c + Vector2(-0.38, 0.38) * s
	var n := Vector2(0.7, 0.7).normalized() * s * 0.13
	draw_colored_polygon(PackedVector2Array([tip, base + n, base - n]), col)
	draw_line(c + Vector2(-0.62, 0.14) * s, c + Vector2(-0.14, 0.62) * s, Color(0.85, 0.7, 0.4), s * 0.16)
	draw_line(base, c + Vector2(-0.78, 0.78) * s, Color(0.45, 0.3, 0.2), s * 0.16)
	draw_circle(c + Vector2(-0.82, 0.82) * s, s * 0.11, Color(0.85, 0.7, 0.4))

func _icon_leaf(c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var u := float(i) / 20.0
		pts.append(c + Vector2(sin(u * PI) * 0.55, lerpf(-1.0, 1.0, u)) * s)
	for i in range(20, -1, -1):
		var u := float(i) / 20.0
		pts.append(c + Vector2(-sin(u * PI) * 0.55, lerpf(-1.0, 1.0, u)) * s)
	draw_colored_polygon(pts, col)
	draw_line(c + Vector2(0, -0.9) * s, c + Vector2(0, 1.1) * s, col.darkened(0.5), 2.0)

func _skill_glyph(id: String, c: Vector2, s: float, col: Color) -> void:
	var i: int = ["entaille", "charge", "fracas", "garde", "fureur", "vent", "souffle", "embrase", "roulade"].find(id)
	var sh := Color(0, 0, 0, 0.5)
	for o in [Vector2(2, 2), Vector2.ZERO]:
		var cc: Color = sh if o != Vector2.ZERO else col
		var q: Vector2 = c + o
		match i:
			0: # Entaille : deux arcs de lame
				draw_arc(q + Vector2(-0.25, 0.25) * s, s, -PI * 0.92, -PI * 0.12, 18, cc, s * 0.22, true)
				draw_arc(q + Vector2(-0.05, 0.45) * s, s * 0.62, -PI * 0.85, -PI * 0.2, 14, cc, s * 0.14, true)
			1: # Charge : chevrons
				for k in 2:
					var off := q + Vector2(-0.5 + k * 0.6, 0) * s
					draw_polyline(PackedVector2Array([off + Vector2(-0.3, -0.62) * s, off + Vector2(0.28, 0) * s, off + Vector2(-0.3, 0.62) * s]), cc, s * 0.22, true)
			2: # Fracas : impact étoilé
				for k in 8:
					var a := TAU * k / 8.0 + PI / 8.0
					var d := Vector2(cos(a), sin(a))
					draw_line(q + d * s * 0.32, q + d * s * (1.0 if k % 2 == 0 else 0.7), cc, s * 0.15, true)
				draw_circle(q, s * 0.24, cc)
			3: # Garde : bouclier
				draw_colored_polygon(PackedVector2Array([q + Vector2(0, -0.9) * s, q + Vector2(0.72, -0.58) * s, q + Vector2(0.62, 0.25) * s, q + Vector2(0, 0.95) * s, q + Vector2(-0.62, 0.25) * s, q + Vector2(-0.72, -0.58) * s]), cc)
			4: # Fureur : flamme
				var pts := PackedVector2Array()
				for k in 25:
					var a := float(k) / 24.0 * TAU
					var rr := 0.55 + 0.22 * sin(a * 3.0)
					pts.append(q + Vector2(sin(a) * rr * 0.85, -cos(a) * rr * 1.1 + 0.15) * s)
				draw_colored_polygon(pts, cc)
			5: # Pas de vent : traits de vitesse
				for k in 3:
					var y := (k - 1) * 0.42 * s
					draw_line(q + Vector2((-0.8 + k * 0.15) * s, y), q + Vector2(0.75 * s, y), cc, s * 0.16, true)
			6: # Souffle clair : croix de soin
				draw_rect(Rect2(q + Vector2(-0.22, -0.8) * s, Vector2(0.44, 1.6) * s), cc)
				draw_rect(Rect2(q + Vector2(-0.8, -0.22) * s, Vector2(1.6, 0.44) * s), cc)
			7: # Embrasement : anneau de flammes
				draw_arc(q, s * 0.6, 0, TAU, 24, cc, s * 0.16, true)
				for k in 6:
					var a := TAU * k / 6.0
					var d := Vector2(cos(a), sin(a))
					draw_colored_polygon(PackedVector2Array([q + d * s * 0.62 + d.orthogonal() * s * 0.16, q + d * s * 1.0, q + d * s * 0.62 - d.orthogonal() * s * 0.16]), cc)
			8: # Roulade : flèche courbe
				draw_arc(q + Vector2(0, 0.1) * s, s * 0.62, PI * 0.9, PI * 2.1, 18, cc, s * 0.2, true)
				var tip := q + Vector2(0.62, 0.1) * s + Vector2(0, 0.0)
				draw_colored_polygon(PackedVector2Array([tip + Vector2(-0.3, -0.05) * s, tip + Vector2(0.3, -0.05) * s, tip + Vector2(0, 0.42) * s]), cc)
	if i == 3:
		draw_line(c + Vector2(0, -0.6) * s, c + Vector2(0, 0.62) * s, Color(0.3, 0.45, 0.7), s * 0.14)
		draw_line(c + Vector2(-0.45, -0.15) * s, c + Vector2(0.45, -0.15) * s, Color(0.3, 0.45, 0.7), s * 0.14)
	elif i == 4:
		draw_circle(c + Vector2(0, 0.3) * s, s * 0.22, Color(1, 0.85, 0.5))

func _icon_hammer(c: Vector2, s: float, col: Color) -> void:
	draw_line(c + Vector2(-0.6, 0.7) * s, c + Vector2(0.25, -0.2) * s, Color(0.55, 0.38, 0.22), s * 0.2)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-0.05, -0.75) * s, c + Vector2(0.8, 0.1) * s, c + Vector2(0.5, 0.4) * s, c + Vector2(-0.35, -0.45) * s]), col)

func _draw_panel() -> void:
	_panel_btns.clear()
	if panel == "": return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	var r := _panel_rect()
	_panel(r, Color(0.1, 0.085, 0.07, 0.96), 10)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 52)), Color(0.22, 0.16, 0.1, 0.95))
	_txt(r.position + Vector2(22, 35), _panel_title, 22, Color(1, 0.9, 0.7))
	# argent
	_txt(r.position + Vector2(r.size.x - 200, 34), "Argent : %d" % G.silver, 16, Color(0.9, 0.92, 1), 120, HORIZONTAL_ALIGNMENT_RIGHT)
	# fermer
	var xb := Rect2(r.position + Vector2(r.size.x - 52, 8), Vector2(40, 36))
	draw_rect(xb, Color(0.45, 0.15, 0.12))
	_txt(xb.position + Vector2(0, 27), "X", 20, Color(1, 1, 1), 40, HORIZONTAL_ALIGNMENT_CENTER)
	_panel_btns.append([xb, ["close"]])
	var y := r.position.y + 62
	for row in _panel_rows():
		var rr := Rect2(r.position.x + 16, y, r.size.x - 32, 66)
		draw_rect(rr, Color(1, 1, 1, 0.05))
		draw_circle(rr.position + Vector2(30, 33), 18, row[2].darkened(0.5))
		draw_circle(rr.position + Vector2(30, 31), 14, row[2])
		_txt(rr.position + Vector2(60, 22), row[0], 16, Color(1, 0.96, 0.88), 380)
		var lines: PackedStringArray = row[1].split("\n")
		for li in lines.size():
			_txt(rr.position + Vector2(60, 40 + li * 16), lines[li], 12, Color(0.82, 0.82, 0.84), 420)
		if row[3] != "":
			var bb := Rect2(rr.position + Vector2(rr.size.x - 150, 13), Vector2(138, 40))
			var en: bool = row[4]
			var busy: bool = _craft_t > 0.0 and row[5].size() > 1 and row[5][0] == "craft" and row[5][1] == _craft_r
			draw_rect(bb, Color(0.25, 0.45, 0.2) if en else Color(0.22, 0.22, 0.24))
			draw_rect(bb, Color(0.85, 0.72, 0.45, 0.6 if en else 0.2), false, 2.0)
			if busy:
				var f: float = 1.0 - _craft_t / _craft_r.time
				draw_rect(Rect2(bb.position, Vector2(bb.size.x * f, bb.size.y)), Color(0.55, 0.8, 0.35, 0.8))
			_txt(bb.position + Vector2(0, 25), row[3], 15, Color(1, 1, 1) if en else Color(0.6, 0.6, 0.62), bb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			if en: _panel_btns.append([bb, row[5]])
		y += 72

## Grande barre du boss (en haut au centre) + annonces de phase.
func _draw_boss() -> void:
	for e in G.enemies:
		if e.kind != "boss" or e.dead: continue
		var st: String = e.state_name()
		if st == "Garde" or st == "Retour": continue
		if e.global_position.distance_to(player.global_position) > 26.0: continue
		var w := 520.0
		var r := Rect2((size.x - w) * 0.5, 96, w, 22)
		_panel(Rect2(r.position - Vector2(10, 30), Vector2(w + 20, 60)), Color(0.08, 0.05, 0.04, 0.82), 6)
		_txt(Vector2(r.position.x, r.position.y - 8), e.display_name, 17, Color(1, 0.7, 0.45))
		_txt(Vector2(r.position.x, r.position.y - 8), "Phase %d" % e.phase, 13, Color(1, 0.85, 0.7), w, HORIZONTAL_ALIGNMENT_RIGHT)
		_bar(r, e.hp / e.max_hp, Color(0.9, 0.3, 0.08) if e.phase < 3 else Color(1.0, 0.15, 0.05))
		for mark in [0.6, 0.25]:
			draw_line(Vector2(r.position.x + w * mark, r.position.y - 2), Vector2(r.position.x + w * mark, r.end.y + 2), Color(1, 0.9, 0.6, 0.9), 2.0)
		_txt(r.position + Vector2(0, 17), "%d / %d" % [e.hp, e.max_hp], 13, Color(1, 1, 1), w, HORIZONTAL_ALIGNMENT_CENTER)
		break
	if _announce[1] > 0.0:
		var a := clampf(_announce[1] / 0.5, 0.0, 1.0)
		_txt(Vector2(0, size.y * 0.32), _announce[0], 30, Color(1, 0.8, 0.5, a), size.x, HORIZONTAL_ALIGNMENT_CENTER)
