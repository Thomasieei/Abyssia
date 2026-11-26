extends Node
# Cœur du jeu : état, formules, combat, butin, sauvegarde. Autoload « G ».

signal hit(amount: float, crit: bool, tap: bool)
signal monster_spawned
signal monster_died(gold: float, golden: bool)
signal boss_failed
signal run_ended(win: bool, text: String)
signal toast(text: String, color: Color)
signal changed  # ressources / stats modifiées (rafraîchir l'interface)
signal level_up(lvl: int)
signal loot(text: String, color: Color)

const SAVE_PATH := "user://abyssia_save.json"
const VERSION := 1
const SPAWN_DELAY := 0.35
const KILLS_PER_STAGE := 10
const INV_MAX := 60

var s: Dictionary = {}          # état sauvegardé
var st: Dictionary = {}         # stats calculées
var dirty = true
var mon: Dictionary = {}        # monstre courant
var mode = "farm"              # farm | dungeon | abyss
var run: Dictionary = {}        # donjon / abysse en cours
var spawn_wait = 0.0
var atk_acc = 0.0
var auto_tap_acc = 0.0
var save_acc = 0.0
var regen_acc = 0.0
var skills_cd = {}
var skills_on = {}
var tap_times: Array = []
var boss_tapped = false
var rng = RandomNumberGenerator.new()
var headless_sim = false
var offline_report: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	load_game()
	for sk in D.SKILLS:
		skills_cd[sk.id] = 0.0
		skills_on[sk.id] = 0.0

# ------------------------------------------------------------------ état
func new_state() -> Dictionary:
	return {
		"v": VERSION, "name": "", "cls": "", "created": Time.get_unix_time_from_system(),
		"gold": 0.0, "gems": 50.0, "souls": 0.0, "ore": 0.0, "keys": 3.0, "tickets": 5.0, "honor": 0.0,
		"level": 1, "xp": 0.0, "alloc": {"force": 0, "agi": 0, "chance": 0, "vit": 0},
		"train": {"atk": 0, "tap": 0, "speed": 0, "crit": 0, "greed": 0},
		"map": 1, "stage": 1, "kills": 0, "max_gi": 1, "run_max_gi": 1, "best_gi": 1, "auto": true,
		"equip": {}, "inv": [], "uid": 1, "auto_salvage": -1,
		"pets": [], "pet_eq": [], "eggs": [0, 0, 0],
		"talents": {}, "talent_bonus": 0, "relics": {}, "honor_up": {},
		"ascensions": 0, "asc_time": Time.get_unix_time_from_system(),
		"dj": {}, "abyss_best": 0,
		"best": {}, "ach": {}, "secrets": {},
		"c": {}, "boost_gold": 0.0, "boost_dmg": 0.0,
		"quests": {"day": "", "list": []},
		"pvp": {"id": "", "secret": "", "rating": 1000, "wins": 0, "losses": 0},
		"seen": Time.get_unix_time_from_system(),
		"sound": true,
	}

func c(key: String) -> float:
	return float(s.c.get(key, 0.0))

func add_c(key: String, v: float = 1.0) -> void:
	s.c[key] = c(key) + v

func load_game() -> void:
	s = new_state()
	if FileAccess.file_exists(SAVE_PATH):
		var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		if typeof(data) == TYPE_DICTIONARY:
			for k in data.keys():
				s[k] = data[k]
	_fix_types()
	dirty = true
	recalc()
	_compute_offline()
	ensure_quests()
	spawn()

func _fix_types() -> void:
	for k in ["level", "map", "stage", "kills", "max_gi", "run_max_gi", "best_gi", "uid", "ascensions", "abyss_best", "talent_bonus", "auto_salvage"]:
		s[k] = int(s[k])
	for k in s.train.keys(): s.train[k] = int(s.train[k])
	for k in s.alloc.keys(): s.alloc[k] = int(s.alloc[k])
	for k in s.talents.keys(): s.talents[k] = int(s.talents[k])
	for k in s.relics.keys(): s.relics[k] = int(s.relics[k])
	for k in s.dj.keys(): s.dj[k] = int(s.dj[k])
	for i in 3: s.eggs[i] = int(s.eggs[i])
	for p in s.pets:
		for k in ["uid", "sp", "rar", "stars", "lvl"]: p[k] = int(p[k])
	var eq = []
	for u in s.pet_eq: eq.append(int(u))
	s.pet_eq = eq
	for it in s.inv: _fix_item(it)
	for k in s.equip.keys(): _fix_item(s.equip[k])
	s.pvp.rating = int(s.pvp.rating)

func _fix_item(it: Dictionary) -> void:
	for k in ["uid", "rar", "ilvl", "plus", "icon"]: it[k] = int(it[k])

func save_game() -> void:
	if headless_sim: return
	s.seen = Time.get_unix_time_from_system()
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(s))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_compute_offline()

