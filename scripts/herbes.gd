@tool
extends Zone
## Touffe d'herbes hautes en ellipse. Les brins sont générés au chargement.

@export var taille := Vector2(8.0, 6.0):
	set(v):
		taille = v
		if is_inside_tree():
			_construire()
@export var densite := 12.0  ## brins par m²


static var _materiau: ShaderMaterial


func _ready() -> void:
	type = Type.HERBE
	super._ready()
	_construire()


func _construire() -> void:
	for enfant in get_children():
		enfant.queue_free()
	var forme := CollisionShape3D.new()
	var cylindre := CylinderShape3D.new()
	cylindre.radius = 0.5
	cylindre.height = 1.5
	forme.shape = cylindre
	forme.scale = Vector3(taille.x, 1.0, taille.y)
	forme.position.y = 0.75
	add_child(forme)

	var brin := PrismMesh.new()
	brin.size = Vector3(0.09, 1.0, 0.03)
	if not _materiau:
		_materiau = ShaderMaterial.new()
		_materiau.shader = load("res://assets/shaders/herbe.gdshader")
	brin.material = _materiau
	var nombre := int(PI * taille.x * taille.y / 4.0 * densite)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = brin
	multi.instance_count = nombre
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(taille)
	for i in nombre:
		var r := sqrt(hasard.randf()) * 0.5
		var a := hasard.randf() * TAU
		var pos := Vector3(cos(a) * r * taille.x, 0.45, sin(a) * r * taille.y)
		var base := Basis(Vector3.UP, hasard.randf() * TAU).scaled(Vector3.ONE * hasard.randf_range(0.7, 1.3))
		base = base.rotated(Vector3.RIGHT, hasard.randf_range(-0.2, 0.2))
		multi.set_instance_transform(i, Transform3D(base, pos * Vector3(1, base.get_scale().y, 1)))
	var rendu := MultiMeshInstance3D.new()
	rendu.multimesh = multi
	rendu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rendu)
