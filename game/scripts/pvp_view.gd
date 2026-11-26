extends Control
# Rejoue un duel d'arène simulé, avec les deux héros animés.

var a: Dictionary
var b: Dictionary
var sim: Dictionary
var done_cb: Callable
var t = 0.0
var idx = 0
var speed = 1.0
var finished = false
var actors = []
var bars = []
var hp_lbls = []
var fx: Node2D
var log_lbl: Label

func start(pa: Dictionary, pb: Dictionary, s: Dictionary, cb: Callable) -> void:
	a = pa
	b = pb
	sim = s
	done_cb = cb
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg = ColorRect.new()
	bg.color = Color("120e1c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var sky = TextureRect.new()
	var g = Gradient.new()
	g.colors = PackedColorArray([Color("2a1836"), Color("8c3b3b")])
	var gt = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	sky.texture = gt
	sky.position = Vector2(0, 220)
	sky.size = Vector2(720, 520)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(sky)
	var floor_r = ColorRect.new()
	floor_r.color = Color("4a3530")
	floor_r.position = Vector2(0, 640)
	floor_r.size = Vector2(720, 100)
	add_child(floor_r)
	var title = UI.lbl("ARÈNE", 44, UI.ACCENT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60)
	title.size = Vector2(720, 60)
	add_child(title)
	var world = Node2D.new()
	add_child(world)
	for i in 2:
		var p: Dictionary = a if i == 0 else b
		var act = preload("res://scripts/actor.gd").new()
		world.add_child(act)
		act.setup(D.CLASSES.get(p.cls, D.CLASSES.chevalier).sprite, true, 1.15)
		act.position = Vector2(200 if i == 0 else 520, 670)
		if i == 1: act.spr.flip_h = true
		actors.append(act)
		var box = UI.vb(4)
		box.position = Vector2(20 if i == 0 else 380, 140)
		box.size = Vector2(320, 10)
		var nm = UI.lbl("%s\nniv %d" % [p.name, p.level], 22, Color("8fd0ff") if i == 0 else Color("ff9a9a"), true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(nm)
		var bar = UI.bar(Color("4fd06a") if i == 0 else Color("e8434f"), 24)
		bar.value = 1.0
		box.add_child(bar)
		var hl = UI.lbl(G.fmt(p.hp), 18, Color.WHITE, true)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hl)
		add_child(box)
		bars.append(bar)
		hp_lbls.append(hl)
	fx = Node2D.new()
	add_child(fx)
	log_lbl = UI.lbl("", 22, UI.TXT, true)
	log_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_lbl.position = Vector2(20, 770)
	log_lbl.size = Vector2(680, 80)
	add_child(log_lbl)
	var h = UI.hb()
	h.position = Vector2(60, 900)
	h.size = Vector2(600, 70)
	h.add_child(UI.expand(UI.btn("Vitesse ×3", func(): speed = 3.0, Color("3a3355"))))
	h.add_child(UI.expand(UI.btn("Passer", func(): speed = 1000.0, Color("6b2a35"))))
	add_child(h)

func _pop(txt: String, pos: Vector2, col: Color, big := false) -> void:
	var l = UI.lbl(txt, 40 if big else 30, col, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.position = pos
	fx.add_child(l)
	var tw = l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 70, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)

func _process(delta: float) -> void:
	if finished: return
	t += delta * speed
	var ev: Array = sim.events
	var steps = 0
	while idx < ev.size() and ev[idx].t <= t:
		var e: Dictionary = ev[idx]
		idx += 1
		steps += 1
		var att = actors[e.who]
		var def = actors[1 - e.who]
		if speed < 100.0:
			att.attack()
			if e.dodge:
				_pop("Esquive !", def.position + Vector2(-60, -230), Color("9ad0ff"))
			else:
				def.hurt()
				_pop(G.fmt(e.dmg) + ("!" if e.crit else ""), def.position + Vector2(-60, -240), Color("ffe14d") if e.crit else Color.WHITE, e.crit)
				if steps < 3: Sfx.play("crit" if e.crit else "hit", -8.0)
		for i in 2:
			var mx: float = a.hp if i == 0 else b.hp
			bars[i].value = e.hp[i] / mx
			hp_lbls[i].text = G.fmt(e.hp[i])
	if idx >= ev.size():
		finished = true
		var win: bool = sim.winner == 0
		actors[1 if win else 0].die()
		actors[0 if win else 1].cheer()
		log_lbl.text = "VICTOIRE !" if win else "DÉFAITE…"
		log_lbl.add_theme_color_override("font_color", UI.GOOD if win else UI.BAD)
		var tw = create_tween()
		tw.tween_interval(1.3)
		tw.tween_callback(func():
			queue_free()
			done_cb.call(win))