# ------------------------------------------------------------------ formats
const SUFFIX := ["", "K", "M", "Md", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
static func fmt(n: float) -> String:
	if n < 0: return "-" + fmt(-n)
	if is_nan(n) or is_inf(n) or n > 1e300: return "∞"
	if n < 1000.0:
		if n < 10.0 and n != floor(n): return "%.1f" % n
		return str(int(floor(n)))
	var e = int(floor(log(n) / log(1000.0)))
	var v = n / pow(1000.0, e)
	var suf = ""
	if e < SUFFIX.size(): suf = SUFFIX[e]
	else:
		var k = e - SUFFIX.size()
		suf = char(97 + int(k / 26) % 26) + char(97 + k % 26)
	if v >= 100: return "%d%s" % [int(v), suf]
	if v >= 10: return "%.1f%s" % [v, suf]
	return "%.2f%s" % [v, suf]

static func fmt_time(sec: float) -> String:
	sec = max(0.0, sec)
	var h = int(sec / 3600.0)
	var m = int(fmod(sec, 3600.0) / 60.0)
	var x = int(fmod(sec, 60.0))
	if h > 0: return "%dh%02d" % [h, m]
	if m > 0: return "%dm%02d" % [m, x]
	return "%ds" % x

# ------------------------------------------------------------------ progression : formules
func gi() -> int:
	return (s.map - 1) * 10 + s.stage

static func map_info(m: int) -> Dictionary:
	var base: Dictionary = D.MAPS[(m - 1) % D.MAPS.size()]
	var info = base.duplicate()
	var cycle = int((m - 1) / D.MAPS.size())
	info["display"] = base.name if cycle == 0 else "%s — Cauchemar %d" % [base.name, cycle]
	return info

static func hp_at(g: float) -> float:
	return 10.0 * pow(1.9, g - 1.0)

static func gold_at(g: float) -> float:
	return 1.5 * pow(1.22, g - 1.0)

static func xp_at(g: float) -> float:
	return 2.0 * pow(1.12, g - 1.0)

func xp_need(lvl: int = -1) -> float:
	if lvl < 0: lvl = s.level
	return 12.0 * pow(1.15, lvl - 1) + 8.0 * lvl

func train_cost(id: String, lvl: int = -1) -> float:
	if lvl < 0: lvl = s.train[id]
	var t: Dictionary = D.TRAIN[id]
	return t.cost * pow(t.grow, lvl)

func relic_lvl(id: String) -> int: return int(s.relics.get(id, 0))
func talent_lvl(id: String) -> int: return int(s.talents.get(id, 0))

func relic_cost(r: Dictionary) -> float:
	return ceil(r.cost * pow(r.grow, relic_lvl(r.id)))

func talent_points_total() -> int:
	return int(s.level / 3) + int(s.talent_bonus)

func talent_points_free() -> int:
	var used = 0
	for k in s.talents.keys(): used += int(s.talents[k])
	return talent_points_total() - used

func stat_points_free() -> int:
	var used = 0
	for k in s.alloc.keys(): used += int(s.alloc[k])
	return (s.level - 1) * 3 - used

func keys_max() -> int: return 5 + relic_lvl("r_cle")
func key_regen() -> float: return 1800.0 * (1.0 - 0.06 * relic_lvl("r_cle"))

# ------------------------------------------------------------------ stats
func _pct() -> Dictionary:
	var p = {}
	for k in D.SUBS.keys(): p[k] = 0.0
	p["dodge"] = 0.0
	p["pet"] = 0.0
	p["forge"] = 0.0
	p["souls"] = 0.0
	p["time"] = 0.0
	var cl: Dictionary = D.CLASSES.get(s.cls, {})
	for k in ["dmg", "tap", "critd", "crit", "gold", "aps", "boss", "def", "dodge"]:
		if cl.has(k): p[k] += float(cl[k])
	for slot in s.equip.keys():
		var it: Dictionary = s.equip[slot]
		for sub in item_stats(it):
			p[sub[0]] += sub[1]
	for sc in D.SECRETS:
		if s.secrets.has(sc.id) and sc.stat != "":
			p[sc.stat] += sc.val
	var pet_mul = (1.0 + 0.12 * relic_lvl("r_bete")) * (1.0 + p.pet / 100.0)
	for u in s.pet_eq:
		var pet = pet_by_uid(u)
		if pet: p[D.PETS[pet.sp].stat] += pet_value(pet) * pet_mul
	p.dmg += 8.0 * talent_lvl("t_lame") + float(s.ach.size())
	p.aps += 3.0 * talent_lvl("t_furie")
	p.boss += 10.0 * talent_lvl("t_brise")
	p.crit += 0.5 * talent_lvl("t_oeil")
	p.critd += 15.0 * talent_lvl("t_mortel")
	p.tap += 20.0 * talent_lvl("t_doigt")
	p.gold += 10.0 * talent_lvl("t_or")
	p.time += float(talent_lvl("t_temps") + relic_lvl("r_sablier"))
	# Bestiaire : chaque palier franchi = +4 % dégâts et +4 % or.
	var tiers = bestiary_tiers_total()
	p.dmg += 4.0 * tiers
	p.gold += 4.0 * tiers
	# Points de caractéristiques.
	p.dmg += 1.0 * s.alloc.force
	p.aps += 1.0 * s.alloc.agi
	p.crit += 0.2 * s.alloc.chance
	p.critd += 2.0 * s.alloc.chance
	p.hp += 3.0 * s.alloc.vit
	p.def += 0.3 * s.alloc.vit
	return p

func recalc() -> void:
	var p = _pct()
	var lv: int = s.level
	var tl: int = s.train.atk
	var base = 4.0 + 1.0 * lv + 2.0 * s.alloc.force
	var train_mul = (1.0 + tl * 0.1) * pow(2.0, floor(tl / 10.0))
	var dmg = base * train_mul * (1.0 + p.dmg / 100.0) * pow(1.01, lv) * pow(1.2, relic_lvl("r_lame")) * pow(1.10, talent_lvl("t_titan"))
	if s.boost_dmg > 0: dmg *= 2.0
	var aps = min(12.0, 1.0 * (1.0 + (s.train.speed * 2.0 + p.aps) / 100.0))
	var crit = min(0.5, 0.05 + (s.train.crit * 0.3 + p.crit + relic_lvl("r_oeil")) / 100.0)
	var critd = 2.0 + (s.train.crit * 4.0 + p.critd) / 100.0
	var tt: int = s.train.tap
	var tapm = 0.4 * (1.0 + tt * 0.06) * (1.0 + p.tap / 100.0) * pow(1.25, relic_lvl("r_main"))
	var gr: int = s.train.greed
	var gold_mul = (1.0 + p.gold / 100.0) * (1.0 + gr * 0.08) * pow(1.18, relic_lvl("r_bourse"))
	if s.boost_gold > 0: gold_mul *= 2.0
	st = {
		"dmg": dmg, "aps": aps, "crit": crit, "critd": critd, "tap": dmg * tapm,
		"gold": gold_mul, "xp": (1.0 + p.xp / 100.0) * pow(1.2, relic_lvl("r_savoir")),
		"boss": 1.0 + p.boss / 100.0, "time": p.time, "forge": p.forge / 100.0, "souls": p.souls / 100.0,
		"item": 1.0 + 0.05 * talent_lvl("t_butin"), "egg": 1.0 + 0.08 * talent_lvl("t_oeufs"), "ore": 1.0 + 0.10 * talent_lvl("t_veine"),
		"hp_pct": p.hp, "def": min(60.0, p.def), "dodge": min(30.0, p.dodge + s.alloc.agi * 0.1),
		"autotap": float(talent_lvl("t_auto")),
	}
	st["power"] = dmg * aps * (1.0 + crit * (critd - 1.0))
	dirty = false

func power() -> float:
	if dirty: recalc()
	return st.power

func mark() -> void:
	dirty = true
	recalc()
	changed.emit()

# ------------------------------------------------------------------ monstres
func spawn() -> void:
	var m = {}
	if mode == "farm":
		var info = map_info(s.map)
		var g = gi()
		var boss: bool = s.stage == 10 and s.kills >= KILLS_PER_STAGE
		var id: String = info.boss if boss else info.mobs[rng.randi() % info.mobs.size()]
		var hp = hp_at(g)
		var golden = false
		var elite = false
		if boss:
			hp *= 7.0
		else:
			var r = rng.randf()
			if r < 0.015: golden = true; hp *= 1.5
			elif r < 0.055: elite = true; hp *= 3.0
		m = {"id": id, "hp": hp, "max": hp, "boss": boss, "golden": golden, "elite": elite, "g": g, "timer": 0.0, "tmax": 0.0}
		if boss:
			m.tmax = 30.0 + st.time
			m.timer = m.tmax
			boss_tapped = false
	elif mode == "dungeon":
		var d: Dictionary = run.d
		var last: bool = run.room == d.rooms
		var g2: float = d.unlock + run.diff * 3
		var hp2 = hp_at(g2) * pow(1.14, run.room - 1) * (6.0 if last else 1.8)
		var id2: String = d.boss if last else d.mobs[rng.randi() % d.mobs.size()]
		m = {"id": id2, "hp": hp2, "max": hp2, "boss": last, "golden": false, "elite": false, "g": g2, "tmax": (40.0 if last else 20.0) + st.time * 0.5}
		m.timer = m.tmax
		boss_tapped = false
	elif mode == "abyss":
		var f: int = run.floor
		var g3 = 8.0 + f * 2.2
		var hp3 = hp_at(g3) * (4.0 if f % 10 == 0 else 1.6)
		var pool = ["brute", "rodeur", "dragon", "sq_mage", "vampire", "sq_guerrier"]
		m = {"id": pool[f % pool.size()] if f % 10 != 0 else "dragon", "hp": hp3, "max": hp3, "boss": f % 10 == 0, "golden": false, "elite": false, "g": g3, "tmax": 15.0 + st.time * 0.5}
		m.timer = m.tmax
	mon = m
	monster_spawned.emit()

# ------------------------------------------------------------------ boucle
func _process(delta: float) -> void:
	if headless_sim: return
	tick(delta)

func tick(delta: float) -> void:
	if dirty: recalc()
	_regen(delta)
	for k in skills_cd.keys():
		skills_cd[k] = max(0.0, skills_cd[k] - delta)
		if skills_on[k] > 0.0:
			skills_on[k] = max(0.0, skills_on[k] - delta)
			if skills_on[k] == 0.0 and k in ["pluie"]: mark()
	if s.boost_gold > 0:
		s.boost_gold = max(0.0, s.boost_gold - delta)
		if s.boost_gold == 0: mark()
	if s.boost_dmg > 0:
		s.boost_dmg = max(0.0, s.boost_dmg - delta)
		if s.boost_dmg == 0: mark()
	save_acc += delta
	if save_acc > 15.0:
		save_acc = 0.0
		save_game()
	if spawn_wait > 0.0:
		spawn_wait -= delta
		if spawn_wait <= 0.0: spawn()
		return
	if mon.is_empty(): return
	if mon.tmax > 0.0:
		mon.timer -= delta
		if mon.timer <= 0.0:
			_timeout()
			return
	var aps: float = st.aps * (2.0 if skills_on.get("hate", 0.0) > 0.0 else 1.0)
	atk_acc += delta * aps
	while atk_acc >= 1.0 and not mon.is_empty() and spawn_wait <= 0.0:
		atk_acc -= 1.0
		_deal(st.dmg, false)
	if st.autotap > 0.0:
		auto_tap_acc += delta * st.autotap
		while auto_tap_acc >= 1.0 and spawn_wait <= 0.0 and not mon.is_empty():
			auto_tap_acc -= 1.0
			_deal(st.tap, true, true)

func _regen(delta: float) -> void:
	regen_acc += delta
	if regen_acc < 1.0: return
	var dt = regen_acc
	regen_acc = 0.0
	var now = Time.get_unix_time_from_system()
	if s.keys < keys_max():
		s.key_acc = float(s.get("key_acc", 0.0)) + dt
		if s.key_acc >= key_regen():
			s.key_acc = 0.0
			s.keys += 1
			changed.emit()
	else:
		s.key_acc = 0.0
	if s.tickets < 10:
		s.ticket_acc = float(s.get("ticket_acc", 0.0)) + dt
		if s.ticket_acc >= 3600.0:
			s.ticket_acc = 0.0
			s.tickets += 1
	# Découverte nocturne
	if not s.secrets.has("s_nuit"):
		var h: int = Time.get_datetime_dict_from_system().hour
		if h >= 2 and h < 5: discover("s_nuit")
	if s.gold >= 1e9 and not s.secrets.has("s_riche"): discover("s_riche")
	var _n = now

func tap() -> void:
	if mon.is_empty() or spawn_wait > 0.0: return
	add_c("taps")
	boss_tapped = true
	var now = Time.get_ticks_msec() / 1000.0
	tap_times.append(now)
	while tap_times.size() > 0 and now - tap_times[0] > 10.0: tap_times.pop_front()
	if tap_times.size() >= 50: discover("s_frenesie")
	_deal(st.tap, true)

func _deal(base: float, is_tap: bool, silent_tap := false) -> void:
	if mon.is_empty(): return
	var d = base
	if skills_on.get("rage", 0.0) > 0.0: d *= 3.0
	if mon.boss: d *= st.boss
	var crit = rng.randf() < st.crit
	if crit:
		d *= st.critd
		s.crit_streak = int(s.get("crit_streak", 0)) + 1
		if s.crit_streak >= 10: discover("s_millier")
	else:
		s.crit_streak = 0
	mon.hp -= d
	hit.emit(d, crit, is_tap and not silent_tap)
	if mon.hp <= 0.0: _kill()

func use_skill(id: String) -> bool:
	if mon.is_empty() and id == "frappe": return false
	var sk: Dictionary = {}
	for x in D.SKILLS:
		if x.id == id: sk = x
	if s.level < sk.lvl or skills_cd[id] > 0.0: return false
	skills_cd[id] = sk.cd
	add_c("skills")
	if id == "frappe":
		_deal(st.dmg * (40.0 + 10.0 * talent_lvl("t_echo")), false)
	else:
		skills_on[id] = sk.dur + (talent_lvl("t_rage") if id in ["rage", "hate"] else 0)
		if id == "pluie": mark()
	return true

func gold_mult_now() -> float:
	return st.gold * (4.0 if skills_on.get("pluie", 0.0) > 0.0 else 1.0)

func _kill() -> void:
	var m = mon
	mon = {}
	spawn_wait = SPAWN_DELAY
	atk_acc = 0.0
	add_c("kills")
	var b: Dictionary = s.get("best", {})
	b[m.id] = float(b.get(m.id, 0.0)) + 1.0
	s.best = b
	if mode == "farm":
		_kill_farm(m)
	elif mode == "dungeon":
		_kill_dungeon(m)
	elif mode == "abyss":
		_kill_abyss(m)
	_check_achievements_silent()

func _gain_xp(v: float) -> void:
	s.xp += v
	var up = false
	while s.xp >= xp_need():
		s.xp -= xp_need()
		s.level += 1
		up = true
	if up:
		level_up.emit(s.level)
		mark()

func _kill_farm(m: Dictionary) -> void:
	var g: float = m.g
	var gold = gold_at(g) * gold_mult_now()
	if m.boss: gold *= 10.0
	if m.golden:
		gold *= 8.0
		add_c("golden")
		if c("golden") >= 10: discover("s_dore")
	if m.elite: gold *= 2.0
	s.gold += gold
	add_c("gold_total", gold)
	_gain_xp(xp_at(g) * st.xp * (5.0 if m.boss else 1.0))
	if s.map == 1 and s.max_gi > 40:
		add_c("nostalgie")
		if c("nostalgie") >= 100: discover("s_nostalgie")
	# Butin
	var item_ch = 0.025 * st.item
	if m.boss or m.elite or rng.randf() < item_ch:
		var min_r = 1 if m.boss else 0
		add_item(make_item(int(g), min_r, 0.0))
	if rng.randf() < (0.004 if not m.boss else 0.12) * st.egg:
		var e = rng.randi() % 3
		s.eggs[e] += 1
		loot.emit("Œuf trouvé : " + D.EGGS[e].name, Color("ffd76a"))
	if rng.randf() < 0.08 or m.boss:
		var o = ceil((1.0 + g / 8.0) * st.ore * (5.0 if m.boss else 1.0))
		s.ore += o
	if m.boss:
		add_c("bosses")
		if not boss_tapped: discover("s_pacifiste")
		var first: bool = not s.has("boss_first") or not (str(s.map) in s.boss_first)
		if not s.has("boss_first"): s.boss_first = {}
		if first:
			s.boss_first[str(s.map)] = true
			s.gems += 15 + 5 * s.map
			s.keys += 1
			toast.emit("Boss vaincu pour la 1re fois ! +%d gemmes, +1 clé" % (15 + 5 * s.map), Color("ffd76a"))
		elif rng.randf() < 0.2:
			s.keys = min(s.keys + 1, keys_max() + 5)
		s.map += 1
		s.stage = 1
		s.kills = 0
		toast.emit("Nouvelle carte : " + map_info(s.map).display, Color("8fe3ff"))
	else:
		s.kills += 1
		if s.kills >= KILLS_PER_STAGE and s.auto:
			if s.stage < 10:
				s.stage += 1
				s.kills = 0
	var g_now = gi()
	if g_now > s.max_gi: s.max_gi = g_now
	if g_now > s.run_max_gi:
		s.run_max_gi = g_now
		if g_now >= 30 and Time.get_unix_time_from_system() - float(s.asc_time) < 600 and s.ascensions > 0: discover("s_eclair")
	if g_now > s.best_gi: s.best_gi = g_now
	monster_died.emit(gold, m.golden)

func _timeout() -> void:
	var m = mon
	mon = {}
	spawn_wait = SPAWN_DELAY * 2
	if mode == "farm":
		add_c("boss_fails")
		if c("boss_fails") >= 25: discover("s_tetu")
		s.auto = false
		s.stage = 9
		s.kills = 0
		boss_failed.emit()
		toast.emit("Le boss t'a échappé… Renforce-toi puis retente !", Color("ff7a7a"))
	elif mode == "dungeon":
		_end_dungeon(false)
	elif mode == "abyss":
		_end_abyss()
	var _x = m

func challenge_boss() -> void:
	if mode != "farm": return
	s.auto = true
	s.stage = 10
	s.kills = KILLS_PER_STAGE
	spawn_wait = 0.0
	spawn()

func set_stage(map: int, stage: int) -> void:
	if (map - 1) * 10 + stage > s.max_gi: return
	s.map = map
	s.stage = stage
	s.kills = 0
	if mode == "farm":
		spawn_wait = 0.0
		spawn()
	changed.emit()

# ------------------------------------------------------------------ objets
func make_item(ilvl: int, min_rar: int, luck: float, slot: String = "") -> Dictionary:
	var w = D.RARITY_WEIGHTS.duplicate()
	for i in range(2, w.size()): w[i] *= (1.0 + luck)
	var tot = 0.0
	for x in w: tot += x
	var r = rng.randf() * tot
	var rar = 0
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			rar = i
			break
	rar = max(rar, min_rar)
	if slot == "": slot = D.SLOTS[rng.randi() % D.SLOTS.size()]
	var subs = []
	var pool: Array = D.SUBS.keys()
	pool.erase(D.SLOT_MAIN[slot])
	pool.shuffle()
	var nsub = clampi(rar, 0, 4)
	for i in nsub:
		subs.append([pool[i], rng.randf_range(0.5, 1.0)])
	var icons: Array = D.SLOT_ICONS[slot]
	var names: Array = D.ITEM_BASE[slot]
	var it = {"uid": s.uid, "slot": slot, "rar": rar, "ilvl": max(1, ilvl), "plus": 0, "subs": subs,
		"name": "%s %s" % [names[rng.randi() % names.size()], D.ITEM_PREFIX[rar].to_lower()], "icon": rng.randi() % icons.size(), "roll": rng.randf_range(0.85, 1.0)}
	s.uid += 1
	if rar == 5: discover("s_mythe")
	return it

func item_scale(it: Dictionary) -> float:
	return D.RARITY_MULT[int(it.rar)] * (1.0 + float(it.ilvl) * 0.09) * (1.0 + 0.12 * float(it.plus))

func item_stats(it: Dictionary) -> Array:
	var out = []
	var sc = item_scale(it)
	var main: String = D.SLOT_MAIN[it.slot]
	var mb: float = D.SUBS[main].base * (2.5 if main == "dmg" else 1.5)
	out.append([main, mb * sc * float(it.get("roll", 1.0))])
	for sub in it.subs:
		out.append([sub[0], D.SUBS[sub[0]].base * sc * 0.6 * float(sub[1])])
	return out

func item_score(it: Dictionary) -> float:
	var sc = 0.0
	for x in item_stats(it):
		sc += x[1] / D.SUBS[x[0]].base
	return sc

func add_item(it: Dictionary) -> void:
	add_c("items")
	if int(it.rar) <= s.auto_salvage:
		salvage_item(it, false)
		return
	if s.inv.size() >= INV_MAX:
		# Sac plein : on recycle le moins bon.
		var worst = 0
		for i in s.inv.size():
			if item_score(s.inv[i]) < item_score(s.inv[worst]): worst = i
		if item_score(s.inv[worst]) < item_score(it):
			salvage_item(s.inv[worst], false)
			s.inv.remove_at(worst)
		else:
			salvage_item(it, false)
			return
	s.inv.append(it)
	var better = not s.equip.has(it.slot) or item_score(it) > item_score(s.equip[it.slot])
	if int(it.rar) >= 2 or better:
		loot.emit(("▲ " if better else "") + it.name + " (" + D.RARITY_NAMES[int(it.rar)] + ")", D.RARITY_COLORS[int(it.rar)])

func salvage_value(it: Dictionary) -> float:
	return (pow(int(it.rar) + 1, 2) * 2.0 + int(it.plus) * 4.0) * (1.0 + float(it.ilvl) / 30.0)

func salvage_item(it: Dictionary, remove := true) -> void:
	s.ore += ceil(salvage_value(it) * st.ore)
	add_c("salvaged")
	if remove:
		for i in s.inv.size():
			if s.inv[i].uid == it.uid:
				s.inv.remove_at(i)
				break

func salvage_all_below(rar: int) -> int:
	var n = 0
	var keep = []
	for it in s.inv:
		if int(it.rar) <= rar:
			salvage_item(it, false)
			n += 1
		else:
			keep.append(it)
	s.inv = keep
	mark()
	return n

func equip_item(it: Dictionary) -> void:
	var slot: String = it.slot
	for i in s.inv.size():
		if s.inv[i].uid == it.uid:
			s.inv.remove_at(i)
			break
	if s.equip.has(slot): s.inv.append(s.equip[slot])
	s.equip[slot] = it
	mark()

func equip_best() -> int:
	var n = 0
	for slot in D.SLOTS:
		var best = s.equip.get(slot)
		var cand = null
		for it in s.inv:
			if it.slot == slot and (best == null or item_score(it) > item_score(best)):
				best = it
				cand = it
		if cand != null:
			equip_item(cand)
			n += 1
	return n

func forge_cost(it: Dictionary) -> Array:
	var p: int = it.plus
	var ore = ceil(6.0 * (p + 1) * (int(it.rar) + 1) * (1.0 + float(it.ilvl) / 40.0))
	var gold = gold_at(float(it.ilvl)) * 15.0 * (p + 1)
	return [ore, gold]

func forge_chance(it: Dictionary) -> float:
	var p: int = it.plus
	if p < 5: return 1.0
	return clampf(1.0 - (p - 4) * 0.07 + st.forge, 0.2, 1.0)

func forge(it: Dictionary) -> int:  # 1 = réussi, 0 = raté, -1 = impossible
	if int(it.plus) >= 20: return -1
	var cost = forge_cost(it)
	if s.ore < cost[0] or s.gold < cost[1]: return -1
	s.ore -= cost[0]
	s.gold -= cost[1]
	add_c("forges")
	if rng.randf() <= forge_chance(it):
		it.plus = int(it.plus) + 1
		mark()
		return 1
	add_c("forge_fails")
	if c("forge_fails") >= 10: discover("s_maudit")
	changed.emit()
	return 0

func reroll(it: Dictionary) -> bool:
	if s.gems < 30 or it.subs.is_empty(): return false
	s.gems -= 30
	var pool: Array = D.SUBS.keys()
	pool.erase(D.SLOT_MAIN[it.slot])
	pool.shuffle()
	var subs = []
	for i in it.subs.size():
		subs.append([pool[i], rng.randf_range(0.5, 1.0)])
	it.subs = subs
	mark()
	return true

# ------------------------------------------------------------------ entraînement / stats / talents / reliques
func buy_train(id: String, times: int = 1) -> int:
	var n = 0
	var t: Dictionary = D.TRAIN[id]
	for i in times:
		if t.has("max") and s.train[id] >= t.max: break
		var cost = train_cost(id)
		if s.gold < cost: break
		s.gold -= cost
		s.train[id] += 1
		n += 1
	if n > 0:
		add_c("trains", n)
		mark()
	return n

func alloc_stat(k: String, n: int = 1) -> void:
	n = min(n, stat_points_free())
	if n <= 0: return
	s.alloc[k] += n
	mark()

func reset_stats() -> bool:
	if s.gems < 50: return false
	s.gems -= 50
	for k in s.alloc.keys(): s.alloc[k] = 0
	mark()
	return true

func talent_available(t: Dictionary) -> bool:
	var prev = null
	for x in D.TALENTS:
		if x.id == t.id: break
		if x.br == t.br: prev = x
	return prev == null or talent_lvl(prev.id) >= 5

func buy_talent(t: Dictionary) -> bool:
	if talent_points_free() <= 0 or talent_lvl(t.id) >= t.max or not talent_available(t): return false
	s.talents[t.id] = talent_lvl(t.id) + 1
	mark()
	return true

func reset_talents() -> bool:
	if s.gems < 100: return false
	s.gems -= 100
	s.talents = {}
	mark()
	return true

func buy_relic(r: Dictionary) -> bool:
	if r.max > 0 and relic_lvl(r.id) >= r.max: return false
	var cost = relic_cost(r)
	if s.souls < cost: return false
	s.souls -= cost
	s.relics[r.id] = relic_lvl(r.id) + 1
	mark()
	return true

# ------------------------------------------------------------------ ascension
func souls_preview() -> float:
	var g: float = s.run_max_gi
	if g < 30: return 0.0
	return floor(0.5 * pow(g / 10.0, 3.5) * pow(1.04, g) * (1.0 + 0.12 * relic_lvl("r_ame") + st.souls))

func ascend() -> bool:
	var gain = souls_preview()
	if gain <= 0: return false
	s.souls += gain
	s.ascensions += 1
	s.gold = 0.0
	for k in s.train.keys(): s.train[k] = 0
	var echo = relic_lvl("r_echo")
	if echo > 0: s.gold = gold_at(4.0 * echo) * 150.0
	s.map = 1
	s.stage = 1
	s.kills = 0
	s.run_max_gi = 1
	s.auto = true
	s.asc_time = Time.get_unix_time_from_system()
	stop_run()
	mark()
	toast.emit("Ascension ! +%s âmes" % fmt(gain), Color("c8a2ff"))
	save_game()
	return true

# ------------------------------------------------------------------ familiers
func pet_by_uid(u: int):
	for p in s.pets:
		if int(p.uid) == u: return p
	return null

func pet_value(p: Dictionary) -> float:
	var stat: String = D.PETS[p.sp].stat
	return D.PET_STAT_BASE[stat] * D.RARITY_MULT[p.rar] * p.stars * (1.0 + 0.08 * (p.lvl - 1))

func hatch(egg: int) -> Dictionary:
	if s.eggs[egg] <= 0: return {}
	s.eggs[egg] -= 1
	var w = [600.0, 280.0, 90.0, 25.0, 4.5, 0.5]
	var tot = 0.0
	for x in w: tot += x
	var r = rng.randf() * tot
	var rar = 0
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			rar = i
			break
	var species = []
	for i in D.PETS.size():
		if D.PETS[i].egg == egg: species.append(i)
	var p = {"uid": s.uid, "sp": species[rng.randi() % species.size()], "rar": rar, "stars": 1, "lvl": 1}
	s.uid += 1
	s.pets.append(p)
	add_c("eggs")
	if s.pet_eq.size() < 3: s.pet_eq.append(p.uid)
	var eggs_seen = {}
	for q in s.pets: eggs_seen[D.PETS[q.sp].egg] = true
	if eggs_seen.size() >= 3: discover("s_trio")
	mark()
	return p

func toggle_pet(p: Dictionary) -> void:
	var u: int = p.uid
	if u in s.pet_eq: s.pet_eq.erase(u)
	elif s.pet_eq.size() < 3: s.pet_eq.append(u)
	else:
		s.pet_eq.pop_front()
		s.pet_eq.append(u)
	mark()

func pet_lvl_cost(p: Dictionary) -> float:
	return 40.0 * pow(1.35, p.lvl) * (p.rar + 1)

func pet_level_up(p: Dictionary) -> bool:
	if p.lvl >= 50: return false
	var cost = pet_lvl_cost(p)
	if s.ore < cost: return false
	s.ore -= cost
	p.lvl += 1
	mark()
	return true

func fuse_candidates(p: Dictionary) -> Array:
	var out = []
	for q in s.pets:
		if q.uid != p.uid and q.sp == p.sp and q.rar == p.rar and q.stars == p.stars: out.append(q)
	return out

func fuse(p: Dictionary) -> bool:
	if p.stars >= 5 and p.rar >= 5: return false
	var c2 = fuse_candidates(p)
	if c2.size() < 2: return false
	for i in 2:
		s.pets.erase(c2[i])
		s.pet_eq.erase(int(c2[i].uid))
	if p.stars >= 5:
		p.rar += 1
		p.stars = 1
	else:
		p.stars += 1
	p.lvl = max(p.lvl, max(int(c2[0].lvl), int(c2[1].lvl)))
	mark()
	return true

# ------------------------------------------------------------------ donjons & abysse
func dungeon_unlocked(d: Dictionary) -> bool:
	return s.max_gi >= d.unlock

func dj_best(d: Dictionary) -> int:
	return int(s.dj.get(d.id, 0))

func start_dungeon(d: Dictionary, diff: int) -> bool:
	if mode != "farm" or s.keys < 1 or not dungeon_unlocked(d) or diff > dj_best(d) + 1: return false
	s.keys -= 1
	mode = "dungeon"
	run = {"d": d, "diff": diff, "room": 1}
	spawn_wait = 0.6
	mon = {}
	changed.emit()
	return true

func _kill_dungeon(m: Dictionary) -> void:
	var gain = gold_at(float(m.g)) * gold_mult_now() * 2.0
	s.gold += gain
	add_c("gold_total", gain)
	_gain_xp(xp_at(float(m.g)) * st.xp * 2.0)
	if run.room >= run.d.rooms:
		_end_dungeon(true)
	else:
		run.room += 1
		monster_died.emit(gain, false)

func _end_dungeon(win: bool) -> void:
	var d: Dictionary = run.d
	var diff: int = run.diff
	var txt = ""
	if win:
		add_c("dungeons")
		if diff > dj_best(d): s.dj[d.id] = diff
		var r: String = d.reward
		var lines = []
		match r:
			"ore":
				var o = ceil(40.0 * diff * (1.0 + d.unlock / 10.0) * st.ore)
				s.ore += o
				lines.append("+%s minerai" % fmt(o))
			"eggs":
				var n = 1 + int(diff / 3)
				for i in n: s.eggs[rng.randi() % 3] += 1
				lines.append("+%d œuf(s)" % n)
			"items":
				for i in 2 + int(diff / 4):
					var it = make_item(d.unlock + diff * 3, 2, 1.0 + diff * 0.2)
					add_item(it)
					lines.append(it.name)
			"talent":
				var t = 1 + int(diff / 4)
				s.talent_bonus += t
				lines.append("+%d point(s) de talent" % t)
			"gems":
				var gm = 40 + 15 * diff
				s.gems += gm
				var gg = gold_at(float(s.max_gi)) * 60.0 * diff
				s.gold += gg
				lines.append("+%d gemmes, +%s or" % [gm, fmt(gg)])
			"souls":
				var so = 5.0 + 3.0 * diff
				s.souls += so
				lines.append("+%s âmes" % fmt(so))
				if rng.randf() < 0.1 + diff * 0.01:
					var it2 = make_item(d.unlock + diff * 3, 5, 0.0)
					add_item(it2)
					lines.append("OBJET MYTHIQUE : " + it2.name)
				else:
					var it3 = make_item(d.unlock + diff * 3, 3, 2.0)
					add_item(it3)
					lines.append(it3.name)
		s.gems += 5
		txt = "%s — difficulté %d terminée !\n%s\n+5 gemmes" % [d.name, diff, "\n".join(lines)]
	else:
		var o2 = ceil(3.0 * run.room * diff * st.ore)
		s.ore += o2
		txt = "Échec dans la salle %d/%d de %s.\nConsolation : +%s minerai" % [run.room, d.rooms, d.name, fmt(o2)]
	stop_run()
	mark()
	run_ended.emit(win, txt)
	save_game()

func start_abyss() -> bool:
	if mode != "farm" or s.max_gi < 20: return false
	mode = "abyss"
	run = {"floor": 1}
	add_c("abyss")
	spawn_wait = 0.6
	mon = {}
	changed.emit()
	return true

func _kill_abyss(_m: Dictionary) -> void:
	var f: int = run.floor
	if f > s.abyss_best:
		s.abyss_best = f
		s.gems += 3
		if f % 10 == 0:
			s.eggs[rng.randi() % 3] += 1
			s.souls += floor(f / 5.0)
			loot.emit("Palier %d de l'Abysse : œuf + âmes !" % f, Color("c8a2ff"))
		if f >= 50: discover("s_abime")
	run.floor = f + 1
	monster_died.emit(0.0, false)

func _end_abyss() -> void:
	var f: int = run.floor
	var txt = "L'Abysse t'a vaincu à l'étage %d.\nRecord : étage %d" % [f, s.abyss_best]
	stop_run()
	mark()
	run_ended.emit(true, txt)
	save_game()

func stop_run() -> void:
	mode = "farm"
	run = {}
	mon = {}
	spawn_wait = 0.4

func abandon_run() -> void:
	if mode == "dungeon": _end_dungeon(false)
	elif mode == "abyss": _end_abyss()

# ------------------------------------------------------------------ bestiaire, succès, secrets, quêtes
func bestiary_tier(id: String) -> int:
	var k: float = float(s.best.get(id, 0.0))
	var t = 0
	for x in D.BESTIARY_TIERS:
		if k >= x: t += 1
	return t

func bestiary_tiers_total() -> int:
	var t = 0
	for id in D.MONSTERS.keys(): t += bestiary_tier(id)
	return t

func discover(id: String) -> void:
	if s.secrets.has(id): return
	s.secrets[id] = true
	for sc in D.SECRETS:
		if sc.id == id:
			toast.emit("DÉCOUVERTE SECRÈTE : %s — %s" % [sc.name, sc.bonus], Color("ff9cf0"))
	if id == "s_nom": s.gems += 300
	mark()

var _ach_cache: Array = []
func achievements() -> Array:
	if not _ach_cache.is_empty(): return _ach_cache
	var defs = [
		["kills", "Tueur", "Tuer %s monstres", [100, 1000, 10000, 100000, 1e6, 1e7]],
		["bosses", "Chasseur de boss", "Vaincre %s boss", [1, 10, 50, 250, 1000, 5000]],
		["max_gi", "Explorateur", "Atteindre l'étape %s", [10, 20, 30, 50, 75, 100, 150, 200, 300, 500]],
		["level", "Vétéran", "Atteindre le niveau %s", [10, 25, 50, 100, 150, 250, 400]],
		["gold_total", "Magnat", "Gagner %s or au total", [1e4, 1e6, 1e9, 1e12, 1e15, 1e18, 1e24]],
		["dungeons", "Plongeur", "Terminer %s donjons", [1, 10, 50, 200, 1000]],
		["pvp_wins", "Gladiateur", "Gagner %s combats d'arène", [1, 10, 50, 200, 1000]],
		["eggs", "Éleveur", "Faire éclore %s œufs", [1, 10, 50, 200, 1000]],
		["ascensions", "Renaissance", "Faire %s ascensions", [1, 5, 20, 50, 100]],
		["forges", "Forgeron", "Améliorer %s fois", [1, 25, 100, 500, 2000]],
		["taps", "Frappeur", "Frapper %s fois", [1000, 10000, 100000, 1e6]],
		["abyss_best", "Abyssal", "Atteindre l'étage %s de l'Abysse", [10, 25, 50, 100, 200, 500]],
		["bestiary", "Naturaliste", "Franchir %s paliers du bestiaire", [5, 15, 30, 50, 65]],
		["secrets", "Curieux", "Trouver %s secrets", [1, 3, 6, 10, 14]],
	]
	for dd in defs:
		for i in dd[3].size():
			_ach_cache.append({"id": "%s_%d" % [dd[0], i], "key": dd[0], "name": "%s %s" % [dd[1], ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][i]], "desc": dd[2] % fmt(dd[3][i]), "goal": float(dd[3][i]), "gems": int(10 * pow(i + 1, 1.6))})
	return _ach_cache

