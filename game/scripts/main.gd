extends Control
# Écran principal : barre du haut, zone de combat, page de contenu, barre de navigation.

const W := 720.0
const BATTLE_H := 560.0
const HERO_POS := Vector2(215, 470)
const MON_POS := Vector2(520, 470)

var pages: Pages
var top_name: Label
var top_lvl: Label
var top_xp: ProgressBar
var top_power: Label
var res_labels = {}
var battle: Control
var sky: TextureRect
var hills_far: Polygon2D
var hills_near: Polygon2D
var ground: ColorRect
var deco: Node2D
var hero: Node2D
var monster: Node2D
var pet_nodes: Array = []
var stage_lbl: Label
var kills_lbl: Label
var mon_name: Label
var mon_hp: ProgressBar
var mon_hp_lbl: Label
var timer_bar: ProgressBar
var timer_lbl: Label
var boss_btn: Button
var auto_btn: Button
var prev_btn: Button
var next_btn: Button
var leave_btn: Button
var skill_btns = {}
var fx_layer: Node2D
var dmg_pool: Array = []
var dmg_i = 0
var content: PanelContainer
var content_box: VBoxContainer
var scroll: ScrollContainer
var nav_btns = {}
var cur_page = "train"
var overlay: Control
var toasts: VBoxContainer
var refresh_acc = 0.0
var need_refresh = false
var hero_atk_cool = 0.0
var cur_theme = -1
var shake = 0.0
var slash: Line2D
var finger_down = false

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
		finger_down = ev.pressed

func setup_hero() -> void:
	if G.s.cls != "":
		hero.setup(D.CLASSES[G.s.cls].sprite, true, 1.0)
	else:
		hero.visible = false

func _ready() -> void:
	theme = UI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_top())
	root.add_child(_build_battle())
	content = UI.panel(UI.PANEL, 0, 10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	content_box = UI.vb(10)
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_box)
	root.add_child(content)
	root.add_child(_build_nav())
	toasts = UI.vb(6)
	toasts.position = Vector2(20, 292)
	toasts.size = Vector2(W - 40, 10)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	pages = Pages.new(self)
	G.hit.connect(_on_hit)
	G.monster_spawned.connect(_on_spawn)
	G.monster_died.connect(_on_died)
	G.toast.connect(func(t, c): show_toast(t, c))
	G.loot.connect(func(t, c): show_toast(t, c, 2.2); Sfx.play("loot"))
	G.level_up.connect(func(l): show_toast("NIVEAU %d ! +3 points de caractéristiques" % l, UI.ACCENT); Sfx.play("level"))
	G.boss_failed.connect(func(): Sfx.play("lose"))
	G.run_ended.connect(_on_run_ended)
	G.changed.connect(func(): need_refresh = true)
	setup_hero()
	show_page("train")
	_apply_theme(true)
	_on_spawn()
	if G.s.name == "" or G.s.cls == "":
		pages.popup_create_hero()
	elif not G.offline_report.is_empty():
		var r: Dictionary = G.offline_report
		popup("Bon retour !", "Pendant ton absence (%s), ton héros a continué de combattre :\n\n+%s or\n+%s XP\n+%s minerai" % [G.fmt_time(r.time), G.fmt(r.gold), G.fmt(r.xp), G.fmt(r.ore)])
		G.offline_report = {}
	Net.sync()
	if OS.get_environment("ABY_TEST") != "":
		var td = load("res://scripts/test_driver.gd").new()
		add_child(td)

# ------------------------------------------------------------------ barre du haut
func _res_chip(key: String, col: Color, label: String) -> Control:
	var h = UI.hb(5)
	var dot = Panel.new()
	dot.custom_minimum_size = Vector2(18, 18)
	dot.add_theme_stylebox_override("panel", UI.sb(col, 9, 2, col.darkened(0.4), 0))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(dot)
	var l = UI.lbl("0", 21, col.lightened(0.35))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.tooltip_text = label
	h.add_child(l)
	res_labels[key] = l
	return h

