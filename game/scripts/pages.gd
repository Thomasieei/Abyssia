class_name Pages
extends RefCounted
# Construction de toutes les pages de menu.

var main
var box: VBoxContainer
var updaters: Array = []
var live = {"train": true, "hero": true, "pets": true, "dj": true, "asc": true, "quests": true, "arena": true, "shop": true}
var rank_tab = "power"
var rank_data: Array = []
var rank_me = {}
var rank_loading = false
var rank_tried = false
var opps: Array = []
var opp_loading = false
var history: Array = []
var inv_filter = ""
var dj_diff = {}

func _init(m) -> void:
	main = m

func refresh() -> void:
	box = main.content_box
	var sv: int = main.scroll.scroll_vertical
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()
	updaters.clear()
	match main.cur_page:
		"train": p_train()
		"hero": p_hero()
		"equip": p_equip()
		"pets": p_pets()
		"dj": p_dj()
		"arena": p_arena()
		"menu": p_menu()
		"asc": p_asc()
		"rank": p_rank()
		"quests": p_quests()
		"ach": p_ach()
		"best": p_best()
		"secrets": p_secrets()
		"shop": p_shop()
		"maps": p_maps()
		"options": p_options()
	update()
	_restore_scroll(sv)

func _restore_scroll(sv: int) -> void:
	await main.get_tree().process_frame
	main.scroll.scroll_vertical = sv

func update() -> void:
	for u in updaters: u.call()

func add(c: Control) -> Control:
	box.add_child(c)
	return c

func card(col := UI.PANEL2, border := Color(1, 1, 1, 0.06)) -> PanelContainer:
	return UI.panel(col, 14, 12, 2, border)

func back_row(title_text: String) -> void:
	var h = UI.hb()
	h.add_child(UI.btn("◀ Retour", func(): main.show_page("menu"), Color("3a3355"), 21, 150))
	var t = UI.title(title_text)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(t)
	add(h)

func live_btn(b: Button, can: Callable) -> Button:
	updaters.append(func(): b.disabled = not can.call())
	return b

