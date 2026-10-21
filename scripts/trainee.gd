class_name Trainee
extends MeshInstance3D
## Traînée rouge légère derrière le ninja pendant son salto : un ruban tourné vers la caméra,
## additif, qui s'amincit et s'estompe en quelques dixièmes de seconde.
## On suit un point (source) ; le ruban est lissé pour rester fluide même à faible cadence.

@export var duree_vie := 0.38  ## temps qu'un morceau de traînée met à disparaître
@export var largeur := 0.22
@export var couleur := Color(1.0, 0.13, 0.08)
@export var intensite := 0.75

var source: Node3D  ## point suivi (posé sur le modèle du ninja)
var actif := false  ## vrai : la traînée s'allonge ; faux : elle finit de s'estomper

var _points: Array[Vector3] = []
var _ages: Array[float] = []
var _maillage := ImmediateMesh.new()


func _ready() -> void:
	top_level = true  # les points sont en coordonnées du monde
	global_transform = Transform3D.IDENTITY
	mesh = _maillage
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var matiere := StandardMaterial3D.new()
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matiere.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	matiere.cull_mode = BaseMaterial3D.CULL_DISABLED
	matiere.vertex_color_use_as_albedo = true
	matiere.no_depth_test = false
	matiere.disable_receive_shadows = true
	material_override = matiere


func _process(delta: float) -> void:
	global_transform = Transform3D.IDENTITY
	for i in _ages.size():
		_ages[i] += delta
	while not _ages.is_empty() and _ages[0] > duree_vie:
		_ages.pop_front()
		_points.pop_front()
	if actif and source and is_instance_valid(source):
		var p := source.global_position
		if _points.is_empty() or _points[-1].distance_to(p) > 0.03:
			_points.append(p)
			_ages.append(0.0)
	_dessiner()


## Vide la traînée d'un coup (réapparition, cinématique).
func effacer() -> void:
	_points.clear()
	_ages.clear()
	_maillage.clear_surfaces()


func _dessiner() -> void:
	_maillage.clear_surfaces()
	if _points.size() < 2:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Courbe lissée (Catmull-Rom) : quelques points intermédiaires entre deux relevés
	var lisse: Array[Vector3] = []
	var vieux: Array[float] = []
	var n := _points.size()
	for i in n - 1:
		var p0 := _points[maxi(i - 1, 0)]
		var p1 := _points[i]
		var p2 := _points[i + 1]
		var p3 := _points[mini(i + 2, n - 1)]
		var pas := clampi(int(p1.distance_to(p2) / 0.05), 1, 8)
		for k in pas:
			var t := float(k) / pas
			lisse.append(_catmull(p0, p1, p2, p3, t))
			vieux.append(lerpf(_ages[i], _ages[i + 1], t))
	lisse.append(_points[-1])
	vieux.append(_ages[-1])

	var oeil := camera.global_position
	_maillage.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in lisse.size():
		var avant := lisse[maxi(i - 1, 0)]
		var apres := lisse[mini(i + 1, lisse.size() - 1)]
		var sens := (apres - avant)
		if sens.length() < 0.0001:
			sens = Vector3.UP
		var cote := sens.cross(oeil - lisse[i]).normalized()
		var vie := 1.0 - clampf(vieux[i] / duree_vie, 0.0, 1.0)
		# fin à la queue comme à la tête, plus épaisse au milieu récent
		var tete := clampf(float(lisse.size() - 1 - i) / 3.0, 0.35, 1.0)
		var demi := largeur * 0.5 * vie * tete
		var c := couleur * (intensite * vie * vie)
		c.a = 1.0
		_maillage.surface_set_color(c)
		_maillage.surface_add_vertex(lisse[i] + cote * demi)
		_maillage.surface_set_color(c)
		_maillage.surface_add_vertex(lisse[i] - cote * demi)
	_maillage.surface_end()


func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)
