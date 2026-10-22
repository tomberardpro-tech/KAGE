class_name GrandeLame
extends Node3D
## La Grande Lame : une épée-dalle immense trouvée dans le coffre du donjon, construite par code.
## Lame large et épaisse (centre noir mat, larges tranchants argentés, pointe en biseau),
## garde en demi-lune de métal gris avec un petit motif, poignée à bandelettes beiges,
## pommeau de métal et une longue bande de tissu qui pend et flotte.
## Repère : la lame monte le long de +y depuis la garde (y = 0), la poignée descend sous la garde ;
## le plat de la lame regarde +z. Dimensions en mètres (lame de 2,2 m).

const LONGUEUR := 2.2
const LARGEUR := 0.46
const POIGNEE := 0.55  ## longueur de la poignée sous la garde
## Point de la poignée où se pose la main (pour la tenir).
const PRISE := Vector3(0.0, -0.3, 0.0)

var _acier: StandardMaterial3D
var _lueur: OmniLight3D
var _tissu: MeshInstance3D
var _tissu_maillage := ImmediateMesh.new()
var _noeuds_tissu: Array[Vector3] = []
var _anciens_tissu: Array[Vector3] = []
var _attache_tissu: Node3D

const NB_TISSU := 12
const PAS_TISSU := 0.065


func _ready() -> void:
	_construire()


## Fait luire la lame (0 = éteinte) : tranchants qui s'illuminent et lumière blanche-dorée.
func briller(force: float) -> void:
	_acier.emission_energy_multiplier = 0.15 + force * 1.6
	_lueur.light_energy = force * 3.0
	_lueur.visible = force > 0.01


func _process(delta: float) -> void:
	_animer_tissu(delta)


# --- Construction ----------------------------------------------------------

