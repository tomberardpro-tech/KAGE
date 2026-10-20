extends SceneTree
## Rig du ninja et des gardes : squelette complet et animations clés, sans changer leur apparence
## (mêmes sommets, même texture : on ajoute seulement des os et des poids de peau).
## Lancer (avec une fenêtre, pour que le maillage soit bien enregistré) :
## godot --path . --script res://scripts/tools/articuler.gd -- [garde] [copie.glb]
## Écrit assets/models/<perso>_articule.res, <perso>_animations.res,
## scenes/characters/<perso>_modele.tscn et, si on donne un chemin .glb, une copie pour Blender.
## Le ninja reçoit aussi son katana (dans le dos, et dans la main pendant le coup).

const CX := -0.03  # milieu du corps du ninja (en x, dans le repère du maillage)

## Os du garde : il tient sa lance dans la main droite (côté -x).
const OS_GARDE := [
	["Bassin", "", Vector3(0.0, -0.35, 0.0)],
	["Ventre", "Bassin", Vector3(0.0, -0.29, 0.0)],
	["Poitrine", "Ventre", Vector3(0.0, -0.19, 0.0)],
	["Tete", "Poitrine", Vector3(0.0, -0.08, 0.0)],
	["BrasG", "Poitrine", Vector3(0.17, -0.13, 0.0)],
	["AvantBrasG", "BrasG", Vector3(0.21, -0.22, 0.0)],
	["BrasD", "Poitrine", Vector3(-0.15, -0.13, 0.0)],
	["AvantBrasD", "BrasD", Vector3(-0.21, -0.17, 0.05)],
	["CuisseG", "Bassin", Vector3(0.075, -0.37, 0.0)],
	["TibiaG", "CuisseG", Vector3(0.075, -0.42, 0.0)],
	["PiedG", "TibiaG", Vector3(0.075, -0.46, 0.0)],
	["CuisseD", "Bassin", Vector3(-0.065, -0.37, 0.0)],
	["TibiaD", "CuisseD", Vector3(-0.065, -0.42, 0.0)],
	["PiedD", "TibiaD", Vector3(-0.065, -0.46, 0.0)],
]
const LANCE := Vector2(-0.21, 0.134)  ## axe de la lance du garde (x, z)

var LES_OS: Array
var garde := false

