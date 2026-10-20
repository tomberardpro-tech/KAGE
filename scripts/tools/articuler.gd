extends SceneTree
## Rig du ninja : squelette complet et animations clés, sans changer son apparence
## (mêmes sommets, même texture : on ajoute seulement des os et des poids de peau).
## Lancer (avec une fenêtre, pour que le maillage soit bien enregistré) :
## godot --path . --script res://scripts/tools/articuler.gd
## Écrit assets/models/ninja_articule.res, assets/models/ninja_animations.res,
## scenes/characters/ninja_modele.tscn et une copie du rig en .glb (pour Blender).

const CX := -0.03  # milieu du corps (en x, dans le repère du maillage)

## Os : nom, parent, position absolue (repère du maillage).
const LES_OS := [
	["Bassin", "", Vector3(CX, -0.31, 0.0)],
	["Ventre", "Bassin", Vector3(CX, -0.26, 0.0)],
	["Poitrine", "Ventre", Vector3(CX, -0.15, 0.0)],
	["Tete", "Poitrine", Vector3(CX, 0.01, 0.0)],
	["BrasG", "Poitrine", Vector3(CX + 0.15, -0.06, 0.0)],
	["AvantBrasG", "BrasG", Vector3(CX + 0.19, -0.15, 0.0)],
	["BrasD", "Poitrine", Vector3(CX - 0.155, -0.06, 0.0)],
	["AvantBrasD", "BrasD", Vector3(CX - 0.185, -0.15, 0.0)],
	["CuisseG", "Bassin", Vector3(CX + 0.055, -0.33, 0.0)],
	["TibiaG", "CuisseG", Vector3(CX + 0.055, -0.41, 0.0)],
	["PiedG", "TibiaG", Vector3(CX + 0.055, -0.47, 0.0)],
	["CuisseD", "Bassin", Vector3(CX - 0.06, -0.33, 0.0)],
	["TibiaD", "CuisseD", Vector3(CX - 0.06, -0.41, 0.0)],
	["PiedD", "TibiaD", Vector3(CX - 0.06, -0.47, 0.0)],
]

## Animations clés, en degrés (x positif : le membre part vers l'arrière, le buste se penche en avant,
## le tibia plie le genou, le pied pointe vers le bas ; avant-bras négatif : le coude plie).
## Chaque clé : [temps, {os: Vector3 degrés}, décalage du bassin en hauteur (m, repère du maillage)].
const BASE_ACCROUPI := {"Ventre": Vector3(20, 0, 0), "Poitrine": Vector3(12, 0, 0), "Tete": Vector3(-28, 0, 0),
	"BrasG": Vector3(-25, 0, 18), "AvantBrasG": Vector3(-75, 0, 0), "BrasD": Vector3(-25, 0, -18),
	"AvantBrasD": Vector3(-75, 0, 0), "CuisseG": Vector3(-45, 0, 8), "TibiaG": Vector3(70, 0, 0),
	"PiedG": Vector3(-25, 0, 0), "CuisseD": Vector3(-45, 0, -8), "TibiaD": Vector3(70, 0, 0), "PiedD": Vector3(-25, 0, 0)}

