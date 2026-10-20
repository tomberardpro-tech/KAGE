extends Zone
## Gros buisson touffu : on peut s'y cacher, même debout. Il frémit quand on y entre
## (bruissement, quelques feuilles qui volent) et devient transparent pour qu'on se voie dedans.

@export var diametre := 2.2

static var _opaque: ShaderMaterial
static var _transparent: ShaderMaterial

var _boules: Array[MeshInstance3D] = []
var _feuilles: CPUParticles3D
var _dedans := false
var _frisson := 0.0


func _ready() -> void:
	type = Type.BUISSON
	super._ready()
	_construire()
	body_entered.connect(func(b): if b is Ninja: _entrer(true))
	body_exited.connect(func(b): if b is Ninja: _entrer(false))


func _construire() -> void:
	if _opaque == null:
		_opaque = ShaderMaterial.new()
		_opaque.shader = load("res://assets/shaders/feuillage.gdshader")
		_opaque.set_shader_parameter("couleur_claire", Color("#3f6a35"))
		_opaque.set_shader_parameter("couleur_sombre", Color("#0e2414"))
		_transparent = ShaderMaterial.new()
		_transparent.shader = load("res://assets/shaders/feuillage_transparent.gdshader")
		_transparent.set_shader_parameter("couleur_claire", Color("#3f6a35"))
		_transparent.set_shader_parameter("couleur_sombre", Color("#0e2414"))
	var r := diametre / 2.0
	var forme := CollisionShape3D.new()
	var cylindre := CylinderShape3D.new()
	cylindre.radius = r * 0.85
	cylindre.height = 1.6
	forme.shape = cylindre
	forme.position.y = 0.8
	add_child(forme)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = int(global_position.x * 31.0 + global_position.z * 17.0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 14
	sphere.rings = 8
	# une grosse boule au centre et des boules plus petites autour, plus haut au milieu
	var boules := [[Vector3(0, r * 0.62, 0), Vector3(r * 1.7, r * 1.35, r * 1.7)]]
	for k in 7:
		var a := k * TAU / 7.0 + hasard.randf_range(-0.3, 0.3)
		var d := r * hasard.randf_range(0.45, 0.7)
		var s := r * hasard.randf_range(0.85, 1.15)
		boules.append([Vector3(cos(a) * d, s * 0.5 + hasard.randf_range(0.0, r * 0.35), sin(a) * d), Vector3(s, s * 0.85, s)])
	for b in boules:
		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		mi.position = b[0]
		mi.scale = b[1]
		mi.material_override = _opaque
		add_child(mi)
		_boules.append(mi)
	_feuilles = CPUParticles3D.new()
	_feuilles.emitting = false
	_feuilles.one_shot = true
	_feuilles.amount = 14
	_feuilles.lifetime = 1.2
	_feuilles.explosiveness = 0.9
	_feuilles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_feuilles.emission_sphere_radius = r * 0.8
	_feuilles.direction = Vector3.UP
	_feuilles.spread = 70.0
	_feuilles.initial_velocity_min = 1.0
	_feuilles.initial_velocity_max = 2.2
	_feuilles.gravity = Vector3(0, -2.5, 0)
	_feuilles.angular_velocity_min = -300.0
	_feuilles.angular_velocity_max = 300.0
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.06)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#4f7a3a")
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	_feuilles.mesh = q
	_feuilles.position.y = r
	add_child(_feuilles)


func _entrer(oui: bool) -> void:
	_dedans = oui
	_frisson = 1.0
	_feuilles.restart()
	Sons.jouer("buisson", -6.0, randf_range(0.9, 1.15))
	for b in _boules:
		b.material_override = _transparent if oui else _opaque


func _process(delta: float) -> void:
	if _frisson <= 0.0:
		return
	_frisson = maxf(_frisson - delta * 2.0, 0.0)
	var w := sin(_frisson * 30.0) * _frisson * 0.06
	scale = Vector3(1.0 + w, 1.0 - w * 0.5, 1.0 - w)