## Os du ninja : nom, parent, position absolue (repère du maillage).
const OS_NINJA := [
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
	var args := Array(OS.get_cmdline_user_args())
	garde = "garde" in args
	args.erase("garde")
	LES_OS = OS_GARDE if garde else OS_NINJA
	var perso := "garde" if garde else "ninja"
	var scene: Node = load("res://assets/models/%s.glb" % perso).instantiate()
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
		poids.append(_poids_garde(p, noms) if garde else _poids_sommet(p, noms))
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

	# La lance reste d'un bloc dans la main, même après le lissage
	if garde:
		var main := PackedFloat32Array()
		main.resize(noms.size())
		main[noms.find("AvantBrasD")] = 1.0
		for i in sommets.size():
			if _est_lance(sommets[i]):
				w_soude[cle[i]] = main

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
	ResourceSaver.save(articule, "res://assets/models/%s_articule.res" % perso)

	# Scène : squelette + maillage avec sa peau
	var modele := Node3D.new()
	modele.name = "Modele"
	modele.set_script(load("res://scripts/anim_chibi.gd"))
	var squelette := Skeleton3D.new()
	squelette.name = "Squelette"
	# même taille et même place que les anciennes scènes *_modele.tscn
	squelette.transform = Transform3D(Basis().scaled(Vector3.ONE * 2.03 * 0.7), Vector3(0, 0.71, 0)) if garde \
		else Transform3D(Basis().scaled(Vector3.ONE * 1.786 * 0.7), Vector3(0, 0.625, 0))
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
	corps.name = "Garde" if garde else "Ninja"
	corps.mesh = load("res://assets/models/%s_articule.res" % perso)
	corps.skin = skin
	squelette.add_child(corps)
	corps.owner = modele
	corps.skeleton = NodePath("..")
	var lib := _bibliotheque(squelette)
	ResourceSaver.save(lib, "res://assets/models/%s_animations.res" % perso)
	if not garde:
		_katanas(squelette, modele)
	var joueur := AnimationPlayer.new()
	joueur.name = "Animations"
	modele.add_child(joueur)
	joueur.owner = modele
	joueur.add_animation_library("", load("res://assets/models/%s_animations.res" % perso))
	var paquet := PackedScene.new()
	paquet.pack(modele)
	var err := ResourceSaver.save(paquet, "res://scenes/characters/%s_modele.tscn" % perso)
	print(perso, " articulé -> ", error_string(err), " (", sommets.size(), " sommets)")
	# Copie du rig avec ses animations en .glb, pour l'ouvrir dans Blender
	var sortie := args
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


## Poids du garde : jambes courtes sous la jupe d'armure, grand casque, lance dans la main droite.
func _poids_garde(p: Vector3, noms: Array) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(noms.size())
	# La lance suit la main droite d'un bloc
	if _est_lance(p):
		w[noms.find("AvantBrasD")] = 1.0
		return w
	var cote := "G" if p.x > 0.0 else "D"
	var jambe := 1.0 - smoothstep(-0.39, -0.35, p.y)
	if jambe > 0.0:
		var pied := 1.0 - smoothstep(-0.47, -0.445, p.y)
		var tibia := (1.0 - smoothstep(-0.435, -0.405, p.y)) * (1.0 - pied)
		w[noms.find("Pied" + cote)] = jambe * pied
		w[noms.find("Tibia" + cote)] = jambe * tibia
		w[noms.find("Cuisse" + cote)] = jambe * (1.0 - pied - tibia)
	var reste := 1.0 - jambe
	var tete := smoothstep(-0.1, -0.05, p.y) * reste
	w[noms.find("Tete")] = tete
	reste -= tete
	var bras := smoothstep(0.13, 0.17, absf(p.x)) * (1.0 - smoothstep(-0.11, -0.07, p.y)) * smoothstep(-0.34, -0.3, p.y) * reste
	var avant := 1.0 - smoothstep(-0.21, -0.17, p.y) if p.x > 0.0 else smoothstep(0.17, 0.2, -p.x)
	w[noms.find("AvantBras" + cote)] = bras * avant
	w[noms.find("Bras" + cote)] = bras * (1.0 - avant)
	reste -= bras
	var poitrine := smoothstep(-0.24, -0.14, p.y)
	var ventre := smoothstep(-0.36, -0.28, p.y) * (1.0 - poitrine)
	w[noms.find("Poitrine")] = reste * poitrine
	w[noms.find("Ventre")] = reste * ventre
	w[noms.find("Bassin")] = reste * (1.0 - poitrine - ventre)
	return w


## Sommets de la lance du garde (manche fin, fer plus large en haut).
func _est_lance(p: Vector3) -> bool:
	var rayon := 0.085 if p.y > 0.24 else 0.045
	return p.y > -0.21 and Vector2(p.x - LANCE.x, p.z - LANCE.y).length() < rayon


## Katana du ninja : le fourreau (saya) toujours dans le dos ; la poignée dépasse du fourreau
## quand le sabre est rangé (KatanaDos), le sabre entier est dans la main droite quand il est sorti (KatanaMain).
func _katanas(squelette: Skeleton3D, modele: Node3D) -> void:
	var main := BoneAttachment3D.new()
	main.name = "MainD"
	main.bone_name = "AvantBrasD"
	squelette.add_child(main)
	main.owner = modele
	var lame := _katana(true)
	lame.name = "KatanaMain"
	lame.position = Vector3(-0.015, -0.1, 0.0)
	lame.scale = Vector3.ONE * 1.5  # un grand sabre, bien visible
	lame.visible = false
	main.add_child(lame)
	_posseder(lame, modele)
	var dos := BoneAttachment3D.new()
	dos.name = "Dos"
	dos.bone_name = "Poitrine"
	squelette.add_child(dos)
	dos.owner = modele
	# en travers du dos, la poignée au-dessus de l'épaule droite
	var place := Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(-35)) * Basis(Vector3(1, 0, 0), deg_to_rad(-90)), Vector3(CX - 0.02, -0.08, -0.12))
	var fourreau := _saya()
	fourreau.name = "Fourreau"
	fourreau.transform = place
	fourreau.scale = Vector3.ONE * 1.5
	dos.add_child(fourreau)
	_posseder(fourreau, modele)
	var poignee := _katana(false)
	poignee.name = "KatanaDos"
	poignee.transform = place
	poignee.scale = Vector3.ONE * 1.5
	dos.add_child(poignee)
	_posseder(poignee, modele)


