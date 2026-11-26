extends SceneTree
# Simulation d'équilibrage : un joueur automatique joue N heures.
func _init(): _go.call_deferred()
func _go():
	var G = root.get_node("G")
	G.headless_sim = true
	G.s = G.new_state(); G.s.name = "sim"; G.s.cls = "barbare"
	G.mark(); G.spawn()
	var hours := float(OS.get_environment("H") if OS.get_environment("H") != "" else "6")
	var dt := 0.1
	var t := 0.0
	var tap_acc := 0.0
	var stuck := 0.0
	var last_gi := 0
	var log_t := 0.0
	var fails := 0
	G.boss_failed.connect(func(): fails += 1)
	while t < hours * 3600.0:
		G.tick(dt)
		tap_acc += dt * 4.0
		while tap_acc >= 1.0: tap_acc -= 1.0; G.tap()
		for sk in ["frappe", "rage", "hate", "pluie"]: G.use_skill(sk)
		if int(t / dt) % 10 == 0:
			# achats
			for k in 3:
				var best = ""
				var bc = INF
				for id in ["atk", "tap", "speed", "crit", "greed"]:
					var cst = G.train_cost(id) * (1.0 if id == "atk" else (2.0 if id == "tap" else 4.0))
					if D.TRAIN[id].has("max") and G.s.train[id] >= D.TRAIN[id].max: continue
					if cst < bc: bc = cst; best = id
				G.buy_train(best, 1)
			if G.stat_points_free() > 0: G.alloc_stat("force", G.stat_points_free())
			for tl in D.TALENTS: G.buy_talent(tl)
			for r in D.RELICS: G.buy_relic(r)
			G.equip_best()
			for e in 3:
				while G.s.eggs[e] > 0: G.hatch(e)
			if not G.s.auto and fails > 0:
				G.challenge_boss(); fails = 0
			for d in D.DUNGEONS:
				if G.mode == "farm" and G.s.keys >= 1 and G.dungeon_unlocked(d): G.start_dungeon(d, G.dj_best(d) + 1 if randf() < 0.5 else max(1, G.dj_best(d)))
		var g = G.gi()
		if g > last_gi: last_gi = g; stuck = 0.0
		else: stuck += dt
		if stuck > 900.0 and G.souls_preview() >= max(10.0, G.s.souls * 0.5):
			print("SIM t=%.0fmin ASCEND run_max=%d souls+%s" % [t / 60.0, G.s.run_max_gi, G.fmt(G.souls_preview())])
			G.ascend(); stuck = 0.0; last_gi = 0
		t += dt
		log_t += dt
		if log_t >= float(OS.get_environment("LOG") if OS.get_environment("LOG") != "" else "900"):
			log_t = 0.0
			print("SIM t=%3dmin crit=%.2f critd=%.1f aps=%.1f tap=%s gi=%d max=%d lvl=%d atkL=%d dmg=%s hp=%s pow=%s gold=%s asc=%d souls=%s items=%d pets=%d dj=%s" % [int(t / 60), G.st.crit, G.st.critd, G.st.aps, G.fmt(G.st.tap), G.gi(), G.s.max_gi, G.s.level, G.s.train.atk, G.fmt(G.st.dmg), G.fmt(G.hp_at(G.gi())), G.fmt(G.st.power), G.fmt(G.s.gold), G.s.ascensions, G.fmt(G.s.souls), G.s.inv.size(), G.s.pets.size(), str(G.s.dj)])
	quit()