# ------------------------------------------------------------------ Entraînement
func p_train() -> void:
	var head = card(Color("2a2238"))
	var hv = UI.vb(4)
	head.add_child(hv)
	var l1 = UI.lbl("", 21, UI.TXT)
	hv.add_child(l1)
	updaters.append(func():
		l1.text = "Dégâts %s · Vitesse %.2f/s · Critique %d %% (×%.1f)\nFrappe %s · Or ×%s · Puissance %s/s" % [G.fmt(G.st.dmg), G.st.aps, int(G.st.crit * 100), G.st.critd, G.fmt(G.st.tap), G.fmt(G.st.gold), G.fmt(G.power())])
	add(head)
	var hb = UI.hb()
	hb.add_child(UI.expand(UI.btn("Choisir une carte", func(): main.show_page("maps"), Color("2f5a7a"))))
	hb.add_child(UI.expand(UI.btn("Quêtes du jour", func(): main.show_page("quests"), Color("5a4a2a"))))
	add(hb)
	for id in D.TRAIN.keys():
		var t: Dictionary = D.TRAIN[id]
		var c = card()
		var h = UI.hb(10)
		c.add_child(h)
		h.add_child(UI.icon("res://assets/items/%s.png" % t.icon, 64))
		var v = UI.vb(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm = UI.lbl("", 23, UI.ACCENT)
		v.add_child(nm)
		v.add_child(UI.lbl(t.desc, 18, UI.DIM))
		var cost_l = UI.lbl("", 19, Color("ffd34d"))
		v.add_child(cost_l)
		h.add_child(v)
		var bv = UI.vb(6)
		var b1 = UI.btn("+1", func(): _train(id, 1), Color("3d6b3d"), 22, 92)
		var b10 = UI.btn("+10", func(): _train(id, 10), Color("3d6b3d"), 20, 92)
		var bm = UI.btn("MAX", func(): _train(id, 100000), Color("6b5a2a"), 20, 92)
		b1.custom_minimum_size.y = 46
		b10.custom_minimum_size.y = 46
		bm.custom_minimum_size.y = 46
		bv.add_child(b1)
		var bh = UI.hb(6)
		bh.add_child(b10)
		bh.add_child(bm)
		bv.add_child(bh)
		h.add_child(bv)
		add(c)
		updaters.append(func():
			var lv: int = G.s.train[id]
			var mx: bool = t.has("max") and lv >= t.max
			nm.text = "%s — niv %d%s" % [t.name, lv, (" (MAX)" if mx else "")]
			cost_l.text = "" if mx else "Coût : %s or" % G.fmt(G.train_cost(id))
			var ok: bool = not mx and G.s.gold >= G.train_cost(id)
			b1.disabled = not ok
			b10.disabled = not ok
			bm.disabled = not ok)
	add(UI.lbl("Astuce : touche l'écran de combat pour frapper ! L'entraînement est remis à zéro à chaque ascension, mais tout le reste est conservé.", 18, UI.DIM))

func _train(id: String, n: int) -> void:
	if G.buy_train(id, n) > 0: Sfx.play("buy")
	update()

# ------------------------------------------------------------------ Héros
func p_hero() -> void:
	var cl: Dictionary = D.CLASSES.get(G.s.cls, {})
	var c = card(Color("2a2238"))
	var v = UI.vb(4)
	c.add_child(v)
	v.add_child(UI.lbl("%s — %s niveau %d" % [G.s.name, cl.get("name", "?"), G.s.level], 25, UI.ACCENT))
	v.add_child(UI.lbl(cl.get("desc", ""), 18, UI.DIM))
	var st = UI.lbl("", 19, UI.TXT)
	v.add_child(st)
	updaters.append(func():
		st.text = "XP %s / %s\nAscensions %d · Étape max %d · Abysse %d\nBonus succès : +%d %% dégâts · Bestiaire : %d paliers" % [G.fmt(G.s.xp), G.fmt(G.xp_need()), G.s.ascensions, G.s.max_gi, G.s.abyss_best, G.s.ach.size(), G.bestiary_tiers_total()])
	add(c)
	add(UI.title("Caractéristiques"))
	var pts = UI.lbl("", 21, UI.GOOD)
	updaters.append(func(): pts.text = "Points libres : %d (3 par niveau)" % G.stat_points_free())
	add(pts)
	var defs = [["force", "Force", "+2 dégâts de base, +1 % dégâts"], ["agi", "Agilité", "+1 % vitesse, +0,1 % esquive en arène"], ["chance", "Chance", "+0,2 % critique, +2 % dégâts critiques"], ["vit", "Vitalité", "+3 % PV et +0,3 % défense en arène"]]
	for d in defs:
		var k: String = d[0]
		var cc = card()
		var h = UI.hb()
		cc.add_child(h)
		var vv = UI.vb(2)
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n = UI.lbl("", 22, UI.TXT)
		vv.add_child(n)
		vv.add_child(UI.lbl(d[2], 17, UI.DIM))
		h.add_child(vv)
		var b1 = live_btn(UI.btn("+1", func(): G.alloc_stat(k, 1); update(), Color("3d6b3d"), 22, 80), func(): return G.stat_points_free() > 0)
		var b10 = live_btn(UI.btn("+10", func(): G.alloc_stat(k, 10); update(), Color("3d6b3d"), 20, 80), func(): return G.stat_points_free() > 0)
		h.add_child(b1)
		h.add_child(b10)
		updaters.append(func(): n.text = "%s : %d" % [d[1], G.s.alloc[k]])
		add(cc)
	add(UI.btn("Réinitialiser les caractéristiques (50 gemmes)", func():
		if G.reset_stats(): Sfx.play("ok")
		else: Sfx.play("error"), Color("5a2a3a")))
	add(UI.title("Talents"))
	var tp = UI.lbl("", 21, UI.GOOD)
	updaters.append(func(): tp.text = "Points de talent : %d libres (1 tous les 3 niveaux + Sanctuaire Perdu)" % G.talent_points_free())
	add(tp)
	add(UI.lbl("Chaque talent débloque le suivant de sa branche quand il atteint le niveau 5.", 17, UI.DIM))
	for br in 3:
		add(UI.lbl("— Branche " + D.TALENT_BRANCHES[br] + " —", 22, Color("c8a2ff")))
		for t in D.TALENTS:
			if t.br != br: continue
			var cc = card()
			var h = UI.hb()
			cc.add_child(h)
			var vv = UI.vb(2)
			vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var n = UI.lbl("", 21, UI.TXT)
			vv.add_child(n)
			vv.add_child(UI.lbl(t.desc, 17, UI.DIM))
			h.add_child(vv)
			var tt: Dictionary = t
			var b = live_btn(UI.btn("+", func():
				if G.buy_talent(tt): Sfx.play("buy")
				update(), Color("4a3f8a"), 26, 80), func(): return G.talent_points_free() > 0 and G.talent_lvl(tt.id) < tt.max and G.talent_available(tt))
			h.add_child(b)
			updaters.append(func():
				var av: bool = G.talent_available(tt)
				n.text = "%s  %d/%d%s" % [tt.name, G.talent_lvl(tt.id), tt.max, "" if av else "  (verrouillé)"]
				n.add_theme_color_override("font_color", UI.TXT if av else Color(1, 1, 1, 0.4)))
			add(cc)
	add(UI.btn("Réinitialiser les talents (100 gemmes)", func():
		if G.reset_talents(): Sfx.play("ok")
		else: Sfx.play("error"), Color("5a2a3a")))

# ------------------------------------------------------------------ Équipement
func _stat_text(sub: Array) -> String:
	var v: float = sub[1]
	return "+%s %% %s" % [("%.1f" % v) if v < 10 else G.fmt(v), D.SUBS[sub[0]].name.to_lower()]

func _item_row(it: Dictionary, equipped := false) -> Control:
	var c = card(Color("26213a"), Color(D.RARITY_COLORS[int(it.rar)]).darkened(0.3))
	var h = UI.hb(10)
	c.add_child(h)
	h.add_child(UI.icon(UI.item_icon_path(it), 56))
	var v = UI.vb(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm = "%s%s" % [it.name, (" +%d" % int(it.plus)) if int(it.plus) > 0 else ""]
	v.add_child(UI.lbl(nm, 21, D.RARITY_COLORS[int(it.rar)]))
	var stats = G.item_stats(it)
	var cur = G.s.equip.get(it.slot)
	var cmp = ""
	if not equipped:
		if cur == null: cmp = "  ▲ NOUVEAU"
		else:
			var d = G.item_score(it) - G.item_score(cur)
			cmp = "  ▲ mieux" if d > 0.01 else "  ▼"
	v.add_child(UI.lbl("%s · niv %d · %s%s" % [D.SLOT_NAMES[it.slot], int(it.ilvl), _stat_text(stats[0]), cmp], 17, UI.GOOD if cmp.begins_with("  ▲") else UI.DIM))
	h.add_child(v)
	var b = UI.btn("Voir", func(): item_popup(it), Color("3a3355"), 20, 90)
	h.add_child(b)
	return c

func p_equip() -> void:
	add(UI.title("Équipement porté"))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for slot in D.SLOTS:
		var it = G.s.equip.get(slot)
		var c = card(Color("26213a"), Color(D.RARITY_COLORS[int(it.rar)]).darkened(0.3) if it else Color(1, 1, 1, 0.05))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h = UI.hb(8)
		c.add_child(h)
		if it:
			h.add_child(UI.icon(UI.item_icon_path(it), 48))
			var v = UI.vb(0)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(UI.lbl("%s%s" % [D.SLOT_NAMES[slot], (" +%d" % int(it.plus)) if int(it.plus) > 0 else ""], 18, D.RARITY_COLORS[int(it.rar)]))
			v.add_child(UI.lbl(_stat_text(G.item_stats(it)[0]), 16, UI.DIM))
			h.add_child(v)
			var itc: Dictionary = it
			var b = UI.btn("›", func(): item_popup(itc, true), Color("3a3355"), 24, 50)
			h.add_child(b)
		else:
			h.add_child(UI.lbl("%s : vide" % D.SLOT_NAMES[slot], 18, Color(1, 1, 1, 0.35)))
		grid.add_child(c)
	add(grid)
	var hb = UI.hb()
	hb.add_child(UI.expand(UI.btn("Équiper le meilleur", func():
		var n = G.equip_best()
		main.show_toast("%d objet(s) équipé(s)" % n, UI.GOOD, 1.5)
		Sfx.play("ok"), Color("3d6b3d"), 20)))
	hb.add_child(UI.expand(UI.btn("Recycler le moins bon", func(): _salvage_menu(), Color("6b4a2a"), 20)))
	add(hb)
	var auto_lbl: String = "Recyclage auto : aucun" if G.s.auto_salvage < 0 else "Recyclage auto : ≤ " + D.RARITY_NAMES[G.s.auto_salvage]
	add(UI.btn(auto_lbl, func():
		G.s.auto_salvage = G.s.auto_salvage + 1 if G.s.auto_salvage < 3 else -1
		refresh(), Color("3a3355"), 19))
	var title_l = UI.title("Sac (%d/%d)" % [G.s.inv.size(), G.INV_MAX])
	add(title_l)
	var fl = HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for f in [["", "Tout"]] + D.SLOTS.map(func(x): return [x, D.SLOT_NAMES[x]]):
		var ff: String = f[0]
		var b = UI.btn(f[1], func():
			inv_filter = ff
			refresh(), Color("5a4d88") if inv_filter == ff else Color("2f2a44"), 17, 0)
		b.custom_minimum_size = Vector2(0, 44)
		fl.add_child(b)
	add(fl)
	var lst: Array = G.s.inv.duplicate()
	if inv_filter != "": lst = lst.filter(func(x): return x.slot == inv_filter)
	lst.sort_custom(func(a, b): return G.item_score(a) > G.item_score(b))
	if lst.is_empty(): add(UI.lbl("Aucun objet. Les monstres d'élite et les boss en lâchent toujours !", 19, UI.DIM))
	var shown = 0
	for it in lst:
		add(_item_row(it))
		shown += 1
		if shown >= 40: break

func _salvage_menu() -> void:
	var v: VBoxContainer = main.modal("Recycler")
	v.add_child(UI.lbl("Recycle tout le sac jusqu'à la rareté choisie (l'équipement porté est conservé). Tu gagnes du minerai.", 20, UI.TXT))
	for r in 5:
		var rr = r
		v.add_child(UI.btn("Jusqu'à " + D.RARITY_NAMES[r], func():
			var n = G.salvage_all_below(rr)
			main.clear_overlay()
			main.show_toast("%d objet(s) recyclé(s)" % n, Color("c28a5a"))
			Sfx.play("forge")
			refresh(), Color(D.RARITY_COLORS[r]).darkened(0.55)))

func item_popup(it: Dictionary, equipped := false) -> void:
	var v: VBoxContainer = main.modal(D.SLOT_NAMES[it.slot])
	var h = UI.hb(12)
	h.add_child(UI.icon(UI.item_icon_path(it), 96))
	var vv = UI.vb(2)
	vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vv.add_child(UI.lbl("%s%s" % [it.name, (" +%d" % int(it.plus)) if int(it.plus) > 0 else ""], 25, D.RARITY_COLORS[int(it.rar)]))
	vv.add_child(UI.lbl("%s · niveau d'objet %d" % [D.RARITY_NAMES[int(it.rar)], int(it.ilvl)], 19, UI.DIM))
	h.add_child(vv)
	v.add_child(h)
	var stats = G.item_stats(it)
	var txt = ""
	for i in stats.size():
		txt += ("★ " if i == 0 else "• ") + _stat_text(stats[i]) + "\n"
	v.add_child(UI.lbl(txt.strip_edges(), 21, UI.TXT))
	var cur = G.s.equip.get(it.slot)
	if not equipped and cur:
		v.add_child(UI.lbl("Porté : %s%s (score %s contre %s)" % [cur.name, (" +%d" % int(cur.plus)) if int(cur.plus) > 0 else "", G.fmt(G.item_score(cur)), G.fmt(G.item_score(it))], 18, UI.DIM))
	if not equipped:
		v.add_child(UI.btn("Équiper", func():
			G.equip_item(it)
			Sfx.play("ok")
			main.clear_overlay()
			refresh(), Color("3d6b3d")))
	var fc = G.forge_cost(it)
	var fl = UI.lbl("", 19, Color("ffd34d"))
	v.add_child(fl)
	var fb = UI.btn("Forger +1", func():
		var r = G.forge(it)
		if r == 1:
			Sfx.play("forge")
			main.show_toast("Forge réussie : +%d !" % int(it.plus), UI.GOOD, 1.2)
		elif r == 0:
			Sfx.play("error")
			main.show_toast("La forge a échoué…", UI.BAD, 1.2)
		else:
			Sfx.play("error")
		item_popup(it, equipped), Color("8a5a2a"))
	v.add_child(fb)
	fl.text = "Forge +%d → +%d : %s minerai + %s or · réussite %d %%" % [int(it.plus), int(it.plus) + 1, G.fmt(fc[0]), G.fmt(fc[1]), int(G.forge_chance(it) * 100)] if int(it.plus) < 20 else "Forge au maximum (+20)"
	fb.disabled = int(it.plus) >= 20 or G.s.ore < fc[0] or G.s.gold < fc[1]
	if not it.subs.is_empty():
		var rb = UI.btn("Relancer les bonus secondaires (30 gemmes)", func():
			if G.reroll(it): Sfx.play("ok")
			item_popup(it, equipped), Color("2f5a7a"), 19)
		rb.disabled = G.s.gems < 30
		v.add_child(rb)
	if not equipped:
		v.add_child(UI.btn("Recycler (+%s minerai)" % G.fmt(ceil(G.salvage_value(it) * G.st.ore)), func():
			G.salvage_item(it)
			G.mark()
			Sfx.play("forge")
			main.clear_overlay()
			refresh(), Color("6b2a35")))

# ------------------------------------------------------------------ Familiers
func _pet_bonus_text(p: Dictionary) -> String:
	var stat: String = D.PETS[p.sp].stat
	var mul = (1.0 + 0.12 * G.relic_lvl("r_bete"))
	return "+%s %% %s" % [G.fmt(G.pet_value(p) * mul), D.SUBS[stat].name.to_lower()]

func _stars(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(5 - n)

func p_pets() -> void:
	add(UI.title("Œufs"))
	var h = UI.hb(8)
	for i in 3:
		var e: Dictionary = D.EGGS[i]
		var c = card(Color("26213a"))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v = UI.vb(4)
		c.add_child(v)
		var ic = UI.icon("res://assets/eggs/%s.png" % e.icon, 84)
		v.add_child(ic)
		var n = UI.lbl("", 18, UI.TXT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var ii = i
		var b = live_btn(UI.btn("Éclore", func(): _hatch(ii), Color("6b5a2a"), 19, 0), func(): return G.s.eggs[ii] > 0)
		v.add_child(b)
		updaters.append(func(): n.text = "%s\n× %d" % [e.name, G.s.eggs[ii]])
		h.add_child(c)
	add(h)
	add(UI.lbl("Les œufs tombent des boss, du Nid du Dragon, de l'Abysse, des quêtes et de la boutique. 3 familiers identiques (même rareté et étoiles) fusionnent en +1 étoile ; à 5 étoiles, la fusion fait monter la rareté.", 17, UI.DIM))
	add(UI.title("Familiers (%d) — %d/3 actifs" % [G.s.pets.size(), G.s.pet_eq.size()]))
	var lst: Array = G.s.pets.duplicate()
	lst.sort_custom(func(a, b):
		var ea: bool = int(a.uid) in G.s.pet_eq
		var eb: bool = int(b.uid) in G.s.pet_eq
		if ea != eb: return ea
		return G.pet_value(a) > G.pet_value(b))
	if lst.is_empty(): add(UI.lbl("Aucun familier pour l'instant.", 19, UI.DIM))
	var count = 0
	for p in lst:
		var eq: bool = int(p.uid) in G.s.pet_eq
		var c = card(Color("2e2846") if eq else Color("26213a"), UI.ACCENT if eq else Color(D.RARITY_COLORS[p.rar]).darkened(0.4))
		var hh = UI.hb(10)
		c.add_child(hh)
		var pd: Dictionary = D.PETS[p.sp]
		var thumb = TextureRect.new()
		thumb.texture = UI.tex("res://assets/thumbs/%s.png" % pd.sprite)
		thumb.custom_minimum_size = Vector2(72, 72)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.modulate = pd.tint
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hh.add_child(thumb)
		var v = UI.vb(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.lbl("%s %s" % [pd.name, "(actif)" if eq else ""], 21, D.RARITY_COLORS[p.rar]))
		v.add_child(UI.lbl("%s · %s · niv %d" % [D.RARITY_NAMES[p.rar], _stars(p.stars), p.lvl], 17, Color("ffd34d")))
		v.add_child(UI.lbl(_pet_bonus_text(p), 17, UI.GOOD))
		hh.add_child(v)
		var pp: Dictionary = p
		hh.add_child(UI.btn("Voir", func(): pet_popup(pp), Color("3a3355"), 20, 90))
		add(c)
		count += 1
		if count >= 40: break

func _hatch(i: int) -> void:
	var p = G.hatch(i)
	if p.is_empty(): return
	Sfx.play("egg")
	var pd: Dictionary = D.PETS[p.sp]
	var v: VBoxContainer = main.modal("Éclosion !")
	var thumb = TextureRect.new()
	thumb.texture = UI.tex("res://assets/thumbs/%s_atk.png" % pd.sprite)
	thumb.custom_minimum_size = Vector2(200, 200)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.modulate = pd.tint
	v.add_child(thumb)
	var l = UI.lbl("%s\n%s" % [pd.name, D.RARITY_NAMES[p.rar]], 30, D.RARITY_COLORS[p.rar], true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.add_child(UI.lbl(_pet_bonus_text(p), 22, UI.GOOD))
	var hb = UI.hb()
	hb.add_child(UI.expand(UI.btn("Super !", func():
		main.clear_overlay()
		main._update_pets()
		refresh(), Color("3d6b3d"))))
	if G.s.eggs[i] > 0:
		hb.add_child(UI.expand(UI.btn("Encore un (%d)" % G.s.eggs[i], func(): _hatch(i), Color("6b5a2a"))))
	v.add_child(hb)
	if p.rar >= 3: Sfx.play("win")

func pet_popup(p: Dictionary) -> void:
	var pd: Dictionary = D.PETS[p.sp]
	var v: VBoxContainer = main.modal(pd.name)
	v.add_child(UI.lbl("%s · %s · niveau %d/50" % [D.RARITY_NAMES[p.rar], _stars(p.stars), p.lvl], 22, D.RARITY_COLORS[p.rar]))
	v.add_child(UI.lbl("Bonus : " + _pet_bonus_text(p), 22, UI.GOOD))
	var eq: bool = int(p.uid) in G.s.pet_eq
	v.add_child(UI.btn("Retirer" if eq else "Rendre actif", func():
		G.toggle_pet(p)
		main._update_pets()
		pet_popup(p), Color("3d6b3d")))
	var cost = G.pet_lvl_cost(p)
	var lb = UI.btn("Nourrir (niv +1) : %s minerai" % G.fmt(cost), func():
		if G.pet_level_up(p): Sfx.play("buy")
		pet_popup(p), Color("6b4a2a"))
	lb.disabled = p.lvl >= 50 or G.s.ore < cost
	v.add_child(lb)
	var cands = G.fuse_candidates(p)
	var fb = UI.btn("Fusionner (%d/2 copies identiques)" % min(2, cands.size()), func():
		if G.fuse(p):
			Sfx.play("win")
			main.show_toast("Fusion réussie : %s %s" % [D.RARITY_NAMES[p.rar], _stars(p.stars)], UI.ACCENT)
			main._update_pets()
		pet_popup(p), Color("4a3f8a"))
	fb.disabled = cands.size() < 2 or (p.stars >= 5 and p.rar >= 5)
	v.add_child(fb)
	v.add_child(UI.btn("Fermer", func():
		main.clear_overlay()
		refresh(), Color("3a3355")))

# ------------------------------------------------------------------ Donjons
func p_dj() -> void:
	var kc = card(Color("2a2238"))
	var kl = UI.lbl("", 21, UI.TXT)
	kc.add_child(kl)
	updaters.append(func():
		var nxt = ""
		if G.s.keys < G.keys_max(): nxt = " · prochaine dans %s" % G.fmt_time(G.key_regen() - float(G.s.get("key_acc", 0.0)))
		kl.text = "Clés : %d/%d%s\nUne clé par entrée. Les boss de carte et les quêtes en donnent aussi." % [int(G.s.keys), G.keys_max(), nxt])
	add(kc)
	if G.mode != "farm":
		add(UI.lbl("Une expédition est déjà en cours !", 22, UI.BAD))
	# Abysse
	var ac = card(Color("231a3d"), Color("8a6bff"))
	var av = UI.vb(4)
	ac.add_child(av)
	av.add_child(UI.lbl("L'Abysse — tour infinie", 25, Color("c8a2ff")))
	av.add_child(UI.lbl("Monte le plus haut possible : un monstre par étage, 15 s chacun. Gemmes à chaque record, œuf et âmes tous les 10 étages. Gratuit. Classement mondial !", 18, UI.DIM))
	av.add_child(UI.lbl("Record : étage %d" % G.s.abyss_best, 21, UI.ACCENT))
	if G.s.max_gi >= 20:
		av.add_child(live_btn(UI.btn("Entrer dans l'Abysse", func():
			if G.start_abyss(): Sfx.play("boss"), Color("5a3a9a")), func(): return G.mode == "farm"))
	else:
		av.add_child(UI.lbl("Débloquée à l'étape 20 (carte 2, boss).", 19, UI.BAD))
	add(ac)
	for d in D.DUNGEONS:
		var dd: Dictionary = d
		var c = card()
		var v = UI.vb(4)
		c.add_child(v)
		var unlocked = G.dungeon_unlocked(d)
		v.add_child(UI.lbl("%s — %d salles" % [d.name, d.rooms], 23, UI.ACCENT if unlocked else Color(1, 1, 1, 0.45)))
		v.add_child(UI.lbl(d.desc, 18, UI.DIM))
		if not unlocked:
			v.add_child(UI.lbl("Débloqué à l'étape %d (carte %d)" % [d.unlock, int((d.unlock - 1) / 10) + 1], 19, UI.BAD))
			add(c)
			continue
		var best = G.dj_best(d)
		if not dj_diff.has(d.id): dj_diff[d.id] = best + 1
		var row = UI.hb(8)
		var dl = UI.lbl("", 21, UI.TXT)
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(UI.btn("−", func():
			dj_diff[dd.id] = max(1, int(dj_diff[dd.id]) - 1)
			update(), Color("3a3355"), 26, 64))
		row.add_child(dl)
		row.add_child(UI.btn("+", func():
			dj_diff[dd.id] = min(G.dj_best(dd) + 1, int(dj_diff[dd.id]) + 1)
			update(), Color("3a3355"), 26, 64))
		v.add_child(row)
		var go = live_btn(UI.btn("Entrer (1 clé)", func():
			if G.start_dungeon(dd, int(dj_diff[dd.id])):
				Sfx.play("boss")
				main.show_toast("%s — difficulté %d" % [dd.name, dj_diff[dd.id]], UI.ACCENT)
			else: Sfx.play("error"), Color("3d6b3d")), func(): return G.mode == "farm" and G.s.keys >= 1)
		v.add_child(go)
		updaters.append(func(): dl.text = "Difficulté %d   (record %d)" % [int(dj_diff[dd.id]), G.dj_best(dd)])
		add(c)

# ------------------------------------------------------------------ Arène
func p_arena() -> void:
	var c = card(Color("2a2238"))
	var v = UI.vb(4)
	c.add_child(v)
	var l = UI.lbl("", 21, UI.TXT)
	v.add_child(l)
	updaters.append(func():
		var nxt = ""
		if G.s.tickets < 10: nxt = " (+1 dans %s)" % G.fmt_time(3600.0 - float(G.s.get("ticket_acc", 0.0)))
		var me = G.pvp_profile()
		l.text = "Cote : %d · Victoires %d · Défaites %d\nTickets : %d/10%s · Honneur : %s\nTon attaque %s · PV %s" % [int(G.s.pvp.rating), int(G.s.pvp.wins), int(G.s.pvp.losses), int(G.s.tickets), nxt, G.fmt(G.s.honor), G.fmt(me.atk), G.fmt(me.hp)])
	add(c)
	add(UI.lbl("Les combats d'arène opposent ta puissance à celle des vrais joueurs (leur dernier profil enregistré). Sans connexion, tu affrontes des adversaires IA.", 17, UI.DIM))
	var find = UI.btn("Rechercher des adversaires" if not opp_loading else "Recherche…", func(): _find_opps(), Color("2f5a7a"))
	find.disabled = opp_loading
	add(find)
	for o in opps:
		var oc = card()
		var h = UI.hb()
		oc.add_child(h)
		var ov = UI.vb(0)
		ov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ov.add_child(UI.lbl("%s — %s niv %d" % [o.name, D.CLASSES.get(o.cls, {"name": "?"}).name, o.level], 21, UI.TXT if not o.bot else UI.DIM))
		var ratio: float = o.power / max(1.0, G.power())
		var diff_txt = "facile" if ratio < 0.7 else ("équilibré" if ratio < 1.4 else "difficile")
		ov.add_child(UI.lbl("Puissance %s · cote %d · %s" % [G.fmt(o.power), o.rating, diff_txt], 17, UI.GOOD if ratio < 0.7 else (UI.ACCENT if ratio < 1.4 else UI.BAD)))
		h.add_child(ov)
		var oo: Dictionary = o
		h.add_child(live_btn(UI.btn("Combattre", func(): fight(oo), Color("8a2a35"), 20, 140), func(): return G.s.tickets >= 1))
		add(oc)
	add(UI.title("Boutique d'honneur"))
	for hd in D.HONOR:
		var hh: Dictionary = hd
		var cc = card()
		var h = UI.hb()
		cc.add_child(h)
		var vv = UI.vb(0)
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n = UI.lbl("", 21, UI.TXT)
		vv.add_child(n)
		vv.add_child(UI.lbl(hd.desc, 17, UI.DIM))
		h.add_child(vv)
		var b = live_btn(UI.btn("", func():
			if G.buy_honor(hh): Sfx.play("buy")
			update(), Color("6b5a2a"), 19, 150), func(): return G.s.honor >= G.honor_cost(hh))
		h.add_child(b)
		updaters.append(func():
			n.text = "%s — niv %d" % [hh.name, G.honor_lvl(hh.id)]
			b.text = "%s honneur" % G.fmt(G.honor_cost(hh)))
		add(cc)
	if not history.is_empty():
		add(UI.title("Derniers combats"))
		for r in history:
			var mine: bool = str(r.attacker) == G.s.pvp.id
			var win: bool = r.win if mine else not r.win
			var who: String = r.defender_name if mine else r.attacker_name
			add(UI.lbl("%s %s %s (%s%d)" % ["Victoire" if win else "Défaite", "contre" if mine else "en défense contre", who, "+" if (r.delta if mine else -r.delta) >= 0 else "", int(r.delta) if mine else -int(r.delta)], 18, UI.GOOD if win else UI.BAD))

func _find_opps() -> void:
	opp_loading = true
	refresh()
	var res: Array = await Net.opponents()
	if res.size() < 3:
		res.append_array(G.bot_opponents().slice(0, 5 - res.size()))
	opps = res
	history = await Net.history()
	opp_loading = false
	if main.cur_page == "arena": refresh()

func fight(o: Dictionary) -> void:
	if G.s.tickets < 1:
		Sfx.play("error")
		return
	G.s.tickets -= 1
	var me = G.pvp_profile()
	var sim = G.pvp_sim(me, o, randi())
	var arena = preload("res://scripts/pvp_view.gd").new()
	main.overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	main.clear_overlay()
	main.overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	main.overlay.add_child(arena)
	arena.start(me, o, sim, func(win: bool):
		var txt = G.pvp_reward(win)
		var delta = 0
		if not o.bot and Net.online:
			delta = await Net.report_duel(o.id, win)
		elif o.bot:
			delta = G.elo(G.s.pvp.rating, o.rating, win)
			G.s.pvp.rating = max(0, int(G.s.pvp.rating) + delta)
		Sfx.play("win" if win else "lose")
		main.popup("Victoire !" if win else "Défaite", "%s\nCote %s%d → %d" % [txt, "+" if delta >= 0 else "", delta, int(G.s.pvp.rating)])
		opps.erase(o)
		G.save_game()
		refresh())

# ------------------------------------------------------------------ Menu
func p_menu() -> void:
	add(UI.title("Menu"))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var claim = G.ach_claimable()
	var qdone = 0
	for q in G.s.quests.list:
		if not q.claimed and G.quest_progress(q) >= float(q.target): qdone += 1
	var items = [["asc", "Ascension", Color("5a3a9a")], ["rank", "Classements", Color("2f5a7a")], ["quests", "Quêtes du jour" + (" (%d !)" % qdone if qdone > 0 else ""), Color("6b5a2a")],
		["ach", "Succès" + (" (%d !)" % claim if claim > 0 else ""), Color("3d6b3d")], ["best", "Bestiaire", Color("4a3f72")], ["secrets", "Découvertes", Color("8a3a7a")],
		["shop", "Boutique", Color("2f7a6b")], ["maps", "Cartes", Color("3a5a3a")], ["options", "Options", Color("3a3355")]]
	for it in items:
		var id: String = it[0]
		var b = UI.btn(it[1], func(): main.show_page(id), it[2], 23)
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	add(grid)

func p_asc() -> void:
	back_row("Ascension")
	var c = card(Color("231a3d"), Color("8a6bff"))
	var v = UI.vb(6)
	c.add_child(v)
	var l = UI.lbl("", 21, UI.TXT)
	v.add_child(l)
	v.add_child(live_btn(UI.btn("ASCENSION", func(): _confirm_ascend(), Color("6b3aaa"), 26), func(): return G.souls_preview() > 0))
	updaters.append(func():
		var sp = G.souls_preview()
		if sp > 0: l.text = "Âmes actuelles : %s\nTu gagnerais : %s âmes (meilleure étape de cette vie : %d)\n\nL'ascension remet à zéro l'or, l'entraînement et la carte. Tu gardes ton niveau, l'équipement, les familiers, talents, reliques, succès et records." % [G.fmt(G.s.souls), G.fmt(sp), G.s.run_max_gi]
		else: l.text = "Âmes actuelles : %s\nAtteins l'étape 30 dans cette vie pour pouvoir faire une ascension (actuellement %d)." % [G.fmt(G.s.souls), G.s.run_max_gi])
	add(c)
	add(UI.title("Reliques"))
	for r in D.RELICS:
		var rr: Dictionary = r
		var cc = card()
		var h = UI.hb()
		cc.add_child(h)
		var vv = UI.vb(0)
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n = UI.lbl("", 21, Color("c8a2ff"))
		vv.add_child(n)
		vv.add_child(UI.lbl(r.desc, 17, UI.DIM))
		h.add_child(vv)
		var b = live_btn(UI.btn("", func():
			if G.buy_relic(rr): Sfx.play("buy")
			update(), Color("4a3f8a"), 19, 150), func(): return (rr.max == 0 or G.relic_lvl(rr.id) < rr.max) and G.s.souls >= G.relic_cost(rr))
		h.add_child(b)
		updaters.append(func():
			var mx: bool = rr.max > 0 and G.relic_lvl(rr.id) >= rr.max
			n.text = "%s — niv %d%s" % [rr.name, G.relic_lvl(rr.id), (" (MAX)" if mx else ("/%d" % rr.max if rr.max > 0 else ""))]
			b.text = "MAX" if mx else "%s âmes" % G.fmt(G.relic_cost(rr)))
		add(cc)

func _confirm_ascend() -> void:
	var v: VBoxContainer = main.modal("Confirmer l'ascension")
	v.add_child(UI.lbl("Gagner %s âmes et recommencer à la carte 1 ?" % G.fmt(G.souls_preview()), 22, UI.TXT))
	var h = UI.hb()
	h.add_child(UI.expand(UI.btn("Annuler", main.clear_overlay, Color("3a3355"))))
	h.add_child(UI.expand(UI.btn("Ascension !", func():
		if G.ascend():
			Sfx.play("win")
			main.cur_theme = -1
			main._apply_theme()
		main.clear_overlay()
		refresh(), Color("6b3aaa"))))
	v.add_child(h)

func p_rank() -> void:
	back_row("Classements")
	var tabs = HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	for t in [["power", "Puissance"], ["max_gi", "Étape"], ["abyss", "Abysse"], ["rating", "Arène"], ["level", "Niveau"]]:
		var id: String = t[0]
		var b = UI.btn(t[1], func():
			rank_tab = id
			_load_rank(), Color("5a4d88") if rank_tab == id else Color("2f2a44"), 19, 0)
		b.custom_minimum_size = Vector2(0, 50)
		tabs.add_child(b)
	add(tabs)
	if rank_loading:
		add(UI.lbl("Chargement…", 22, UI.DIM))
		return
	if rank_data.is_empty():
		if not rank_tried:
			rank_tried = true
			_load_rank.call_deferred()
		add(UI.btn("Charger le classement", _load_rank, Color("2f5a7a")))
		if not Net.online: add(UI.lbl("Connexion Internet nécessaire.", 19, UI.DIM))
		return
	if rank_me.has(rank_tab):
		add(UI.lbl("Ta place : %d / %d" % [int(rank_me[rank_tab]), int(rank_me.get("total", 0))], 23, UI.ACCENT))
	var i = 1
	for r in rank_data:
		var mine: bool = str(r.id) == G.s.pvp.id
		var val = ""
		match rank_tab:
			"power": val = G.fmt(float(r.power))
			"max_gi": val = "étape %d" % int(r.max_gi)
			"abyss": val = "étage %d" % int(r.abyss)
			"rating": val = "%d (%d V)" % [int(r.rating), int(r.wins)]
			"level": val = "niv %d" % int(r.level)
		var c = card(Color("3a3060") if mine else Color("26213a"), UI.ACCENT if mine else Color(1, 1, 1, 0.05))
		var h = UI.hb()
		c.add_child(h)
		var col = Color("ffd34d") if i == 1 else (Color("d8d8e8") if i == 2 else (Color("d08a4a") if i == 3 else UI.DIM))
		var pl = UI.lbl("#%d" % i, 22, col)
		pl.custom_minimum_size = Vector2(60, 0)
		h.add_child(pl)
		var nm = UI.lbl("%s (%s)" % [r.name, D.CLASSES.get(r.cls, {"name": "?"}).name], 20, UI.TXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(UI.lbl(val, 20, UI.ACCENT))
		add(c)
		i += 1

func _load_rank() -> void:
	rank_loading = true
	refresh()
	await Net.sync()
	rank_data = await Net.leaderboard(rank_tab)
	rank_me = await Net.ranks()
	rank_loading = false
	if main.cur_page == "rank": refresh()

func p_quests() -> void:
	back_row("Quêtes du jour")
	G.ensure_quests()
	add(UI.lbl("Nouvelles quêtes chaque jour. Toutes terminées : bonus d'un œuf et de 2 clés !", 18, UI.DIM))
	for q in G.s.quests.list:
		var d = G.quest_def(q.id)
		var qq: Dictionary = q
		var c = card()
		var v = UI.vb(4)
		c.add_child(v)
		v.add_child(UI.lbl(d.name % int(q.target), 21, UI.TXT))
		var b = UI.bar(Color("6ee06e"), 16)
		v.add_child(b)
		var h = UI.hb()
		var pl = UI.lbl("", 18, UI.DIM)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(pl)
		var cb = UI.btn("", func():
			if G.claim_quest(qq): Sfx.play("coin")
			refresh(), Color("6b5a2a"), 19, 170)
		h.add_child(cb)
		v.add_child(h)
		updaters.append(func():
			var pr = G.quest_progress(qq)
			b.value = pr / float(qq.target)
			pl.text = "%s / %s · +%d gemmes" % [G.fmt(pr), G.fmt(float(qq.target)), d.gems]
			cb.text = "Réclamée" if qq.claimed else "Réclamer"
			cb.disabled = qq.claimed or pr < float(qq.target))
		add(c)

func p_ach() -> void:
	back_row("Succès")
	add(UI.lbl("Chaque succès réclamé donne des gemmes ET +1 %% de dégâts permanents. (%d/%d)" % [G.s.ach.size(), G.achievements().size()], 18, UI.DIM))
	var lst = G.achievements().duplicate()
	lst.sort_custom(func(a, b):
		var ka = 0 if (not G.s.ach.has(a.id) and G.ach_value(a.key) >= a.goal) else (2 if G.s.ach.has(a.id) else 1)
		var kb = 0 if (not G.s.ach.has(b.id) and G.ach_value(b.key) >= b.goal) else (2 if G.s.ach.has(b.id) else 1)
		if ka != kb: return ka < kb
		return G.ach_value(a.key) / a.goal > G.ach_value(b.key) / b.goal)
	var n = 0
	for a in lst:
		var aa: Dictionary = a
		var done: bool = G.s.ach.has(a.id)
		var ready: bool = not done and G.ach_value(a.key) >= a.goal
		var c = card(Color("2e4a2e") if ready else Color("26213a"))
		var h = UI.hb()
		c.add_child(h)
		var v = UI.vb(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.lbl(a.name, 20, UI.ACCENT if not done else UI.DIM))
		v.add_child(UI.lbl("%s · %s / %s" % [a.desc, G.fmt(min(G.ach_value(a.key), a.goal)), G.fmt(a.goal)], 17, UI.DIM))
		h.add_child(v)
		if done: h.add_child(UI.lbl("✓", 28, UI.GOOD))
		else:
			var b = UI.btn("+%d" % a.gems, func():
				if G.claim_ach(aa): Sfx.play("coin")
				refresh(), Color("3d6b3d"), 20, 100)
			b.disabled = not ready
			h.add_child(b)
		add(c)
		n += 1
		if n > 60: break

func p_best() -> void:
	back_row("Bestiaire")
	add(UI.lbl("Chaque palier (100, 1 000, 10 000, 100 000, 1 000 000 éliminations) d'un monstre donne +4 % de dégâts et +4 % d'or pour toujours.", 18, UI.DIM))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for id in D.MONSTERS.keys():
		var md: Dictionary = D.MONSTERS[id]
		var k: float = float(G.s.best.get(id, 0.0))
		var c = card(Color("26213a"))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v = UI.vb(2)
		c.add_child(v)
		var t = TextureRect.new()
		t.texture = UI.tex("res://assets/thumbs/%s.png" % md.sprite)
		t.custom_minimum_size = Vector2(0, 120)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if k <= 0: t.modulate = Color(0, 0, 0, 0.8)
		v.add_child(t)
		var tier = G.bestiary_tier(id)
		var nl = UI.lbl(md.name if k > 0 else "???", 20, UI.ACCENT if k > 0 else UI.DIM)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
		var nxt: float = D.BESTIARY_TIERS[min(tier, 4)]
		var il = UI.lbl("%s éliminés · palier %d/5%s" % [G.fmt(k), tier, ("" if tier >= 5 else "\nprochain : " + G.fmt(nxt))], 16, UI.DIM)
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(il)
		grid.add_child(c)
	add(grid)

func p_secrets() -> void:
	back_row("Découvertes")
	add(UI.lbl("Des secrets se cachent dans Abyssia. Chaque découverte donne un bonus permanent. Trouvées : %d/%d" % [G.s.secrets.size(), D.SECRETS.size()], 18, UI.DIM))
	for sc in D.SECRETS:
		var found: bool = G.s.secrets.has(sc.id)
		var c = card(Color("3a2246") if found else Color("26213a"), Color("ff9cf0") if found else Color(1, 1, 1, 0.05))
		var v = UI.vb(2)
		c.add_child(v)
		v.add_child(UI.lbl(sc.name if found else "??? — " + sc.hint, 21, Color("ff9cf0") if found else UI.DIM))
		if found: v.add_child(UI.lbl("%s · %s" % [sc.how, sc.bonus], 17, UI.GOOD))
		add(c)

func p_shop() -> void:
	back_row("Boutique")
	add(UI.lbl("Tout s'achète avec des gemmes gagnées en jouant (boss, quêtes, succès, arène, donjons). Aucun achat réel.", 18, UI.DIM))
	var bst = UI.lbl("", 19, UI.ACCENT)
	updaters.append(func():
		var t = []
		if G.s.boost_gold > 0: t.append("Or ×2 : %s" % G.fmt_time(G.s.boost_gold))
		if G.s.boost_dmg > 0: t.append("Dégâts ×2 : %s" % G.fmt_time(G.s.boost_dmg))
		bst.text = " · ".join(t))
	add(bst)
	for it in D.SHOP:
		var id: String = it.id
		var c = card()
		var h = UI.hb()
		c.add_child(h)
		var v = UI.vb(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.lbl(it.name, 21, UI.TXT))
		v.add_child(UI.lbl(it.desc, 17, UI.DIM))
		h.add_child(v)
		var gems: int = it.gems
		h.add_child(live_btn(UI.btn("%d gemmes" % gems, func():
			if G.buy_shop(id):
				Sfx.play("buy")
				main.show_toast("Acheté : " + it.name, UI.GOOD, 1.2)
			update(), Color("2f7a6b"), 19, 160), func(): return G.s.gems >= gems))
		add(c)

func p_maps() -> void:
	back_row("Cartes")
	var max_map = int((G.s.max_gi - 1) / 10) + 1
	add(UI.lbl("Retourne farmer une étape déjà atteinte (pratique pour le bestiaire et les secrets).", 18, UI.DIM))
	for m in range(max_map, 0, -1):
		var info = G.map_info(m)
		var c = card(Color("2e2846") if m == G.s.map else Color("26213a"))
		var v = UI.vb(6)
		c.add_child(v)
		v.add_child(UI.lbl("Carte %d — %s" % [m, info.display], 21, UI.ACCENT))
		var fl = HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 6)
		for st in range(1, 11):
			var g = (m - 1) * 10 + st
			if g > G.s.max_gi: break
			var mm = m
			var ss = st
			var b = UI.btn(str(st) if st < 10 else "B", func():
				if G.mode != "farm": return
				G.set_stage(mm, ss)
				main._apply_theme()
				refresh(), Color("5a4d88") if (m == G.s.map and st == G.s.stage) else Color("2f2a44"), 19, 52)
			b.custom_minimum_size = Vector2(52, 48)
			fl.add_child(b)
		v.add_child(fl)
		add(c)
		if max_map - m > 15: break

func p_options() -> void:
	back_row("Options")
	add(UI.btn("Son : " + ("activé" if G.s.get("sound", true) else "coupé"), func():
		G.s.sound = not G.s.get("sound", true)
		refresh(), Color("3a3355")))
	add(UI.lbl("Changer de nom", 21, UI.TXT))
	var le = LineEdit.new()
	le.text = G.s.name
	le.max_length = 16
	add(le)
	add(UI.btn("Valider le nom", func():
		if le.text.strip_edges().length() >= 2:
			G.set_name_checked(le.text)
			Net.sync()
			main.show_toast("Nom changé", UI.GOOD, 1.2), Color("3d6b3d")))
	add(UI.lbl("Sauvegarde automatique toutes les 15 s et à la fermeture. Gains hors-ligne : jusqu'à 8 h.\nIdentifiant en ligne : %s" % (G.s.pvp.id if G.s.pvp.id != "" else "pas encore connecté"), 17, UI.DIM))
	add(UI.lbl("Abyssia — version 1.0", 17, UI.DIM))

# ------------------------------------------------------------------ Création du héros
var _new_cls = "chevalier"
func popup_create_hero() -> void:
	var v: VBoxContainer = main.modal("Bienvenue dans Abyssia", false)
	v.add_child(UI.lbl("Choisis le nom et la classe de ton héros.", 21, UI.TXT))
	var le = LineEdit.new()
	le.placeholder_text = "Nom du héros"
	le.max_length = 16
	le.text = G.s.name
	v.add_child(le)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var desc = UI.lbl(D.CLASSES[_new_cls].desc, 19, UI.GOOD)
	for k in D.CLASSES.keys():
		var cl: Dictionary = D.CLASSES[k]
		var sel: bool = k == _new_cls
		var c = Button.new()
		c.focus_mode = Control.FOCUS_NONE
		c.custom_minimum_size = Vector2(0, 220)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_stylebox_override("normal", UI.sb(Color("3a3060") if sel else Color("221e2e"), 14, 3, UI.ACCENT if sel else Color(1, 1, 1, 0.1), 6))
		c.add_theme_stylebox_override("hover", UI.sb(Color("3a3060"), 14, 3, UI.ACCENT, 6))
		c.add_theme_stylebox_override("pressed", UI.sb(Color("4a4080"), 14, 3, UI.ACCENT, 6))
		c.icon = UI.tex("res://assets/thumbs/%s_cheer.png" % cl.sprite)
		c.expand_icon = true
		c.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		c.text = cl.name
		c.add_theme_font_size_override("font_size", 22)
		var kk: String = k
		c.pressed.connect(func():
			_new_cls = kk
			G.s.name = le.text
			Sfx.play("click")
			popup_create_hero())
		grid.add_child(c)
	v.add_child(grid)
	v.add_child(desc)
	v.add_child(UI.btn("Commencer l'aventure", func():
		var n = le.text.strip_edges()
		if n.length() < 2:
			main.show_toast("Choisis un nom (2 lettres minimum)", UI.BAD)
			return
		G.s.cls = _new_cls
		G.set_name_checked(n)
		G.mark()
		main.setup_hero()
		main.clear_overlay()
		Sfx.play("win")
		Net.sync()
		main.show_toast("Touche l'écran pour frapper les monstres !", UI.ACCENT, 3.5), Color("3d6b3d"), 26))
