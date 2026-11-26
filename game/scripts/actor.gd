extends Node2D
# Personnage animé à partir d'une planche de sprites (une ligne par animation).
# Monstres : 0 repos, 1 attaque, 2 coup reçu, 3 mort.
# Héros : 0 repos, 1 attaque, 2 compétence, 3 coup reçu, 4 mort, 5 victoire.

const FR := 224
const COUNTS_MON := [8, 8, 5, 8]
const COUNTS_HERO := [8, 8, 8, 5, 8, 8]

var spr: Sprite2D
var counts: Array = COUNTS_MON
var hero = false
var row = 0
var frame_f = 0.0
var fps = 10.0
var loop = true
var queued_idle = true
var dead = false
var base_scale = 1.0
var bob_t = 0.0
var flash = 0.0
var tint = Color.WHITE
var shadow: Polygon2D

static var _sheets := {}

func _ready() -> void:
	shadow = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in 20:
		var a = TAU * i / 20.0
		pts.append(Vector2(cos(a) * 62, sin(a) * 14))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.32)
	add_child(shadow)
	spr = Sprite2D.new()
	spr.centered = true
	spr.offset = Vector2(0, -FR / 2.0 + 12)
	add_child(spr)

func setup(sheet: String, is_hero: bool, scale_v := 1.0, col := Color.WHITE) -> void:
	hero = is_hero
	counts = COUNTS_HERO if hero else COUNTS_MON
	if not _sheets.has(sheet):
		_sheets[sheet] = load("res://assets/sprites/%s.png" % sheet)
	spr.texture = _sheets[sheet]
	spr.hframes = 8
	spr.vframes = counts.size()
	base_scale = scale_v
	scale = Vector2.ONE * scale_v
	tint = col
	spr.modulate = col
	dead = false
	visible = true
	modulate.a = 1.0
	play(0, true)

func play(r: int, lp := false, speed := 12.0) -> void:
	if dead and r != counts.size() - (2 if hero else 1): return
	row = r
	frame_f = 0.0
	loop = lp
	fps = speed
	_apply()

func idle() -> void: play(0, true, 9.0)
func attack() -> void:
	if not dead: play(1, false, 22.0)
func skill() -> void:
	if hero and not dead: play(2, false, 16.0)
func hurt() -> void:
	flash = 1.0
	if dead: return
	if row == 0: play(3 if hero else 2, false, 20.0)
func die() -> void:
	play(4 if hero else 3, false, 14.0)
	dead = true
func cheer() -> void:
	if hero: play(5, true, 10.0)

func _apply() -> void:
	if spr.texture == null: return
	var n: int = counts[row]
	var f = int(frame_f)
	if f >= n: f = n - 1
	spr.frame = row * 8 + f

func _process(delta: float) -> void:
	if spr == null or spr.texture == null: return
	frame_f += delta * fps
	var n: int = counts[row]
	if frame_f >= n:
		if loop: frame_f = fmod(frame_f, n)
		elif dead: frame_f = n - 1
		else:
			idle()
	_apply()
	if flash > 0.0:
		flash = max(0.0, flash - delta * 10.0)
		spr.modulate = tint.lerp(Color(1.8, 1.6, 1.6), flash * 0.5)
	if not dead:
		bob_t += delta
		spr.scale = Vector2(1.0 + sin(bob_t * 3.0) * 0.012, 1.0 - sin(bob_t * 3.0) * 0.012)
