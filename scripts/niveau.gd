class_name Niveau
extends Node3D
## Règles du niveau : point de reprise, parchemin, sortie, mort, victoire et nuages sur la lune.

signal parchemin_pris
signal victoire(temps: float)
signal mort

const SCENE_MENU := "res://scenes/ui/menu.tscn"

@export var cycle_nuages := 14.0  ## secondes entre deux passages de nuages
@export var duree_nuages := 5.0

var lune_visible := true
var a_le_parchemin := false
var temps := 0.0
var fois_repere := 0
var gardes_tues := 0

var _point_reprise: Vector3
var _fini := false
var _horloge_lune := 0.0

@onready var ninja: Ninja = $Ninja
@onready var _messages: Messages = $Messages
@onready var _lune: DirectionalLight3D = $Lune


func _ready() -> void:
	_point_reprise = ninja.global_position
	for garde in get_tree().get_nodes_in_group("gardes"):
		garde.joueur_repere.connect(_sur_repere)
	for autel in find_children("*", "Autel"):
		autel.active.connect(_sur_autel)
	$Parchemin.touche.connect(_sur_parchemin)
	$Sortie.touche.connect(_sur_sortie)
	_messages.afficher("NIVEAU 1 · LE CHÂTEAU", "Prends le parchemin du donjon, puis sors par le rempart est.", 4.0)


func _process(delta: float) -> void:
	if not _fini:
		temps += delta
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _fini:
		Transition.vers(SCENE_MENU)


func _sur_autel(autel: Autel) -> void:
	if _point_reprise.distance_to(autel.global_position) > 1.0:
		_point_reprise = autel.global_position + Vector3(0, 0, 1.2)
		if autel.name != "Depart":
			_messages.afficher("AUTEL", "Tu repartiras d'ici.", 1.6)


func _sur_parchemin() -> void:
	if a_le_parchemin:
		return
	a_le_parchemin = true
	$Parchemin.queue_free()
	parchemin_pris.emit()
	_messages.afficher("PARCHEMIN RÉCUPÉRÉ", "Maintenant, file par la sortie du rempart est.", 3.0)


func _sur_sortie() -> void:
	if _fini:
		return
	if not a_le_parchemin:
		_messages.afficher("PAS SANS LE PARCHEMIN", "Il est dans le donjon.", 2.0)
		return
	_fini = true
	ninja.bloque = true
	victoire.emit(temps)
	var sous_titre := "Temps : %d:%02d" % [int(temps) / 60, int(temps) % 60]
	if fois_repere == 0:
		sous_titre += " · Fantôme"
	if gardes_tues == 0:
		sous_titre += " · Pacifiste"
	_messages.afficher("VICTOIRE", sous_titre, 4.0)
	await get_tree().create_timer(4.0).timeout
	Transition.vers(SCENE_MENU)


func _sur_repere(_garde: Garde) -> void:
	if ninja.bloque:
		return
	fois_repere += 1
	ninja.bloque = true
	mort.emit()
	_messages.afficher("DÉCOUVERT", "Tu repars du dernier autel.", 1.6)
	await get_tree().create_timer(1.6).timeout
	for garde in get_tree().get_nodes_in_group("gardes"):
		garde.reinitialiser()
	ninja.reapparaitre(_point_reprise)
	ninja.bloque = false


func compter_garde_tue() -> void:
	gardes_tues += 1