func ach_value(key: String) -> float:
	match key:
		"max_gi": return float(s.max_gi)
		"level": return float(s.level)
		"ascensions": return float(s.ascensions)
		"abyss_best": return float(s.abyss_best)
		"pvp_wins": return float(s.pvp.wins)
		"bestiary": return float(bestiary_tiers_total())
		"secrets": return float(s.secrets.size())
	return c(key)

func ach_claimable() -> int:
	var n = 0
	for a in achievements():
		if not s.ach.has(a.id) and ach_value(a.key) >= a.goal: n += 1
	return n

var _ach_check_acc = 0
func _check_achievements_silent() -> void:
	_ach_check_acc += 1

func claim_ach(a: Dictionary) -> bool:
	if s.ach.has(a.id) or ach_value(a.key) < a.goal: return false
	s.ach[a.id] = true
	s.gems += a.gems
	mark()
	return true

func today() -> String:
	var d = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func ensure_quests() -> void:
	if s.quests.day == today(): return
	var pool = D.QUESTS.duplicate()
	pool.shuffle()
	var lst = []
	var mult = 1.0 + s.level / 50.0
	for i in 4:
		var q: Dictionary = pool[i]
		var target = ceil(q.base * (mult if q.stat in ["kills", "taps", "trains"] else 1.0))
		lst.append({"id": q.id, "target": target, "base": c(q.stat), "claimed": false})
	s.quests = {"day": today(), "list": lst}

