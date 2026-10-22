extends Node3D
## Toit japonais d'un bâtiment qu'on doit pouvoir voir de l'intérieur (parchemin) :
## il pâlit quand le ninja approche et disparaît quand il entre, puis revient quand il ressort.

@export var emprise := Rect2()  ## rectangle du bâtiment au sol (x, z du monde)
@export var hauteur := 0.0  ## hauteur des murs : un ninja plus haut que ça est SUR le toit, qui reste alors visible

var _ninja: Node3D
var _actuel := 0.0
var _morceaux: Array[GeometryInstance3D] = []


func _ready() -> void:
	for n in find_children("*", "GeometryInstance3D", true, false):
		_morceaux.append(n)


func _process(delta: float) -> void:
	if _ninja == null:
		_ninja = get_tree().get_first_node_in_group("ninja")
		if _ninja == null:
			return
	var p := Vector2(_ninja.global_position.x, _ninja.global_position.z)
	var cible := 0.0
	if hauteur > 0.0 and _ninja.global_position.y > hauteur - 0.3:
		cible = 0.0  # sur le toit (ou en sautant dessus) : il ne s'efface pas
	elif emprise.grow(0.3).has_point(p):
		cible = 1.0
	elif emprise.grow(3.0).has_point(p):
		cible = 0.55
	var avant := _actuel
	_actuel = move_toward(_actuel, cible, delta * 3.0)
	if _actuel == avant:
		return
	for m in _morceaux:
		m.transparency = _actuel
		m.visible = _actuel < 0.99