func _init() -> void:
	var scene: Node = load("res://assets/models/ninja.glb").instantiate()
	var source: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = source.mesh
	var materiau := mesh.surface_get_material(0)
	var arrays := mesh.surface_get_arrays(0)
	var sommets: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var noms := LES_OS.map(func(o): return o[0])

	# Poids bruts selon la place de chaque sommet dans le corps
	var poids: Array = []
	for p in sommets:
		poids.append(_poids_sommet(p, noms))
	# Lissage le long de la surface (sommets soudés par position) pour des plis doux
	var soude := {}
	var cle := PackedInt32Array()
	cle.resize(sommets.size())
	for i in sommets.size():
		var k := Vector3i((sommets[i] * 2000.0).round())
		if not soude.has(k):
			soude[k] = soude.size()
		cle[i] = soude[k]
	var voisins := []
	voisins.resize(soude.size())
	for i in voisins.size():
		voisins[i] = {}
	for t in range(0, indices.size(), 3):
		for a in 3:
			for b in 3:
				if a != b:
					voisins[cle[indices[t + a]]][cle[indices[t + b]]] = true
	var w_soude := []
	w_soude.resize(soude.size())
	for i in sommets.size():
		w_soude[cle[i]] = poids[i]
	for passe in 4:
		var suivant := []
		suivant.resize(w_soude.size())
		for i in w_soude.size():
			var somme: PackedFloat32Array = w_soude[i].duplicate()
			var n := 1.0
			for v in voisins[i]:
				for b in somme.size():
					somme[b] += w_soude[v][b]
				n += 1.0
			for b in somme.size():
				somme[b] /= n
			suivant[i] = somme
		w_soude = suivant

	# 4 os au plus par sommet
	var os_tab := PackedInt32Array()
	var w_tab := PackedFloat32Array()
	for i in sommets.size():
		var w: PackedFloat32Array = w_soude[cle[i]]
		var ordre := range(w.size())
		ordre.sort_custom(func(a, b): return w[a] > w[b])
		var total := 0.0
		for k in 4:
			total += w[ordre[k]]
		for k in 4:
			os_tab.append(ordre[k])
			w_tab.append(w[ordre[k]] / maxf(total, 0.0001))
	arrays[Mesh.ARRAY_BONES] = os_tab
	arrays[Mesh.ARRAY_WEIGHTS] = w_tab
	var articule := ArrayMesh.new()
	articule.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	articule.surface_set_material(0, materiau)
	ResourceSaver.save(articule, "res://assets/models/ninja_articule.res")

	# Scène : squelette + maillage avec sa peau
	var modele := Node3D.new()
	modele.name = "Modele"
	modele.set_script(load("res://scripts/anim_chibi.gd"))
	var squelette := Skeleton3D.new()
	squelette.name = "Squelette"
	squelette.transform = Transform3D(Basis().scaled(Vector3.ONE * 1.786 * 0.7), Vector3(0, 0.625, 0))
	modele.add_child(squelette)
	squelette.owner = modele
	var skin := Skin.new()
	for o in LES_OS:
		var i := squelette.add_bone(o[0])
		var parent: int = squelette.find_bone(o[1]) if o[1] != "" else -1
		squelette.set_bone_parent(i, parent)
		var local: Vector3 = o[2] - (LES_OS[parent][2] if parent >= 0 else Vector3.ZERO)
		squelette.set_bone_rest(i, Transform3D(Basis(), local))
		skin.add_named_bind(o[0], Transform3D(Basis(), -o[2]))
	squelette.reset_bone_poses()
	var corps := MeshInstance3D.new()
	corps.name = "Ninja"
	corps.mesh = load("res://assets/models/ninja_articule.res")
	corps.skin = skin
	squelette.add_child(corps)
	corps.owner = modele
	corps.skeleton = NodePath("..")
	var lib := _bibliotheque(squelette)
	ResourceSaver.save(lib, "res://assets/models/ninja_animations.res")
	var joueur := AnimationPlayer.new()
	joueur.name = "Animations"
	modele.add_child(joueur)
	joueur.owner = modele
	joueur.add_animation_library("", load("res://assets/models/ninja_animations.res"))
	var paquet := PackedScene.new()
	paquet.pack(modele)
	var err := ResourceSaver.save(paquet, "res://scenes/characters/ninja_modele.tscn")
	print("ninja articulé -> ", error_string(err), " (", sommets.size(), " sommets)")
	# Copie du rig avec ses animations en .glb, pour l'ouvrir dans Blender
	var sortie := OS.get_cmdline_user_args()
	if not sortie.is_empty():
		var gltf := GLTFDocument.new()
		var etat := GLTFState.new()
		gltf.append_from_scene(modele, etat)
		print("glb -> ", error_string(gltf.write_to_filesystem(etat, sortie[0])))
	scene.free()
	modele.free()
	quit()


func _poids_sommet(p: Vector3, noms: Array) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(noms.size())
	var dx := p.x - CX
	var cote := "G" if dx > 0.0 else "D"
	# Jambes : cuisse, tibia sous le genou (-0,41), pied sous la cheville (-0,465)
	var jambe := 1.0 - smoothstep(-0.38, -0.31, p.y)
	if jambe > 0.0:
		var pied := 1.0 - smoothstep(-0.475, -0.455, p.y)
		var tibia := (1.0 - smoothstep(-0.43, -0.39, p.y)) * (1.0 - pied)
		w[noms.find("Pied" + cote)] = jambe * pied
		w[noms.find("Tibia" + cote)] = jambe * tibia
		w[noms.find("Cuisse" + cote)] = jambe * (1.0 - pied - tibia)
	var reste := 1.0 - jambe
	# Tête au-dessus du cou
	var tete := smoothstep(-0.03, 0.05, p.y) * reste
	w[noms.find("Tete")] = tete
	reste -= tete
	# Bras le long du corps : bras, puis avant-bras et main sous le coude (-0,15)
	var seuil := 0.13 if dx > 0.0 else 0.135
	var bras := smoothstep(seuil, seuil + 0.04, absf(dx)) * (1.0 - smoothstep(-0.07, -0.01, p.y)) * smoothstep(-0.3, -0.26, p.y)
	bras *= reste
	var avant := 1.0 - smoothstep(-0.17, -0.13, p.y)
	w[noms.find("AvantBras" + cote)] = bras * avant
	w[noms.find("Bras" + cote)] = bras * (1.0 - avant)
	reste -= bras
	# Tronc : bassin, ventre, poitrine
	var poitrine := smoothstep(-0.2, -0.1, p.y)
	var ventre := smoothstep(-0.32, -0.24, p.y) * (1.0 - poitrine)
	w[noms.find("Poitrine")] = reste * poitrine
	w[noms.find("Ventre")] = reste * ventre
	w[noms.find("Bassin")] = reste * (1.0 - poitrine - ventre)
	return w


