class_name Habitant
extends Node3D
## Habitant du village, fait de formes simples au style chibi du ninja (grosse tête, petit corps).
## Il suit sa journée : une liste d'étapes [endroit, activité, durée] qu'il enchaîne en boucle
## (marcher, balayer, porter du bois, pêcher, discuter, se reposer...). Quand le ninja s'approche,
## il s'arrête, se tourne vers lui et le salue ; son nom apparaît au-dessus de sa tête.

enum Allure { ADULTE, VIEUX, ENFANT }
enum Activite { REPOS, BALAYER, PORTER, PECHER, DISCUTER, ASSIS, JOUER }

@export var nom_affiche := ""
@export var allure := Allure.ADULTE
@export var kimono := Color("#3d5a80")
@export var obi := Color("#c9a24a")
@export var cheveux := Color("#1b1a1f")
@export var chapeau := false  ## chapeau de paille conique
@export var chignon := false
@export var barbe := false
@export var baton := false
## Étapes de sa journée : [Vector3 endroit, Activite, durée en s]. Vide : il reste là, au repos.
@export var journee: Array = []
@export var vitesse := 1.0

const PEAU := Color("#f0c9a4")
const DISTANCE_SALUT := 2.6

var _etape := 0
var _attente := 0.0
var _t := randf() * 10.0
var _salut := 0.0  ## > 0 : il salue (révérence)
var _a_salue := 0.0
var _corps: Node3D
var _buste: Node3D
var _tete: Node3D
var _bras: Array[Node3D] = []
var _jambes: Array[Node3D] = []
var _objet: Node3D  ## balai, fagot ou canne à pêche, selon l'activité
var _nom: Label3D
var _taille := 1.0

static var _materiaux := {}


static func _mat(couleur: Color, rugosite := 0.85) -> StandardMaterial3D:
	var cle := couleur.to_html() + str(rugosite)
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = couleur
		m.roughness = rugosite
		_materiaux[cle] = m
	return _materiaux[cle]


func _ready() -> void:
	add_to_group("habitants")
	_taille = {Allure.ADULTE: 1.0, Allure.VIEUX: 0.92, Allure.ENFANT: 0.72}[allure]
	_construire()
	_nom = Label3D.new()
	_nom.text = nom_affiche
	_nom.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nom.no_depth_test = true
	_nom.font_size = 30
	_nom.outline_size = 10
	_nom.fixed_size = true  # même taille à l'écran, de près comme de loin
	_nom.pixel_size = 0.0011
	_nom.font = load("res://assets/fonts/IBMPlexSansJP-SemiBold.ttf")
	_nom.modulate = Color(Palette.WASHI, 0.0)
	_nom.outline_modulate = Color(Palette.NOIR, 0.0)
	_nom.position.y = 1.75 * _taille
	add_child(_nom)
	if not journee.is_empty():
		_attente = randf_range(0.0, 2.0)


# --- Le personnage -----------------------------------------------------------

