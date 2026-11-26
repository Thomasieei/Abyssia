extends SceneTree
# Rend chaque modèle 3D animé en planche de sprites (une ligne par animation).
# Lancement : xvfb-run godot --path game --rendering-driver opengl3 -s res://render_tmp.gd

const FR := 224
var jobs := [
	# id, chemin, yaw (deg), [ [nom_anim, frames, fraction_debut, fraction_fin], ... ]
	["zombie", "res://raw/character-zombie.glb", -40, "kenney"],
	["squelette", "res://raw/character-skeleton.glb", -40, "kenney"],
	["fantome", "res://raw/character-ghost.glb", -40, "kenney"],
	["vampire", "res://raw/character-vampire.glb", -40, "kenney"],
	["gardien", "res://raw/character-keeper.glb", -40, "kenney"],
	["orc", "res://raw/md/character-orc.glb", -40, "kenney"],
	["sq_minion", "res://raw/Skeleton_Minion.glb", -40, "kaykit"],
	["sq_guerrier", "res://raw/Skeleton_Warrior.glb", -40, "kaykit"],
	["sq_voleur", "res://raw/Skeleton_Rogue.glb", -40, "kaykit"],
	["sq_mage", "res://raw/Skeleton_Mage.glb", -40, "kaykit_mage"],
	["brute", "res://raw/brute.glb", -40, "valdbrume"],
	["rodeur", "res://raw/rodeur.glb", -40, "valdbrume"],
	["dragon", "res://raw/Dragon_Evolved.gltf", -55, "dragon"],
	["h_chevalier", "res://raw/Knight.glb", 40, "hero_knight"],
	["h_barbare", "res://raw/Barbarian.glb", 40, "hero_barb"],
	["h_mage", "res://raw/Mage.glb", 40, "hero_mage"],
	["h_voleur", "res://raw/Rogue_Hooded.glb", 40, "hero_rogue"],
]
var sets := {
	"kenney": [["idle", 8, 0, 1], ["attack-melee-right", 8, 0, 1], ["die", 5, 0, 0.35], ["die", 8, 0, 1]],
	"kaykit": [["Idle", 8, 0, 1], ["1H_Melee_Attack_Chop", 8, 0, 1], ["Hit_A", 5, 0, 1], ["Death_A", 8, 0, 1]],
	"kaykit_mage": [["Idle", 8, 0, 1], ["Spellcast_Shoot", 8, 0, 1], ["Hit_A", 5, 0, 1], ["Death_A", 8, 0, 1]],
	"valdbrume": [["Idle", 8, 0, 1], ["Attack", 8, 0, 1], ["Die", 5, 0, 0.3], ["Die", 8, 0, 1]],
	"dragon": [["Flying_Idle", 8, 0, 1], ["Headbutt", 8, 0, 1], ["HitReact", 5, 0, 1], ["Death", 8, 0, 1]],
	"hero_knight": [["Idle", 8, 0, 1], ["1H_Melee_Attack_Slice_Diagonal", 8, 0, 1], ["2H_Melee_Attack_Spin", 8, 0, 1], ["Hit_A", 5, 0, 1], ["Death_A", 8, 0, 1], ["Cheer", 8, 0, 1]],
	"hero_barb": [["2H_Melee_Idle", 8, 0, 1], ["2H_Melee_Attack_Chop", 8, 0, 1], ["2H_Melee_Attack_Spin", 8, 0, 1], ["Hit_A", 5, 0, 1], ["Death_A", 8, 0, 1], ["Cheer", 8, 0, 1]],
	"hero_mage": [["Idle", 8, 0, 1], ["Spellcast_Shoot", 8, 0, 1], ["Spellcast_Raise", 8, 0, 1], ["Hit_A", 5, 0, 1], ["Death_A", 8, 0, 1], ["Cheer", 8, 0, 1]],
	"hero_rogue": [["Idle", 8, 0, 1], ["Dualwield_Melee_Attack_Slice", 8, 0, 1], ["2H_Melee_Attack_Spin", 8, 0, 1], ["Hit_A", 5, 0, 1], ["Death_A", 8, 0, 1], ["Cheer", 8, 0, 1]],
}

