@tool
class_name Zone
extends Area3D
## Zone qui change la visibilité du ninja : ombre, herbes hautes, lumière ou clair de lune.

enum Type { OMBRE, HERBE, LUMIERE, LUNE }

@export var type := Type.OMBRE
@export var active := true:
	set(v):
		active = v
		monitoring = v


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # le ninja
	body_entered.connect(func(b): if b is Ninja: b.entrer_zone(self))
	body_exited.connect(func(b): if b is Ninja: b.sortir_zone(self))