func _posseder(n: Node, modele: Node) -> void:
	n.owner = modele
	for e in n.get_children():
		_posseder(e, modele)


func _mat_katana(couleur: String, metal := 0.0, rugueux := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(couleur)
	m.metallic = metal
	m.roughness = rugueux
	return m


## Katana le long de +z : poignée de -0,15 à 0, lame courbe de 0 à 0,5 (en unités du maillage).
## nu = faux : seulement la poignée, la garde et la bague (le reste est dans le fourreau).
func _katana(nu: bool) -> Node3D:
	var k := Node3D.new()
	# poignée tressée (tsuka) : fond de galuchat clair, losanges de tresse noire
	var galuchat := _mat_katana("#e8e0cc", 0.0, 0.7)
	var tresse := _mat_katana("#15151b", 0.0, 0.8)
	var or_ := _mat_katana("#d4a94e", 0.8, 0.3)
	var fer := _mat_katana("#26262c", 0.7, 0.45)
	_cylindre_k(k, 0.017, 0.016, 0.15, Vector3(0, 0, -0.075), galuchat, 12, Vector3(1.0, 1.25, 1.0))
	for n in 6:
		for s in [-1.0, 1.0]:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.037, 0.008, 0.03)
			b.mesh = bm
			b.material_override = tresse
			b.position = Vector3(0, 0, -0.015 - n * 0.023)
			b.rotation.z = s * 0.7
			b.scale = Vector3(1.0, 1.0, 1.0)
			k.add_child(b)
	_cylindre_k(k, 0.02, 0.02, 0.014, Vector3(0, 0, -0.152), or_, 12, Vector3(1.0, 1.25, 1.0))  # kashira
	_cylindre_k(k, 0.019, 0.019, 0.01, Vector3(0, 0, -0.004), or_, 12, Vector3(1.0, 1.25, 1.0))  # fuchi
	# garde ronde en fer, cerclée d'or
	_cylindre_k(k, 0.042, 0.042, 0.009, Vector3(0, 0, 0.006), fer, 20, Vector3(1.0, 1.08, 1.0))
	_cylindre_k(k, 0.044, 0.044, 0.005, Vector3(0, 0, 0.006), or_, 20, Vector3(1.0, 1.08, 1.0))
	_cylindre_k(k, 0.014, 0.016, 0.025, Vector3(0, 0, 0.022), or_, 10, Vector3(0.7, 1.6, 1.0))  # habaki
	if nu:
		var lame := MeshInstance3D.new()
		lame.mesh = _maillage_lame()
		var acier := StandardMaterial3D.new()
		acier.vertex_color_use_as_albedo = true
		acier.metallic = 0.85
		acier.roughness = 0.18
		acier.emission_enabled = true
		acier.emission = Color("#9fb4d4")
		acier.emission_energy_multiplier = 0.18
		lame.material_override = acier
		k.add_child(lame)
	return k


