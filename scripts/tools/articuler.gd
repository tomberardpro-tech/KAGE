extends SceneTree
## Donne un squelette au modèle TRELLIS du ninja, sans changer son apparence :
## mêmes sommets, même texture, on ajoute seulement des os et des poids de peau.
## Lancer (avec une fenêtre, pour que le maillage soit bien enregistré) :
## godot --path . --script res://scripts/tools/articuler.gd
## Écrit assets/models/ninja_articule.res et scenes/characters/ninja_modele.tscn.

const CX := -0.03  # milieu du corps (en x, dans le repère du maillage)

## Os : nom, parent, position absolue (repère du maillage).
const LES_OS := [
	["Bassin", "", Vector3(CX, -0.31, 0.0)],
	["Corps", "Bassin", Vector3(CX, -0.31, 0.0)],
	["Tete", "Corps", Vector3(CX, 0.01, 0.0)],
	["BrasG", "Corps", Vector3(CX + 0.15, -0.06, 0.0)],
	["BrasD", "Corps", Vector3(CX - 0.155, -0.06, 0.0)],
	["JambeG", "Bassin", Vector3(CX + 0.055, -0.33, 0.0)],
	["GenouG", "JambeG", Vector3(CX + 0.055, -0.42, 0.0)],
	["JambeD", "Bassin", Vector3(CX - 0.06, -0.33, 0.0)],
	["GenouD", "JambeD", Vector3(CX - 0.06, -0.42, 0.0)],
]


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
	var paquet := PackedScene.new()
	paquet.pack(modele)
	var err := ResourceSaver.save(paquet, "res://scenes/characters/ninja_modele.tscn")
	print("ninja articulé -> ", error_string(err), " (", sommets.size(), " sommets)")
	scene.free()
	modele.free()
	quit()


func _poids_sommet(p: Vector3, noms: Array) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(noms.size())
	var dx := p.x - CX
	var gauche := dx > 0.0
	# Jambes, avec le genou en dessous de -0,42
	var jambe := 1.0 - smoothstep(-0.38, -0.31, p.y)
	if jambe > 0.0:
		var genou := 1.0 - smoothstep(-0.45, -0.40, p.y)
		w[noms.find("Genou" + ("G" if gauche else "D"))] = jambe * genou
		w[noms.find("Jambe" + ("G" if gauche else "D"))] = jambe * (1.0 - genou)
	var reste := 1.0 - jambe
	# Tête au-dessus du cou
	var tete := smoothstep(-0.03, 0.05, p.y) * reste
	w[noms.find("Tete")] = tete
	reste -= tete
	# Bras le long du corps
	var seuil := 0.13 if gauche else 0.135
	var bras := smoothstep(seuil, seuil + 0.04, absf(dx)) * (1.0 - smoothstep(-0.07, -0.01, p.y)) * smoothstep(-0.3, -0.26, p.y)
	bras *= reste
	w[noms.find("Bras" + ("G" if gauche else "D"))] = bras
	reste -= bras
	# Le reste suit le tronc (bassin en bas, buste au-dessus)
	var buste := smoothstep(-0.32, -0.2, p.y)
	w[noms.find("Corps")] = reste * buste
	w[noms.find("Bassin")] = reste * (1.0 - buste)
	return w
