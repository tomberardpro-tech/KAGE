extends "res://scripts/tools/constructeur.gd"
## Décor d'ambiance japonaise, partagé par les trois niveaux (ticket 4.4).
## Textures Poly Haven et rochers Kenney (CC0, voir CREDITS.md), le reste est construit ici :
## murs blancs à tuiles, buissons taillés, bambous, bannières, braseros, ruisseau, cascade,
## pont rouge, nénuphars, lucioles et brume.
## Tout ce décor est sans collision (sauf les gros rochers) : il ne change pas le jeu.
## Les petits objets répétés sont regroupés en MultiMesh pour rester léger dans le navigateur.

const TEX := "res://assets/textures/polyhaven/"
const SHADERS := "res://assets/shaders/"

var _deco := {}  # nom -> {"mesh": Mesh, "transforms": Array, "ombre": bool, "materiau": Material}
var _hasard := RandomNumberGenerator.new()
var _meshes := {}
var _corps_rochers: StaticBody3D


# --- Matériaux et ambiance -------------------------------------------------

func _materiaux() -> void:
	super._materiaux()
	materiaux["herbe"] = _texture("leafy_grass", "#4c6646", 0.3)
	materiaux["pave"] = _texture("patterned_cobblestone", "#c4c6cc", 0.35)
	materiaux["allee"] = _texture("stone_tiles_02", "#8d909a", 0.4)
	materiaux["mur"] = _texture("white_plaster_02", "#f2ece0", 0.5)
	materiaux["pierre"] = _texture("cobblestone_floor_04", "#8e9099", 0.9)
	materiaux["tuiles"] = _texture("grey_roof_tiles", "#5a6070", 0.8)
	materiaux["bois"] = _texture("dark_wooden_planks", "#8a6a50", 0.6)
	materiaux["parquet"] = _texture("dark_wooden_planks", "#9a7a5c", 0.5)
	materiaux["sable"] = _texture("gravel_floor", "#bdbbb4", 0.5)
	materiaux["terre"] = _texture("gravel_floor", "#7a6650", 0.4)
	materiaux["rocher"] = _texture("mossy_rock", "#8f958c", 0.6)
	materiaux["eau"] = _shader("eau")
	materiaux["feuillage"] = _shader("feuillage")
	var fonce: ShaderMaterial = _shader("feuillage")
	fonce.set_shader_parameter("couleur_claire", Color("#2f4a33"))
	fonce.set_shader_parameter("couleur_sombre", Color("#0b1a14"))
	materiaux["feuillage_fonce"] = fonce
	materiaux["fenetre"] = mat("#2b2320")
	materiaux["shoji"] = mat("#e8d2a0", {"emission_enabled": true, "emission": Color("#d99a4e"),
		"emission_energy_multiplier": 0.55})
	materiaux["laque_vive"] = mat("#b8321e", {"roughness": 0.5})
	materiaux["noir"] = mat("#1c1c22", {"roughness": 0.6})
	materiaux["or"] = mat("#d99a4e", {"metallic": 0.6, "roughness": 0.35})