func _construire() -> void:
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color("#17171b")
	noir.roughness = 0.95
	noir.metallic = 0.15
	_acier = StandardMaterial3D.new()
	_acier.albedo_color = Color("#c9ced6")
	_acier.metallic = 0.6
	_acier.roughness = 0.3
	_acier.emission_enabled = true
	_acier.emission = Color("#dfe6f0")
	_acier.emission_energy_multiplier = 0.15
	var acier_sombre := StandardMaterial3D.new()
	acier_sombre.albedo_color = Color("#8d939c")
	acier_sombre.metallic = 0.8
	acier_sombre.roughness = 0.4
	var gris := StandardMaterial3D.new()
	gris.albedo_color = Color("#6c7079")
	gris.metallic = 0.75
	gris.roughness = 0.5
	var gris_clair := StandardMaterial3D.new()
	gris_clair.albedo_color = Color("#a9adb5")
	gris_clair.metallic = 0.8
	gris_clair.roughness = 0.35
	var beige := StandardMaterial3D.new()
	beige.albedo_color = Color("#cbb68f")
	beige.roughness = 0.9
	var beige_fonce := StandardMaterial3D.new()
	beige_fonce.albedo_color = Color("#9c8762")
	beige_fonce.roughness = 0.95
	var cuir := StandardMaterial3D.new()
	cuir.albedo_color = Color("#2b211b")
	cuir.roughness = 0.9
	# pièces fines et plates : on dessine les deux faces, quel que soit le sens des triangles
	for m in [noir, _acier, acier_sombre, gris, gris_clair, beige, beige_fonce, cuir]:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Lame en trois épaisseurs : fil argenté fin tout autour, plat argenté, centre noir épais.
	var l := LONGUEUR
	var h := LARGEUR / 2.0
	# pointe en biseau : coupée en diagonale, plus haute du côté droit (+x)
	var biseau := func(x: float) -> float: return lerpf(l - 0.36, l + 0.04, (x + h) / (2.0 * h))
	var contour := PackedVector2Array([Vector2(-h, 0.0), Vector2(h, 0.0), Vector2(h, biseau.call(h)), Vector2(-h, biseau.call(-h))])
	_extruder(contour, 0.03, _acier)
	var e := 0.065  # largeur du fil argenté visible
	var plat := PackedVector2Array([Vector2(-h + e, 0.0), Vector2(h - e, 0.0),
		Vector2(h - e, biseau.call(h - e) - e * 1.4), Vector2(-h + e, biseau.call(-h + e) - e * 1.4)])
	_extruder(plat, 0.055, acier_sombre)
	var c := 0.12  # demi-largeur du centre noir
	var centre := PackedVector2Array([Vector2(-c, 0.0), Vector2(c, 0.0),
		Vector2(c, biseau.call(c) - 0.2), Vector2(-c, biseau.call(-c) - 0.2)])
	_extruder(centre, 0.085, noir)
	# petit talon de lame (ricasso) au ras de la garde
	_extruder(PackedVector2Array([Vector2(-h - 0.01, -0.02), Vector2(h + 0.01, -0.02), Vector2(h + 0.01, 0.12), Vector2(-h - 0.01, 0.12)]), 0.095, gris)

	# Garde en demi-lune, cornes vers la lame
	var lune := PackedVector2Array()
	for i in 25:
		var a := deg_to_rad(lerpf(192.0, 348.0, i / 24.0))
		lune.append(Vector2(cos(a) * 0.4, 0.1 + sin(a) * 0.3))
	for i in 25:
		var a := deg_to_rad(lerpf(348.0, 192.0, i / 24.0))
		lune.append(Vector2(cos(a) * 0.3, 0.17 + sin(a) * 0.19))
	_extruder(lune, 0.13, gris)
	# motif : losange clair et anneau sur les deux faces de la garde
	var losange := PackedVector2Array([Vector2(0, -0.18), Vector2(0.065, -0.11), Vector2(0, -0.04), Vector2(-0.065, -0.11)])
	_extruder(losange, 0.15, gris_clair)
	var point := PackedVector2Array()
	for i in 16:
		point.append(Vector2(0, -0.11) + Vector2.from_angle(TAU * i / 16.0) * 0.028)
	_extruder(point, 0.165, cuir)
	for s in [-1.0, 1.0]:
		var bout := PackedVector2Array()
		for i in 12:
			bout.append(Vector2(s * 0.37, 0.05) + Vector2.from_angle(TAU * i / 12.0) * 0.035)
		_extruder(bout, 0.15, gris_clair)

	# Poignée : âme de cuir, bandelettes beiges croisées, pommeau de métal
	_cylindre(0.042, POIGNEE, Vector3(0, -0.12 - POIGNEE / 2.0, 0), cuir, Vector3.ZERO)
	for k in 9:
		var y := -0.16 - k * 0.055
		var penche := 0.32 if k % 2 == 0 else -0.32
		_cylindre(0.052, 0.04, Vector3(0, y, 0), beige if k % 2 == 0 else beige_fonce, Vector3(0, 0, penche))
	_cylindre(0.06, 0.04, Vector3(0, -0.13, 0), gris, Vector3.ZERO)
	_cylindre(0.075, 0.07, Vector3(0, -0.12 - POIGNEE - 0.04, 0), gris, Vector3.ZERO)
	var boule := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.1
	boule.mesh = sphere
	boule.material_override = gris_clair
	boule.position = Vector3(0, -0.12 - POIGNEE - 0.1, 0)
	add_child(boule)

	# Lumière de la révélation (éteinte en temps normal)
	_lueur = OmniLight3D.new()
	_lueur.light_color = Color(0.95, 0.9, 1.0)
	_lueur.omni_range = 5.0
	_lueur.shadow_enabled = false
	_lueur.light_energy = 0.0
	_lueur.visible = false
	_lueur.position = Vector3(0, 1.0, 0.4)
	add_child(_lueur)

	# Bande de tissu qui pend du bas de la poignée
	_attache_tissu = Node3D.new()
	_attache_tissu.position = Vector3(0.0, -0.12 - POIGNEE + 0.04, 0.05)
	add_child(_attache_tissu)
	var tissu_mat := StandardMaterial3D.new()
	tissu_mat.albedo_color = Color("#c2ad86")
	tissu_mat.roughness = 1.0
	tissu_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tissu_mat.vertex_color_use_as_albedo = true
	_tissu = MeshInstance3D.new()
	_tissu.mesh = _tissu_maillage
	_tissu.material_override = tissu_mat
	_tissu.top_level = true
	_tissu.extra_cull_margin = 3.0
	add_child(_tissu)