var keep := {
	"h_chevalier": ["1H_Sword", "Round_Shield"],
	"h_barbare": ["2H_Axe"],
	"h_mage": ["2H_Staff"],
	"h_voleur": ["Knife", "Knife_Offhand"],
}
var weapons := {
	"sq_minion": [["handslot.r", "res://raw/sk/Skeleton_Blade.gltf"]],
	"sq_guerrier": [["handslot.r", "res://raw/sk/Skeleton_Axe.gltf"], ["handslot.l", "res://raw/sk/Skeleton_Shield_Large_A.gltf"]],
	"sq_voleur": [["handslot.r", "res://raw/sk/Skeleton_Blade.gltf"], ["handslot.l", "res://raw/sk/Skeleton_Shield_Small_B.gltf"]],
	"sq_mage": [["handslot.r", "res://raw/sk/Skeleton_Staff.gltf"]],
}
const HIDE_ALWAYS := ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "1H_Sword", "2H_Sword", "1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug", "Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]

var vp: SubViewport
var cam: Camera3D
var holder: Node3D

func _init():
	vp = SubViewport.new()
	vp.size = Vector2i(FR, FR)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.85)
	e.ambient_light_energy = 0.75
	env.environment = e
	vp.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, 25, 0)
	l.light_energy = 1.25
	vp.add_child(l)
	var l2 := DirectionalLight3D.new()
	l2.rotation_degrees = Vector3(-20, 200, 0)
	l2.light_energy = 0.45
	l2.light_color = Color(0.7, 0.8, 1.0)
	vp.add_child(l2)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)
	_run.call_deferred()

func _anim_len(ap: AnimationPlayer, n: String) -> float:
	if not ap.has_animation(n): return -1.0
	return ap.get_animation(n).length

func _run():
	var only := OS.get_environment("ONLY")
	DirAccess.make_dir_recursive_absolute("res://assets/sprites")
	for j in jobs:
		if only != "" and not (j[0] in only.split(",")): continue
		var sc = load(j[1])
		var inst: Node3D = sc.instantiate()
		holder.add_child(inst)
		inst.rotation_degrees.y = j[2]
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			if m.name in HIDE_ALWAYS: m.visible = m.name in keep.get(j[0], [])
		if weapons.has(j[0]):
			var skl: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
			for w in weapons[j[0]]:
				var ba := BoneAttachment3D.new()
				skl.add_child(ba)
				ba.bone_name = w[0]
				ba.add_child(load(w[1]).instantiate())
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var rows: Array = sets[j[3]]
		# Cadrage : on mesure l'AABB sur la pose idle et la pose d'attaque.
		var aabb := AABB()
		var first := true
		for r in rows:
			var n: String = r[0]
			if not ap.has_animation(n): continue
			for k in 4:
				ap.play(n); ap.seek(_anim_len(ap, n) * k / 4.0, true)
				for m in inst.find_children("*", "MeshInstance3D", true, false):
					var mi: MeshInstance3D = m
					var bb := mi.global_transform * mi.get_aabb()
					if first: aabb = bb; first = false
					else: aabb = aabb.merge(bb)
		var size := maxf(aabb.size.x, aabb.size.y) * 1.08
		cam.size = size
		var c := aabb.get_center()
		cam.position = Vector3(c.x, c.y, c.z + 20)
		cam.look_at(c)
		var cols := 0
		for r in rows: cols = maxi(cols, r[1])
		var sheet := Image.create(cols * FR, rows.size() * FR, false, Image.FORMAT_RGBA8)
		var info := []
		for ri in rows.size():
			var r = rows[ri]
			var n: String = r[0]
			var len := _anim_len(ap, n)
			if len < 0:
				print("RENDER manque ", j[0], " ", n)
				n = rows[0][0]; len = _anim_len(ap, n)
			info.append(r[1])
			for f in r[1]:
				var t: float = lerpf(r[2], r[3], float(f) / float(max(1, r[1] - (0 if r[3] < 1.0 else 0)))) * len
				if r[3] >= 1.0 and n.to_lower().find("death") < 0 and n.to_lower() != "die": t = float(f) / r[1] * len
				ap.play(n); ap.seek(minf(t, len - 0.001), true)
				await process_frame
				await process_frame
				var img := vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(img, Rect2i(0, 0, FR, FR), Vector2i(f * FR, ri * FR))
		sheet.save_png("res://assets/sprites/%s.png" % j[0])
		print("RENDER ok ", j[0], " ", info)
		inst.queue_free()
		await process_frame
	quit()