func _texture(nom: String, teinte: String, echelle: float) -> StandardMaterial3D:
	var m := mat(teinte)
	m.albedo_texture = load(TEX + nom + ".jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * echelle
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _shader(nom: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + nom + ".gdshader")
	return m


func _ambiance() -> void:
	super._ambiance()
	var env: Environment = (racine.get_node("Ambiance") as WorldEnvironment).environment
	env.ambient_light_color = Color("#4f5f86")
	env.ambient_light_energy = 0.42
	(racine.get_node("Lune") as DirectionalLight3D).light_energy = 0.75
	env.fog_light_color = Color("#2c3448")
	env.fog_density = 0.012
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9


# --- Petits objets regroupés ----------------------------------------------

func deco(nom: String, mesh: Mesh, t: Transform3D, materiau: Material = null, ombre := true) -> void:
	if not _deco.has(nom):
		_deco[nom] = {"mesh": mesh, "transforms": [], "ombre": ombre, "materiau": materiau}
	_deco[nom]["transforms"].append(t)


func finir(chemin: String) -> void:
	var noeud := Node3D.new()
	noeud.name = "DecorJaponais"
	ajouter(racine, noeud)
	for nom in _deco:
		var d: Dictionary = _deco[nom]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = d["mesh"]
		multi.instance_count = d["transforms"].size()
		for k in multi.instance_count:
			multi.set_instance_transform(k, d["transforms"][k])
		var rendu := MultiMeshInstance3D.new()
		rendu.name = nom
		rendu.multimesh = multi
		if d["materiau"]:
			rendu.material_override = d["materiau"]
		if not d["ombre"]:
			rendu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ajouter(noeud, rendu)
	super.finir(chemin)


func _boite_unite() -> BoxMesh:
	if not _meshes.has("boite"):
		_meshes["boite"] = BoxMesh.new()
	return _meshes["boite"]


func _sphere() -> SphereMesh:
	if not _meshes.has("sphere"):
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 14
		s.rings = 7
		_meshes["sphere"] = s
	return _meshes["sphere"]


## Boîte décorative (sans collision) de taille donnée en mètres, centrée en `centre`.
func plaque(nom: String, centre: Vector3, taille: Vector3, materiau: String, ombre := true) -> void:
	deco(nom, _boite_unite(), Transform3D(Basis().scaled(taille), centre), materiaux[materiau], ombre)


# --- Murs et bâtiments ------------------------------------------------------

## Mur blanc à soubassement de pierre, poutre sombre, petites fenêtres et toit de tuiles à faîtage.
func mur(nom: String, x: float, y: float, w: float, d: float, h: float) -> void:
	boite(nom, x, y, w, d, h, "mur")
	boite(nom + "Tuiles", x - 6, y - 6, w + 12, d + 12, 0.25, "tuiles", null, h)
	var centre := P(x + w / 2.0, y + d / 2.0)
	var long := maxf(w, d) * ECHELLE
	var epais := minf(w, d) * ECHELLE
	var le_long_x := w >= d
	var taille := func(l: float, haut: float, e: float) -> Vector3:
		return Vector3(l, haut, e) if le_long_x else Vector3(e, haut, l)
	plaque("Soubassements", centre + Vector3(0, 0.3, 0), taille.call(long + 0.04, 0.6, epais + 0.08), "pierre")
	plaque("Poutres", centre + Vector3(0, h - 0.12, 0), taille.call(long + 0.02, 0.14, epais + 0.04), "bois")
	# Faîtage arrondi et rangée de tuiles rondes au bord du toit
	plaque("Faitages", centre + Vector3(0, h + 0.33, 0), taille.call(long + 0.5, 0.16, 0.22), "noir")
	plaque("Faitages", centre + Vector3(0, h + 0.27, 0), taille.call(long + 0.42, 0.06, 0.5), "tuiles")
	# Petites fenêtres à barreaux sur les deux faces, tous les 3,5 m
	if long > 4.0:
		var n := int(long / 3.5)
		for k in n:
			var t := (k + 0.5) / n - 0.5
			for cote in [-1.0, 1.0]:
				var decal := Vector3(t * long, h * 0.62, cote * (epais / 2.0 + 0.02))
				if not le_long_x:
					decal = Vector3(cote * (epais / 2.0 + 0.02), h * 0.62, t * long)
				plaque("Fenetres", centre + decal, taille.call(0.42, 0.34, 0.05), "fenetre", false)
				for b in 3:
					var barreau := decal + (Vector3((b - 1) * 0.11, 0, 0.02 * cote) if le_long_x else Vector3(0.02 * cote, 0, (b - 1) * 0.11))
					plaque("Barreaux", centre + barreau, taille.call(0.03, 0.34, 0.05), "bois", false)


## Bâtiment : murs blancs à colombages sombres, fenêtres shoji éclairées, toit de tuiles débordant.
func batiment(nom: String, x: float, y: float, w: float, d: float, h: float, toit := "tuiles") -> void:
	super.batiment(nom, x, y, w, d, h, toit)
	var c := P(x + w / 2.0, y + d / 2.0)
	var lx := w * ECHELLE
	var lz := d * ECHELLE
	# Poteaux d'angle et poutre haute
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			plaque("Poteaux", c + Vector3(sx * lx / 2.0, h / 2.0, sz * lz / 2.0), Vector3(0.18, h, 0.18), "bois")
	plaque("Poutres", c + Vector3(0, h - 0.15, 0), Vector3(lx + 0.06, 0.16, lz + 0.06), "bois")
	# Faîtage sur le toit, dans le sens de la longueur
	var faitage := Vector3(lx + 0.6, 0.16, 0.24) if lx >= lz else Vector3(0.24, 0.16, lz + 0.6)
	plaque("Faitages", c + Vector3(0, h + 0.38, 0), faitage, "noir")
	# Fenêtres shoji : une lueur chaude derrière le papier, sur chaque face
	var faces := [[Vector3(0, 0, lz / 2.0 + 0.02), lx, true], [Vector3(0, 0, -lz / 2.0 - 0.02), lx, true],
		[Vector3(lx / 2.0 + 0.02, 0, 0), lz, false], [Vector3(-lx / 2.0 - 0.02, 0, 0), lz, false]]
	for f in faces:
		var n := int(f[1] / 2.6)
		for k in n:
			var t: float = ((k + 0.5) / n - 0.5) * f[1]
			var pos: Vector3 = c + f[0] + (Vector3(t, h * 0.55, 0) if f[2] else Vector3(0, h * 0.55, t))
			var taille := Vector3(0.8, 0.6, 0.04) if f[2] else Vector3(0.04, 0.6, 0.8)
			plaque("Shoji", pos, taille, "shoji", false)
			# Croisillons du shoji
			var montant := Vector3(0.04, 0.6, 0.06) if f[2] else Vector3(0.06, 0.6, 0.04)
			var traverse := Vector3(0.8, 0.04, 0.06) if f[2] else Vector3(0.06, 0.04, 0.8)
			for m in [-0.2, 0.2]:
				plaque("Croisillons", pos + (Vector3(m, 0, 0) if f[2] else Vector3(0, 0, m)), montant, "noir", false)
			plaque("Croisillons", pos, traverse, "noir", false)


# --- Végétation -------------------------------------------------------------

## Buissons taillés en boule : [x, y, diamètre en m].
func buissons(liste: Array) -> void:
	_hasard.seed = 4404
	for b in liste:
		var r: float = b[2] / 2.0
		var c := P(b[0], b[1])
		var nombre := 5 + int(r * 4.0)
		deco("Buissons", _sphere(), Transform3D(Basis().scaled(Vector3(r * 1.9, r * 1.5, r * 1.9)), c + Vector3(0, r * 0.65, 0)), materiaux["feuillage"])
		for k in nombre:
			var a := _hasard.randf() * TAU
			var dist := _hasard.randf_range(0.35, 0.75) * r
			var s := r * _hasard.randf_range(0.7, 1.05)
			var pos := c + Vector3(cos(a) * dist, s * 0.55 + _hasard.randf_range(0.0, r * 0.45), sin(a) * dist)
			deco("Buissons", _sphere(), Transform3D(Basis().scaled(Vector3(s, s * 0.85, s)), pos), materiaux["feuillage"])
		touffes(c, r + 0.5, 4)


## Petites touffes d'herbe autour d'un point (rayon en m).
func touffes(centre: Vector3, rayon: float, nombre: int) -> void:
	if not _meshes.has("touffe"):
		var brin := PrismMesh.new()
		brin.size = Vector3(0.07, 0.35, 0.02)
		_meshes["touffe"] = brin
		var m := mat("#3e5a3a", {"cull_mode": BaseMaterial3D.CULL_DISABLED})
		materiaux["touffe"] = m
	for k in nombre:
		var a := _hasard.randf() * TAU
		var c := centre + Vector3(cos(a), 0, sin(a)) * rayon * _hasard.randf_range(0.7, 1.1)
		for j in 7:
			var base := Basis(Vector3.UP, _hasard.randf() * TAU).rotated(Vector3.RIGHT, _hasard.randf_range(-0.35, 0.35))
			var s := _hasard.randf_range(0.6, 1.2)
			var p := c + Vector3(_hasard.randf_range(-0.12, 0.12), 0.17 * s, _hasard.randf_range(-0.12, 0.12))
			deco("Touffes", _meshes["touffe"], Transform3D(base.scaled(Vector3.ONE * s), p), materiaux["touffe"], false)


## Touffes d'herbe éparpillées sur un rectangle [x, y, w, d] (px).
func parsemer(x: float, y: float, w: float, d: float, nombre: int) -> void:
	_hasard.seed = int(x * 5 + y * 11)
	for k in nombre:
		touffes(P(x + _hasard.randf() * w, y + _hasard.randf() * d), 0.0, 1)


## Bosquet de bambous dans un rectangle [x, y, w, d] en px.
func bambous(x: float, y: float, w: float, d: float, nombre := 12) -> void:
	_hasard.seed = int(x * 7 + y)
	var tige := CylinderMesh.new()
	tige.top_radius = 0.045
	tige.bottom_radius = 0.055
	tige.height = 1.0
	tige.radial_segments = 6
	tige.rings = 1
	var feuille := QuadMesh.new()
	feuille.size = Vector2(0.07, 0.34)
	var mf := mat("#4f7038", {"cull_mode": BaseMaterial3D.CULL_DISABLED})
	for k in nombre:
		var h := _hasard.randf_range(3.2, 4.6)
		var p := P(x + _hasard.randf() * w, y + _hasard.randf() * d)
		var penche := Basis(Vector3(1, 0, 0), _hasard.randf_range(-0.06, 0.06)).rotated(Vector3(0, 0, 1), _hasard.randf_range(-0.08, 0.08))
		deco("Bambous", tige, Transform3D(penche.scaled(Vector3(1, h, 1)), p + Vector3(0, h / 2.0, 0)), _shader("bambou"))
		for j in 22:
			var hauteur := _hasard.randf_range(h * 0.45, h * 1.02)
			var a := _hasard.randf() * TAU
			var base := Basis(Vector3.UP, a).rotated(Vector3(cos(a), 0, sin(a)), _hasard.randf_range(0.6, 1.3))
			var pos := p + penche * Vector3(0, hauteur, 0) + Vector3(cos(a), 0, sin(a)) * 0.18
			deco("FeuillesBambou", feuille, Transform3D(base, pos), mf, false)


## Fleurs higanbana (lys araignée rouge) : tige et pétales fins recourbés.
func higanbanas(nombre: int, graine: int, x0: float, x1: float, y0: float, y1: float, chemin: float) -> void:
	_hasard.seed = graine
	var mesh := _mesh_higanbana()
	var m := mat("#ffffff", {"vertex_color_use_as_albedo": true, "emission_enabled": true,
		"emission": Color("#5a0e08"), "emission_energy_multiplier": 0.4})
	var poses := 0
	while poses < nombre:
		var x := _hasard.randf_range(x0, x1)
		var y := _hasard.randf_range(y0, y1)
		if absf(x - chemin) < 70:
			continue  # on laisse le chemin libre
		var base := Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3.ONE * _hasard.randf_range(0.8, 1.2))
		deco("Higanbanas", mesh, Transform3D(base, P(x, y)), m, false)
		poses += 1


