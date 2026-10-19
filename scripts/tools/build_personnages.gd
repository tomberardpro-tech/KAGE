extends SceneTree
## Génère les modèles 3D chibi du ninja et du garde d'après les planches Figma
## (page Personnages). Formes simples et douces, façon Animal Crossing.
## Lancer : godot --headless --script res://scripts/tools/build_personnages.gd

const PEAU := Color("#F1C7A2")
const NOIR := Color("#1B1C22")
const NOIR_TISSU := Color("#24252C")
const GRIS := Color("#5C606B")
const ROUGE := Color("#C23B22")
const OR := Color("#D99A4E")
const BOIS := Color("#5A3A22")
const ACIER := Color("#C9CCD2")
const ROUGE_ONI := Color("#B5281C")
const JAUNE := Color("#FFC531")

var racine: Node3D
var _mats := {}


func _init() -> void:
	_sauver(_ninja(), "res://scenes/characters/ninja_modele.tscn")
	_sauver(_garde(), "res://scenes/characters/garde_modele.tscn")
	quit()


func _sauver(modele: Node3D, chemin: String) -> void:
	var scene := PackedScene.new()
	var err := scene.pack(modele)
	if err == OK:
		err = ResourceSaver.save(scene, chemin)
	print(chemin, " -> ", error_string(err))
	modele.free()


# --- Ninja ------------------------------------------------------------------

