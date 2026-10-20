extends Area3D
## Zone invisible qui prévient le niveau quand le ninja y entre (une seule fois, jusqu'à réarmer()).

signal entre

var _arme := true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # le ninja
	body_entered.connect(func(corps: Node3D):
		if _arme and corps is Ninja:
			_arme = false
			entre.emit())


func rearmer() -> void:
	_arme = true