## Bouquet de higanbanas dans un rectangle [x, y, w, d] en px (pour les jardins).
func massif_higanbanas(x: float, y: float, w: float, d: float, nombre: int) -> void:
	higanbanas(nombre, int(x + y * 3), x, x + w, y, y + d, -1000)


func _mesh_higanbana() -> ArrayMesh:
	if _meshes.has("higanbana"):
		return _meshes["higanbana"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vert := Color("#2f4a2a")
	var rouge := Color("#c8261a")
	_prisme(st, Vector3(0, 0, 0), Vector3(0, 0.42, 0), 0.012, vert)
	for k in 7:
		var a := k * TAU / 7.0
		var dir := Vector3(cos(a), 0, sin(a))
		var milieu := Vector3(0, 0.44, 0) + dir * 0.07 + Vector3(0, 0.03, 0)
		_prisme(st, Vector3(0, 0.42, 0), milieu, 0.022, rouge)
		_prisme(st, milieu, milieu + dir * 0.05 + Vector3(0, 0.05, 0), 0.016, rouge)
		# étamines, longues et fines
		_prisme(st, Vector3(0, 0.43, 0), Vector3(0, 0.43, 0) + dir * 0.1 + Vector3(0, 0.1, 0), 0.004, Color("#e0493a"))
	st.generate_normals()
	var mesh := st.commit()
	_meshes["higanbana"] = mesh
	return mesh


## Petit prisme carré entre deux points (pour les tiges et pétales générés).
func _prisme(st: SurfaceTool, a: Vector3, b: Vector3, e: float, couleur: Color) -> void:
	var axe := (b - a).normalized()
	var u := axe.cross(Vector3.FORWARD if absf(axe.y) > 0.9 else Vector3.UP).normalized() * e
	var v := axe.cross(u).normalized() * e
	var coins := [u + v, u - v, -u - v, -u + v]
	st.set_color(couleur)
	for i in 4:
		var c0: Vector3 = coins[i]
		var c1: Vector3 = coins[(i + 1) % 4]
		for p in [a + c0, b + c0, b + c1, a + c0, b + c1, a + c1]:
			st.add_vertex(p)


# --- Rochers ----------------------------------------------------------------

## Rochers moussus (formes Kenney, texture Poly Haven) : [x, y, taille en m, modèle 0-8].
## Ceux de plus de 0,8 m ont une collision.
func rochers(liste: Array) -> void:
	var modeles := ["stone_largeA", "stone_largeB", "stone_largeC", "stone_largeE", "stone_tallA",
		"stone_tallB", "stone_smallA", "stone_smallC", "stone_smallFlatA"]
	if not _corps_rochers:
		_corps_rochers = StaticBody3D.new()
		_corps_rochers.name = "Rochers"
		ajouter(racine, _corps_rochers)
	for r in liste:
		var nom: String = modeles[int(r[3]) % modeles.size()]
		if not _meshes.has(nom):
			_meshes[nom] = _mesh_du_modele("res://assets/models/nature/%s.glb" % nom)
		var mesh: Mesh = _meshes[nom]
		var aabb := mesh.get_aabb()
		var s: float = r[2] / maxf(aabb.size.x, aabb.size.z)
		var base := Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3.ONE * s)
		var pos := P(r[0], r[1]) - Vector3(0, aabb.position.y * s + 0.05, 0)
		deco("Rochers" + nom, mesh, Transform3D(base, pos), materiaux["rocher"])
		if r[2] > 0.8:
			var forme := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = r[2] * 0.4
			cyl.height = aabb.size.y * s
			forme.shape = cyl
			forme.position = P(r[0], r[1], cyl.height / 2.0)
			ajouter(_corps_rochers, forme)


