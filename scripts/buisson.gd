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
		_opaque = Touffu.materiau()
		_transparent = _opaque.duplicate()
		_transparent.set_shader_parameter("opacite", 0.45)
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
	# une grosse touffe au centre et trois plus petites autour
	var boules := [[Vector3(0, r * 0.55, 0), Vector3(r, r * 0.95, r), 0]]
	for k in 3:
		var a := k * TAU / 3.0 + hasard.randf_range(-0.4, 0.4)
		var d := r * hasard.randf_range(0.5, 0.7)
		var s := r * hasard.randf_range(0.55, 0.7)
		boules.append([Vector3(cos(a) * d, s * 0.5, sin(a) * d), Vector3(s, s * 0.9, s), k + 1])
	for b in boules:
		var mi := MeshInstance3D.new()
		mi.mesh = Touffu.maillage(b[2])
		mi.position = b[0]
		mi.scale = b[1]
		mi.rotation.y = hasard.randf() * TAU
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
	Sons.jouer("buisson", -10.0, randf_range(0.92, 1.08))
	for b in _boules:
		b.material_override = _transparent if oui else _opaque


func _process(delta: float) -> void:
	if _frisson <= 0.0:
		return
	_frisson = maxf(_frisson - delta * 2.0, 0.0)
	var w := sin(_frisson * 30.0) * _frisson * 0.06
	scale = Vector3(1.0 + w, 1.0 - w * 0.5, 1.0 - w)
