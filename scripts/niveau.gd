class_name Niveau
extends Node3D
## Règles du niveau : point de reprise, parchemin, sortie, mort, victoire et nuages sur la lune.
## Le HUD et les écrans (tutoriel, pause, défaite, victoire) sont des enfants du niveau.

signal parchemin_pris
signal victoire(temps: float)
signal mort

@export var numero := 1
@export var titre := ""  ## ex. « LE CHÂTEAU », affiché au tutoriel
@export var lieu := ""  ## ex. « Le château », pour la phrase de victoire
@export_multiline var objectif := ""  ## dernière ligne du tutoriel
@export var ou_parchemin := ""  ## rappel si on arrive à la sortie sans le parchemin
@export var ou_sortie := ""  ## message quand on prend le parchemin
@export_file("*.tscn") var niveau_suivant := ""  ## vide : dernier niveau, on revient au menu
@export var cycle_nuages := 14.0  ## secondes entre deux passages de nuages
@export var duree_nuages := 5.0

var lune_visible := true
var a_le_parchemin := false
var temps := 0.0
var fois_repere := 0
var gardes_tues := 0
var decouvert := false  ## entre le moment où un garde nous voit et la reprise

var _conseils_donnes: Array[String] = []
var _point_reprise: Vector3
var _fini := false
var _horloge_lune := 0.0

@onready var ninja: Ninja = $Ninja
@onready var _messages: Messages = $Messages
@onready var _ecrans: EcransJeu = $Ecrans
@onready var _lune: DirectionalLight3D = $Lune


func _ready() -> void:
	_point_reprise = ninja.global_position
	for garde in get_tree().get_nodes_in_group("gardes"):
		garde.joueur_repere.connect(_sur_repere)
		garde.chasse_commencee.connect(_sur_chasse)
	for autel in find_children("*", "Autel"):
		autel.active.connect(_sur_autel)
	$Parchemin.touche.connect(_sur_parchemin)
	$Sortie.touche.connect(_sur_sortie)
	Sons.musique("jeu")
	_debut()
	# ambiance : pluie et esprits qui passent autour du ninja
	for script in [preload("res://scripts/pluie.gd"), preload("res://scripts/esprits.gd")]:
		var effet = script.new()
		effet.cible = ninja
		add_child(effet)


func _process(delta: float) -> void:
	if not _fini:
		temps += delta
		Sons.chasse(en_chasse() and not decouvert)
	# Les nuages passent devant la lune de temps en temps.
	_horloge_lune = fmod(_horloge_lune + delta, cycle_nuages)
	var visible := _horloge_lune < cycle_nuages - duree_nuages
	if visible != lune_visible:
		lune_visible = visible
		for zone in find_children("*", "Zone"):
			if zone.type == Zone.Type.LUNE:
				zone.active = visible
				for lumiere in zone.find_children("*", "Light3D"):
					create_tween().tween_property(lumiere, "light_energy", 2.0 if visible else 0.0, 1.5)
		create_tween().tween_property(_lune, "light_energy", 0.9 if visible else 0.25, 1.5)


## Au premier niveau, le maître du clan parle au ninja dans la cabane, puis vient le tutoriel.
func _debut() -> void:
	var maitre := get_node_or_null("Maitre")
	if maitre:
		var anim := maitre.get_node_or_null("Animations") as AnimationPlayer
		if anim:
			anim.play("repos")
		ninja.bloque = true
		var dialogue := Dialogue.new()
		add_child(dialogue)
		await get_tree().create_timer(0.8).timeout
		await dialogue.jouer("MAÎTRE KAGEMARU", [
			"Te voilà enfin, Kage. Approche, et parle bas : les murs ont des oreilles.",
			"Le chef du village cache le plan du château dans sa maison, tout au nord.",
			"Ses gardes portent des lanternes. Reste dans l'ombre, et ils passeront sans te voir.",
			"Si l'un d'eux te barre la route, ton katana fera le reste. Mais prends garde : trois coups, et c'en est fini de toi.",
			"Va. Et que personne ne sache que tu étais là.",
		])
		dialogue.queue_free()
		ninja.bloque = false
	_ecrans.tutoriel()


func peut_mettre_en_pause() -> bool:
	return not _fini and not decouvert


func _sur_autel(autel: Autel) -> void:
	if _point_reprise.distance_to(autel.global_position) > 1.0:
		_point_reprise = autel.global_position + Vector3(0, 0, 1.2)
		if autel.name != "Depart":
			Sons.jouer("autel")
			_messages.afficher("AUTEL", "Tu repartiras d'ici.", 1.6)


func _sur_parchemin() -> void:
	if a_le_parchemin:
		return
	a_le_parchemin = true
	$Parchemin.queue_free()
	parchemin_pris.emit()
	Sons.jouer("parchemin")
	_messages.afficher("PARCHEMIN RÉCUPÉRÉ", ou_sortie, 3.0)


func _sur_sortie() -> void:
	if _fini:
		return
	if not a_le_parchemin:
		_messages.afficher("PAS SANS LE PARCHEMIN", ou_parchemin, 2.0)
		return
	_fini = true
	ninja.bloque = true
	victoire.emit(temps)
	Sons.jingle("victoire")
	if not niveau_suivant.is_empty():
		Sauvegarde.atteindre(niveau_suivant)
	_ecrans.victoire(temps, fois_repere == 0, gardes_tues == 0)


## Un garde nous a vus : il nous prend en chasse. Le bonus Fantôme est perdu.
func _sur_chasse(garde: Garde) -> void:
	var deja := get_tree().get_nodes_in_group("gardes").any(
		func(g: Garde): return g != garde and g.etat == Garde.Etat.CHASSE)
	if not deja:
		_messages.afficher("REPÉRÉ", "Sème-le, cache-toi ou tranche-le.", 1.6)
		Sons.jouer("alerte")
	fois_repere += 1


## Vrai tant qu'au moins un garde nous poursuit.
func en_chasse() -> bool:
	for garde: Garde in get_tree().get_nodes_in_group("gardes"):
		if garde.etat == Garde.Etat.CHASSE:
			return true
	return false


## Bruit à un endroit (plancher qui grince, clochettes) : les gardes à portée viennent voir.
func bruit(point: Vector3, rayon: float, conseil := "") -> void:
	Onde.emettre(self, point, rayon)
	for garde: Garde in get_tree().get_nodes_in_group("gardes"):
		if garde.global_position.distance_to(point) < rayon:
			garde.entendre(point)
	if not conseil.is_empty() and conseil not in _conseils_donnes:
		_conseils_donnes.append(conseil)
		_messages.afficher("CHUT !", conseil, 2.5)


## Le garde nous a rattrapés et frappés.
func _sur_repere(_garde: Garde) -> void:
	if ninja.bloque:
		return
	ninja.bloque = true
	decouvert = true
	Sons.jingle("defaite")
	mort.emit()
	await get_tree().create_timer(0.8).timeout
	_ecrans.defaite()


## Les gardes reprennent leur ronde et le ninja repart du dernier autel.
func recommencer_a_l_autel() -> void:
	get_tree().paused = false
	for garde in get_tree().get_nodes_in_group("gardes"):
		garde.reinitialiser()
	ninja.reapparaitre(_point_reprise)
	ninja.bloque = false
	decouvert = false
	Sons.musique("jeu")


func compter_garde_tue() -> void:
	gardes_tues += 1
