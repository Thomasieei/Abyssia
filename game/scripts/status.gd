extends RefCounted
## Statut de l'aventurier (façon DanMachi) : on devient fort par ce qu'on fait VRAIMENT.
## - Cinq aptitudes (Force, Endurance, Dextérité, Agilité, Magie), de 0 à 999, notées I → S.
## - Chaque acte réel nourrit une aptitude (coups portés, coups encaissés, contres, esquives, sorts),
##   mais l'expérience reste « en attente » tant qu'Aldric ne l'a pas inscrite au registre du bourg
##   (la « mise à jour de statut »). Plus une aptitude est haute, plus elle monte lentement.
## - Les techniques naissent d'exploits répétés (G.stats) et s'éveillent à la mise à jour.
## - Niveau supérieur : un grand exploit (le Gardien de cendre) + une aptitude au rang E ou mieux.
##   Les aptitudes repartent de I, mais tout ce qui a été acquis reste (réserve cachée).

const ABIL := ["force", "endurance", "dexterite", "agilite", "magie"]
const NAMES := {"force": "Force", "endurance": "Endurance", "dexterite": "Dextérité", "agilite": "Agilité", "magie": "Magie"}
const WHAT := {"force": "dégâts", "endurance": "vie max.", "dexterite": "fenêtre de contre", "agilite": "vitesse, esquive", "magie": "énergie"}
const COLORS := {"force": Color(1.0, 0.45, 0.3), "endurance": Color(0.95, 0.75, 0.35), "dexterite": Color(0.45, 0.8, 1.0),
	"agilite": Color(0.55, 1.0, 0.7), "magie": Color(0.8, 0.6, 1.0)}
const GRADES := ["I", "H", "G", "F", "E", "D", "C", "B", "A", "S"]
const LEVEL_NEED := 400     # rang E

## Techniques : [clé de G.stats, seuil]
const TECHS := {
	"dernier_instant": {"name": "Dernier instant", "stat": "contres_parfaits", "n": 3,
		"desc": "La riposte d'un contre parfait libère une onde qui renverse l'équilibre des ennemis proches.",
		"hint": "Détourner trois coups au tout dernier instant."},
	"pas_ombre": {"name": "Pas de l'ombre", "stat": "esquives_parfaites", "n": 3,
		"desc": "Après une esquive parfaite : élan de 3 s (vitesse, dégâts +50 %).",
		"hint": "Glisser trois fois sous un coup au dernier moment."},
	"briseur": {"name": "Briseur", "stat": "chutes", "n": 5,
		"desc": "Tes coups brisent l'équilibre 50 % plus vite.",
		"hint": "Jeter cinq ennemis au sol."},
	"tenace": {"name": "Ténacité", "stat": "survies", "n": 2,
		"desc": "Une fois par minute, au bord de la mort : un sursaut rend 20 % de vie.",
		"hint": "Survivre deux fois au bord de la mort."},
}

