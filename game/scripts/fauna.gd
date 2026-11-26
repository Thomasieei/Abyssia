extends Node3D
## Vie du monde : papillons près des fleurs, vols d'oiseaux (avec leur ombre), poussières dorées
## dans la lumière, ambiance sonore forêt/bourg qui se fond selon la position, musique douce.

const BUTTERFLY_SPOTS := [Vector3(-3, 0, 25), Vector3(3, 0, 21), Vector3(-11, 0, 18), Vector3(-16, 0, 12), Vector3(5, 0, 6),
	Vector3(11, 0, 10), Vector3(-4, 0, 67.5), Vector3(4.5, 0, 67.8), Vector3(-13, 0, 6)]
var _birds: Array = []      # [MeshInstance3D, vitesse, phase]
var _bird_t := 6.0
var _bird_mat: StandardMaterial3D
var _amb_forest: AudioStreamPlayer
var _amb_town: AudioStreamPlayer
var _music: AudioStreamPlayer
var _motes: CPUParticles3D

func _ready() -> void:
	_butterflies()
	_bird_mat = StandardMaterial3D.new()
	_bird_mat.albedo_texture = load("res://assets/fx/oiseau.png")
	_bird_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_bird_mat.alpha_scissor_threshold = 0.5
	_bird_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bird_mat.uv1_scale = Vector3(0.5, 1, 1)
	_audio()

# --- Papillons -----------------------------------------------------------------
func _butterflies() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/fx/papillon.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = 2
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = true
	mat.vertex_color_use_as_albedo = true
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.32)
	q.material = mat
	var tints := [Color(1, 1, 1), Color(0.7, 0.85, 1.4), Color(1.3, 1.25, 0.6), Color(1.2, 0.7, 1.1)]
	for i in BUTTERFLY_SPOTS.size():
		var p := CPUParticles3D.new()
		p.mesh = q
		p.amount = 3
		p.lifetime = 7.0
		p.preprocess = 7.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 1.6
		p.direction = Vector3(1, 0.3, 0)
		p.spread = 180.0
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.35
		p.initial_velocity_max = 0.8
		p.tangential_accel_min = -0.6
		p.tangential_accel_max = 0.6
		p.anim_speed_min = 9.0
		p.anim_speed_max = 13.0
		p.color = tints[i % tints.size()]
		p.position = BUTTERFLY_SPOTS[i] + Vector3.UP * 0.9
		p.local_coords = false
		add_child(p)

# --- Oiseaux -------------------------------------------------------------------
func _spawn_flock() -> void:
	var half: float = G.world.HALF
	var from_left := randf() < 0.5
	var z := randf_range(-30.0, 70.0)
	var start := Vector3(-half - 10 if from_left else half + 10, 0, z)
	var dir := Vector3(1 if from_left else -1, 0, randf_range(-0.4, 0.4)).normalized()
	for i in randi_range(4, 7):
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(0.9, 0.45)
		q.material = _bird_mat
		m.mesh = q
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(m)
		# formation en V
		var row := (i + 1) / 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var off := -dir * row * 1.4 + Vector3(-dir.z, 0, dir.x) * side * row * 1.1
		m.position = start + off + Vector3.UP * (11.0 + randf_range(-0.5, 0.5))
		m.rotation.y = atan2(dir.x, dir.z) + PI
		_birds.append([m, dir * randf_range(6.5, 7.5), randf() * TAU])

func _process(delta: float) -> void:
	_bird_t -= delta
	if _bird_t <= 0.0:
		_bird_t = randf_range(18.0, 32.0)
		_spawn_flock()
	var keep := []
	var t := Time.get_ticks_msec() / 1000.0
	for b in _birds:
		var m: MeshInstance3D = b[0]
		m.position += b[1] * delta
		m.position.y += sin(t * 2.0 + b[2]) * 0.01
		# battement d'ailes : une image sur deux
		var flap := fmod(t * 3.0 + b[2], 1.0) < 0.5
		m.scale = Vector3(1.0 if flap else 0.55, 1, 1)
		if absf(m.position.x) > G.world.HALF + 14.0: m.queue_free()
		else: keep.append(b)
	_birds = keep
	_mix_audio(delta)

# --- Son ---------------------------------------------------------------------------
func _audio() -> void:
	_amb_forest = _loop_player("amb_foret", -6.0)
	_amb_town = _loop_player("amb_bourg", -40.0)
	_music = _loop_player("musique_brumefeuille", -15.0)

func _loop_player(name: String, db: float) -> AudioStreamPlayer:
	var s: AudioStreamWAV = load("res://assets/sfx/%s.wav" % name)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / 2
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	add_child(p)
	p.play()
	return p

func _mix_audio(delta: float) -> void:
	if G.player == null: return
	var town := clampf((G.player.global_position.z - 36.0) / 10.0, 0.0, 1.0)
	_amb_forest.volume_db = move_toward(_amb_forest.volume_db, lerpf(-6.0, -26.0, town), delta * 12.0)
	_amb_town.volume_db = move_toward(_amb_town.volume_db, lerpf(-34.0, -5.0, town), delta * 12.0)
