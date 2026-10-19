extends Light3D
## Fait vaciller doucement une flamme (brasero).

@export var amplitude := 0.15

var _base := 0.0
var _t := 0.0


func _ready() -> void:
	_base = light_energy
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	var vacille := sin(_t * 7.3) * 0.5 + sin(_t * 13.1) * 0.3 + sin(_t * 3.7) * 0.2
	light_energy = _base * (1.0 + amplitude * vacille)
