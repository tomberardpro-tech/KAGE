class_name Autel
extends Area3D
## Petit autel : en passant devant, il devient le point de reprise.

signal active(autel: Autel)

var deja_active := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_sur_entree)


func _sur_entree(corps: Node3D) -> void:
	if corps is Ninja:
		active.emit(self)
		if not deja_active:
			deja_active = true
			var flamme := get_node_or_null("Flamme") as Node3D
			if flamme:
				flamme.visible = true