func _ninja() -> Node3D:
	racine = Node3D.new()
	racine.name = "Modele"
	racine.set_script(load("res://scripts/anim_chibi.gd"))

	var corps := _pivot(racine, "Corps", Vector3(0, 0.30, 0))
	# Tronc : petite veste noire, ceinture grise nouée devant
	_boule(corps, "Tronc", Vector3(0, 0.14, 0), Vector3(0.50, 0.46, 0.40), "tissu")
	_boule(corps, "Col", Vector3(0, 0.30, 0.0), Vector3(0.36, 0.14, 0.30), "tissu")
	_anneau(corps, "Ceinture", Vector3(0, 0.03, 0), 0.215, 0.255, 0.07, "gris")
	_boule(corps, "Noeud", Vector3(0, 0.03, 0.24), Vector3(0.09, 0.07, 0.05), "gris")
	_boite(corps, "PanG", Vector3(-0.035, -0.04, 0.245), Vector3(0.04, 0.10, 0.02), "gris", Vector3(0, 0, 12))
	_boite(corps, "PanD", Vector3(0.035, -0.04, 0.245), Vector3(0.04, 0.10, 0.02), "gris", Vector3(0, 0, -12))

	# Sabre dans le dos, en diagonale
	var sabre := _pivot(corps, "Sabre", Vector3(0, 0.18, -0.21))
	sabre.rotation_degrees = Vector3(0, 0, -38)
	_tube(sabre, "Fourreau", Vector3(0, -0.02, 0), 0.025, 0.62, "noir")
	_tube(sabre, "Tsuba", Vector3(0, 0.30, 0), 0.05, 0.015, "or")
	_tube(sabre, "Poignee", Vector3(0, 0.39, 0), 0.022, 0.17, "rouge")
	_tube(sabre, "Kashira", Vector3(0, 0.48, 0), 0.026, 0.02, "or")

	# Tête : grosse capuche ronde, ouverture du visage, bandeau gris, masque noir
	var tete := _pivot(racine, "Tete", Vector3(0, 0.88, 0))
	_boule(tete, "Capuche", Vector3(0, 0.02, 0), Vector3(0.80, 0.76, 0.76), "tissu")
	_boule(tete, "Pointe", Vector3(0, 0.22, -0.30), Vector3(0.20, 0.22, 0.24), "tissu", Vector3(-35, 0, 0))
	_boule(tete, "Visage", Vector3(0, 0.02, 0.19), Vector3(0.60, 0.27, 0.43), "peau")
	_boule(tete, "Bandeau", Vector3(0, 0.155, 0.18), Vector3(0.62, 0.09, 0.44), "gris")
	_boule(tete, "Masque", Vector3(0, -0.135, 0.20), Vector3(0.64, 0.17, 0.43), "tissu")
	for cote in [-1.0, 1.0]:
		var oeil := _boule(tete, "Oeil" + ("G" if cote < 0 else "D"), Vector3(cote * 0.11, 0.025, 0.395), Vector3(0.09, 0.115, 0.04), "noir")
		_boule(oeil, "Reflet", Vector3(-0.15, 0.22, 0.45), Vector3(0.32, 0.30, 0.3), "blanc")

	# Foulard rouge autour du cou, deux pans qui flottent derrière
	var foulard := _pivot(racine, "Foulard", Vector3(0, 0.62, 0))
	_anneau(foulard, "Tour", Vector3.ZERO, 0.16, 0.27, 0.11, "rouge")
	var pans := _pivot(foulard, "Pans", Vector3(0.12, 0.0, -0.22))
	_boite(pans, "Pan1", Vector3(0.04, -0.02, -0.17), Vector3(0.11, 0.035, 0.34), "rouge", Vector3(-10, 25, 0))
	_boite(pans, "Pan2", Vector3(0.12, -0.08, -0.12), Vector3(0.09, 0.03, 0.26), "rouge", Vector3(-22, 50, 0))

	# Bras : manche noire, protège-bras gris, main
	for cote in [-1.0, 1.0]:
		var bras := _pivot(racine, "Bras" + ("G" if cote < 0 else "D"), Vector3(cote * 0.25, 0.55, 0))
		bras.rotation_degrees.z = cote * 18.0
		_boule(bras, "Manche", Vector3(0, -0.08, 0), Vector3(0.15, 0.22, 0.15), "tissu")
		_tube(bras, "Protege", Vector3(0, -0.19, 0), 0.068, 0.09, "gris")
		_boule(bras, "Main", Vector3(0, -0.27, 0), Vector3(0.12, 0.12, 0.12), "peau")

	# Jambes : pantalon bouffant, bandes grises, chaussons noirs
	for cote in [-1.0, 1.0]:
		var jambe := _pivot(racine, "Jambe" + ("G" if cote < 0 else "D"), Vector3(cote * 0.11, 0.24, 0))
		_boule(jambe, "Cuisse", Vector3(0, -0.06, 0), Vector3(0.18, 0.18, 0.18), "tissu")
		_tube(jambe, "Bande", Vector3(0, -0.15, 0), 0.07, 0.08, "gris")
		_boule(jambe, "Pied", Vector3(0, -0.215, 0.03), Vector3(0.15, 0.09, 0.21), "noir")
	return racine


# --- Garde ------------------------------------------------------------------

