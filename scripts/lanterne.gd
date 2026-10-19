class_name Lanterne
extends Node3D
## Lanterne en pierre. Elle éclaire autour d'elle ; un coup de sabre l'éteint.

signal eteinte(lanterne: Lanterne)

@export var rayon := 4.0
var allumee := true

@onready var _lumiere: OmniLight3D = $Lumiere
@onready var _zone: Zone = $Zone
@onready var _flamme: MeshInstance3D = $Flamme


func _ready() -> void:
	add_to_group("lanternes")
	(_zone.get_node("Forme") as CollisionShape3D).shape.radius = rayon
	_lumiere.omni_range = rayon + 1.0


func eteindre() -> void:
	if not allumee:
		return
	allumee = false
	_zone.active = false
	_flamme.visible = false
	var tween := create_tween()
	tween.tween_property(_lumiere, "light_energy", 0.0, 0.25)
	eteinte.emit(self)
