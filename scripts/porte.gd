class_name Porte
extends Node3D
## Porte animée, construite au chargement :
## - « battants » : la grande porte du château, deux lourds vantaux qui s'ouvrent vers le nord (E).
## - « herse » : la grille du donjon, levée au départ, qui tombe derrière le ninja pour le combat.
## Les vantaux et la grille ont une vraie collision qui suit l'animation.

signal ouverture  ## la grande porte commence à s'ouvrir (le niveau lance sa petite cinématique)

enum Genre { BATTANTS, HERSE }

@export var genre := Genre.BATTANTS
@export var largeur := 4.8  ## m
@export var hauteur := 4.2
@export var epaisseur := 0.3

var ouverte := false
var _pieces: Array[AnimatableBody3D] = []


func _ready() -> void:
	if genre == Genre.BATTANTS:
		_construire_battants()
		add_to_group("interactifs")
	else:
		_construire_herse()
		ouverte = true
		_pieces[0].position.y = hauteur + 0.2
		_pieces[0].visible = false
		_pieces[0].get_child(0).disabled = true


# --- Interaction (grande porte) ------------------------------------------

func texte_action() -> String:
	return "Ouvrir la grande porte"


func peut_interagir() -> bool:
	return genre == Genre.BATTANTS and not ouverte


func interagir() -> void:
	if ouverte:
		return
	ouverte = true
	remove_from_group("interactifs")
	ouverture.emit()
	Sons.jouer("porte")
	for i in _pieces.size():
		var battant := _pieces[i]
		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_interval(0.25)
		t.tween_property(battant, "rotation:y", (1.0 if i == 0 else -1.0) * deg_to_rad(100.0), 2.4)


# --- Herse (donjon) ------------------------------------------------------

func fermer() -> void:
	if not ouverte:
		return
	ouverte = false
	var grille := _pieces[0]
	grille.visible = true
	grille.get_child(0).set_deferred("disabled", false)
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(grille, "position:y", 0.0, 0.35)
	t.tween_callback(func(): Sons.jouer("herse"))


func ouvrir() -> void:
	if ouverte:
		return
	ouverte = true
	var grille := _pieces[0]
	Sons.jouer("herse", -6.0, 0.8)
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(grille, "position:y", hauteur + 0.2, 1.6)
	t.tween_callback(func():
		grille.visible = false
		grille.get_child(0).disabled = true)


## Remise à zéro quand le ninja repart de l'autel (herse levée).
func relever() -> void:
	ouverte = true
	var grille := _pieces[0]
	grille.position.y = hauteur + 0.2
	grille.visible = false
	grille.get_child(0).disabled = true


# --- Construction --------------------------------------------------------

func _corps(taille: Vector3, centre: Vector3) -> AnimatableBody3D:
	var corps := AnimatableBody3D.new()
	corps.collision_layer = 1
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = taille
	forme.shape = boite
	forme.position = centre
	corps.add_child(forme)
	add_child(corps)
	_pieces.append(corps)
	return corps


func _boite(parent: Node3D, taille: Vector3, centre: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.position = centre
	mi.material_override = m
	parent.add_child(mi)


func _matiere(couleur: String, metal := 0.0, rugueux := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(couleur)
	m.metallic = metal
	m.roughness = rugueux
	return m


## Deux vantaux de bois sombre cerclés de fer noir et cloutés d'or ; chacun pivote sur son poteau.
func _construire_battants() -> void:
	var bois := _matiere("#3b261a")
	var bois_clair := _matiere("#4f3424")
	var fer := _matiere("#1a1a1f", 0.6, 0.5)
	var or_ := _matiere("#c9a24a", 0.7, 0.35)
	var demi := largeur / 2.0
	for i in 2:
		var signe := -1.0 if i == 0 else 1.0
		var battant := _corps(Vector3(demi, hauteur, epaisseur), Vector3(-signe * demi / 2.0, hauteur / 2.0, 0))
		battant.position.x = signe * demi  # pivot au poteau
		# planches verticales
		var planches := 5
		for k in planches:
			var w := demi / planches
			var x := -signe * (w * (k + 0.5))
			_boite(battant, Vector3(w - 0.02, hauteur, epaisseur), Vector3(x, hauteur / 2.0, 0), bois if k % 2 == 0 else bois_clair)
		# trois bandes de fer et leurs clous dorés
		for y in [0.5, hauteur * 0.5, hauteur - 0.5]:
			_boite(battant, Vector3(demi, 0.16, epaisseur + 0.04), Vector3(-signe * demi / 2.0, y, 0), fer)
			for k in 6:
				var x := -signe * (demi * (k + 0.5) / 6.0)
				for z in [-1.0, 1.0]:
					_boite(battant, Vector3(0.07, 0.07, 0.05), Vector3(x, y, z * (epaisseur / 2.0 + 0.03)), or_)
		# anneau de bronze pour tirer la porte
		_boite(battant, Vector3(0.12, 0.3, 0.06), Vector3(-signe * (demi - 0.35), hauteur * 0.42, epaisseur / 2.0 + 0.05), or_)


## Grille de barreaux en bois laqué noir, renforcée de traverses de fer.
func _construire_herse() -> void:
	var noir := _matiere("#1c1414", 0.2, 0.5)
	var fer := _matiere("#2a2a30", 0.7, 0.4)
	var grille := _corps(Vector3(largeur, hauteur, 0.2), Vector3(0, hauteur / 2.0, 0))
	var n := int(largeur / 0.32)
	for k in n + 1:
		var x := -largeur / 2.0 + largeur * k / n
		_boite(grille, Vector3(0.1, hauteur, 0.1), Vector3(x, hauteur / 2.0, 0), noir)
	for y in [0.4, hauteur * 0.5, hauteur - 0.3]:
		_boite(grille, Vector3(largeur, 0.12, 0.16), Vector3(0, y, 0), fer)
	# pointes en bas
	for k in n + 1:
		var x := -largeur / 2.0 + largeur * k / n
		_boite(grille, Vector3(0.06, 0.18, 0.06), Vector3(x, -0.05, 0), fer)