func _garde() -> Node3D:
	racine = Node3D.new()
	racine.name = "Modele"
	racine.set_script(load("res://scripts/anim_chibi.gd"))

	var corps := _pivot(racine, "Corps", Vector3(0, 0.34, 0))
	# Armure noire à lacets rouges, cordon rouge à la taille
	_boule(corps, "Tronc", Vector3(0, 0.14, 0), Vector3(0.60, 0.52, 0.46), "noir")
	for i in 3:
		_boite(corps, "Lacet%d" % i, Vector3(0, 0.25 - i * 0.09, 0.225), Vector3(0.30, 0.018, 0.02), "rouge")
	_anneau(corps, "Cordon", Vector3(0, 0.0, 0), 0.25, 0.29, 0.05, "rouge")
	_boule(corps, "Noeud", Vector3(0, -0.01, 0.28), Vector3(0.10, 0.06, 0.05), "rouge")
	# Jupe d'armure (kusazuri)
	_tube(corps, "Jupe", Vector3(0, -0.10, 0), 0.30, 0.16, "noir", 0.24)
	for i in 2:
		_anneau(corps, "LigneJupe%d" % i, Vector3(0, -0.07 - i * 0.07, 0), 0.265 + i * 0.02, 0.285 + i * 0.02, 0.012, "rouge")
	# Épaulières (sode)
	for cote in [-1.0, 1.0]:
		var sode := _boite(corps, "Sode" + ("G" if cote < 0 else "D"), Vector3(cote * 0.33, 0.26, 0), Vector3(0.12, 0.20, 0.30), "noir", Vector3(0, 0, cote * 20))
		_boite(sode, "Lacet", Vector3(0.0, -0.03, 0), Vector3(0.126, 0.015, 0.31), "rouge")

	# Tête : masque oni rouge, yeux jaunes, crocs, casque noir à cimier doré
	var tete := _pivot(racine, "Tete", Vector3(0, 0.98, 0))
	_boule(tete, "Visage", Vector3(0, -0.04, 0.06), Vector3(0.62, 0.56, 0.52), "oni")
	_boule(tete, "Nuque", Vector3(0, -0.02, -0.06), Vector3(0.60, 0.56, 0.50), "noir")
	for cote in [-1.0, 1.0]:
		var s := "G" if cote < 0 else "D"
		_boule(tete, "Oeil" + s, Vector3(cote * 0.12, 0.0, 0.29), Vector3(0.14, 0.085, 0.04), "jaune", Vector3(0, 0, cote * 15))
		_boite(tete, "Sourcil" + s, Vector3(cote * 0.12, 0.07, 0.30), Vector3(0.15, 0.035, 0.03), "noir", Vector3(0, 0, -cote * 22))
		_cone(tete, "Croc" + s, Vector3(cote * 0.09, -0.17, 0.29), 0.022, 0.05, "blanc")
	_boite(tete, "Bouche", Vector3(0, -0.14, 0.305), Vector3(0.20, 0.02, 0.02), "noir")
	var casque := _pivot(tete, "Casque", Vector3(0, 0.20, -0.02))
	_boule(casque, "Bol", Vector3(0, 0.08, 0), Vector3(0.72, 0.44, 0.70), "noir")
	_tube(casque, "Couvre-nuque", Vector3(0, -0.10, -0.13), 0.40, 0.24, "noir", 0.32)
	for i in 3:
		_anneau(casque, "Ligne%d" % i, Vector3(0, -0.03 - i * 0.065, -0.13), 0.33 + i * 0.02, 0.345 + i * 0.02, 0.012, "rouge")
	_boule(casque, "Visiere", Vector3(0, -0.10, 0.22), Vector3(0.66, 0.08, 0.30), "noir")
	# Cimier en U doré (kuwagata) et rosace
	var cimier := _pivot(casque, "Cimier", Vector3(0, 0.06, 0.34))
	_tube(cimier, "Rosace", Vector3(0, 0, 0), 0.055, 0.03, "or", -1.0, Vector3(90, 0, 0))
	for cote in [-1.0, 1.0]:
		_boite(cimier, "Corne" + ("G" if cote < 0 else "D"), Vector3(cote * 0.09, 0.10, 0.0), Vector3(0.05, 0.24, 0.035), "or", Vector3(0, 0, -cote * 20))
	_boite(cimier, "Base", Vector3(0, 0.0, 0.0), Vector3(0.16, 0.05, 0.035), "or")

	# Bras : le droit tient la lance
	for cote in [-1.0, 1.0]:
		var bras := _pivot(racine, "Bras" + ("G" if cote < 0 else "D"), Vector3(cote * 0.30, 0.60, 0))
		bras.rotation_degrees.z = cote * 14.0
		_boule(bras, "Manche", Vector3(0, -0.09, 0), Vector3(0.17, 0.24, 0.17), "noir")
		_boule(bras, "Gant", Vector3(0, -0.24, 0), Vector3(0.13, 0.12, 0.13), "noir")
		if cote > 0:
			var lance := _pivot(bras, "Lance", Vector3(0, -0.24, 0.02))
			lance.rotation_degrees.z = -14.0
			_tube(lance, "Hampe", Vector3(0, 0.30, 0), 0.022, 1.6, "bois")
			_tube(lance, "Bague", Vector3(0, 1.08, 0), 0.03, 0.04, "or")
			_tube(lance, "Pompon", Vector3(0, 1.03, 0), 0.04, 0.06, "rouge")
			_boule(lance, "Lame", Vector3(0, 1.24, 0), Vector3(0.07, 0.30, 0.025), "acier")

	for cote in [-1.0, 1.0]:
		var jambe := _pivot(racine, "Jambe" + ("G" if cote < 0 else "D"), Vector3(cote * 0.12, 0.22, 0))
		_boule(jambe, "Cuisse", Vector3(0, -0.06, 0), Vector3(0.19, 0.18, 0.19), "noir")
		_anneau(jambe, "Lien", Vector3(0, -0.12, 0), 0.07, 0.09, 0.025, "rouge")
		_boule(jambe, "Pied", Vector3(0, -0.195, 0.03), Vector3(0.16, 0.09, 0.22), "noir")
	return racine


