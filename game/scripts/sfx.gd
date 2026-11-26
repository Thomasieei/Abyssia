extends Node
# Sons : petit lot de lecteurs réutilisés. Autoload « Sfx ».

const SOUNDS := {
	"hit": ["impactPunch_medium_000", "impactPunch_medium_001"],
	"crit": ["impactPunch_heavy_000"],
	"tap": ["knifeSlice", "chop"],
	"coin": ["handleCoins", "handleCoins2"],
	"click": ["click_002"],
	"ok": ["confirmation_001"],
	"buy": ["confirmation_002"],
	"error": ["error_004"],
	"loot": ["drop_002"],
	"level": ["jingles_NES03"],
	"boss": ["impactBell_heavy_000"],
	"win": ["jingles_NES09"],
	"lose": ["jingles_HIT05"],
	"egg": ["impactGlass_light_000"],
	"forge": ["impactMetal_light_000"],
	"secret": ["jingles_NES00"],
}

var players: Array = []
var streams = {}
var last_play = {}

func _ready() -> void:
	for i in 10:
		var p = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	for k in SOUNDS.keys():
		var arr = []
		for n in SOUNDS[k]:
			var path = "res://assets/sfx/%s.ogg" % n
			if ResourceLoader.exists(path): arr.append(load(path))
		streams[k] = arr

func play(id: String, vol := 0.0) -> void:
	if G.headless_sim or not G.s.get("sound", true): return
	var arr: Array = streams.get(id, [])
	if arr.is_empty(): return
	var now = Time.get_ticks_msec()
	if now - int(last_play.get(id, 0)) < 60: return  # pas de rafale qui sature
	last_play[id] = now
	for p in players:
		if not p.playing:
			p.stream = arr[randi() % arr.size()]
			p.volume_db = vol
			p.pitch_scale = randf_range(0.94, 1.06)
			p.play()
			return