func quest_def(id: String) -> Dictionary:
	for q in D.QUESTS:
		if q.id == id: return q
	return {}

func quest_progress(q: Dictionary) -> float:
	var d = quest_def(q.id)
	return min(float(q.target), c(d.stat) - float(q.base))

func claim_quest(q: Dictionary) -> bool:
	if q.claimed or quest_progress(q) < float(q.target): return false
	q.claimed = true
	var d = quest_def(q.id)
	s.gems += d.gems
	var all = true
	for x in s.quests.list:
		if not x.claimed: all = false
	if all:
		s.eggs[rng.randi() % 3] += 1
		s.keys += 2
		toast.emit("Toutes les quêtes du jour ! +1 œuf, +2 clés", Color("ffd76a"))
	mark()
	return true

# ------------------------------------------------------------------ boutique
func buy_shop(id: String) -> bool:
	var item: Dictionary = {}
	for x in D.SHOP:
		if x.id == id: item = x
	if s.gems < item.gems: return false
	s.gems -= item.gems
	match id:
		"egg0": s.eggs[0] += 1
		"egg1": s.eggs[1] += 1
		"egg2": s.eggs[2] += 1
		"keys": s.keys += 3
		"ore": s.ore += ceil(80.0 * (1.0 + s.max_gi / 10.0))
		"tickets": s.tickets += 5
		"boost_gold": s.boost_gold = float(s.boost_gold) + 1800.0
		"boost_dmg": s.boost_dmg = float(s.boost_dmg) + 1800.0
		"talent": s.talent_bonus += 1
	mark()
	return true

