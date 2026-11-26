extends Node
# Liaison Supabase : inscription, synchro du profil, classements, arène. Autoload « Net ».

const URL := "https://xtbolgcxyegdwpvpcupc.supabase.co"
const KEY := "sb_publishable_u2uC7CQjQ9YyMXF7Y89G8Q_Np6xKSk4"

var online = false
var busy_register = false
var sync_acc = 50.0

func _process(delta: float) -> void:
	if G.headless_sim or G.s.name == "": return
	sync_acc += delta
	if sync_acc >= 60.0:
		sync_acc = 0.0
		sync()

func _headers() -> PackedStringArray:
	return PackedStringArray(["apikey: " + KEY, "Authorization: Bearer " + KEY, "Content-Type: application/json"])

# Appel générique : renvoie [ok, données]
func call_api(method: int, path: String, body = null, extra := PackedStringArray()) -> Array:
	var req = HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	var h = _headers()
	h.append_array(extra)
	var err = req.request(URL + path, h, method, "" if body == null else JSON.stringify(body))
	if err != OK:
		req.queue_free()
		online = false
		return [false, null]
	var res: Array = await req.request_completed
	req.queue_free()
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if text != "" else null
	online = res[0] == HTTPRequest.RESULT_SUCCESS and code > 0
	return [code >= 200 and code < 300, data]

func rpc_call(fn: String, args: Dictionary) -> Array:
	return await call_api(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + fn, args)

func ensure_registered() -> bool:
	if G.s.pvp.id != "": return true
	if busy_register: return false
	busy_register = true
	var r = await rpc_call("aby_register", {"p_name": G.s.name, "p_cls": G.s.cls})
	busy_register = false
	if r[0] and typeof(r[1]) == TYPE_DICTIONARY:
		G.s.pvp.id = str(r[1].id)
		G.s.pvp.secret = str(r[1].secret)
		G.save_game()
		return true
	return false

func sync() -> bool:
	if not await ensure_registered(): return false
	var p = G.pvp_profile()
	var prof = {"atk": p.atk, "hp": p.hp, "aps": p.aps, "crit": p.crit, "critd": p.critd, "def": p.def, "dodge": p.dodge, "power": p.power}
	var r = await rpc_call("aby_sync", {"p_id": G.s.pvp.id, "p_secret": G.s.pvp.secret, "p_name": G.s.name, "p_cls": G.s.cls,
		"p_level": G.s.level, "p_power": G.power(), "p_max_gi": G.s.max_gi, "p_abyss": G.s.abyss_best, "p_asc": G.s.ascensions, "p_profile": prof})
	if r[0] and typeof(r[1]) == TYPE_DICTIONARY:
		G.s.pvp.rating = int(r[1].rating)
		return true
	if not r[0] and typeof(r[1]) == TYPE_DICTIONARY and str(r[1].get("message", "")).find("auth") >= 0:
		G.s.pvp.id = ""  # compte perdu côté serveur : on se réinscrit
	return false

func leaderboard(col: String) -> Array:
	var r = await call_api(HTTPClient.METHOD_GET, "/rest/v1/aby_players?select=id,name,cls,level,power,max_gi,abyss,rating,wins&order=%s.desc&limit=50" % col)
	if r[0] and typeof(r[1]) == TYPE_ARRAY: return r[1]
	return []

func ranks() -> Dictionary:
	if G.s.pvp.id == "": return {}
	var r = await rpc_call("aby_ranks", {"p_id": G.s.pvp.id})
	if r[0] and typeof(r[1]) == TYPE_DICTIONARY: return r[1]
	return {}

func opponents() -> Array:
	if not await sync(): return []
	var r = await rpc_call("aby_opponents", {"p_id": G.s.pvp.id})
	var out = []
	if r[0] and typeof(r[1]) == TYPE_ARRAY:
		for row in r[1]:
			var pr: Dictionary = row.get("profile", {})
			if not pr.has("atk"): continue
			out.append({"id": str(row.id), "name": row.name, "cls": row.cls, "level": int(row.level), "rating": int(row.rating),
				"atk": float(pr.atk), "hp": float(pr.hp), "aps": float(pr.aps), "crit": float(pr.crit), "critd": float(pr.critd),
				"def": float(pr.def), "dodge": float(pr.dodge), "power": float(pr.power), "bot": false})
	return out

func report_duel(opp_id: String, win: bool) -> int:
	var r = await rpc_call("aby_duel", {"p_id": G.s.pvp.id, "p_secret": G.s.pvp.secret, "p_opp": opp_id, "p_win": win})
	if r[0] and typeof(r[1]) == TYPE_DICTIONARY:
		G.s.pvp.rating = int(r[1].rating)
		return int(r[1].delta)
	return 0

func history() -> Array:
	if G.s.pvp.id == "": return []
	var r = await call_api(HTTPClient.METHOD_GET, "/rest/v1/aby_duels?select=attacker_name,defender_name,win,delta,created_at,attacker&or=(attacker.eq.%s,defender.eq.%s)&order=created_at.desc&limit=15" % [G.s.pvp.id, G.s.pvp.id])
	if r[0] and typeof(r[1]) == TYPE_ARRAY: return r[1]
	return []
