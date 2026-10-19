extends Area3D
## Objet déclenché quand le ninja le touche (parchemin, sortie).

signal touche

@export var tourne := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b): if b is Ninja: touche.emit())


func _process(delta: float) -> void:
	if tourne:
		rotation.y += delta * 1.5