## Polygone plat (dans le plan xy) épaissi le long de z, centré sur z = 0.
func _extruder(contour: PackedVector2Array, epaisseur: float, m: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := Geometry2D.triangulate_polygon(contour)
	var z := epaisseur / 2.0
	for face in [1.0, -1.0]:
		for i in range(0, tri.size(), 3):
			var coins: Array[Vector3] = []
			for k in 3:
				var p := contour[tri[i + k]]
				coins.append(Vector3(p.x, p.y, z * face))
			_triangle(st, coins[0], coins[1], coins[2], Vector3(0, 0, face))
	var n := contour.size()
	var sens := 1.0 if _aire(contour) > 0.0 else -1.0
	for i in n:
		var a := contour[i]
		var b := contour[(i + 1) % n]
		var normale := Vector3(b.y - a.y, a.x - b.x, 0).normalized() * sens
		var c := [Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(b.x, b.y, -z), Vector3(a.x, a.y, -z)]
		_triangle(st, c[0], c[1], c[2], normale)
		_triangle(st, c[0], c[2], c[3], normale)
	if tri.is_empty():
		push_warning("GrandeLame : contour impossible à trianguler")
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)


## Triangle tourné du bon côté : Godot voit de face les triangles dans le sens des aiguilles d'une montre.
func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normale: Vector3) -> void:
	var ordre := [a, b, c] if (b - a).cross(c - a).dot(normale) < 0.0 else [a, c, b]
	for p in ordre:
		st.set_normal(normale)
		st.add_vertex(p)


func _aire(contour: PackedVector2Array) -> float:
	var a := 0.0
	for i in contour.size():
		var p := contour[i]
		var q := contour[(i + 1) % contour.size()]
		a += p.x * q.y - q.x * p.y
	return a / 2.0


func _cylindre(rayon: float, hauteur: float, centre: Vector3, m: Material, rotation_: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rayon
	c.bottom_radius = rayon
	c.height = hauteur
	c.radial_segments = 14
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = centre
	mi.rotation = rotation_
	add_child(mi)


# --- Bande de tissu ------------------------------------------------------

## Une chaîne de points (Verlet) qui pend sous la poignée, poussée par un petit vent qui ondule.
func _animer_tissu(delta: float) -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		_tissu_maillage.clear_surfaces()
		return
	var depart := _attache_tissu.global_position
	var echelle := global_transform.basis.get_scale().x
	var pas := PAS_TISSU * echelle
	if _noeuds_tissu.is_empty() or _noeuds_tissu[0].distance_to(depart) > 3.0:
		_noeuds_tissu.clear()
		_anciens_tissu.clear()
		for i in NB_TISSU:
			var p := depart + Vector3.DOWN * pas * i
			_noeuds_tissu.append(p)
			_anciens_tissu.append(p)
	var dt := minf(delta, 1.0 / 20.0)
	var t := Time.get_ticks_msec() / 1000.0
	_noeuds_tissu[0] = depart
	for i in range(1, NB_TISSU):
		var p := _noeuds_tissu[i]
		var vitesse := (p - _anciens_tissu[i]) * 0.94
		var vent := Vector3(sin(t * 2.3 + i * 0.5), 0.0, cos(t * 1.7 + i * 0.4)) * (0.9 + 0.5 * sin(t * 5.0 + i))
		_anciens_tissu[i] = p
		_noeuds_tissu[i] = p + vitesse + (Vector3.DOWN * 6.0 + vent * 2.5) * dt * dt
	for passe in 4:
		_noeuds_tissu[0] = depart
		for i in range(1, NB_TISSU):
			var a := _noeuds_tissu[i - 1]
			var b := _noeuds_tissu[i]
			var ecart := b - a
			var d := ecart.length()
			if d > 0.0001:
				_noeuds_tissu[i] = a + ecart / d * pas
	_dessiner_tissu(echelle)


func _dessiner_tissu(echelle: float) -> void:
	_tissu_maillage.clear_surfaces()
	_tissu.global_transform = Transform3D.IDENTITY
	var cote := global_transform.basis.x.normalized()
	_tissu_maillage.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in NB_TISSU:
		var u := float(i) / (NB_TISSU - 1)
		var demi := 0.045 * echelle * (1.0 - 0.35 * u)
		var teinte := Color(1, 1, 1).lerp(Color(0.72, 0.62, 0.5), u)  # bout plus sale
		var long_de := _noeuds_tissu[mini(i + 1, NB_TISSU - 1)] - _noeuds_tissu[maxi(i - 1, 0)]
		var normale := cote.cross(long_de).normalized()
		for s in [1.0, -1.0]:
			_tissu_maillage.surface_set_normal(normale)
			_tissu_maillage.surface_set_color(teinte)
			_tissu_maillage.surface_add_vertex(_noeuds_tissu[i] + cote * demi * s)
	_tissu_maillage.surface_end()