func _build_top() -> Control:
	var p = UI.panel(Color("1b1726"), 0, 10)
	var v = UI.vb(6)
	p.add_child(v)
	var r1 = UI.hb(10)
	top_name = UI.lbl("", 26, UI.TXT)
	top_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	r1.add_child(top_name)
	top_lvl = UI.lbl("", 24, UI.ACCENT)
	top_lvl.autowrap_mode = TextServer.AUTOWRAP_OFF
	r1.add_child(top_lvl)
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(sp)
	top_power = UI.lbl("", 22, Color("ff9f6b"))
	top_power.autowrap_mode = TextServer.AUTOWRAP_OFF
	r1.add_child(top_power)
	v.add_child(r1)
	top_xp = UI.bar(Color("8f6bff"), 12)
	v.add_child(top_xp)
	var r2 = HFlowContainer.new()
	r2.add_theme_constant_override("h_separation", 16)
	r2.add_child(_res_chip("gold", Color("ffcc4d"), "Or"))
	r2.add_child(_res_chip("gems", Color("4fe3ff"), "Gemmes"))
	r2.add_child(_res_chip("ore", Color("c28a5a"), "Minerai"))
	r2.add_child(_res_chip("souls", Color("c8a2ff"), "Âmes"))
	r2.add_child(_res_chip("keys", Color("8fe38f"), "Clés"))
	v.add_child(r2)
	return p

# ------------------------------------------------------------------ combat
func _build_battle() -> Control:
	battle = Control.new()
	battle.custom_minimum_size = Vector2(W, BATTLE_H)
	battle.clip_contents = true
	battle.mouse_filter = Control.MOUSE_FILTER_STOP
	battle.gui_input.connect(_on_battle_input)
	sky = TextureRect.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.add_child(sky)
	var world = Node2D.new()
	battle.add_child(world)
	deco = Node2D.new()
	world.add_child(deco)
	hills_far = Polygon2D.new()
	world.add_child(hills_far)
	hills_near = Polygon2D.new()
	world.add_child(hills_near)
	ground = ColorRect.new()
	ground.position = Vector2(0, 440)
	ground.size = Vector2(W + 400, 200)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(ground)
	for i in 3:
		var pn = preload("res://scripts/actor.gd").new()
		world.add_child(pn)
		pn.position = Vector2(48 + i * 44, 462 + (i % 2) * 10)
		pn.visible = false
		pet_nodes.append(pn)
	hero = preload("res://scripts/actor.gd").new()
	world.add_child(hero)
	hero.position = HERO_POS
	monster = preload("res://scripts/actor.gd").new()
	world.add_child(monster)
	monster.position = MON_POS
	slash = Line2D.new()
	slash.width = 10
	slash.default_color = Color(1, 1, 1, 0.0)
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	world.add_child(slash)
	fx_layer = Node2D.new()
	world.add_child(fx_layer)
	for i in 28:
		var l = UI.lbl("", 30, Color.WHITE, true)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.visible = false
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(240, 40)
		fx_layer.add_child(l)
		dmg_pool.append(l)
	# Informations (haut)
	var info = UI.vb(4)
	info.position = Vector2(16, 10)
	info.size = Vector2(W - 32, 10)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.add_child(info)
	var row = UI.hb(8)
	prev_btn = UI.btn("◀", func(): _step_stage(-1), Color(0, 0, 0, 0.35), 24, 60)
	prev_btn.custom_minimum_size = Vector2(60, 52)
	row.add_child(prev_btn)
	var mid = UI.vb(0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_lbl = UI.lbl("", 23, Color.WHITE, true)
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(stage_lbl)
	kills_lbl = UI.lbl("", 19, Color(1, 1, 1, 0.85), true)
	kills_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(kills_lbl)
	row.add_child(mid)
	next_btn = UI.btn("▶", func(): _step_stage(1), Color(0, 0, 0, 0.35), 24, 60)
	next_btn.custom_minimum_size = Vector2(60, 52)
	row.add_child(next_btn)
	info.add_child(row)
	mon_name = UI.lbl("", 22, Color.WHITE, true)
	mon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(mon_name)
	var hpbox = Control.new()
	hpbox.custom_minimum_size = Vector2(0, 26)
	mon_hp = UI.bar(Color("e8434f"), 26)
	mon_hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hpbox.add_child(mon_hp)
	mon_hp_lbl = UI.lbl("", 18, Color.WHITE, true)
	mon_hp_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mon_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mon_hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hpbox.add_child(mon_hp_lbl)
	info.add_child(hpbox)
	var tb = Control.new()
	tb.custom_minimum_size = Vector2(0, 20)
	timer_bar = UI.bar(Color("ffb03a"), 20)
	timer_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tb.add_child(timer_bar)
	timer_lbl = UI.lbl("", 16, Color.WHITE, true)
	timer_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tb.add_child(timer_lbl)
	info.add_child(tb)
	var row2 = UI.hb(8)
	auto_btn = UI.btn("", func():
		G.s.auto = not G.s.auto
		_update_battle_ui(), Color(0, 0, 0, 0.4), 19, 0)
	auto_btn.custom_minimum_size = Vector2(0, 48)
	row2.add_child(auto_btn)
	boss_btn = UI.btn("⚔ Défier le boss", func(): G.challenge_boss(), Color("b8323f"), 20, 0)
	boss_btn.custom_minimum_size = Vector2(0, 48)
	row2.add_child(boss_btn)
	leave_btn = UI.btn("Abandonner", func(): G.abandon_run(), Color("6b2a35"), 19, 0)
	leave_btn.custom_minimum_size = Vector2(0, 48)
	row2.add_child(leave_btn)
	info.add_child(row2)
	# Compétences (bas)
	var sk = UI.hb(8)
	sk.position = Vector2(12, BATTLE_H - 84)
	sk.size = Vector2(W - 24, 76)
	battle.add_child(sk)
	for d in D.SKILLS:
		var b = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 74)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_stylebox_override("normal", UI.sb(Color(0.08, 0.06, 0.14, 0.82), 14, 2, Color(1, 0.8, 0.3, 0.5), 6))
		b.add_theme_stylebox_override("pressed", UI.sb(Color(0.3, 0.2, 0.5, 0.9), 14, 2, Color(1, 0.8, 0.3, 0.8), 6))
		b.add_theme_stylebox_override("hover", UI.sb(Color(0.12, 0.09, 0.2, 0.85), 14, 2, Color(1, 0.8, 0.3, 0.6), 6))
		b.add_theme_stylebox_override("disabled", UI.sb(Color(0.05, 0.05, 0.08, 0.7), 14, 2, Color(1, 1, 1, 0.1), 6))
		var id: String = d.id
		b.pressed.connect(func(): _use_skill(id))
		sk.add_child(b)
		skill_btns[id] = b
	return battle

