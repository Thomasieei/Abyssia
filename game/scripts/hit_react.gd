extends SkeletonModifier3D
## Réactions aux coups par-dessus l'animation : le buste plie à l'opposé du coup puis revient
## comme un ressort (léger rebond), la tête suit avec un temps de retard. En titubement, le buste
## oscille. Tout est calculé ici, sans allocation, et uniquement si une réaction est en cours.

var _bones := PackedInt32Array()
var _weights := PackedFloat32Array([0.3, 0.42, 0.28])
var _axis := Vector3.RIGHT      # axe de flexion (espace du squelette)
var _x := 0.0                   # angle actuel (radians)
var _v := 0.0                   # vitesse angulaire
var _wobble := 0.0              # amplitude du titubement
var _wob_t := 0.0
var _scale := 1.0

func setup(sk: Skeleton3D, scale := 1.0, names := ["Spine", "Chest", "Head"]) -> void:
	_scale = scale
	for n in names:
		var b := sk.find_bone(n)
		if b >= 0: _bones.append(b)

## dir_local : direction du coup (de l'attaquant vers la victime) dans l'espace du squelette.
func kick(dir_local: Vector3, strength: float) -> void:
	dir_local.y = 0.0
	if dir_local.length() < 0.01: dir_local = Vector3.BACK
	_axis = Vector3.UP.cross(dir_local.normalized()).normalized()
	_v += strength * 14.0 * _scale

func stagger(amount: float) -> void:
	_wobble = maxf(_wobble, amount)

func active() -> bool:
	return absf(_x) > 0.002 or absf(_v) > 0.01 or _wobble > 0.002

func step(delta: float) -> void:
	if not active(): return
	# ressort amorti : k = 170, c = 15 (un petit rebond, pas de tremblement)
	_v += (-170.0 * _x - 15.0 * _v) * delta
	_x += _v * delta
	_x = clampf(_x, -0.9, 0.9)
	if _wobble > 0.0:
		_wob_t += delta
		_wobble = maxf(_wobble - delta * 0.35, 0.0)

func _process_modification() -> void:
	if not active(): return
	var sk := get_skeleton()
	if sk == null: return
	var wob := sin(_wob_t * 7.0) * _wobble
	var wob_fwd := sin(_wob_t * 4.3 + 1.0) * _wobble * 0.5
	for i in _bones.size():
		var b := _bones[i]
		var w := _weights[i]
		var gp := sk.get_bone_global_pose(b)
		var basis := Basis(_axis, _x * w * (1.0 if i < 2 else 1.35))
		if _wobble > 0.0:
			basis = Basis(Vector3.FORWARD, wob * w) * Basis(Vector3.RIGHT, wob_fwd * w) * basis
		gp.basis = basis * gp.basis
		sk.set_bone_global_pose(b, gp)
