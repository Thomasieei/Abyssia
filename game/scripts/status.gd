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

var level := 1
var val := {}        # aptitudes visibles (0–999)
var banked := {}     # acquis des niveaux précédents (toujours actifs)
var pending := {}    # expérience pas encore inscrite
var techs := {}      # techniques éveillées

func _init() -> void:
	for a in ABIL:
		val[a] = 0
		banked[a] = 0
		pending[a] = 0.0

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
		if G.stats.get(t.stat, 0) >= t.n: out.append(id)
	return out

func can_level() -> bool:
	if not G.stats.get("gardien", false) or level >= 2: return false
	for a in ABIL:
		if int(val[a] + pending[a]) >= LEVEL_NEED: return true
	return false

func has_news() -> bool:
	return pending_total() >= 1 or not ready_techs().is_empty() or can_level()

## Mise à jour de statut : inscrit l'expérience, éveille les techniques, monte de niveau.
## Rend {from, to, techs, level_up} pour l'animation du registre.
func update() -> Dictionary:
	var from := val.duplicate()
	for a in ABIL:
		val[a] = mini(999, val[a] + int(pending[a]))
		pending[a] = fmod(pending[a], 1.0)
	var new_t := ready_techs()
	for id in new_t: techs[id] = true
	var to := val.duplicate()
	var up := can_level()
	if up:
		level += 1
		for a in ABIL:
			banked[a] += val[a]
			val[a] = 0
	G.status_changed.emit()
	return {"from": from, "to": to, "techs": new_t, "level_up": up}

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
	f.store_string(JSON.stringify({"level": level, "val": val, "banked": banked, "pending": pending, "techs": techs, "stats": G.stats}))

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
	var st: Dictionary = d.get("stats", {})
	for k in st:
		if k == "kills":
			for kk in st.kills: G.stats.kills[kk] = int(st.kills[kk])
		elif typeof(st[k]) == TYPE_BOOL: G.stats[k] = st[k]
		else: G.stats[k] = int(st[k])