func honor_lvl(id: String) -> int: return int(s.honor_up.get(id, 0))
func honor_cost(h: Dictionary) -> float: return ceil(h.cost * pow(h.grow, honor_lvl(h.id)))
func buy_honor(h: Dictionary) -> bool:
	var cost = honor_cost(h)
	if s.honor < cost: return false
	s.honor -= cost
	s.honor_up[h.id] = honor_lvl(h.id) + 1
	mark()
	return true

# ------------------------------------------------------------------ arène (PvP)
func pvp_profile() -> Dictionary:
	if dirty: recalc()
	var cl: Dictionary = D.CLASSES.get(s.cls, {})
	var atk: float = st.power * (1.0 + 0.05 * honor_lvl("h_atk"))
	var hp: float = st.power * 6.0 * (1.0 + st.hp_pct / 100.0 + float(cl.get("hp", 0.0))) * (1.0 + 0.05 * honor_lvl("h_hp"))
	return {"name": s.name, "cls": s.cls, "level": s.level, "atk": atk, "hp": hp, "aps": st.aps, "crit": st.crit, "critd": st.critd,
		"def": st.def, "dodge": st.dodge, "power": st.power, "rating": s.pvp.rating}

# Simulation déterministe d'un duel : renvoie la liste des événements.
static func pvp_sim(a: Dictionary, b: Dictionary, seed_v: int) -> Dictionary:
	var r = RandomNumberGenerator.new()
	r.seed = seed_v
	var hp = [float(a.hp), float(b.hp)]
	var f = [a, b]
	var t = [0.0, 0.15]
	var ev = []
	var time = 0.0
	while hp[0] > 0 and hp[1] > 0 and time < 60.0:
		var i = 0 if t[0] <= t[1] else 1
		var j = 1 - i
		time = t[i]
		var atk: Dictionary = f[i]
		var dfn: Dictionary = f[j]
		var aps_i: float = max(0.5, float(atk.aps))
		t[i] += 1.0 / min(aps_i, 3.0)
		if r.randf() * 100.0 < float(dfn.dodge):
			ev.append({"t": time, "who": i, "dmg": 0.0, "crit": false, "dodge": true, "hp": hp.duplicate()})
			continue
		var d: float = float(atk.atk) / min(aps_i, 3.0) * max(1.0, aps_i / 3.0)
		var crit = r.randf() < float(atk.crit)
		if crit: d *= float(atk.critd)
		d *= (1.0 - float(dfn.def) / 100.0) * r.randf_range(0.9, 1.1)
		hp[j] = max(0.0, hp[j] - d)
		ev.append({"t": time, "who": i, "dmg": d, "crit": crit, "dodge": false, "hp": hp.duplicate()})
	var winner = 0 if hp[1] <= 0 else (1 if hp[0] <= 0 else (0 if hp[0] / float(a.hp) >= hp[1] / float(b.hp) else 1))
	return {"events": ev, "winner": winner}

