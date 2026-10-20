@tool
extends Node3D
## Carpes koï qui nagent en rond dans un bassin. Les poissons sont générés au chargement.

@export var taille := Vector2(6.0, 4.0)  ## zone de nage, en mètres
@export var nombre := 5

var _poissons: Array[Node3D] = []
var _phases: Array[Vector3] = []  # angle de départ, vitesse, rayon relatif
var _t := 0.0


func _ready() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(taille)
	var couleurs := [Color("#f07a28"), Color("#f4f0e8"), Color("#e8452a"), Color("#f2b33a")]
	for i in nombre:
		var poisson := Node3D.new()
		var corps := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 10
		s.rings = 5
		var m := StandardMaterial3D.new()
		m.albedo_color = couleurs[i % couleurs.size()]
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 0.25
		s.material = m
		corps.mesh = s
		corps.scale = Vector3(0.11, 0.05, 0.3)
		poisson.add_child(corps)
		var queue := MeshInstance3D.new()
		var p := PrismMesh.new()
		p.size = Vector3(0.14, 0.12, 0.01)
		p.material = m
		queue.mesh = p
		queue.rotation_degrees = Vector3(-90, 0, 0)
		queue.position = Vector3(0, 0, 0.2)
		poisson.add_child(queue)
		add_child(poisson)
		_poissons.append(poisson)
		_phases.append(Vector3(hasard.randf() * TAU, hasard.randf_range(0.25, 0.5) * (1 if i % 2 == 0 else -1), hasard.randf_range(0.45, 0.95)))


func _process(delta: float) -> void:
	_t += delta
	for i in _poissons.size():
		var ph := _phases[i]
		var a := ph.x + _t * ph.y
		var r := ph.z
		var pos := Vector3(cos(a) * taille.x * 0.5 * r, -0.02, sin(a) * taille.y * 0.5 * r)
		# Petit ondulement du corps
		var vague := sin(_t * 6.0 + i) * 0.25
		var dir := Vector3(-sin(a), 0, cos(a)) * signf(ph.y)
		_poissons[i].position = pos
		_poissons[i].basis = Basis.looking_at(-dir, Vector3.UP).rotated(Vector3.UP, vague) if dir.length() > 0.01 else Basis()
