extends SceneTree
# Extrait les animations utiles de UAL1/UAL2 (Quaternius) dans une AnimationLibrary légère.
const KEEP := ["Idle_Loop","Jog_Fwd_Loop","Sprint_Loop","Walk_Loop","Sword_Idle","Sword_Regular_A","Sword_Regular_B","Sword_Regular_C","Sword_Heavy_A","Sword_Dash","Sword_GroundPound","Sword_Block","Idle_Shield_Loop","Hit_Chest","Hit_Knockback","Death01","Roll","Farm_Harvest","PickUp_Kneeling","Celebration","Spell_Simple_Shoot","Consume","Idle_LookAround_Loop","Jump_Start","Jump_Loop","Jump_Land"]
func _init():
	var lib := AnimationLibrary.new()
	for path in OS.get_cmdline_user_args():
		var doc := GLTFDocument.new(); var st := GLTFState.new()
		if doc.append_from_file(path, st) != OK: push_error("load " + path); continue
		var root := doc.generate_scene(st)
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		for n in ap.get_animation_list():
			if n in KEEP and not lib.has_animation(n):
				var a: Animation = ap.get_animation(n).duplicate(true)
				# garder seulement les pistes d'os (rotation + position du bassin), pas d'échelle
				for i in range(a.get_track_count() - 1, -1, -1):
					if a.track_get_type(i) == Animation.TYPE_SCALE_3D: a.remove_track(i)
				if n.ends_with("_Loop") or n in ["Sword_Idle"]: a.loop_mode = Animation.LOOP_LINEAR
				lib.add_animation(n, a)
		root.free()
	print("anims: ", lib.get_animation_list().size(), " ", lib.get_animation_list())
	var tracks = lib.get_animation(lib.get_animation_list()[0])
	print("track0: ", tracks.track_get_path(0))
	ResourceSaver.save(lib, "res://assets/anims/hero_anims.res", ResourceSaver.FLAG_COMPRESS)
	quit()