## Sorts : on ne les reçoit plus d'un objet, on les apprend en vivant (« tu deviens ce que tu fais »).
## Trois familles, une par emplacement du moyeu (casque = protection, plastron = puissance, bottes = mouvement).
## Les gestes de base sont connus dès le départ ; les autres naissent d'un acte réel (clé de G.stats, ou
## « kills:<espèce> ») et s'éveillent à la mise à jour de statut, comme les techniques.
const SLOTS := ["casque", "plastron", "bottes"]
const SLOT_NAMES := {"casque": "Protection", "plastron": "Puissance", "bottes": "Mouvement"}
const SPELLS := {
	"garde": {"slot": "casque", "base": true, "desc": "Bouclier de 35 % de ta vie pendant 6 s."},
	"souffle": {"slot": "casque", "stat": "lin_recolte", "n": 12, "desc": "Rend 22 % de ta vie d'un souffle.",
		"hint": "Cueillir douze brins de lin sauvage.", "how": "Né de l'odeur du lin."},
	"toile": {"slot": "casque", "stat": "toiles_vues", "n": 3, "desc": "Crache une toile qui englue les ennemis.",
		"hint": "Regarder trois fois une tisseuse cracher sa toile.", "how": "Volé du regard aux tisseuses."},
	"fureur": {"slot": "plastron", "base": true, "desc": "Dégâts +40 % pendant 8 s."},
	"embrase": {"slot": "plastron", "stat": "kills:brute", "n": 4, "desc": "Une aura de lave brûle tout autour de toi.",
		"hint": "Abattre quatre brutes de lave.", "how": "La lave des brutes, dans ton sang."},
	"vent": {"slot": "bottes", "base": true, "desc": "Vitesse +60 % pendant 4 s."},
	"roulade": {"slot": "bottes", "stat": "kills:rodeur", "n": 3, "desc": "Roulade : invincible le temps du geste.",
		"hint": "Vaincre trois rôdeurs des falaises.", "how": "Le pas des rôdeurs, devenu tien."},
}

var level := 1
var val := {}        # aptitudes visibles (0–999)
var banked := {}     # acquis des niveaux précédents (toujours actifs)
var pending := {}    # expérience pas encore inscrite
var techs := {}      # techniques éveillées
var spells := {}     # sorts appris
var loadout := {"casque": "garde", "plastron": "fureur", "bottes": "vent"}   # sort choisi par emplacement
var g: Node          # le nœud global G (donné à la création : pas de dépendance à l'autoload à la compilation)

func _init() -> void:
	for a in ABIL:
		val[a] = 0
		banked[a] = 0
		pending[a] = 0.0
	for id in SPELLS:
		if SPELLS[id].get("base", false): spells[id] = true

static func grade(v: int) -> String:
	return GRADES[clampi(v / 100, 0, 9)]

## Un acte réel : l'expérience est en attente ; elle ralentit à mesure que l'aptitude grandit.
func gain(a: String, x: float) -> void:
	if x <= 0.0: return
	pending[a] += x * 300.0 / (300.0 + val[a] + pending[a])

func pending_total() -> int:
	var s := 0
	for a in ABIL: s += int(pending[a])
	return s

func ready_techs() -> Array:
	var out := []
	for id in TECHS:
		if techs.has(id): continue
		var t: Dictionary = TECHS[id]
		if g.stats.get(t.stat, 0) >= t.n: out.append(id)
	return out

## Avancement d'un acte : G.stats[clé] ou G.stats.kills[espèce] pour « kills:espèce ».
func progress(stat: String) -> int:
	if stat.begins_with("kills:"): return int(g.stats.kills.get(stat.substr(6), 0))
	return int(g.stats.get(stat, 0))

func ready_spells() -> Array:
	var out := []
	for id in SPELLS:
		if spells.has(id) or SPELLS[id].get("base", false): continue
		if progress(SPELLS[id].stat) >= SPELLS[id].n: out.append(id)
	return out

func knows(id: String) -> bool:
	return spells.has(id)

## Choisir le sort d'un emplacement (au registre).
func choose(id: String) -> void:
	if not spells.has(id): return
	loadout[SPELLS[id].slot] = id
	g.gear_changed.emit()

func can_level() -> bool:
	if not g.stats.get("gardien", false) or level >= 2: return false
	for a in ABIL:
		if int(val[a] + pending[a]) >= LEVEL_NEED: return true
	return false

func has_news() -> bool:
	return pending_total() >= 1 or not ready_techs().is_empty() or not ready_spells().is_empty() or can_level()

