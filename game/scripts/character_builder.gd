extends RefCounted
## Assemble un personnage Quaternius : tête du personnage de base + tenue modulaire (même squelette).
## Le corps de base est réduit à la tête (sinon il traverse les vêtements), comme le conseille Quaternius.

const BASES := {"male": "res://assets/hero/Superhero_Male_FullBody.gltf", "female": "res://assets/hero/Superhero_Female_FullBody.gltf"}
static var _head_meshes := {}
static var _mat_cache := {}

## Corps de base -> tête seule (triangles au-dessus du cou, position de repos), calculé une fois.
static func _head_only(src: Mesh, cut_y: float) -> ArrayMesh:
	if _head_meshes.has(src): return _head_meshes[src]
	var arr := src.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var keep := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var y := (v[idx[t]].y + v[idx[t + 1]].y + v[idx[t + 2]].y) / 3.0
		var x := absf(v[idx[t]].x + v[idx[t + 1]].x + v[idx[t + 2]].x) / 3.0
		if y > cut_y and x < 0.2:
			keep.append(idx[t]); keep.append(idx[t + 1]); keep.append(idx[t + 2])
	arr[Mesh.ARRAY_INDEX] = keep
	# canaux personnalisés inutilisés par nos matériaux (leur format exigerait des drapeaux)
	arr[Mesh.ARRAY_CUSTOM0] = null
	arr[Mesh.ARRAY_CUSTOM1] = null
	arr[Mesh.ARRAY_CUSTOM2] = null
	arr[Mesh.ARRAY_CUSTOM3] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, src.surface_get_material(0))
	_head_meshes[src] = m
	return m

## opts : outfit (chemin glTF), texture (variante de couleur), hair ("" / chemin), beard (bool), hide (noms de pièces à masquer)
static func build(opts: Dictionary) -> Node3D:
	var model: Node3D = load(BASES[opts.get("base", "male")]).instantiate()
	var sk: Skeleton3D = model.find_child("Skeleton3D")
	var body: MeshInstance3D = null
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name.to_lower().begins_with("superhero"): body = mi
	# on coupe juste sous la nuque (le col des tenues recouvre la jointure)
	var cut_y := sk.get_bone_global_rest(sk.find_bone("neck_01")).origin.y - 0.05
	body.mesh = _head_only(body.mesh, cut_y)
	# sourcils : la texture a de la transparence (sinon taches blanches)
	var brows: MeshInstance3D = model.find_child("Eyebrows")
	if brows:
		var bm: StandardMaterial3D = brows.mesh.surface_get_material(0).duplicate()
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		bm.alpha_scissor_threshold = 0.5
		bm.albedo_color = opts.get("hair_color", Color(0.32, 0.2, 0.12))
		brows.set_surface_override_material(0, bm)
	var outfit: Node3D = load(opts.outfit).instantiate()
	var tex: Texture2D = load(opts.texture) if opts.has("texture") else null
	for mi in outfit.find_children("*", "MeshInstance3D", true, false):
		var piece: MeshInstance3D = mi.duplicate()
		piece.name = mi.name
		sk.add_child(piece)
		piece.skeleton = NodePath("..")
		piece.skin = mi.skin
		# les textures Quaternius sont trop claires sous ce rendu : on assombrit la tenue
		var dim: Color = opts.get("dim", Color(0.8, 0.82, 0.76))
		for si in piece.mesh.get_surface_count():
			var m: Material = piece.mesh.surface_get_material(si)
			if not (m is StandardMaterial3D): continue
			var key := [m, tex, dim]
			if not _mat_cache.has(key):
				var c: StandardMaterial3D = m.duplicate()
				if tex and c.albedo_texture and c.albedo_texture.get_width() > 0 and not "Regular" in c.albedo_texture.resource_path:
					c.albedo_texture = tex
				c.albedo_color = c.albedo_color * dim
				_mat_cache[key] = c
			piece.set_surface_override_material(si, _mat_cache[key])
		if mi.name in opts.get("hide", []): piece.visible = false
	outfit.free()
	var head_rest := sk.get_bone_global_rest(sk.find_bone("Head"))
	var hairs := []
	if opts.get("hair", "") != "": hairs.append(opts.hair)
	if opts.get("beard", false): hairs.append("res://assets/hero/Hair_Beard.gltf")
	var skin_tint: Color = opts.get("skin", Color.WHITE)
	if skin_tint != Color.WHITE:
		var sm: StandardMaterial3D = body.mesh.surface_get_material(0).duplicate()
		sm.albedo_color = skin_tint
		body.set_surface_override_material(0, sm)
	for hp in hairs:
		var ba := BoneAttachment3D.new()
		ba.bone_name = "Head"
		ba.name = "Cheveux" if not "Beard" in hp else "Barbe"
		sk.add_child(ba)
		var hair: Node3D = load(hp).instantiate()
		ba.add_child(hair)
		hair.transform = head_rest.affine_inverse()
		for hm in hair.find_children("*", "MeshInstance3D", true, false):
			var hmat: StandardMaterial3D = hm.mesh.surface_get_material(0).duplicate()
			hmat.albedo_color = opts.get("hair_color", Color(0.32, 0.2, 0.12))
			hm.set_surface_override_material(0, hmat)
	return model

## Objet tenu dans une main (épée, bouclier, outil).
static func hold(model: Node3D, scene_path: String, bone: String, pos: Vector3, rot_deg: Vector3, scale := 1.0) -> Node3D:
	var sk: Skeleton3D = model.find_child("Skeleton3D")
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var item: Node3D = load(scene_path).instantiate()
	ba.add_child(item)
	item.position = pos
	item.rotation_degrees = rot_deg
	item.scale = Vector3.ONE * scale
	return item