func _construire() -> void:
	_corps = Node3D.new()
	_corps.scale = Vector3.ONE * _taille
	add_child(_corps)
	var tissu := _mat(kimono)
	var fonce := _mat(kimono.darkened(0.35))
	var peau := _mat(PEAU, 0.7)
	# jambes (le pied sous le kimono)
	for s in [-1.0, 1.0]:
		var hanche := Node3D.new()
		hanche.position = Vector3(s * 0.09, 0.32, 0)
		_corps.add_child(hanche)
		_piece(hanche, _cylindre(0.055, 0.05, 0.3), Vector3(0, -0.15, 0), fonce)
		_piece(hanche, _boite(Vector3(0.09, 0.05, 0.15)), Vector3(0, -0.3, 0.03), _mat(Color("#2a2420")))
		_jambes.append(hanche)
	_buste = Node3D.new()
	_buste.position.y = 0.3
	_corps.add_child(_buste)
	# kimono évasé, ceinture obi et col croisé
	_piece(_buste, _cylindre(0.16, 0.25, 0.48), Vector3(0, 0.22, 0), tissu)
	_piece(_buste, _cylindre(0.175, 0.19, 0.09), Vector3(0, 0.27, 0), _mat(obi))
	var col := _piece(_buste, _boite(Vector3(0.05, 0.2, 0.02)), Vector3(0, 0.4, 0.165), _mat(Color("#efe6d2")))
	col.rotation.z = 0.5
	# bras : larges manches et petites mains
	for s in [-1.0, 1.0]:
		var epaule := Node3D.new()
		epaule.position = Vector3(s * 0.2, 0.42, 0)
		_buste.add_child(epaule)
		var manche := _piece(epaule, _cylindre(0.065, 0.09, 0.3), Vector3(s * 0.02, -0.14, 0), tissu)
		manche.rotation.z = s * 0.15
		_piece(epaule, _sphere(0.055), Vector3(s * 0.04, -0.3, 0), peau)
		_bras.append(epaule)
	# grosse tête
	_tete = Node3D.new()
	_tete.position.y = 0.62
	_buste.add_child(_tete)
	_piece(_tete, _sphere(0.25), Vector3(0, 0.2, 0), peau)
	var noir := _mat(Color("#1a1416"), 0.4)
	for s in [-1.0, 1.0]:
		_piece(_tete, _sphere(0.035, Vector3(1, 1.3, 0.5)), Vector3(s * 0.085, 0.2, 0.225), noir)
		_piece(_tete, _sphere(0.04, Vector3(1.2, 0.6, 0.4)), Vector3(s * 0.13, 0.13, 0.2), _mat(Color("#f2a3a0"), 0.9))
		var sourcil := _piece(_tete, _boite(Vector3(0.07, 0.016, 0.02)),
			Vector3(s * 0.085, 0.27, 0.225), _mat(Color("#eeeeee") if allure == Allure.VIEUX else cheveux))
		sourcil.rotation.z = -s * 0.15
	# cheveux : calotte, ou couronne blanche pour le vieux maître
	var mat_cheveux := _mat(cheveux, 0.6)
	if allure == Allure.VIEUX:
		for s in [-1.0, 1.0]:
			_piece(_tete, _sphere(0.11, Vector3(0.7, 1.0, 1.2)), Vector3(s * 0.2, 0.18, -0.04), mat_cheveux)
	else:
		_piece(_tete, _sphere(0.262, Vector3(1, 0.8, 1)), Vector3(0, 0.27, -0.035), mat_cheveux)
	if chignon:
		_piece(_tete, _sphere(0.1), Vector3(0, 0.47, -0.08), mat_cheveux)
		_piece(_tete, _sphere(0.045), Vector3(0.09, 0.44, -0.02), _mat(Color("#e04a5a")))
	if barbe:
		var b := _piece(_tete, _cylindre(0.12, 0.015, 0.32), Vector3(0, 0.0, 0.17), _mat(Color("#f2efe8"), 0.95))
		b.rotation.x = 0.35
	if chapeau:
		_piece(_tete, _cylindre(0.02, 0.4, 0.17, 16), Vector3(0, 0.46, 0), _mat(Color("#c9a35a"), 0.9))
	if baton:
		var b := _piece(_bras[0], _cylindre(0.022, 0.028, 1.2), Vector3(-0.06, -0.15, 0.06), _mat(Color("#6b4a2c")))
		b.rotation.x = 0.08
	for mi in _corps.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _piece(parent: Node3D, mesh: Mesh, position_: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = position_
	mi.material_override = m
	parent.add_child(mi)
	return mi


static var _formes := {}


func _cylindre(haut: float, bas: float, hauteur: float, cotes := 10) -> CylinderMesh:
	var cle := "c%s_%s_%s_%d" % [haut, bas, hauteur, cotes]
	if not _formes.has(cle):
		var c := CylinderMesh.new()
		c.top_radius = haut
		c.bottom_radius = bas
		c.height = hauteur
		c.radial_segments = cotes
		c.rings = 1
		_formes[cle] = c
	return _formes[cle]


func _sphere(rayon: float, etire := Vector3.ONE) -> Mesh:
	var cle := "s%s_%s" % [rayon, etire]
	if not _formes.has(cle):
		var s := SphereMesh.new()
		s.radius = rayon
		s.height = rayon * 2.0
		s.radial_segments = 14
		s.rings = 8
		# l'étirement est porté par le maillage : une seule forme par réglage
		var arrays := s.get_mesh_arrays()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for k in v.size():
			v[k] *= etire
		arrays[Mesh.ARRAY_VERTEX] = v
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_formes[cle] = am
	return _formes[cle]


func _boite(taille: Vector3) -> BoxMesh:
	var cle := "b%s" % taille
	if not _formes.has(cle):
		var b := BoxMesh.new()
		b.size = taille
		_formes[cle] = b
	return _formes[cle]


## Objet tenu pendant une activité : balai, fagot de bois sur le dos, canne à pêche.
func _tenir(activite: int) -> void:
	if _objet:
		_objet.queue_free()
		_objet = null
	var bois := _mat(Color("#7a5530"))
	match activite:
		Activite.BALAYER:
			_objet = Node3D.new()
			_bras[1].add_child(_objet)
			_objet.position = Vector3(0.05, -0.3, 0.1)
			_objet.rotation.x = 0.5
			_piece(_objet, _cylindre(0.015, 0.015, 0.9), Vector3(0, -0.1, 0), bois)
			_piece(_objet, _cylindre(0.03, 0.09, 0.22), Vector3(0, -0.6, 0), _mat(Color("#b89a5a"), 0.95))
		Activite.PORTER:
			_objet = Node3D.new()
			_buste.add_child(_objet)
			_objet.position = Vector3(0, 0.45, -0.24)
			for k in 3:
				var buche := _piece(_objet, _cylindre(0.05, 0.05, 0.5), Vector3((k - 1) * 0.09, 0.05 * (k % 2), 0), bois)
				buche.rotation.z = PI / 2.0 + (k - 1) * 0.1
		Activite.PECHER:
			_objet = Node3D.new()
			_bras[1].add_child(_objet)
			_objet.position = Vector3(0.04, -0.3, 0.05)
			var canne := _piece(_objet, _cylindre(0.008, 0.016, 1.8), Vector3(0, 0.3, 0.75), _mat(Color("#8a6a3a")))
			canne.rotation.x = 1.1


# --- Sa journée ----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_a_salue -= delta
	var ninja: Node3D = get_tree().get_first_node_in_group("ninja")
	var distance := ninja.global_position.distance_to(global_position) if ninja else 99.0
	# le nom apparaît quand on s'approche
	var a := clampf((7.0 - distance) / 2.0, 0.0, 1.0)
	var niveau := get_tree().current_scene
	if niveau and niveau.get("en_cinematique") == true:
		a = 0.0
	_nom.modulate.a = lerpf(_nom.modulate.a, a, 1.0 - exp(-6.0 * delta))
	_nom.outline_modulate.a = _nom.modulate.a * 0.85
	_nom.visible = _nom.modulate.a > 0.01
	if _salut > 0.0:
		_salut -= delta
		_poser_salut(delta)
		return
	if distance < DISTANCE_SALUT:
		var vers := ninja.global_position - global_position
		_tourner(atan2(vers.x, vers.z), delta * 5.0)
		if _a_salue <= 0.0:
			saluer()
		else:
			_poser_repos(delta)
		return
	if journee.is_empty():
		_poser_repos(delta)
		return
	var etape: Array = journee[_etape]
	var but: Vector3 = etape[0]
	var ecart := but - position
	ecart.y = 0.0
	if ecart.length() > 0.15:
		# il marche jusqu'à l'endroit de l'étape (en portant son fagot s'il le faut)
		var pas := (1.7 if allure == Allure.ENFANT else 1.0) * vitesse
		position += ecart.normalized() * minf(pas * delta, ecart.length())
		_tourner(atan2(ecart.x, ecart.z), delta * 6.0)
		_poser_marche(delta, pas)
		_attente = etape[2]
		if _objet == null and etape[1] == Activite.PORTER:
			_tenir(Activite.PORTER)
		return
	if _objet == null and etape[1] in [Activite.BALAYER, Activite.PECHER, Activite.PORTER]:
		_tenir(etape[1])
	if etape.size() > 3:
		_tourner(deg_to_rad(etape[3]), delta * 3.0)
	_poser_activite(etape[1], delta)
	_attente -= delta
	if _attente <= 0.0:
		_etape = (_etape + 1) % journee.size()
		var suivante: Array = journee[_etape]
		if suivante[1] != etape[1] and _objet:
			_tenir(-1)


func _tourner(angle: float, vitesse_rot: float) -> void:
	rotation.y = lerp_angle(rotation.y, angle, clampf(vitesse_rot, 0.0, 1.0))


## Révérence (au ninja qui passe, ou au début du jeu pour le maître).
func saluer() -> void:
	_salut = 1.4
	_a_salue = 12.0


# --- Les poses, calculées à chaque image ------------------------------------------

func _vers(n: Node3D, rx: float, rz: float, l: float) -> void:
	n.rotation.x = lerpf(n.rotation.x, rx, l)
	n.rotation.z = lerpf(n.rotation.z, rz, l)


func _poser_repos(delta: float) -> void:
	var l := 1.0 - exp(-8.0 * delta)
	var souffle := sin(_t * 2.0)
	_corps.position.y = lerpf(_corps.position.y, 0.0, l)
	_vers(_buste, 0.03 + souffle * 0.015 + (0.12 if allure == Allure.VIEUX else 0.0), 0.0, l)
	_vers(_tete, -0.05 + sin(_t * 0.7) * 0.05, sin(_t * 0.5) * 0.06, l)
	for k in 2:
		_vers(_bras[k], 0.05 + souffle * 0.03, (k * 2 - 1) * 0.08, l)
		_vers(_jambes[k], 0.0, 0.0, l)


func _poser_marche(delta: float, pas: float) -> void:
	var l := 1.0 - exp(-12.0 * delta)
	var phase := _t * 7.0 * pas
	var balance := sin(phase)
	_corps.position.y = absf(cos(phase)) * 0.035
	_vers(_buste, 0.08 + (0.1 if allure == Allure.VIEUX else 0.0), balance * 0.04, l)
	_vers(_tete, -0.04, 0.0, l)
	for k in 2:
		var s := 1.0 if k == 0 else -1.0
		_vers(_jambes[k], balance * 0.55 * s, 0.0, l)
		var porte := _objet != null and _objet.get_parent() == _buste
		_vers(_bras[k], -0.35 if porte else -balance * 0.5 * s, (k * 2 - 1) * 0.1, l)


func _poser_activite(activite: int, delta: float) -> void:
	var l := 1.0 - exp(-8.0 * delta)
	match activite:
		Activite.BALAYER:
			var v := sin(_t * 3.2)
			_poser_repos(delta)
			_vers(_buste, 0.25, v * 0.08, l)
			_vers(_bras[1], -0.6 + v * 0.1, 0.3 + v * 0.35, l)
			_vers(_bras[0], -0.7 + v * 0.1, -0.1 + v * 0.3, l)
		Activite.PECHER, Activite.ASSIS:
			# assis en tailleur
			_corps.position.y = lerpf(_corps.position.y, -0.24, l)
			for k in 2:
				_vers(_jambes[k], -1.4, (k * 2 - 1) * 0.5, l)
			_vers(_buste, 0.05 + sin(_t * 2.0) * 0.01, 0.0, l)
			_vers(_tete, 0.1 if activite == Activite.PECHER else -0.05, sin(_t * 0.4) * 0.1, l)
			_vers(_bras[1], -0.8 if activite == Activite.PECHER else 0.3, 0.1, l)
			_vers(_bras[0], -0.5 if activite == Activite.PECHER else 0.3, -0.1, l)
		Activite.DISCUTER:
			# il parle avec les mains et hoche la tête
			_poser_repos(delta)
			var v := sin(_t * 2.6)
			_vers(_bras[1], -0.7 + v * 0.35, 0.25, l)
			_vers(_tete, -0.05 + maxf(0.0, sin(_t * 4.0)) * 0.12, 0.0, l)
		Activite.JOUER:
			# l'enfant sautille sur place
			_poser_repos(delta)
			_corps.position.y = absf(sin(_t * 6.0)) * 0.12
			_vers(_bras[0], -2.6, -0.3, l)
			_vers(_bras[1], -2.6, 0.3, l)
		_:
			_poser_repos(delta)


func _poser_salut(delta: float) -> void:
	var l := 1.0 - exp(-8.0 * delta)
	var incline := sin(clampf(1.0 - _salut / 1.4, 0.0, 1.0) * PI)
	_corps.position.y = lerpf(_corps.position.y, 0.0, l)
	_vers(_buste, 0.05 + incline * 0.55, 0.0, l)
	_vers(_tete, incline * 0.2, 0.0, l)
	for k in 2:
		_vers(_bras[k], 0.15, (k * 2 - 1) * 0.05, l)
		_vers(_jambes[k], 0.0, 0.0, l)