func _hill_poly(y: float, amp: float, seed_v: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	pts.append(Vector2(-20, BATTLE_H))
	var r = RandomNumberGenerator.new()
	r.seed = seed_v
	var ph = r.randf() * 10.0
	for i in 25:
		var x = -20.0 + i * 32.0
		pts.append(Vector2(x, y - amp * (0.5 + 0.5 * sin(x * 0.012 + ph)) - amp * 0.35 * sin(x * 0.031 + ph * 2.0)))
	pts.append(Vector2(W + 20, BATTLE_H))
	return pts

func _apply_theme(force := false) -> void:
	var m: int = G.s.map
	var key = m
	if G.mode == "dungeon": key = 1000 + D.DUNGEONS.find(G.run.d)
	elif G.mode == "abyss": key = 2000
	if key == cur_theme and not force: return
	cur_theme = key
	var info = G.map_info(m)
	if G.mode == "dungeon": info = D.MAPS[[2, 3, 7, 8, 4, 9][D.DUNGEONS.find(G.run.d)]].duplicate()
	elif G.mode == "abyss": info = D.MAPS[9].duplicate()
	var g = Gradient.new()
	var c0: Color = info.sky[0]
	var c1: Color = info.sky[1]
	if G.mode != "farm":
		c0 = c0.darkened(0.35)
		c1 = c1.darkened(0.3)
	g.colors = PackedColorArray([c0, c1])
	var gt = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	sky.texture = gt
	hills_far.polygon = _hill_poly(370, 90, m * 7)
	hills_far.color = Color(info.hill).lerp(c1, 0.45)
	hills_near.polygon = _hill_poly(430, 60, m * 13 + 3)
	hills_near.color = info.hill
	ground.color = info.ground
	for ch in deco.get_children(): ch.queue_free()
	# Astre (soleil / lune)
	var sun = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in 24:
		pts.append(Vector2(cos(TAU * i / 24.0), sin(TAU * i / 24.0)) * 34)
	sun.polygon = pts
	sun.position = Vector2(600, 210)
	sun.color = Color(1, 0.95, 0.75, 0.55) if c1.v > 0.5 else Color(0.85, 0.85, 1.0, 0.4)
	deco.add_child(sun)
	# Herbe / pierres au sol
	var r = RandomNumberGenerator.new()
	r.seed = m * 31
	for i in 16:
		var tuft = Polygon2D.new()
		var x = r.randf() * W
		var y = 452 + r.randf() * 95
		var s = r.randf_range(6, 14)
		tuft.polygon = PackedVector2Array([Vector2(-s, 0), Vector2(0, -s * 1.6), Vector2(s, 0)])
		tuft.position = Vector2(x, y)
		tuft.color = Color(info.ground).darkened(r.randf_range(0.12, 0.3))
		deco.add_child(tuft)
	deco.move_to_front()
	hills_far.get_parent().move_child(deco, 0)
	_update_pets()

func _update_pets() -> void:
	for i in 3:
		var pn = pet_nodes[i]
		if i < G.s.pet_eq.size():
			var p = G.pet_by_uid(G.s.pet_eq[i])
			if p:
				var pd: Dictionary = D.PETS[p.sp]
				pn.setup(pd.sprite, false, 0.36, pd.tint)
				pn.spr.flip_h = true
				continue
		pn.visible = false

func _on_battle_input(ev: InputEvent) -> void:
	var pressed = false
	if ev is InputEventScreenTouch and ev.pressed: pressed = true
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available(): pressed = true
	if not pressed: return
	if ev.position.y > BATTLE_H - 90 or ev.position.y < 230: return
	G.tap()
	_do_slash()

func _do_slash() -> void:
	var a = MON_POS + Vector2(randf_range(-70, -20), randf_range(-190, -120))
	var b = MON_POS + Vector2(randf_range(20, 70), randf_range(-60, -20))
	slash.points = PackedVector2Array([a, a.lerp(b, 0.5) + Vector2(0, -12), b])
	slash.default_color = Color(1, 1, 1, 0.9)
	var tw = create_tween()
	tw.tween_property(slash, "default_color", Color(1, 0.9, 0.5, 0.0), 0.18)
	if hero_atk_cool <= 0.0:
		hero.attack()
		hero_atk_cool = 0.25

func _use_skill(id: String) -> void:
	if G.use_skill(id):
		hero.skill()
		Sfx.play("boss" if id == "frappe" else "ok")
		if id == "frappe":
			shake = 0.35
			_flash_screen(Color(1, 0.9, 0.5, 0.45))
	else:
		Sfx.play("error")

func _flash_screen(c: Color) -> void:
	var r = ColorRect.new()
	r.color = c
	r.size = Vector2(W, BATTLE_H)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.add_child(r)
	var tw = create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.35)
	tw.tween_callback(r.queue_free)

