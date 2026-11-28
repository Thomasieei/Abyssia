extends Node3D
## Ressource récoltable : buisson de lin sauvage. Se vide en 3 récoltes, repousse ensuite.

const GATHER_TIME := 2.2
const CHARGES := 3
const REGROW := 40.0

var charges := CHARGES
var _regrow_t := 0.0
var _bush: Node3D
var _gatherer: Node3D
var _shake_t := 0.0
var _base_scale := Vector3.ONE
var _marker: MeshInstance3D

func setup(pos: Vector3, yaw: float, scale_f: float) -> void:
	position = pos
	rotation.y = yaw
	_base_scale = Vector3.ONE * scale_f

func _ready() -> void:
	_bush = load("res://assets/nature/Bush_Common_Flowers.gltf").instantiate()
	_bush.scale = _base_scale
	add_child(_bush)
	G.world._wind_small(_bush, 0.05, 1.2)
	# anneau discret au sol : « on peut récolter ici »
	_marker = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.6, 2.6)
	_marker.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/telegraph.gdshader")
	mat.set_shader_parameter("color", Color(1.0, 0.92, 0.55, 0.55))
	mat.set_shader_parameter("shape", 0)
	mat.set_shader_parameter("progress", 0.0)
	_marker.material_override = mat
	_marker.position.y = 0.05
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.7 * _base_scale.x
	sh.height = 1.2
	cs.shape = sh
	cs.position.y = 0.6
	body.add_child(cs)
	add_child(body)

func ready_to_gather() -> bool:
	return charges > 0 and _gatherer == null

func begin_gather(p: Node3D) -> void:
	_gatherer = p
	_shake_t = 0.0

func cancel_gather() -> void:
	_gatherer = null
	_bush.rotation = Vector3.ZERO

func complete_gather() -> void:
	_gatherer = null
	charges -= 1
	var n := randi_range(2, 3)
	G.give_item("lin", n)
	G.stats.lin_recolte += n   # la cueillette enseigne « Souffle clair »
	Sfx.play("pickup", -4.0)
	G.burst(global_position + Vector3.UP * 0.9, "star_06", Color(1, 0.95, 0.7, 1), 10, 2.5, 0.35, 0.5, -3.0)
	G.burst(global_position + Vector3.UP * 0.6, "light_01", Color(0.9, 1.0, 0.7, 0.6), 8, 1.5, 0.5, 0.6, 1.0)
	var target_scale := _base_scale * (0.55 + 0.45 * float(charges) / CHARGES)
	_bush.create_tween().tween_property(_bush, "scale", target_scale, 0.3).set_trans(Tween.TRANS_BACK)
	if charges <= 0:
		_regrow_t = REGROW
		_marker.visible = false
		_bush.create_tween().tween_property(_bush, "scale", _base_scale * 0.3, 0.4)

func _process(delta: float) -> void:
	if _gatherer:
		_shake_t += delta
		_bush.rotation.z = sin(_shake_t * 22.0) * 0.06
		_bush.rotation.x = cos(_shake_t * 17.0) * 0.04
		if fmod(_shake_t, 0.55) < delta: Sfx.play_at("gather", global_position, -8.0)
		if fmod(_shake_t, 0.4) < delta:
			G.burst(global_position + Vector3.UP * 0.8, "dirt_02", Color(0.75, 0.85, 0.5, 0.8), 3, 1.5, 0.25, 0.5, -4.0)
	elif charges <= 0:
		_regrow_t -= delta
		if _regrow_t <= 0.0:
			charges = CHARGES
			_marker.visible = true
			_bush.create_tween().tween_property(_bush, "scale", _base_scale, 0.6).set_trans(Tween.TRANS_BACK)
	if _marker.visible:
		var t := Time.get_ticks_msec() / 1000.0
		_marker.material_override.set_shader_parameter("progress", fmod(t * 0.5, 1.0))
