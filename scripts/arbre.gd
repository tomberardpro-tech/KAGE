@tool
extends Zone
## Pin japonais. Son ombre au sol est une cachette.

@export var rayon := 2.5:
	set(v):
		rayon = v
		if is_inside_tree():
			_construire()
@export var cerisier := false:  ## cerisier en fleurs au lieu d'un pin, avec des pétales qui tombent
	set(v):
		cerisier = v
		if is_inside_tree():
			_construire()


static var _feuilles: ShaderMaterial
static var _fleurs: ShaderMaterial
static var _glycine: ShaderMaterial  # variante violette (un arbre en fleurs sur deux, environ)
static var _ecorce: StandardMaterial3D


func _ready() -> void:
	type = Type.OMBRE
	super._ready()
	_construire()


func _construire() -> void:
	for enfant in get_children():
		enfant.queue_free()
	var forme := CollisionShape3D.new()
	var cylindre := CylinderShape3D.new()
	cylindre.radius = rayon
	cylindre.height = 2.0
	forme.shape = cylindre
	forme.position.y = 1.0
	add_child(forme)

	if not _feuilles:
		_feuilles = ShaderMaterial.new()
		_feuilles.shader = load("res://assets/shaders/feuillage.gdshader")
		_feuilles.set_shader_parameter("couleur_claire", Color("#2d4a32"))
		_feuilles.set_shader_parameter("couleur_sombre", Color("#09170f"))
		_feuilles.set_shader_parameter("touffes", 5.0)
		_fleurs = ShaderMaterial.new()
		_fleurs.shader = _feuilles.shader
		_fleurs.set_shader_parameter("couleur_claire", Color("#f6bfd0"))
		_fleurs.set_shader_parameter("couleur_sombre", Color("#b0587a"))
		_fleurs.set_shader_parameter("touffes", 8.0)
		_glycine = ShaderMaterial.new()
		_glycine.shader = _feuilles.shader
		_glycine.set_shader_parameter("couleur_claire", Color("#c9a3ec"))
		_glycine.set_shader_parameter("couleur_sombre", Color("#6a3f9a"))
		_glycine.set_shader_parameter("touffes", 8.0)
		_ecorce = StandardMaterial3D.new()
		_ecorce.albedo_color = Color("#3a2a1e")
		_ecorce.roughness = 1.0
	# Pin japonais taillé : tronc tordu, branches qui partent sur les côtés
	# et feuillage en nuages aplatis au bout de chaque branche.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(global_position.round()) if is_inside_tree() else 1
	var violet := cerisier and hasard.randf() < 0.45
	var pos := Vector3.ZERO
	var dir := Vector3(hasard.randf_range(-0.3, 0.3), 1.0, hasard.randf_range(-0.3, 0.3)).normalized()
	var sommets: Array[Vector3] = []
	for i in 3:
		var longueur := 1.0 - i * 0.15
		var suivant := pos + dir * longueur
		_branche(pos, suivant, 0.24 - i * 0.05, 0.19 - i * 0.05)
		sommets.append(suivant)
		pos = suivant
		dir = (dir + Vector3(hasard.randf_range(-0.5, 0.5), 0.3, hasard.randf_range(-0.5, 0.5))).normalized()
	var nuages: Array[Vector3] = [pos + Vector3(0, 0.25, 0)]
	var nombre := 3 + int(rayon)
	for k in nombre:
		var depart: Vector3 = sommets[1 + k % 2]
		var a := k * TAU / nombre + hasard.randf_range(-0.4, 0.4)
		var fin := depart + Vector3(cos(a) * rayon * 0.6, hasard.randf_range(0.0, 0.4), sin(a) * rayon * 0.6)
		_branche(depart, fin, 0.08, 0.05)
		nuages.append(fin)
	for c in nuages:
		var taille := rayon * hasard.randf_range(0.38, 0.5)
		for j in 4:
			var boule := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 12
			sphere.rings = 6
			sphere.material = (_glycine if violet else _fleurs) if cerisier else _feuilles
			boule.mesh = sphere
			var s := taille * (1.0 if j == 0 else hasard.randf_range(0.55, 0.8))
			boule.scale = Vector3(s * 1.5, s * 0.6, s * 1.5)
			boule.position = c + (Vector3.ZERO if j == 0 else Vector3(hasard.randf_range(-1, 1) * taille * 0.6, hasard.randf_range(0.0, 0.2), hasard.randf_range(-1, 1) * taille * 0.6))
			add_child(boule)
	if cerisier:
		add_child(_petales(Color("#d8b8f2") if violet else Color("#f9c9d6")))
	# Ombre au sol
	var ombre := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = rayon
	disque.bottom_radius = rayon
	disque.height = 0.02
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.02, 0.03, 0.03, 0.6)
	noir.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	noir.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disque.material = noir
	ombre.mesh = disque
	ombre.position.y = 0.03
	ombre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ombre)


func _branche(a: Vector3, b: Vector3, r_bas: float, r_haut: float) -> void:
	var morceau := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_haut
	cyl.bottom_radius = r_bas
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 7
	cyl.rings = 1
	cyl.material = _ecorce
	morceau.mesh = cyl
	var haut := (b - a).normalized()
	var cote := haut.cross(Vector3.FORWARD if absf(haut.z) < 0.9 else Vector3.RIGHT).normalized()
	morceau.basis = Basis(cote, haut, cote.cross(haut))
	morceau.position = (a + b) / 2.0
	add_child(morceau)


## Pétales roses (ou mauves) qui tombent en tourbillonnant sous le cerisier.
func _petales(couleur: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.position.y = 2.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(rayon, 0.4, rayon)
	p.direction = Vector3(1, 0, 0.3)
	p.spread = 30.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0, -0.45, 0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.06)
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	return p