func _on_hit(amount: float, crit: bool, is_tap: bool) -> void:
	monster.hurt()
	if not is_tap and hero_atk_cool <= 0.0:
		hero.attack()
		hero_atk_cool = 0.32
	var l: Label = dmg_pool[dmg_i]
	dmg_i = (dmg_i + 1) % dmg_pool.size()
	l.text = G.fmt(amount) + ("!" if crit else "")
	var col = Color("ffe14d") if crit else (Color("ffffff") if is_tap else Color("ffb0a0"))
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 40 if crit else (30 if is_tap else 26))
	l.visible = true
	l.modulate.a = 1.0
	l.position = MON_POS + Vector2(randf_range(-110, -10), randf_range(-240, -190))
	l.scale = Vector2.ONE * (1.3 if crit else 1.0)
	var tw = l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.4)
	if crit:
		shake = max(shake, 0.12)
		Sfx.play("crit", -6.0)
	else:
		Sfx.play("tap" if is_tap else "hit", -10.0)

var death_tw: Tween
func _on_died(gold: float, golden: bool) -> void:
	monster.die()
	if death_tw: death_tw.kill()
	var tw = monster.create_tween()
	death_tw = tw
	tw.tween_interval(0.25)
	tw.tween_property(monster, "modulate:a", 0.0, 0.12)
	if gold > 0:
		var l: Label = dmg_pool[dmg_i]
		dmg_i = (dmg_i + 1) % dmg_pool.size()
		l.text = "+" + G.fmt(gold) + " or"
		l.add_theme_color_override("font_color", Color("ffd34d"))
		l.add_theme_font_size_override("font_size", 34 if golden else 24)
		l.visible = true
		l.modulate.a = 1.0
		l.scale = Vector2.ONE
		l.position = MON_POS + Vector2(-120, -60)
		var t2 = l.create_tween()
		t2.set_parallel(true)
		t2.tween_property(l, "position:y", l.position.y - 50, 0.8)
		t2.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.5)
		Sfx.play("coin", -8.0)
	if G.mode == "farm" and G.s.kills == 0 and G.s.stage == 1: _apply_theme()

