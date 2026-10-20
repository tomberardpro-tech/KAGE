extends Camera3D
## Caméra haute et dézoomée, orientée plein nord, qui suit le ninja en douceur.
## secouer() la fait trembler un instant (grande porte, coups du boss).

@export var target: Node3D
@export var offset := Vector3(0.0, 10.5, 11.0)
@export var smoothing := 6.0

var _secousse := 0.0
var _base := Vector3.ZERO


func _ready() -> void:
	if target:
		global_position = target.global_position + offset
	_base = global_position
	look_at(global_position - offset, Vector3.UP)


func secouer(force: float) -> void:
	_secousse = maxf(_secousse, force)


## Replace la caméra d'un coup derrière le ninja (fin d'une cinématique).
func recaler() -> void:
	if target:
		_base = target.global_position + offset
		global_position = _base


func _physics_process(delta: float) -> void:
	if not target:
		return
	var goal := target.global_position + offset
	_base = _base.lerp(goal, 1.0 - exp(-smoothing * delta))
	_secousse = move_toward(_secousse, 0.0, delta * 1.5)
	var tremble := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _secousse * 0.6
	global_position = _base + tremble