func _mesh_du_modele(chemin: String) -> Mesh:
	var scene: Node = load(chemin).instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = mi.mesh.duplicate()
	scene.free()
	return mesh


# --- Eau ----------------------------------------------------------------------

## Ruisseau : bandes d'eau entre les points [[x, y]...] (px), avec des galets sur les berges.
func ruisseau(nom: String, points: Array, largeur: float) -> void:
	var noeud := Node3D.new()
	noeud.name = nom
	ajouter(racine, noeud)
	_hasard.seed = int(largeur * 13)
	for k in points.size() - 1:
		var a := P(points[k][0], points[k][1], 0.035)
		var b := P(points[k + 1][0], points[k + 1][1], 0.035)
		var bande := MeshInstance3D.new()
		var plan := PlaneMesh.new()
		plan.size = Vector2(a.distance_to(b) + largeur * ECHELLE, largeur * ECHELLE)
		plan.material = materiaux["eau"]
		bande.mesh = plan
		bande.position = (a + b) / 2.0
		bande.rotation.y = -atan2(b.z - a.z, b.x - a.x)
		bande.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ajouter(noeud, bande)
		# Galets le long des deux berges
		var dir := (b - a).normalized()
		var cote := dir.cross(Vector3.UP)
		var n := int(a.distance_to(b) / 0.5)
		for i in n:
			for s in [-1.0, 1.0]:
				var p: Vector3 = a.lerp(b, (i + _hasard.randf()) / n) + cote * s * (largeur * ECHELLE / 2.0 + _hasard.randf_range(-0.05, 0.12))
				var t := _hasard.randf_range(0.12, 0.28)
				deco("Galets", _sphere(), Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(t * 1.3, t * 0.55, t)), Vector3(p.x, 0.03, p.z)), materiaux["rocher"])


