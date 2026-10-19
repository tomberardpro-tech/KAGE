extends Camera3D
## Caméra haute et dézoomée, orientée plein nord, qui suit le ninja en douceur.

@export var target: Node3D
@export var offset := Vector3(0.0, 15.0, 13.0)
@export var smoothing := 6.0


func _ready() -> void:
	if target:
		global_position = target.global_position + offset
	look_at(global_position - offset, Vector3.UP)


func _physics_process(delta: float) -> void:
	if not target:
		return
	var goal := target.global_position + offset
	global_position = global_position.lerp(goal, 1.0 - exp(-smoothing * delta))
