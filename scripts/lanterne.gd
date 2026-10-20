class_name Lanterne
extends Node3D
## Lanterne en pierre. Elle éclaire autour d'elle ; un coup de sabre l'éteint.

signal eteinte(lanterne: Lanterne)

@export var rayon := 4.0
var allumee := true
var _energie := 0.0
var _t := randf() * 10.0

@onready var _lumiere: OmniLight3D = $Lumiere
@onready var _zone: Zone = $Zone
@onready var _flamme: MeshInstance3D = $Flamme


func _ready() -> void:
	add_to_group("lanternes")
	(_zone.get_node("Forme") as CollisionShape3D).shape.radius = rayon
	_lumiere.omni_range = rayon + 1.0
	_energie = _lumiere.light_energy


## La flamme vacille doucement tant qu'elle brûle.
func _process(delta: float) -> void:
	if not allumee:
		return
	_t += delta
	_lumiere.light_energy = _energie * (0.93 + 0.04 * sin(_t * 7.3) + 0.03 * sin(_t * 12.9))


func texte_action() -> String:
	return "TRANCHER LA LANTERNE"


func peut_interagir() -> bool:
	return allumee


func interagir() -> void:
	eteindre()


func eteindre() -> void:
	if not allumee:
		return
	allumee = false
	Sons.jouer("lanterne", -2.0)
	_zone.active = false
	_flamme.visible = false
	var tween := create_tween()
	tween.tween_property(_lumiere, "light_energy", 0.0, 0.25)
	eteinte.emit(self)
