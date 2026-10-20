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
static var _mesh_brin: ArrayMesh
static var _meneur: Node  ## une seule touffe envoie la position du ninja au shader partagé


func _ready() -> void:
	type = Type.HERBE
	super._ready()
	_construire()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _meneur == null or not is_instance_valid(_meneur):
		_meneur = self
	if _meneur != self:
		return
	var ninja: Node3D = get_tree().get_first_node_in_group("ninja")
	if ninja:
		_materiau.set_shader_parameter("joueur", ninja.global_position)


## Un brin courbé et effilé (quatre segments), de y = −0,5 à 0,5 comme l'ancien prisme.
static func _brin() -> ArrayMesh:
	if _mesh_brin:
		return _mesh_brin
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 4
	var bords := []
	for k in segments + 1:
		var t := float(k) / segments
		var largeur := 0.055 * (1.0 - t * 0.92)
		var courbe := 0.12 * t * t  # le brin ploie vers l'avant
		bords.append([Vector3(-largeur, t - 0.5, courbe), Vector3(largeur, t - 0.5, courbe)])
	for k in segments:
		var a: Array = bords[k]
		var b: Array = bords[k + 1]
		for v in [a[0], b[0], b[1], a[0], b[1], a[1]]:
			st.set_normal(Vector3(0, 0.3, 1).normalized())
			st.add_vertex(v)
	_mesh_brin = st.commit()
	return _mesh_brin


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

	var brin := _brin()
	if not _materiau:
		_materiau = ShaderMaterial.new()
		_materiau.shader = load("res://assets/shaders/herbe.gdshader")
	brin.surface_set_material(0, _materiau)
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