func pvp_reward(win: bool) -> String:
	add_c("pvp")
	if win:
		s.pvp.wins = int(s.pvp.wins) + 1
		var hon = 10.0
		var gm = 5 + honor_lvl("h_gems")
		s.honor += hon
		s.gems += gm
		mark()
		return "+%d honneur, +%d gemmes" % [hon, gm]
	s.pvp.losses = int(s.pvp.losses) + 1
	s.honor += 3
	mark()
	return "+3 honneur"

static func elo(ra: float, rb: float, win: bool) -> int:
	var ea = 1.0 / (1.0 + pow(10.0, (rb - ra) / 400.0))
	return int(round(32.0 * ((1.0 if win else 0.0) - ea)))

func bot_opponents() -> Array:
	var me = pvp_profile()
	var names = ["Kael", "Lyra", "Thorn", "Mira", "Draven", "Selen", "Orin", "Vex", "Nyx", "Bram", "Ilda", "Zorak"]
	var cls = D.CLASSES.keys()
	var out = []
	for i in 5:
		var f = rng.randf_range(0.55, 1.6)
		out.append({"id": "bot%d" % i, "name": names[rng.randi() % names.size()] + " (IA)", "cls": cls[rng.randi() % cls.size()], "level": max(1, int(s.level * rng.randf_range(0.8, 1.2))),
			"atk": me.atk * f, "hp": me.hp * f * rng.randf_range(0.8, 1.2), "aps": me.aps * rng.randf_range(0.8, 1.2), "crit": clampf(me.crit + rng.randf_range(-0.05, 0.05), 0.05, 0.75),
			"critd": me.critd, "def": me.def, "dodge": me.dodge, "power": me.power * f, "rating": s.pvp.rating + int((f - 1.0) * 200), "bot": true})
	return out