## Pose symétrique : la gauche devient la droite (et les rotations de côté s'inversent).
func _miroir(pose: Dictionary) -> Dictionary:
	var m := {}
	for nom in pose:
		var v: Vector3 = pose[nom]
		var autre: String = nom
		if nom.ends_with("G"):
			autre = nom.trim_suffix("G") + "D"
		elif nom.ends_with("D"):
			autre = nom.trim_suffix("D") + "G"
		m[autre] = Vector3(v.x, -v.y, -v.z)
	return m


func _fusion(a: Dictionary, b: Dictionary) -> Dictionary:
	var r := a.duplicate()
	r.merge(b, true)
	return r


func _animations() -> Dictionary:
	# Course : contact jambe gauche devant, passage, puis la même chose en miroir
	var contact := {"CuisseG": Vector3(-42, 0, 0), "TibiaG": Vector3(12, 0, 0), "PiedG": Vector3(-12, 0, 0),
		"CuisseD": Vector3(38, 0, 0), "TibiaD": Vector3(35, 0, 0), "PiedD": Vector3(22, 0, 0),
		"BrasG": Vector3(48, 0, 8), "AvantBrasG": Vector3(-55, 0, 0), "BrasD": Vector3(-50, 0, -8), "AvantBrasD": Vector3(-70, 0, 0),
		"Ventre": Vector3(10, 0, 0), "Poitrine": Vector3(4, -10, 0), "Tete": Vector3(-10, 9, 0), "Bassin": Vector3(0, 7, 0)}
	var passage := {"CuisseG": Vector3(2, 0, 0), "TibiaG": Vector3(18, 0, 0), "PiedG": Vector3(0, 0, 0),
		"CuisseD": Vector3(-18, 0, 0), "TibiaD": Vector3(95, 0, 0), "PiedD": Vector3(30, 0, 0),
		"BrasG": Vector3(0, 0, 8), "AvantBrasG": Vector3(-70, 0, 0), "BrasD": Vector3(0, 0, -8), "AvantBrasD": Vector3(-70, 0, 0),
		"Ventre": Vector3(12, 0, 0), "Poitrine": Vector3(4, 0, 0), "Tete": Vector3(-12, 0, 0), "Bassin": Vector3.ZERO}
	# Accroupi : petits pas sur la pose de base
	var pas_g := _fusion(BASE_ACCROUPI, {"CuisseG": Vector3(-58, 0, 8), "TibiaG": Vector3(65, 0, 0), "CuisseD": Vector3(-32, 0, -8), "TibiaD": Vector3(80, 0, 0)})
	var saut_haut := {"CuisseG": Vector3(-65, 0, 0), "TibiaG": Vector3(90, 0, 0), "PiedG": Vector3(0, 0, 0),
		"CuisseD": Vector3(12, 0, 0), "TibiaD": Vector3(60, 0, 0), "PiedD": Vector3(10, 0, 0),
		"BrasG": Vector3(-150, 0, 22), "AvantBrasG": Vector3(-25, 0, 0), "BrasD": Vector3(-150, 0, -22), "AvantBrasD": Vector3(-25, 0, 0),
		"Ventre": Vector3(-4, 0, 0), "Poitrine": Vector3(-4, 0, 0), "Tete": Vector3(-10, 0, 0)}
	var chute := {"CuisseG": Vector3(-28, 0, 6), "TibiaG": Vector3(40, 0, 0), "PiedG": Vector3(-10, 0, 0),
		"CuisseD": Vector3(12, 0, -6), "TibiaD": Vector3(25, 0, 0), "PiedD": Vector3(10, 0, 0),
		"BrasG": Vector3(-25, 0, 75), "AvantBrasG": Vector3(-20, 0, 0), "BrasD": Vector3(-25, 0, -75), "AvantBrasD": Vector3(-20, 0, 0),
		"Ventre": Vector3(4, 0, 0), "Tete": Vector3(8, 0, 0)}
	var dash := {"Ventre": Vector3(28, 0, 0), "Poitrine": Vector3(16, 0, 0), "Tete": Vector3(-34, 0, 0),
		"BrasG": Vector3(85, 0, 22), "AvantBrasG": Vector3(-10, 0, 0), "BrasD": Vector3(85, 0, -22), "AvantBrasD": Vector3(-10, 0, 0),
		"CuisseG": Vector3(-62, 0, 0), "TibiaG": Vector3(75, 0, 0), "PiedG": Vector3(-10, 0, 0),
		"CuisseD": Vector3(52, 0, 0), "TibiaD": Vector3(45, 0, 0), "PiedD": Vector3(35, 0, 0)}
	var repos_a := {"Poitrine": Vector3(2, 0, 0), "BrasG": Vector3(3, 0, 6), "AvantBrasG": Vector3(-12, 0, 0),
		"BrasD": Vector3(3, 0, -6), "AvantBrasD": Vector3(-12, 0, 0), "Tete": Vector3(2, -6, 0)}
	var repos_b := {"Poitrine": Vector3(-3, 0, 0), "BrasG": Vector3(-3, 0, 10), "AvantBrasG": Vector3(-18, 0, 0),
		"BrasD": Vector3(-3, 0, -10), "AvantBrasD": Vector3(-18, 0, 0), "Tete": Vector3(-3, 6, 0)}
	return {
		"repos": {"boucle": true, "duree": 2.6, "cles": [[0.0, repos_a, 0.0], [1.3, repos_b, 0.004], [2.6, repos_a, 0.0]]},
		"course": {"boucle": true, "duree": 0.5, "cles": [[0.0, contact, -0.012], [0.125, passage, 0.02],
			[0.25, _miroir(contact), -0.012], [0.375, _miroir(passage), 0.02], [0.5, contact, -0.012]]},
		"accroupi": {"boucle": true, "duree": 0.9, "cles": [[0.0, pas_g, -0.035], [0.45, _miroir(pas_g), -0.03], [0.9, pas_g, -0.035]]},
		"accroupi_repos": {"boucle": true, "duree": 1.6, "cles": [[0.0, BASE_ACCROUPI, -0.035],
			[0.8, _fusion(BASE_ACCROUPI, {"Poitrine": Vector3(8, 0, 0), "Tete": Vector3(-24, 10, 0)}), -0.033], [1.6, BASE_ACCROUPI, -0.035]]},
		"saut": {"boucle": false, "duree": 0.28, "cles": [[0.0, _fusion(BASE_ACCROUPI, {"BrasG": Vector3(40, 0, 10), "BrasD": Vector3(40, 0, -10)}), -0.03], [0.28, saut_haut, 0.0]]},
		"chute": {"boucle": true, "duree": 0.7, "cles": [[0.0, chute, 0.0],
			[0.35, _fusion(chute, {"BrasG": Vector3(-25, 0, 62), "BrasD": Vector3(-25, 0, -62)}), 0.0], [0.7, chute, 0.0]]},
		"dash": {"boucle": false, "duree": 0.12, "cles": [[0.0, dash, -0.01], [0.12, dash, -0.01]]},
		"atterrissage": {"boucle": false, "duree": 0.32, "cles": [[0.0, _fusion(BASE_ACCROUPI, {"BrasG": Vector3(-20, 0, 45), "BrasD": Vector3(-20, 0, -45)}), -0.045],
			[0.32, repos_a, 0.0]]},
	}


func _bibliotheque(squelette: Skeleton3D) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var anims := _animations()
	for nom in anims:
		var d: Dictionary = anims[nom]
		var anim := Animation.new()
		anim.length = d["duree"]
		anim.loop_mode = Animation.LOOP_LINEAR if d["boucle"] else Animation.LOOP_NONE
		for o in LES_OS:
			var piste := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(piste, NodePath("Squelette:" + o[0]))
			for cle in d["cles"]:
				var v: Vector3 = cle[1].get(o[0], Vector3.ZERO)
				anim.rotation_track_insert_key(piste, cle[0], Quaternion.from_euler(v * PI / 180.0))
		var bassin := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(bassin, NodePath("Squelette:Bassin"))
		var repos: Vector3 = squelette.get_bone_rest(0).origin
		for cle in d["cles"]:
			bassin_insere(anim, bassin, cle[0], repos + Vector3(0, cle[2], 0))
		lib.add_animation(nom, anim)
	return lib


func bassin_insere(anim: Animation, piste: int, t: float, v: Vector3) -> void:
	anim.position_track_insert_key(piste, t, v)