## Sillons ratissés en cercles autour d'un rocher du jardin zen (rayon du premier cercle en m).
func ratisser(x: float, y: float, rayon: float) -> void:
	var m := mat("#a8a59d")
	for k in 3:
		var r := rayon + k * 0.32
		var anneau := TorusMesh.new()
		anneau.inner_radius = r - 0.05
		anneau.outer_radius = r + 0.05
		anneau.rings = 48
		anneau.ring_segments = 6
		deco("Sillons%d_%d" % [int(x), k], anneau, Transform3D(Basis().scaled(Vector3(1, 0.4, 1)), P(x, y, 0.03)), m, false)


## Galets et pierres tout autour d'un bassin rectangulaire [x, y, w, d] (px).
func berge(x: float, y: float, w: float, d: float) -> void:
	_hasard.seed = int(x + y * 2)
	var coins := [P(x, y), P(x + w, y), P(x + w, y + d), P(x, y + d)]
	for k in 4:
		var a: Vector3 = coins[k]
		var b: Vector3 = coins[(k + 1) % 4]
		var n := int(a.distance_to(b) / 0.32)
		for i in n:
			var p := a.lerp(b, (i + _hasard.randf_range(0.2, 0.8)) / n)
			var t := _hasard.randf_range(0.18, 0.34)
			deco("Galets", _sphere(), Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(t * 1.4, t * 0.6, t)), Vector3(p.x, 0.04, p.z)), materiaux["rocher"])


## Nénuphars dans un rectangle [x, y, w, d] (px), posés à la hauteur h.
func nenuphars(x: float, y: float, w: float, d: float, nombre: int, h := 0.06) -> void:
	_hasard.seed = int(x + y)
	var feuille := CylinderMesh.new()
	feuille.top_radius = 0.22
	feuille.bottom_radius = 0.22
	feuille.height = 0.015
	feuille.radial_segments = 12
	var m := mat("#2f5a34", {"roughness": 0.4})
	var fleur := SphereMesh.new()
	fleur.radius = 0.07
	fleur.height = 0.08
	var mfleur := mat("#f0c6d0", {"emission_enabled": true, "emission": Color("#e8a0b0"), "emission_energy_multiplier": 0.35})
	for k in nombre:
		var p := P(x + _hasard.randf() * w, y + _hasard.randf() * d, h)
		var s := _hasard.randf_range(0.7, 1.3)
		deco("Nenuphars", feuille, Transform3D(Basis().scaled(Vector3(s, 1, s)), p), m, false)
		if _hasard.randf() < 0.35:
			deco("FleursLotus", fleur, Transform3D(Basis(), p + Vector3(0.05, 0.04, 0.03)), mfleur, false)