# ------------------------------------------------------------------ hors-ligne
func _compute_offline() -> void:
	var now = Time.get_unix_time_from_system()
	var away: float = now - float(s.get("seen", now))
	s.seen = now
	if away < 60 or s.name == "": return
	away = min(away, 8.0 * 3600.0)
	if dirty: recalc()
	var g = float(gi())
	var kill_time = max(hp_at(g) / max(1.0, st.power), SPAWN_DELAY + 0.4)
	var kills: float = away / kill_time * 0.5
	var gold = kills * gold_at(g) * st.gold
	var xp = kills * xp_at(g) * st.xp
	var ore = ceil(kills * 0.08 * (1.0 + g / 8.0) * st.ore)
	s.gold += gold
	add_c("gold_total", gold)
	add_c("kills", kills)
	s.ore += ore
	_gain_xp(xp)
	# Recharge des clés et tickets
	s.keys = min(keys_max(), s.keys + int(away / key_regen()))
	s.tickets = min(10, s.tickets + int(away / 3600.0))
	offline_report = {"time": away, "gold": gold, "xp": xp, "ore": ore, "kills": kills}
	mark()

func set_name_checked(n: String) -> void:
	s.name = n.strip_edges().substr(0, 16)
	if s.name.to_lower() == "abyssia": discover("s_nom")
	save_game()
