extends Node
# Pilote de test (activé seulement avec la variable d'environnement ABY_TEST).
# Joue réellement : frappe, achète, ouvre chaque page, lance donjon/abysse/arène et capture l'écran.

var main
var n = 0
const OUT := "/tmp/shots/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = get_parent()
	_run.call_deferred()

func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img = get_viewport().get_texture().get_image()
	n += 1
	img.save_png(OUT + "%02d_%s.png" % [n, name])
	print("SHOT ", name)

func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func taps(sec: float, rate := 6.0) -> void:
	var t = 0.0
	while t < sec:
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = Vector2(500, 380)
		main._on_battle_input(ev)
		await wait(1.0 / rate)
		t += 1.0 / rate

func _run() -> void:
	var phase = OS.get_environment("ABY_TEST")
	await wait(1.0)
	if phase == "fresh":
		await shot("creation")
		main.pages._new_cls = "mage"
		main.pages.popup_create_hero()
		await shot("creation_mage")
		G.s.cls = "mage"
		G.set_name_checked("Testeur")
		G.mark()
		main.setup_hero()
		main.clear_overlay()
		await wait(0.5)
		await shot("debut_combat")
		await taps(6.0)
		await shot("combat_6s")
		for i in 40:
			for id in ["atk", "atk", "tap", "speed"]: G.buy_train(id, 1)
			await taps(0.5)
		await shot("apres_entrainement")
		print("STATE gi=", G.gi(), " lvl=", G.s.level, " gold=", G.s.gold)
	elif phase == "pages":
		# Profil avancé pour remplir toutes les pages
		G.s.cls = "barbare"
		G.set_name_checked("Testeur")
		main.setup_hero()
		main.clear_overlay()
		G.s.gold = 1e9
		G.s.gems = 2000
		G.s.ore = 50000
		G.s.souls = 500
		G.s.level = 60
		G.s.max_gi = 80
		G.s.run_max_gi = 45
		G.s.map = 5
		G.s.stage = 3
		G.s.keys = 5
		G.s.eggs = [3, 2, 2]
		for i in 25: G.add_item(G.make_item(40 + i, i % 6, 0.5))
		G.equip_best()
		for i in 6: G.hatch(i % 3)
		G.s.c.kills = 2500.0
		G.s.best = {"zombie": 1500.0, "squelette": 300.0, "fantome": 120.0, "orc": 40.0}
		G.s.secrets = {"s_nuit": true, "s_dore": true}
		G.mark()
		main.cur_theme = -1
		main._apply_theme()
		G.spawn()
		await wait(1.0)
		await taps(2.0)
		for p in ["train", "hero", "equip", "pets", "dj", "arena", "menu", "asc", "quests", "ach", "best", "secrets", "shop", "maps", "options", "rank"]:
			main.show_page(p)
			await wait(0.7)
			await shot("page_" + p)
		main.show_page("equip")
		await wait(0.3)
		main.pages.item_popup(G.s.inv[0])
		await shot("popup_objet")
		main.clear_overlay()
		main.pages._hatch(0)
		await shot("popup_eclosion")
		main.clear_overlay()
		main.pages.pet_popup(G.s.pets[0])
		await shot("popup_familier")
		main.clear_overlay()
		# Boss
		G.set_stage(5, 10)
		G.s.kills = 10
		G.spawn()
		await wait(1.5)
		await shot("boss")
		# Donjon
		G.stop_run()
		G.start_dungeon(D.DUNGEONS[0], 1)
		await taps(3.0)
		await shot("donjon")
		await taps(15.0, 8.0)
		await shot("donjon_fin")
		main.clear_overlay()
		# Abysse
		G.stop_run()
		G.start_abyss()
		await taps(4.0)
		await shot("abysse")
		G.abandon_run()
		await wait(0.5)
		main.clear_overlay()
		# Arène contre IA
		main.show_page("arena")
		main.pages.opps = G.bot_opponents()
		main.pages.refresh()
		await wait(0.5)
		await shot("arene_liste")
		main.pages.fight(main.pages.opps[0])
		await wait(2.0)
		await shot("arene_combat")
		await wait(25.0)
		await shot("arene_resultat")
		main.clear_overlay()
		# Ascension
		main.show_page("asc")
		main.pages._confirm_ascend()
		await shot("ascension_confirm")
		main.clear_overlay()
	print("TEST FINI")
	get_tree().quit()