# --- Outils -----------------------------------------------------------------

func _mat(nom: String) -> StandardMaterial3D:
	if _mats.has(nom):
		return _mats[nom]
	var m := StandardMaterial3D.new()
	m.roughness = 0.75
	match nom:
		"peau": m.albedo_color = PEAU
		"tissu": m.albedo_color = NOIR_TISSU; m.roughness = 0.95
		"noir": m.albedo_color = NOIR
		"gris": m.albedo_color = GRIS
		"rouge": m.albedo_color = ROUGE
		"or": m.albedo_color = OR; m.metallic = 0.5; m.roughness = 0.4
		"bois": m.albedo_color = BOIS
		"acier": m.albedo_color = ACIER; m.metallic = 0.7; m.roughness = 0.3
		"oni": m.albedo_color = ROUGE_ONI
		"blanc": m.albedo_color = Color.WHITE
		"jaune":
			m.albedo_color = JAUNE
			m.emission_enabled = true
			m.emission = JAUNE
			m.emission_energy_multiplier = 1.5
	_mats[nom] = m
	return m


func _pivot(parent: Node, nom: String, position: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nom
	n.position = position
	_ajouter(parent, n)
	return n


func _piece(parent: Node, nom: String, mesh: Mesh, mat: String, position: Vector3, rotation := Vector3.ZERO, echelle := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = nom
	mesh.material = _mat(mat)
	m.mesh = mesh
	m.position = position
	m.rotation_degrees = rotation
	m.scale = echelle
	_ajouter(parent, m)
	return m


## Ellipsoïde de dimensions `taille` (diamètres).
func _boule(parent: Node, nom: String, position: Vector3, taille: Vector3, mat: String, rotation := Vector3.ZERO) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 24
	s.rings = 12
	return _piece(parent, nom, s, mat, position, rotation, taille)


func _boite(parent: Node, nom: String, position: Vector3, taille: Vector3, mat: String, rotation := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = taille
	return _piece(parent, nom, b, mat, position, rotation)


func _tube(parent: Node, nom: String, position: Vector3, rayon: float, hauteur: float, mat: String, rayon_haut := -1.0, rotation := Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = rayon
	c.top_radius = rayon if rayon_haut < 0.0 else rayon_haut
	c.height = hauteur
	c.radial_segments = 20
	return _piece(parent, nom, c, mat, position, rotation)


func _cone(parent: Node, nom: String, position: Vector3, rayon: float, hauteur: float, mat: String) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = 0.0
	c.top_radius = rayon
	c.height = hauteur
	c.radial_segments = 8
	return _piece(parent, nom, c, mat, position)


func _anneau(parent: Node, nom: String, position: Vector3, interieur: float, exterieur: float, epaisseur: float, mat: String) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = interieur
	t.outer_radius = exterieur
	t.rings = 24
	var e := epaisseur / (exterieur - interieur)
	return _piece(parent, nom, t, mat, position, Vector3.ZERO, Vector3(1, e, 1))


func _ajouter(parent: Node, enfant: Node) -> void:
	parent.add_child(enfant)
	enfant.owner = racine