## Cascade qui tombe d'un amas de rochers dans l'eau : (x, y) en px est le pied de la chute,
## `regard` est l'angle (degrés) vers lequel l'eau coule (0 = vers le sud).
func cascade(nom: String, x: float, y: float, hauteur := 2.2, regard := 0.0) -> void:
	var noeud := Node3D.new()
	noeud.name = nom
	noeud.position = P(x, y)
	noeud.rotation_degrees.y = regard
	ajouter(racine, noeud)
	var chute := MeshInstance3D.new()
	chute.name = "Chute"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, hauteur)
	quad.material = _shader("cascade")
	chute.mesh = quad
	chute.position = Vector3(0, hauteur / 2.0, -0.35)
	chute.rotation_degrees.x = -8
	chute.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ajouter(noeud, chute)
	# Rochers autour et derrière la chute (en coordonnées locales, tournées avec la cascade)
	var rocs := [[-0.9, -0.6, 1.4, 4], [0.9, -0.6, 1.3, 5], [0.0, -1.2, 1.6, 0], [-1.5, 0.1, 0.9, 2],
		[1.4, 0.2, 0.8, 3], [-0.6, 0.5, 0.5, 7], [0.7, 0.6, 0.45, 6]]
	for r in rocs:
		var local := Vector3(r[0], 0, r[1]).rotated(Vector3.UP, deg_to_rad(regard))
		var p := noeud.position + local
		var px := p.x / ECHELLE + origine.x
		var py := p.z / ECHELLE + origine.y
		var s: float = r[2] * (1.0 if r[1] > -1.0 else hauteur / 1.6)
		rochers([[px, py, s, r[3]]])
	# Écume et embruns au pied de la chute
	var ecume := CPUParticles3D.new()
	ecume.name = "Embruns"
	ecume.amount = 24
	ecume.lifetime = 1.6
	ecume.mesh = _quad_lumineux(0.35, Color(0.75, 0.82, 0.95, 0.35))
	ecume.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ecume.emission_box_extents = Vector3(0.4, 0.05, 0.2)
	ecume.direction = Vector3(0, 1, 1)
	ecume.spread = 40.0
	ecume.initial_velocity_min = 0.4
	ecume.initial_velocity_max = 0.9
	ecume.gravity = Vector3(0, -0.3, 0)
	ecume.scale_amount_min = 0.6
	ecume.scale_amount_max = 1.6
	ecume.color_ramp = _rampe(Color(1, 1, 1, 0), Color(1, 1, 1, 0.5))
	ecume.position = Vector3(0, 0.1, 0)
	ajouter(noeud, ecume)


## Pont rouge : garde-corps laqués, poteaux à pommeaux noirs, sur le rectangle [x, y, w, d] (px).
func pont_rouge(x: float, y: float, w: float, d: float, h := 0.2) -> void:
	var c := P(x + w / 2.0, y + d / 2.0)
	var le_long_z := d > w
	var long := (d if le_long_z else w) * ECHELLE
	var large := (w if le_long_z else d) * ECHELLE
	var pommeau := SphereMesh.new()
	pommeau.radius = 0.08
	pommeau.height = 0.2
	for s in [-1.0, 1.0]:
		var cote := Vector3(s * large / 2.0, 0, 0) if le_long_z else Vector3(0, 0, s * large / 2.0)
		var rail := Vector3(0.08, 0.08, long) if le_long_z else Vector3(long, 0.08, 0.08)
		plaque("GardeCorps", c + cote + Vector3(0, h + 0.75, 0), rail, "laque_vive")
		plaque("GardeCorps", c + cote + Vector3(0, h + 0.4, 0), rail * Vector3(0.7, 0.6, 1) if le_long_z else rail * Vector3(1, 0.6, 0.7), "laque_vive")
		var n := int(long / 1.3) + 1
		for k in n:
			var t := (float(k) / (n - 1) - 0.5) * long
			var p := c + cote + (Vector3(0, 0, t) if le_long_z else Vector3(t, 0, 0))
			plaque("PoteauxPont", p + Vector3(0, (h + 0.85) / 2.0 - 0.3, 0), Vector3(0.13, h + 1.15, 0.13), "laque_vive")
			deco("Pommeaux", pommeau, Transform3D(Basis(), p + Vector3(0, h + 0.92, 0)), materiaux["noir"])


# --- Lumières et objets d'ambiance -----------------------------------------

## Lanternes du jeu : en pierre (tōrō) ou sur poteau, en alternance.
func lanternes(points: Array) -> void:
	var noeud := Node3D.new()
	noeud.name = "Lanternes"
	ajouter(racine, noeud)
	for k in points.size():
		var scene := "res://scenes/objets/lanterne.tscn" if k % 2 == 0 else "res://scenes/objets/lanterne_poteau.tscn"
		var lanterne := instance(scene, "Lanterne%d" % k, P(points[k][0], points[k][1]), noeud)
		if points[k].size() > 2:
			lanterne.set("rayon", points[k][2])