func _on_spawn() -> void:
	_apply_theme()
	if G.mon.is_empty(): return
	if death_tw:
		death_tw.kill()
		death_tw = null
	var md: Dictionary = D.MONSTERS[G.mon.id]
	var info = G.map_info(G.s.map)
	var col: Color = info.tint
	if G.mon.golden: col = Color(1.6, 1.3, 0.4)
	elif G.mon.elite: col = Color(1.3, 0.8, 1.4)
	var sc: float = md.scale * (1.3 if G.mon.boss else 1.0)
	monster.setup(md.sprite, false, sc, col)
	monster.modulate.a = 1.0
	monster.position = MON_POS + Vector2(140, 0)
	var tw = monster.create_tween()
	tw.tween_property(monster, "position", MON_POS, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if G.mon.boss:
		Sfx.play("boss")
		show_toast("BOSS : " + md.name + " !", Color("ff6b6b"), 1.6)
	hero.idle()

func _on_run_ended(win: bool, text: String) -> void:
	Sfx.play("win" if win else "lose")
	hero.cheer() if win else hero.idle()
	popup("Victoire !" if win else "Fin de l'expédition", text)
	cur_theme = -1
	_apply_theme()
	need_refresh = true

func _step_stage(d: int) -> void:
	if G.mode != "farm": return
	var g = G.gi() + d
	if g < 1 or g > G.s.max_gi: return
	G.set_stage(int((g - 1) / 10) + 1, (g - 1) % 10 + 1)
	if d > 0: G.s.auto = true
	_apply_theme()

# ------------------------------------------------------------------ boucle d'affichage
func _process(delta: float) -> void:
	hero_atk_cool -= delta
	if shake > 0.0:
		shake = max(0.0, shake - delta)
		battle.position.x = randf_range(-6, 6) * shake * 8
	else:
		battle.position.x = 0
	_update_top()
	_update_battle_ui()
	refresh_acc += delta
	if refresh_acc > 0.5:
		refresh_acc = 0.0
		if need_refresh and not finger_down:
			need_refresh = false
			pages.refresh()
		elif pages.live.has(cur_page):
			pages.update()

func _update_top() -> void:
	top_name.text = G.s.name
	top_lvl.text = "Niv %d" % G.s.level
	top_xp.value = clampf(G.s.xp / G.xp_need(), 0, 1)
	top_power.text = "Puissance %s" % G.fmt(G.power())
	res_labels.gold.text = G.fmt(G.s.gold)
	res_labels.gems.text = G.fmt(G.s.gems)
	res_labels.ore.text = G.fmt(G.s.ore)
	res_labels.souls.text = G.fmt(G.s.souls)
	res_labels.keys.text = "%d/%d" % [int(G.s.keys), G.keys_max()]

func _update_battle_ui() -> void:
	var m = G.mon
	var farm = G.mode == "farm"
	if farm:
		var info = G.map_info(G.s.map)
		stage_lbl.text = "Carte %d · %s" % [G.s.map, info.display]
		if m.get("boss", false): kills_lbl.text = "Étape %d/10 — BOSS" % G.s.stage
		else: kills_lbl.text = "Étape %d/10 · %d/%d monstres" % [G.s.stage, min(G.s.kills, 10), G.KILLS_PER_STAGE]
	elif G.mode == "dungeon":
		stage_lbl.text = "%s · difficulté %d" % [G.run.d.name, G.run.diff]
		kills_lbl.text = "Salle %d/%d" % [G.run.room, G.run.d.rooms]
	else:
		stage_lbl.text = "L'Abysse"
		kills_lbl.text = "Étage %d · record %d" % [G.run.floor, G.s.abyss_best]
	prev_btn.visible = farm
	next_btn.visible = farm
	prev_btn.disabled = G.gi() <= 1
	next_btn.disabled = G.gi() >= G.s.max_gi
	if m.is_empty():
		mon_hp.value = 0
		mon_hp_lbl.text = ""
	else:
		var md: Dictionary = D.MONSTERS[m.id]
		var tag = ""
		if m.boss: tag = "BOSS · "
		elif m.golden: tag = "DORÉ · "
		elif m.elite: tag = "ÉLITE · "
		mon_name.text = tag + md.name
		mon_name.add_theme_color_override("font_color", Color("ff7a7a") if m.boss else (Color("ffd34d") if m.golden else (Color("e2a2ff") if m.elite else Color.WHITE)))
		mon_hp.value = clampf(m.hp / m.max, 0, 1)
		mon_hp_lbl.text = "%s / %s" % [G.fmt(max(0.0, m.hp)), G.fmt(m.max)]
	var timed: bool = not m.is_empty() and m.tmax > 0.0
	timer_bar.get_parent().visible = timed
	if timed:
		timer_bar.value = clampf(m.timer / m.tmax, 0, 1)
		timer_lbl.text = "%.1f s" % max(0.0, m.timer)
	auto_btn.visible = farm
	auto_btn.text = "Avance auto : OUI" if G.s.auto else "Avance auto : NON"
	boss_btn.visible = farm and not G.s.auto and G.s.stage >= 9 and G.s.map * 10 >= G.s.max_gi
	leave_btn.visible = not farm
	for d in D.SKILLS:
		var b: Button = skill_btns[d.id]
		var cd: float = G.skills_cd[d.id]
		var on: float = G.skills_on.get(d.id, 0.0)
		if G.s.level < d.lvl:
			b.text = "%s\nNiv %d" % [d.name, d.lvl]
			b.disabled = true
		elif on > 0.0:
			b.text = "%s\nACTIF %ds" % [d.name, ceil(on)]
			b.disabled = true
		elif cd > 0.0:
			b.text = "%s\n%ds" % [d.name, ceil(cd)]
			b.disabled = true
		else:
			b.text = "%s\nPRÊT" % d.name
			b.disabled = false

# ------------------------------------------------------------------ navigation
func _build_nav() -> Control:
	var p = UI.panel(Color("1b1726"), 0, 6)
	var h = UI.hb(4)
	p.add_child(h)
	var items = [["train", "Entraîner", "power"], ["hero", "Héros", "singleplayer"], ["equip", "Équip.", "wrench"], ["pets", "Familiers", "star"], ["dj", "Donjons", "locked"], ["arena", "Arène", "multiplayer"], ["menu", "Plus", "menuGrid"]]
	for it in items:
		var b = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.icon = UI.tex("res://assets/icons/%s.png" % it[2])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = it[1]
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_constant_override("icon_max_width", 40)
		var id: String = it[0]
		b.pressed.connect(func():
			Sfx.play("click")
			show_page(id))
		h.add_child(b)
		nav_btns[id] = b
	return p

func show_page(id: String) -> void:
	cur_page = id
	for k in nav_btns.keys():
		var b: Button = nav_btns[k]
		var sel: bool = k == id or (k == "menu" and not nav_btns.has(id))
		b.add_theme_stylebox_override("normal", UI.sb(Color("5a4d88") if sel else Color("2a2440"), 12, 2, UI.ACCENT if sel else Color(1, 1, 1, 0.08), 4))
	scroll.scroll_vertical = 0
	pages.refresh()

# ------------------------------------------------------------------ popups & toasts
func show_toast(text: String, col := Color.WHITE, dur := 2.6) -> void:
	if toasts.get_child_count() > 4: toasts.get_child(0).queue_free()
	var p = UI.panel(Color(0.05, 0.04, 0.1, 0.88), 12, 10, 2, col.darkened(0.2))
	var l = UI.lbl(text, 21, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(p)
	p.modulate.a = 0.0
	var tw = p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(dur)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	if text.begins_with("DÉCOUVERTE"): Sfx.play("secret")

func clear_overlay() -> void:
	for ch in overlay.get_children():
		overlay.remove_child(ch)
		ch.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Fenêtre modale : renvoie la boîte de contenu pour y ajouter des éléments.
func modal(title_text: String, closable := true) -> VBoxContainer:
	clear_overlay()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var cc = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var p = UI.panel(Color("2a2440"), 20, 22, 3, Color("6b5ba3"))
	p.custom_minimum_size = Vector2(W - 50, 0)
	cc.add_child(p)
	var v = UI.vb(14)
	p.add_child(v)
	var h = UI.hb()
	var t = UI.title(title_text)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if closable:
		h.add_child(UI.btn("✕", clear_overlay, Color("6b2a35"), 24, 64))
	v.add_child(h)
	return v

func popup(title_text: String, text: String) -> void:
	var v = modal(title_text)
	v.add_child(UI.lbl(text, 24, UI.TXT))
	v.add_child(UI.btn("OK", clear_overlay, Color("3d7a3d")))
