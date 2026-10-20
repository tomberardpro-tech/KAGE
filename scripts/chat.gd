extends Node3D
## Petit chat assis, fait de formes simples : sa queue ondule, il tourne la tête vers le ninja
## et miaule quand on passe près de lui. Purement décoratif.

@export var pelage := 0  ## 0 roux, 1 noir, 2 tigré gris

const COULEURS := [Color("#c47a3a"), Color("#1e1d22"), Color("#7d7a74")]

var _tete: Node3D
var _queue: Array[Node3D] = []
var _t := randf() * 10.0
var _miaule := 0.0
var _son: AudioStreamPlayer3D


func _ready() -> void:
	var poil := StandardMaterial3D.new()
	poil.albedo_color = COULEURS[pelage % COULEURS.size()]
	poil.roughness = 1.0
	var clair := StandardMaterial3D.new()
	clair.albedo_color = poil.albedo_color.lightened(0.45)
	var yeux := StandardMaterial3D.new()
	yeux.albedo_color = Color("#d8e86a")
	yeux.emission_enabled = true
	yeux.emission = Color("#c8e04a")
	yeux.emission_energy_multiplier = 1.2
	# corps assis
	_sphere(self, Vector3(0.2, 0.24, 0.26), Vector3(0, 0.16, -0.02), poil)
	_sphere(self, Vector3(0.13, 0.12, 0.1), Vector3(0, 0.15, 0.1), clair)
	for s in [-1.0, 1.0]:
		_sphere(self, Vector3(0.06, 0.06, 0.1), Vector3(s * 0.06, 0.03, 0.12), clair)
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.33, 0.06)
	add_child(_tete)
	_sphere(_tete, Vector3(0.17, 0.15, 0.15), Vector3.ZERO, poil)
	_sphere(_tete, Vector3(0.08, 0.06, 0.06), Vector3(0, -0.03, 0.065), clair)
	for s in [-1.0, 1.0]:
		var oreille := MeshInstance3D.new()
		var prisme := PrismMesh.new()
		prisme.size = Vector3(0.06, 0.07, 0.03)
		oreille.mesh = prisme
		oreille.material_override = poil
		oreille.position = Vector3(s * 0.05, 0.08, 0)
		oreille.rotation.z = -s * 0.25
		_tete.add_child(oreille)
		_sphere(_tete, Vector3(0.025, 0.03, 0.02), Vector3(s * 0.035, 0.01, 0.07), yeux)
	# queue en quatre morceaux, chacun accroché au précédent
	var parent: Node3D = self
	var depart := Vector3(0, 0.05, -0.15)
	for k in 4:
		var bout := Node3D.new()
		bout.position = depart
		parent.add_child(bout)
		_sphere(bout, Vector3(0.045, 0.045, 0.1), Vector3(0, 0, -0.04), poil)
		_queue.append(bout)
		parent = bout
		depart = Vector3(0, 0.0, -0.08)
	_son = AudioStreamPlayer3D.new()
	if ResourceLoader.exists("res://assets/audio/sfx/miaou.ogg"):
		_son.stream = load("res://assets/audio/sfx/miaou.ogg")
	_son.unit_size = 4.0
	_son.volume_db = -10.0
	_son.bus = "Bruitages"
	add_child(_son)


func _sphere(parent: Node3D, taille: Vector3, centre: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 10
	s.rings = 6
	mi.mesh = s
	mi.scale = taille
	mi.position = centre
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	for k in _queue.size():
		_queue[k].rotation.y = sin(_t * 1.6 - k * 0.7) * 0.35
		_queue[k].rotation.x = 0.35 if k == 0 else 0.15
	_miaule -= delta
	var ninja: Node3D = get_tree().get_first_node_in_group("ninja")
	var angle := sin(_t * 0.4) * 0.4
	if ninja and ninja.global_position.distance_to(global_position) < 3.0:
		var local := to_local(ninja.global_position)
		angle = clampf(atan2(local.x, local.z), -1.2, 1.2)
		if _miaule <= 0.0 and _son.stream:
			_miaule = 12.0
			_son.pitch_scale = randf_range(0.9, 1.15)
			_son.play()
	_tete.rotation.y = lerp_angle(_tete.rotation.y, angle, 1.0 - exp(-4.0 * delta))