## Bannières nobori sur leur mât : [x, y, angle en degrés].
func bannieres(liste: Array) -> void:
	var tissu := PlaneMesh.new()
	tissu.size = Vector2(0.6, 1.8)
	tissu.subdivide_width = 6
	tissu.subdivide_depth = 10
	tissu.orientation = PlaneMesh.FACE_Z
	for i in liste.size():
		var b: Array = liste[i]
		var noeud := Node3D.new()
		noeud.name = "Banniere%d" % i
		noeud.position = P(b[0], b[1])
		noeud.rotation_degrees.y = b[2] if b.size() > 2 else 0.0
		ajouter(racine, noeud)
		var mat_tissu := _shader("banniere")
		mat_tissu.set_shader_parameter("phase", float(i) * 1.7)
		var drap := MeshInstance3D.new()
		drap.name = "Tissu"
		drap.mesh = tissu
		drap.material_override = mat_tissu
		drap.position = Vector3(0.34, 2.15, 0)
		ajouter(noeud, drap)
		plaque("Mats", noeud.position + Vector3(0, 1.6, 0), Vector3(0.07, 3.2, 0.07), "bois")
		var travers := Vector3(0.34, 3.08, 0).rotated(Vector3.UP, noeud.rotation.y)
		var de_face := absf(sin(noeud.rotation.y)) < 0.7
		plaque("Mats", noeud.position + travers, Vector3(0.7, 0.05, 0.05) if de_face else Vector3(0.05, 0.05, 0.7), "bois")
		plaque("SoclesMats", noeud.position + Vector3(0, 0.15, 0), Vector3(0.3, 0.3, 0.3), "pierre")


## Braseros (kagaribi) sur trépied, avec flamme vivante : [x, y]. À poser près d'une lanterne,
## pour que leur lumière corresponde à une zone éclairée du jeu.
func braseros(liste: Array) -> void:
	var pied := CylinderMesh.new()
	pied.top_radius = 0.025
	pied.bottom_radius = 0.025
	pied.height = 1.3
	var coupe := CylinderMesh.new()
	coupe.top_radius = 0.28
	coupe.bottom_radius = 0.16
	coupe.height = 0.22
	coupe.radial_segments = 10
	for i in liste.size():
		var p := P(liste[i][0], liste[i][1])
		for k in 3:
			var a := k * TAU / 3.0
			var base := Basis(Vector3(cos(a + PI / 2.0), 0, sin(a + PI / 2.0)), 0.22)
			deco("Trepieds", pied, Transform3D(base, p + Vector3(cos(a) * 0.14, 0.62, sin(a) * 0.14)), materiaux["noir"])
		deco("Coupes", coupe, Transform3D(Basis(), p + Vector3(0, 1.3, 0)), materiaux["noir"])
		var flamme := MeshInstance3D.new()
		flamme.name = "Brasero%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(0.55, 0.8)
		quad.material = _shader("flamme")
		flamme.mesh = quad
		flamme.position = p + Vector3(0, 1.75, 0)
		flamme.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ajouter(racine, flamme)
		var lueur := OmniLight3D.new()
		lueur.name = "Lueur"
		lueur.light_color = Color("#ff9a4a")
		lueur.light_energy = 1.2
		lueur.omni_range = 3.0
		lueur.set_script(load("res://scripts/scintillement.gd"))
		ajouter(flamme, lueur)
		var braises := CPUParticles3D.new()
		braises.name = "Braises"
		braises.amount = 10
		braises.lifetime = 1.4
		braises.mesh = _quad_lumineux(0.05, Color(1.0, 0.6, 0.2, 1.0))
		braises.direction = Vector3.UP
		braises.spread = 25.0
		braises.initial_velocity_min = 0.5
		braises.initial_velocity_max = 1.1
		braises.gravity = Vector3(0, 0.2, 0)
		braises.color_ramp = _rampe(Color(1, 0.7, 0.3, 0), Color(1, 0.6, 0.2, 1))
		ajouter(flamme, braises)