## Mise à jour de statut : inscrit l'expérience, éveille les techniques, monte de niveau.
## Rend {from, to, techs, level_up} pour l'animation du registre.
func update() -> Dictionary:
	var from := val.duplicate()
	for a in ABIL:
		val[a] = mini(999, val[a] + int(pending[a]))
		pending[a] = fmod(pending[a], 1.0)
	var new_t := ready_techs()
	for id in new_t: techs[id] = true
	# un sort tout juste appris prend sa place dans le moyeu si l'emplacement porte encore le geste de base
	var new_s := ready_spells()
	for id in new_s:
		spells[id] = true
		var sl: String = SPELLS[id].slot
		if SPELLS[loadout[sl]].get("base", false): loadout[sl] = id
	if not new_s.is_empty(): g.gear_changed.emit()
	var to := val.duplicate()
	var up := can_level()
	if up:
		level += 1
		for a in ABIL:
			banked[a] += val[a]
			val[a] = 0
	g.status_changed.emit()
	return {"from": from, "to": to, "techs": new_t, "spells": new_s, "level_up": up}

func eff(a: String) -> float:
	return float(val[a] + banked[a])

# --- Effets (lus par le héros) -------------------------------------------------------
func dmg_mult() -> float:
	return (1.0 + 0.3 * (level - 1)) * (1.0 + eff("force") / 1500.0)

func max_hp() -> float:
	return 420.0 + 160.0 * (level - 1) + eff("endurance") * 0.5

func max_energy() -> float:
	return 200.0 + 40.0 * (level - 1) + eff("magie") * 0.15

func energy_regen() -> float:
	return 7.0 + eff("magie") * 0.006

func counter_bonus() -> float:
	return minf(eff("dexterite"), 1500.0) * 0.00008

func speed_mult() -> float:
	return 1.0 + minf(eff("agilite"), 1500.0) * 0.00022

func dodge_bonus() -> float:
	return minf(eff("agilite"), 1500.0) * 0.00008

func has(id: String) -> bool:
	return techs.has(id)

# --- Sauvegarde (hors tests) ---------------------------------------------------------
const PATH := "user://statut.json"

func save() -> void:
	if OS.get_environment("ABY_TEST") != "": return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"level": level, "val": val, "banked": banked, "pending": pending, "techs": techs, "stats": g.stats,
		"spells": spells, "loadout": loadout, "silver": g.silver, "inventory": g.inventory, "owned_gear": g.owned_gear, "equipped": g.equipped}))

func load_saved() -> void:
	if OS.get_environment("ABY_TEST") != "" or not FileAccess.file_exists(PATH): return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY: return
	level = int(d.get("level", 1))
	for a in ABIL:
		val[a] = int(d.get("val", {}).get(a, 0))
		banked[a] = int(d.get("banked", {}).get(a, 0))
		pending[a] = float(d.get("pending", {}).get(a, 0.0))
	for id in d.get("techs", {}): techs[id] = true
	for id in d.get("spells", {}):
		if SPELLS.has(id): spells[id] = true
	var lo: Dictionary = d.get("loadout", {})
	for sl in lo:
		if SLOTS.has(sl) and spells.has(lo[sl]) and SPELLS[lo[sl]].slot == sl: loadout[sl] = lo[sl]
	# sac, argent et équipement : l'économie survit à la fermeture du jeu
	g.silver = int(d.get("silver", g.silver))
	var inv: Dictionary = d.get("inventory", {})
	for k in inv:
		if g.ITEMS.has(k) and int(inv[k]) > 0: g.inventory[k] = int(inv[k])
	for k in d.get("owned_gear", {}):
		if g.GEAR.has(k): g.owned_gear[k] = true
	var eq: Dictionary = d.get("equipped", {})
	for sl in eq:
		if g.GEAR.has(eq[sl]) and g.owned_gear.has(eq[sl]) and g.GEAR[eq[sl]].slot == sl: g.equipped[sl] = eq[sl]
	var st: Dictionary = d.get("stats", {})
	for k in st:
		if k == "kills":
			for kk in st.kills: g.stats.kills[kk] = int(st.kills[kk])
		elif typeof(st[k]) == TYPE_BOOL: g.stats[k] = st[k]
		else: g.stats[k] = int(st[k])
