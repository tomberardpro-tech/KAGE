extends Control
## Pétales rouges qui tombent en tournoyant sur le menu principal (higanbana et camélia),
## portés par un petit vent. Dessinés directement, sans texture.

const NOMBRE := 60

var _petales: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in NOMBRE:
		_petales.append(_nouveau(true))


func _nouveau(partout := false) -> Dictionary:
	var taille := _taille()
	var profondeur := randf()  # 0 loin (petit, pâle, lent), 1 près
	return {
		"pos": Vector2(randf_range(-100, taille.x), randf_range(-taille.y, taille.y) if partout else randf_range(-120, -20)),
		"taille": lerpf(13.0, 32.0, profondeur),
		"vitesse": lerpf(38.0, 95.0, profondeur),
		"angle": randf() * TAU,
		"tour": randf_range(-2.2, 2.2),
		"phase": randf() * TAU,
		"bascule": randf() * TAU,
		"couleur": Color("#c41e2a").lerp(Color("#e8505a"), randf()) * Color(1, 1, 1, lerpf(0.5, 0.95, profondeur)),
	}


func _taille() -> Vector2:
	return size if size.x > 0 else get_viewport_rect().size


func _process(delta: float) -> void:
	_t += delta
	var vent := 30.0 + sin(_t * 0.4) * 22.0
	for p in _petales:
		p["pos"] += Vector2(vent + sin(_t * 1.3 + p["phase"]) * 40.0, p["vitesse"]) * delta
		p["angle"] += p["tour"] * delta
		p["bascule"] += delta * 2.4
		var taille := _taille()
		if p["pos"].y > taille.y + 40 or p["pos"].x > taille.x + 60:
			p.merge(_nouveau(), true)
	queue_redraw()


func _draw() -> void:
	for p in _petales:
		var s: float = p["taille"]
		# le pétale bascule sur lui-même : il s'aplatit et s'élargit tour à tour
		var aplati: float = 0.35 + 0.65 * absf(cos(p["bascule"]))
		var points := PackedVector2Array()
		for k in 14:
			var a := float(k) / 14.0 * TAU
			# forme de goutte un peu échancrée au bout
			var r := s * (0.55 + 0.45 * sin(a * 0.5)) * (1.0 - 0.18 * maxf(0.0, cos(a * 2.0 - PI)))
			points.append(Vector2(cos(a) * r * aplati, sin(a) * r * 0.62).rotated(p["angle"]) + p["pos"])
		draw_colored_polygon(points, p["couleur"])
		draw_polyline(points, Color(p["couleur"].darkened(0.3), p["couleur"].a * 0.5), 1.0)