## Lucioles qui flottent et clignotent dans les rectangles [x, y, w, d] (px).
func lucioles(zones: Array) -> void:
	for i in zones.size():
		var z: Array = zones[i]
		var p := CPUParticles3D.new()
		p.name = "Lucioles%d" % i
		p.position = P(z[0] + z[2] / 2.0, z[1] + z[3] / 2.0, 1.0)
		p.amount = clampi(int(z[2] * z[3] / 2500.0), 6, 22)
		p.lifetime = 5.0
		p.preprocess = 5.0
		p.mesh = _quad_lumineux(0.16, Color(0.85, 1.0, 0.45, 1.0))
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(z[2] * ECHELLE / 2.0, 0.6, z[3] * ECHELLE / 2.0)
		p.direction = Vector3(0, 1, 0)
		p.spread = 180.0
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.05
		p.initial_velocity_max = 0.25
		p.angular_velocity_min = -30.0
		p.angular_velocity_max = 30.0
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.35, 0.5, 0.65, 0.85, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.15),
			Color(1, 1, 1, 1), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		p.color_ramp = g
		ajouter(racine, p)


## Nappes de brume au ras du sol : [x, y, w, d] (px).
func brume(zones: Array) -> void:
	var noeud := Node3D.new()
	noeud.name = "Brume"
	ajouter(racine, noeud)
	var m := _shader("brume")
	for i in zones.size():
		var z: Array = zones[i]
		var nappe := MeshInstance3D.new()
		nappe.name = "Nappe%d" % i
		var plan := PlaneMesh.new()
		plan.size = Vector2(z[2], z[3]) * ECHELLE
		nappe.mesh = plan
		nappe.material_override = m
		nappe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nappe.position = P(z[0] + z[2] / 2.0, z[1] + z[3] / 2.0, 0.35 + (i % 3) * 0.12)
		ajouter(noeud, nappe)


## Pieux d'une palissade : rangée de rondins pointus le long du rectangle [x, y, w, d] (px).
func pieux(x: float, y: float, w: float, d: float, h: float) -> void:
	var rondin := CylinderMesh.new()
	rondin.top_radius = 0.1
	rondin.bottom_radius = 0.11
	rondin.height = 1.0
	rondin.radial_segments = 7
	var pointe := CylinderMesh.new()
	pointe.top_radius = 0.0
	pointe.bottom_radius = 0.1
	pointe.height = 0.22
	pointe.radial_segments = 7
	var e := minf(w, d)
	var decal := (Vector3(0, 0, 1) if w >= d else Vector3(1, 0, 0)) * (e * ECHELLE / 2.0 - 0.07)
	var a := P(x + e / 2.0, y + e / 2.0)
	var b := P(x + w - e / 2.0, y + d - e / 2.0)
	var n := int(a.distance_to(b) / 0.21) + 1
	_hasard.seed = int(x * 3 + y)
	for face in [-1.0, 1.0]:
		for k in n:
			var p: Vector3 = a.lerp(b, float(k) / maxf(n - 1, 1)) + decal * face
			var hk := h + _hasard.randf_range(-0.08, 0.1)
			deco("Rondins", rondin, Transform3D(Basis().scaled(Vector3(1, hk, 1)), p + Vector3(0, hk / 2.0, 0)), materiaux["bois"])
			deco("Pointes", pointe, Transform3D(Basis(), p + Vector3(0, hk + 0.11, 0)), materiaux["bois"])


## Pousses de riz en rangées dans une rizière inondée [x, y, w, d] (px).
func riz(x: float, y: float, w: float, d: float) -> void:
	if not _meshes.has("pousse"):
		var brin := PrismMesh.new()
		brin.size = Vector3(0.05, 0.45, 0.02)
		_meshes["pousse"] = brin
		materiaux["pousse"] = mat("#5f7f3c", {"cull_mode": BaseMaterial3D.CULL_DISABLED})
	_hasard.seed = int(x + y)
	var pas := 0.55
	var nx := int(w * ECHELLE / pas)
	var nz := int(d * ECHELLE / pas)
	for i in nx:
		for j in nz:
			var c := P(x, y) + Vector3((i + 0.5) * pas, 0.0, (j + 0.5) * pas)
			for k in 5:
				var base := Basis(Vector3.UP, _hasard.randf() * TAU).rotated(Vector3.RIGHT, _hasard.randf_range(-0.3, 0.3))
				deco("Riz", _meshes["pousse"], Transform3D(base, c + Vector3(_hasard.randf_range(-0.06, 0.06), 0.24, _hasard.randf_range(-0.06, 0.06))), materiaux["pousse"], false)


func _quad_lumineux(taille: float, couleur: Color) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(taille, taille)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = couleur
	var halo := GradientTexture2D.new()
	halo.fill = GradientTexture2D.FILL_RADIAL
	halo.fill_from = Vector2(0.5, 0.5)
	halo.fill_to = Vector2(1.0, 0.5)
	halo.width = 32
	halo.height = 32
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	halo.gradient = g
	m.albedo_texture = halo
	q.material = m
	return q


func _rampe(debut: Color, milieu: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([debut, milieu, Color(milieu.r, milieu.g, milieu.b, 0.0)])
	return g
