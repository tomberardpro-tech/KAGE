@tool
extends Zone
## Pin japonais. Son ombre au sol est une cachette.

@export var rayon := 2.5:
	set(v):
		rayon = v
		if is_inside_tree():
			_construire()


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

	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color("#3a2a1e")
	var feuilles := StandardMaterial3D.new()
	feuilles.albedo_color = Color("#1f3326")

	var tronc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.25
	cyl.height = 2.6
	cyl.material = bois
	tronc.mesh = cyl
	tronc.position.y = 1.3
	add_child(tronc)
	# Feuillage en plateaux, comme un pin taillé
	for i in 3:
		var plateau := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rayon * (0.9 - i * 0.2)
		sphere.height = 0.9
		sphere.material = feuilles
		plateau.mesh = sphere
		plateau.position = Vector3((i - 1) * 0.4, 2.3 + i * 0.6, (1 - i) * 0.2)
		add_child(plateau)
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