func _cylindre_k(parent: Node3D, haut: float, bas: float, longueur: float, centre: Vector3, m: Material,
		cotes: int, etire := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = haut
	c.bottom_radius = bas
	c.height = longueur
	c.radial_segments = cotes
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = centre
	mi.rotation.x = PI / 2.0  # le long de z
	mi.scale = Vector3(etire.x, etire.z, etire.y)
	parent.add_child(mi)


## Lame courbe : dos plat, arête (shinogi), tranchant clair avec une ligne de trempe ondulée (hamon),
## et une pointe (kissaki) qui remonte vers le dos.
func _maillage_lame() -> ArrayMesh:
	var longueur := 0.5
	var large := 0.036
	var epais := 0.011
	var sori := 0.022  # courbure
	var anneaux := 28
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := []
	for a in anneaux + 1:
		var u := float(a) / anneaux
		var z := 0.03 + u * longueur
		var y0 := sori * u * u  # le dos remonte vers la pointe
		var w := large * (1.0 - 0.25 * u)
		var pointe := smoothstep(0.86, 1.0, u)
		var bas := -w / 2.0 + pointe * w * 0.95  # le tranchant remonte vers le dos à la pointe
		var haut := w / 2.0
		var t := epais * (1.0 - 0.4 * u) * (1.0 - pointe * 0.9)
		var ondule := 0.32 + 0.08 * sin(u * 48.0) + 0.04 * sin(u * 113.0)
		var acier := Color("#8f97a3")
		var trempe := Color("#f2f5fa")
		# dos (2), arête (2), tranchant (1) ; la couleur passe au blanc sous la ligne de trempe
		var pts := [Vector2(-t * 0.35, haut), Vector2(t * 0.35, haut), Vector2(t / 2.0, haut - (haut - bas) * 0.3),
			Vector2(0.0, bas), Vector2(-t / 2.0, haut - (haut - bas) * 0.3)]
		var cols := [acier, acier, acier.lerp(trempe, 0.2), trempe, acier.lerp(trempe, 0.2)]
		var anneau := []
		for i in pts.size():
			anneau.append([Vector3(pts[i].x, pts[i].y + y0, z), cols[i].lerp(trempe, 0.0 if i < 3 or i == 4 else ondule)])
		sections.append(anneau)
	for a in anneaux:
		var s0: Array = sections[a]
		var s1: Array = sections[a + 1]
		for i in 5:
			var j := (i + 1) % 5
			for v in [s0[i], s1[i], s1[j], s0[i], s1[j], s0[j]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


## Fourreau laqué noir aux reflets rouges, bague d'or à l'entrée et bout ferré, cordon rouge.
func _saya() -> Node3D:
	var k := Node3D.new()
	var laque := _mat_katana("#14090b", 0.1, 0.22)
	laque.clearcoat_enabled = true
	laque.clearcoat = 0.8
	var or_ := _mat_katana("#d4a94e", 0.8, 0.3)
	var cordon := _mat_katana("#b3242a", 0.0, 0.8)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anneaux := 20
	var cotes := 12
	var longueur := 0.53
	for a in anneaux:
		for c in cotes:
			for d in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
				var u := float(a + d[0]) / anneaux
				var ang := float(c + d[1]) / cotes * TAU
				var z := 0.03 + u * longueur
				var y0 := 0.022 * u * u
				st.set_normal(Vector3(cos(ang), sin(ang), 0))
				st.add_vertex(Vector3(cos(ang) * 0.016, sin(ang) * 0.027 + y0, z))
	st.generate_normals()
	var corps := MeshInstance3D.new()
	corps.mesh = st.commit()
	corps.material_override = laque
	k.add_child(corps)
	_cylindre_k(k, 0.018, 0.018, 0.02, Vector3(0, 0, 0.04), or_, 12, Vector3(1.0, 1.65, 1.0))  # koiguchi
	_cylindre_k(k, 0.018, 0.016, 0.025, Vector3(0, 0.022, 0.55), or_, 12, Vector3(1.0, 1.6, 1.0))  # kojiri
	_cylindre_k(k, 0.019, 0.019, 0.012, Vector3(0, 0.001, 0.12), cordon, 12, Vector3(1.05, 1.7, 1.0))  # kurikata
	return k


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
	return _animations_garde() if garde else _animations_ninja()


func _animations_garde() -> Dictionary:
	var pas := {"CuisseG": Vector3(-26, 0, 0), "TibiaG": Vector3(8, 0, 0), "CuisseD": Vector3(22, 0, 0), "TibiaD": Vector3(25, 0, 0),
		"BrasG": Vector3(-22, 0, 6), "AvantBrasG": Vector3(-15, 0, 0), "BrasD": Vector3(4, 0, 0),
		"Poitrine": Vector3(0, -6, 0), "Ventre": Vector3(3, 0, 0), "Bassin": Vector3(0, 5, 0)}
	var milieu := {"CuisseG": Vector3(0, 0, 0), "TibiaG": Vector3(20, 0, 0), "CuisseD": Vector3(-8, 0, 0), "TibiaD": Vector3(45, 0, 0),
		"BrasG": Vector3(0, 0, 6), "AvantBrasG": Vector3(-20, 0, 0), "Ventre": Vector3(3, 0, 0)}
	var cours := {"CuisseG": Vector3(-40, 0, 0), "TibiaG": Vector3(15, 0, 0), "CuisseD": Vector3(35, 0, 0), "TibiaD": Vector3(45, 0, 0),
		"BrasG": Vector3(-35, 0, 10), "AvantBrasG": Vector3(-40, 0, 0), "BrasD": Vector3(0, 0, 0), "AvantBrasD": Vector3(8, 0, 0),
		"Poitrine": Vector3(8, -10, 0), "Ventre": Vector3(10, 0, 0), "Tete": Vector3(-8, 0, 0), "Bassin": Vector3(0, 8, 0)}
	var cours_m := {"CuisseG": Vector3(0, 0, 0), "TibiaG": Vector3(30, 0, 0), "CuisseD": Vector3(-12, 0, 0), "TibiaD": Vector3(70, 0, 0),
		"BrasG": Vector3(0, 0, 10), "AvantBrasG": Vector3(-40, 0, 0), "BrasD": Vector3(0, 0, 0), "AvantBrasD": Vector3(8, 0, 0),
		"Poitrine": Vector3(8, 0, 0), "Ventre": Vector3(10, 0, 0), "Tete": Vector3(-8, 0, 0)}
	var repos_a := {"Poitrine": Vector3(1, 0, 0), "BrasG": Vector3(0, 0, 4), "Tete": Vector3(0, -8, 0)}
	var repos_b := {"Poitrine": Vector3(-2, 0, 0), "BrasG": Vector3(0, 0, 7), "Tete": Vector3(0, 8, 0)}
	# Coup de lance : il se ramasse en arrière puis se fend en avant, la lance pointée
	# (le bras de la lance bouge peu : la lance est d'un seul bloc avec la main)
	var arme := {"BrasD": Vector3(10, 0, 0), "AvantBrasD": Vector3(0, 0, 0), "Poitrine": Vector3(-10, 12, 0), "Ventre": Vector3(-6, 0, 0),
		"CuisseG": Vector3(-20, 0, 0), "TibiaG": Vector3(20, 0, 0), "CuisseD": Vector3(15, 0, 0), "TibiaD": Vector3(20, 0, 0), "BrasG": Vector3(-20, 0, 15)}
	var pique := {"BrasD": Vector3(-12, 0, 0), "AvantBrasD": Vector3(28, 0, 0), "Poitrine": Vector3(22, -12, 0), "Ventre": Vector3(16, 0, 0),
		"CuisseG": Vector3(-35, 0, 0), "TibiaG": Vector3(30, 0, 0), "CuisseD": Vector3(25, 0, 0), "TibiaD": Vector3(15, 0, 0), "BrasG": Vector3(25, 0, 15)}
	return {
		"repos": {"boucle": true, "duree": 3.0, "cles": [[0.0, repos_a, 0.0], [1.5, repos_b, 0.003], [3.0, repos_a, 0.0]]},
		"marche": {"boucle": true, "duree": 0.9, "cles": [[0.0, pas, -0.006], [0.225, milieu, 0.008],
			[0.45, _miroir_garde(pas), -0.006], [0.675, _miroir_garde(milieu), 0.008], [0.9, pas, -0.006]]},
		"course": {"boucle": true, "duree": 0.5, "cles": [[0.0, cours, -0.01], [0.125, cours_m, 0.015],
			[0.25, _miroir_garde(cours), -0.01], [0.375, _miroir_garde(cours_m), 0.015], [0.5, cours, -0.01]]},
		"frappe": {"boucle": false, "duree": 0.6, "cles": [[0.0, repos_a, 0.0], [0.32, arme, -0.01], [0.42, pique, -0.015], [0.6, pique, -0.012]]},
	}


## Miroir pour le garde : seules les jambes et le bras gauche changent de côté,
## le bras droit garde la lance.
func _miroir_garde(pose: Dictionary) -> Dictionary:
	var m := {}
	for nom in pose:
		var v: Vector3 = pose[nom]
		if nom in ["BrasD", "AvantBrasD"]:
			m[nom] = v
		elif nom.begins_with("Cuisse") or nom.begins_with("Tibia") or nom.begins_with("Pied"):
			var autre: String = nom.trim_suffix("G") + "D" if nom.ends_with("G") else nom.trim_suffix("D") + "G"
			m[autre] = Vector3(v.x, -v.y, -v.z)
		elif nom == "BrasG":
			m[nom] = Vector3(-v.x, v.y, v.z)
		else:
			m[nom] = Vector3(v.x, -v.y, -v.z)
	return m


func _animations_ninja() -> Dictionary:
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
	# Coup de katana : il lève le sabre au-dessus de l'épaule et tranche en diagonale
	var garde_haute := {"BrasD": Vector3(-30, 0, -10), "AvantBrasD": Vector3(-50, 0, 0), "BrasG": Vector3(-10, 0, 15), "AvantBrasG": Vector3(-40, 0, 0),
		"CuisseG": Vector3(-25, 0, 6), "TibiaG": Vector3(30, 0, 0), "CuisseD": Vector3(18, 0, -6), "TibiaD": Vector3(28, 0, 0),
		"Ventre": Vector3(8, 0, 0), "Tete": Vector3(-6, 0, 0)}
	var armer := _fusion(garde_haute, {"BrasD": Vector3(-160, 0, -25), "AvantBrasD": Vector3(-40, 0, 0), "Poitrine": Vector3(-6, 28, 0),
		"Ventre": Vector3(0, 10, 0), "BrasG": Vector3(-40, 0, 25)})
	var frappe := _fusion(garde_haute, {"BrasD": Vector3(-35, 0, 15), "AvantBrasD": Vector3(-5, 0, 0), "Poitrine": Vector3(14, -30, 0),
		"Ventre": Vector3(14, -10, 0), "BrasG": Vector3(20, 0, 30), "CuisseG": Vector3(-45, 0, 6), "TibiaG": Vector3(45, 0, 0), "Tete": Vector3(-14, 0, 0)})
	var suite := _fusion(frappe, {"BrasD": Vector3(5, 0, 25), "Poitrine": Vector3(16, -38, 0)})
	# Escalade : bras tendus vers le haut pour s'agripper, puis il se hisse genou en avant
	var accroche := {"BrasG": Vector3(-165, 0, 12), "AvantBrasG": Vector3(-20, 0, 0), "BrasD": Vector3(-165, 0, -12), "AvantBrasD": Vector3(-20, 0, 0),
		"CuisseG": Vector3(-35, 0, 0), "TibiaG": Vector3(70, 0, 0), "CuisseD": Vector3(10, 0, 0), "TibiaD": Vector3(40, 0, 0),
		"Ventre": Vector3(-6, 0, 0), "Tete": Vector3(-20, 0, 0)}
	var hisse := {"BrasG": Vector3(-70, 0, 20), "AvantBrasG": Vector3(-95, 0, 0), "BrasD": Vector3(-70, 0, -20), "AvantBrasD": Vector3(-95, 0, 0),
		"CuisseG": Vector3(-90, 0, 0), "TibiaG": Vector3(110, 0, 0), "PiedG": Vector3(-20, 0, 0), "CuisseD": Vector3(-20, 0, 0), "TibiaD": Vector3(80, 0, 0),
		"Ventre": Vector3(28, 0, 0), "Poitrine": Vector3(15, 0, 0), "Tete": Vector3(-30, 0, 0)}
	# Trésor : il brandit l'objet bien haut de la main droite, le poing gauche sur la hanche, fier
	var brandir := {"BrasD": Vector3(-10, 0, -135), "AvantBrasD": Vector3(-10, 0, 0),
		"BrasG": Vector3(-10, 0, 48), "AvantBrasG": Vector3(-95, 0, 0),
		"CuisseG": Vector3(-4, 0, 12), "CuisseD": Vector3(-4, 0, -12), "Poitrine": Vector3(-10, -6, 0), "Tete": Vector3(-16, 8, 0)}
	# Marche lente (le vieux maître, les villageois)
	var pas_lent := {"CuisseG": Vector3(-26, 0, 0), "TibiaG": Vector3(8, 0, 0), "CuisseD": Vector3(20, 0, 0), "TibiaD": Vector3(22, 0, 0),
		"BrasG": Vector3(22, 0, 6), "AvantBrasG": Vector3(-20, 0, 0), "BrasD": Vector3(-22, 0, -6), "AvantBrasD": Vector3(-25, 0, 0),
		"Ventre": Vector3(6, 0, 0), "Poitrine": Vector3(6, 0, 0)}
	var salut := {"Ventre": Vector3(18, 0, 0), "Poitrine": Vector3(26, 0, 0), "Tete": Vector3(14, 0, 0),
		"BrasG": Vector3(8, 0, 4), "AvantBrasG": Vector3(-30, 0, 0), "BrasD": Vector3(8, 0, -4), "AvantBrasD": Vector3(-30, 0, 0)}
	return {
		"repos": {"boucle": true, "duree": 2.6, "cles": [[0.0, repos_a, 0.0], [1.3, repos_b, 0.004], [2.6, repos_a, 0.0]]},
		"brandir": {"boucle": false, "duree": 0.7, "cles": [[0.0, repos_a, 0.0], [0.3, _fusion(brandir, {"BrasD": Vector3(-20, 0, -95), "AvantBrasD": Vector3(-45, 0, 0)}), -0.01], [0.5, brandir, 0.03], [0.7, brandir, 0.02]]},
		"marche": {"boucle": true, "duree": 1.1, "cles": [[0.0, pas_lent, -0.005], [0.275, repos_a, 0.008], [0.55, _miroir(pas_lent), -0.005], [0.825, repos_a, 0.008], [1.1, pas_lent, -0.005]]},
		"salut": {"boucle": false, "duree": 1.4, "cles": [[0.0, repos_a, 0.0], [0.45, salut, -0.01], [0.95, salut, -0.01], [1.4, repos_a, 0.0]]},
		"course": {"boucle": true, "duree": 0.5, "cles": [[0.0, contact, -0.012], [0.125, passage, 0.02],
			[0.25, _miroir(contact), -0.012], [0.375, _miroir(passage), 0.02], [0.5, contact, -0.012]]},
		"accroupi": {"boucle": true, "duree": 0.9, "cles": [[0.0, pas_g, -0.035], [0.45, _miroir(pas_g), -0.03], [0.9, pas_g, -0.035]]},
		"accroupi_repos": {"boucle": true, "duree": 1.6, "cles": [[0.0, BASE_ACCROUPI, -0.035],
			[0.8, _fusion(BASE_ACCROUPI, {"Poitrine": Vector3(8, 0, 0), "Tete": Vector3(-24, 10, 0)}), -0.033], [1.6, BASE_ACCROUPI, -0.035]]},
		"saut": {"boucle": false, "duree": 0.28, "cles": [[0.0, _fusion(BASE_ACCROUPI, {"BrasG": Vector3(40, 0, 10), "BrasD": Vector3(40, 0, -10)}), -0.03], [0.28, saut_haut, 0.0]]},
		"chute": {"boucle": true, "duree": 0.7, "cles": [[0.0, chute, 0.0],
			[0.35, _fusion(chute, {"BrasG": Vector3(-25, 0, 62), "BrasD": Vector3(-25, 0, -62)}), 0.0], [0.7, chute, 0.0]]},
		"dash": {"boucle": false, "duree": 0.12, "cles": [[0.0, dash, -0.01], [0.12, dash, -0.01]]},
		"frappe": {"boucle": false, "duree": 0.42, "cles": [[0.0, garde_haute, -0.01], [0.1, armer, -0.015],
			[0.2, frappe, -0.03], [0.3, suite, -0.03], [0.42, garde_haute, -0.01]]},
		"grimpe": {"boucle": false, "duree": 0.42, "cles": [[0.0, accroche, 0.0], [0.2, hisse, 0.02], [0.42, BASE_ACCROUPI, -0.03]]},
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
