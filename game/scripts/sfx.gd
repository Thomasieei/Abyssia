extends Node
## Sons : bancs préchargés + pool de lecteurs (aucune allocation pendant le jeu).

const BANKS := {
	"step": ["footstep_grass_000", "footstep_grass_001", "footstep_grass_002", "footstep_grass_003", "footstep_grass_004"],
	"swing": ["drawKnife1", "drawKnife2", "knifeSlice", "knifeSlice2"],
	"hit": ["impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_medium_000"],
	"hit_heavy": ["impactPlate_heavy_000", "impactMetal_heavy_000", "impactMetal_heavy_001"],
	"flesh": ["impactSoft_heavy_000", "impactSoft_heavy_001"],
	"slam": ["impactWood_heavy_000", "impactPlate_heavy_000"],
	"gather": ["cloth1", "cloth2"],
	"loot": ["handleCoins", "handleCoins2"],
	"pickup": ["dropLeather"],
	"ui": ["metalClick"],
	"parade": ["parade"],
}
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _i := 0
var _j := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in BANKS:
		var arr: Array[AudioStream] = []
		for f in BANKS[k]:
			var path := "res://assets/sfx/%s.ogg" % f
			if not ResourceLoader.exists(path): path = "res://assets/sfx/%s.wav" % f
			var s: AudioStream = load(path)
			if s: arr.append(s)
		_streams[k] = arr
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in 12:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 8.0
		p3.max_distance = 40.0
		add_child(p3)
		_pool3d.append(p3)

func play(bank: String, vol_db := 0.0, pitch := 1.0) -> void:
	var arr: Array = _streams.get(bank, [])
	if arr.is_empty(): return
	var p := _pool[_i]
	_i = (_i + 1) % _pool.size()
	p.stream = arr[randi() % arr.size()]
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.play()

func play_at(bank: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	var arr: Array = _streams.get(bank, [])
	if arr.is_empty(): return
	var p := _pool3d[_j]
	_j = (_j + 1) % _pool3d.size()
	p.stream = arr[randi() % arr.size()]
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.play()
