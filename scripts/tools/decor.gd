extends "res://scripts/tools/constructeur.gd"
## Décor d'ambiance japonaise, partagé par les trois niveaux (ticket 4.4).
## Rochers Kenney (CC0, voir CREDITS.md) ; le reste est construit ici, avec des matières dessinées par shader :
## murs blancs à tuiles, buissons taillés, bambous, bannières, braseros, ruisseau, cascade,
## pont rouge, nénuphars, lucioles et brume.
## Tout ce décor est sans collision (sauf les gros rochers) : il ne change pas le jeu.
## Les petits objets répétés sont regroupés en MultiMesh pour rester léger dans le navigateur.

const SHADERS := "res://assets/shaders/"
const CARRE := 32.0  ## taille des carrés de décor (m) pour que la caméra ignore ceux hors de l'écran
## Petits détails du sol, dessinés seulement près de la caméra (m) : c'est là que l'essentiel des
## dizaines de milliers d'objets du décor se trouve.
const PETITS_DETAILS := ["Gazon", "Touffes", "Fleurs", "FeuillesBambou", "Galets", "Flaques", "PasJaponais", "Lucioles"]
const PORTEE_DETAILS := 55.0
## Petits objets qui ne projettent pas d'ombre de lune : on ne la verrait presque pas, et les ombres
## doublent le travail de dessin de tout ce qui en projette.
const ZONE_VERTE := 2780.0  ## au sud de cette ligne (px), la première zone garde ses arbres verts
const SANS_OMBRE := ["Galets", "PasJaponais", "Guirlande", "Sanctuaire", "Rochersstone_small", "Poutres", "Bambous", "Touffes"]

var _deco := {}  # nom -> {"mesh": Mesh, "transforms": Array, "ombre": bool, "materiau": Material}
var _hasard := RandomNumberGenerator.new()
var _meshes := {}
var _corps_rochers: StaticBody3D
var _occupe: Array[Rect2] = []  # sols, murs, bâtiments, eau : pas de gazon dessus
var _sol := Rect2()
var _sols_durs := []  # [Rect2 en px, hauteur du dessus] : allées, cours pavées, chemins de terre (flaques)


# --- Matériaux et ambiance -------------------------------------------------

func _materiaux() -> void:
	super._materiaux()
	materiaux["herbe"] = _matiere(0, "#558a42", "#33612c")
	materiaux["allee"] = _matiere(1, "#9a968c", "#827e76", "#4a5440")
	materiaux["pave"] = _matiere(2, "#8c8378", "#6a645c", "#47423b")
	materiaux["mur"] = _matiere(3, "#ddd4c2", "#ddd4c2")
	# toits du château en tuiles rouges (comme demandé), un peu plus sombres que celles du village
	materiaux["tuiles"] = _matiere(4, "#a23a2a", "#4a130d")
	materiaux["bois"] = _matiere(5, "#8c5c3b", "#5c3a25")
	materiaux["parquet"] = _matiere(5, "#b08254", "#7f5636")
	materiaux["pierre"] = _matiere(6, "#a19c92", "#78746c", "#3b3a37")
	materiaux["sable"] = _matiere(7, "#e0dccf", "#b7b2a5")
	materiaux["terre"] = _matiere(8, "#93765a", "#6f5741", "#4a3a2c")
	materiaux["rocher"] = _matiere(9, "#a3a39d", "#6d6d6a")
	materiaux["chaume"] = _matiere(10, "#c2a868", "#806c42")
	materiaux["tuiles_rouges"] = _matiere(4, "#9c3426", "#47120d")
	materiaux["bardeaux"] = _matiere(4, "#8a6646", "#43301f")  # toits de bois des cabanes du village
	materiaux["planches"] = _matiere(5, "#a87850", "#6e4a2e")
	materiaux["bois_sombre"] = _matiere(5, "#4a3020", "#2c1c13")
	materiaux["tatami"] = _matiere(11, "#b3aa6c", "#8e8652")
	# gravier blanc ratissé des cours du château (jardin sec), remparts en bois sombre sur pierre
	materiaux["gravier"] = _matiere(7, "#c4bfb2", "#97928a")
	materiaux["bois_rempart"] = _matiere(5, "#3b2c24", "#231912")
	var ishigaki := _matiere(6, "#9d978b", "#6f6a61", "#34322e")
	ishigaki.set_shader_parameter("echelle", 0.55)
	materiaux["ishigaki"] = ishigaki
	materiaux["laque"] = mat("#b8321e", {"roughness": 0.45})
	materiaux["rouge"] = mat("#c23b22", {"roughness": 0.5})
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


## Matière dessinée (voir assets/shaders/matiere.gdshader pour la liste des motifs).
func _matiere(motif: int, a: String, b: String, joint := "#1c1c20") -> ShaderMaterial:
	var m := _shader("matiere")
	m.set_shader_parameter("motif", motif)
	m.set_shader_parameter("couleur_a", Color(a))
	m.set_shader_parameter("couleur_b", Color(b))
	m.set_shader_parameter("couleur_joint", Color(joint))
	return m


func _shader(nom: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + nom + ".gdshader")
	return m


func _ambiance() -> void:
	super._ambiance()
	var env: Environment = (racine.get_node("Ambiance") as WorldEnvironment).environment
	# Nuit douce façon jeu cosy : ambiance bleu lavande assez claire pour bien lire les formes,
	# lune légèrement plus présente, ombres adoucies, et un halo chaud autour des lanternes.
	env.ambient_light_color = Color("#6272a8")
	env.ambient_light_energy = 0.55
	var lune_douce := racine.get_node("Lune") as DirectionalLight3D
	lune_douce.light_color = Color("#d4dcff")
	lune_douce.light_energy = 0.85
	lune_douce.shadow_blur = 1.6
	lune_douce.shadow_opacity = 0.72
	env.fog_light_color = Color("#34395a")
	env.fog_density = 0.011
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_saturation = 1.14
	env.adjustment_contrast = 1.04
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.05
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 0.6)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.6)
	env.set_glow_level(5, 0.3)
	# ciel de nuit dessiné : étoiles, lune et nuages (la brume ne le recouvre presque pas)
	var ciel := ShaderMaterial.new()
	ciel.shader = load(SHADERS + "ciel.gdshader")
	env.sky.sky_material = ciel
	env.fog_sky_affect = 0.2
	# ombres de la lune seulement près de la caméra : plus nettes et bien moins coûteuses
	var lune := racine.get_node("Lune") as DirectionalLight3D
	lune.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	lune.directional_shadow_max_distance = 26.0


# --- Petits objets regroupés ----------------------------------------------

func deco(nom: String, mesh: Mesh, t: Transform3D, materiau: Material = null, ombre := true) -> void:
	if not _deco.has(nom):
		_deco[nom] = {"mesh": mesh, "transforms": [], "ombre": ombre, "materiau": materiau}
	_deco[nom]["transforms"].append(t)


## Comme constructeur.boite(), mais on note la place prise pour ne pas y faire pousser le gazon.
func boite(nom: String, x: float, y: float, w: float, d: float, h: float, mat_nom: String,
		parent: Node = null, base := 0.0) -> CSGBox3D:
	if nom == "Sol":
		_sol = Rect2(x, y, w, d)
	elif base > -0.5 and mat_nom != "herbe":
		_occupe.append(Rect2(x, y, w, d).grow(8))
	if base > -0.5 and mat_nom in ["allee", "pave", "terre"]:
		_sols_durs.append([Rect2(x, y, w, d), base + h])
	if mat_nom == "allee":
		_bordure(Rect2(x, y, w, d), base + h)
	return super.boite(nom, x, y, w, d, h, mat_nom, parent, base)


## Bordure de pierres le long des deux grands côtés d'une allée.
func _bordure(r: Rect2, haut: float) -> void:
	var h := RandomNumberGenerator.new()
	h.seed = int(r.position.x * 13 + r.position.y)
	var long_x := r.size.x > r.size.y
	var longueur := (r.size.x if long_x else r.size.y) * ECHELLE
	var n := int(longueur / 0.36)
	for cote in [0.0, 1.0]:
		for i in n:
			var t := (i + 0.5) / n
			var px: float = r.position.x + (t * r.size.x if long_x else cote * r.size.x + (3.0 if cote == 0.0 else -3.0))
			var py: float = r.position.y + (cote * r.size.y + (3.0 if cote == 0.0 else -3.0) if long_x else t * r.size.y)
			var taille := Vector3(0.3, 0.07 + h.randf() * 0.04, 0.14) if long_x else Vector3(0.14, 0.07 + h.randf() * 0.04, 0.3)
			var base := Basis(Vector3.UP, h.randf_range(-0.08, 0.08)).scaled(taille)
			deco("Bordures", _boite_unite(), Transform3D(base, P(px, py, haut + taille.y * 0.3)), materiaux["pierre"])


func eau(nom: String, x: float, y: float, w: float, d: float, h: float) -> void:
	_occupe.append(Rect2(x, y, w, d).grow(10))
	super.eau(nom, x, y, w, d, h)


## Gazon court sur toute l'herbe libre du niveau (une touffe tous les ~0,8 m).
func _gazon() -> void:
	if _sol.size == Vector2.ZERO:
		return
	var touffe := _mesh_touffe()
	var m := _shader("gazon")
	_hasard.seed = 2024
	var pas := 30.0  # px (assez espacé pour que la pelouse reste nette)
	var x := _sol.position.x + pas / 2.0
	while x < _sol.end.x:
		var y := _sol.position.y + pas / 2.0
		while y < _sol.end.y:
			var px := x + _hasard.randf_range(-pas, pas) * 0.45
			var py := y + _hasard.randf_range(-pas, pas) * 0.45
			var libre := true
			for r in _occupe:
				if r.has_point(Vector2(px, py)):
					libre = false
					break
			if libre:
				var base := Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3.ONE * _hasard.randf_range(0.7, 1.3))
				deco("Gazon", touffe, Transform3D(base, P(px, py, 0.0)), m, false)
			y += pas
		x += pas


## Flaques de pluie sur les allées, cours et chemins : elles brillent et reflètent les lanternes.
func _flaques() -> void:
	var flaque := QuadMesh.new()
	flaque.orientation = PlaneMesh.FACE_Y
	flaque.size = Vector2.ONE
	var m := _shader("flaque")
	var h := RandomNumberGenerator.new()
	h.seed = 314
	for s in _sols_durs:
		var r: Rect2 = s[0]
		var aire := r.size.x * r.size.y * ECHELLE * ECHELLE
		for i in int(aire / 22.0) + 1:
			var px := h.randf_range(r.position.x + 15, r.end.x - 15)
			var py := h.randf_range(r.position.y + 15, r.end.y - 15)
			var taille := h.randf_range(0.8, 2.2)
			var base := Basis(Vector3.UP, h.randf() * TAU).scaled(Vector3(taille, 1, taille * h.randf_range(0.6, 1.0)))
			deco("Flaques", flaque, Transform3D(base, P(px, py, s[1] + 0.004)), m, false)


## Petits coins de jardin sur l'herbe libre : pierres moussues, buissons taillés,
## pas japonais et petits sanctuaires. Rien n'a de collision : le jeu ne change pas.
func _jardinage() -> void:
	if _sol.size == Vector2.ZERO:
		return
	var h := RandomNumberGenerator.new()
	h.seed = 4545
	var zone := _sol.grow(-70.0)
	var essais := int(_sol.size.x * _sol.size.y * ECHELLE * ECHELLE / 110.0)
	for i in essais:
		var x := h.randf_range(zone.position.x, zone.end.x)
		var y := h.randf_range(zone.position.y, zone.end.y)
		var libre := true
		for r in _occupe:
			if r.grow(35.0).has_point(Vector2(x, y)):
				libre = false
				break
		if not libre:
			continue
		var choix := h.randf()
		if choix < 0.35:
			rochers([[x, y, h.randf_range(0.45, 0.7), 6 + h.randi() % 3],
				[x + h.randf_range(10, 18), y + h.randf_range(-12, 12), h.randf_range(0.25, 0.4), 6 + h.randi() % 3],
				[x - h.randf_range(8, 14), y + h.randf_range(6, 14), h.randf_range(0.2, 0.35), 6 + h.randi() % 3]])
		elif choix < 0.62:
			var taille := h.randf_range(1.1, 1.7)  # m
			buissons([[x, y, taille]])
			_occupe.append(Rect2(x, y, 0, 0).grow(taille / ECHELLE * 0.6))
		elif choix < 0.75:
			var a := h.randf() * TAU
			var dir := Vector2(cos(a), sin(a))
			for k in 6:
				var q := Vector2(x, y) + dir * k * 18.0 + Vector2(-dir.y, dir.x) * sin(k * 1.3) * 6.0
				var s := h.randf_range(0.36, 0.5)
				var pierre := Basis(Vector3.UP, h.randf() * TAU).scaled(Vector3(s, 0.06, s * h.randf_range(0.75, 1.0)))
				deco("PasJaponais", _galet(), Transform3D(pierre, P(q.x, q.y, 0.02)), materiaux["pierre"])
				_occupe.append(Rect2(q, Vector2.ZERO).grow(10))
		# (plus de petits sanctuaires semés au hasard : ils encombraient l'herbe)


## Galet plat (cylindre à 10 côtés), rayon 0.5, hauteur 1.
func _galet() -> CylinderMesh:
	if not _meshes.has("galet"):
		var g := CylinderMesh.new()
		g.top_radius = 0.45
		g.bottom_radius = 0.5
		g.height = 1.0
		g.radial_segments = 10
		g.rings = 1
		_meshes["galet"] = g
	return _meshes["galet"]


## Petit sanctuaire (hokora) : socle en pierre, maisonnette en bois à façade claire,
## toit à deux pentes en tuiles, et un petit torii rouge devant. Sans collision.
func _sanctuaire(centre: Vector3, angle: float, e: float) -> void:
	var b := Basis(Vector3.UP, angle)
	var piece := func(nom: String, local: Vector3, taille: Vector3, materiau: String, incline := 0.0) -> void:
		var base := (b * Basis(Vector3(1, 0, 0), incline)).scaled(taille * e)
		deco(nom, _boite_unite(), Transform3D(base, centre + b * (local * e)), materiaux[materiau])
	piece.call("SanctuairePierre", Vector3(0, 0.12, 0), Vector3(1.0, 0.24, 0.8), "pierre")
	piece.call("SanctuairePierre", Vector3(0, 0.32, 0), Vector3(0.78, 0.16, 0.62), "pierre")
	piece.call("SanctuaireBois", Vector3(0, 0.62, 0), Vector3(0.56, 0.44, 0.46), "bois")
	piece.call("SanctuaireShoji", Vector3(0, 0.62, 0.235), Vector3(0.4, 0.32, 0.02), "shoji")
	piece.call("SanctuaireToit", Vector3(0, 0.95, 0.17), Vector3(0.78, 0.05, 0.42), "tuiles", 0.55)
	piece.call("SanctuaireToit", Vector3(0, 0.95, -0.17), Vector3(0.78, 0.05, 0.42), "tuiles", -0.55)
	piece.call("SanctuaireFaitage", Vector3(0, 1.05, 0), Vector3(0.82, 0.06, 0.07), "noir")


## Autels (points de reprise) : même rôle qu'avant, mais en forme de petit sanctuaire avec sa lanterne.
func autels(liste: Array) -> void:
	var autel_script := load("res://scripts/autel.gd")
	var halo: Material = load("res://assets/materiaux/halo.tres")
	for a in liste:
		var autel := Area3D.new()
		autel.set_script(autel_script)
		autel.name = a[0]
		autel.position = P(a[1], a[2])
		ajouter(racine, autel)
		var forme := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.6
		forme.shape = sphere
		ajouter(autel, forme)
		_sanctuaire(autel.position, 0.0, 1.15)
		_occupe.append(Rect2(a[1], a[2], 0, 0).grow(35))
		var flamme := OmniLight3D.new()
		flamme.name = "Flamme"
		flamme.light_color = Color("#ffb05a")
		flamme.light_energy = 1.4
		flamme.omni_range = 3.5
		flamme.position = Vector3(0, 0.75, 0.45)
		flamme.visible = a[0] == "Depart"
		ajouter(autel, flamme)
		var lueur := MeshInstance3D.new()
		lueur.name = "Lueur"
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		lueur.mesh = q
		lueur.material_override = halo
		lueur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ajouter(flamme, lueur)
		# cercle lumineux au sol et cristal flottant : on voit de loin que c'est une sauvegarde
		var cercle := MeshInstance3D.new()
		cercle.name = "Cercle"
		var plan := PlaneMesh.new()
		plan.size = Vector2(2.6, 2.6)
		cercle.mesh = plan
		var m_cercle := _shader("cercle_sauvegarde")
		m_cercle.set_shader_parameter("actif", 1.0 if a[0] == "Depart" else 0.0)
		cercle.material_override = m_cercle
		cercle.position.y = 0.04
		cercle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ajouter(autel, cercle)
		var cristal := MeshInstance3D.new()
		cristal.name = "Cristal"
		var prisme := SphereMesh.new()
		prisme.radius = 0.14
		prisme.height = 0.42
		prisme.radial_segments = 4
		prisme.rings = 2
		cristal.mesh = prisme
		cristal.material_override = mat("#9cc8ff" if a[0] != "Depart" else "#ffd27a", {"emission_enabled": true,
			"emission": Color("#5b8cff") if a[0] != "Depart" else Color("#ffb347"), "emission_energy_multiplier": 1.6})
		cristal.position.y = 1.75
		cristal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ajouter(autel, cristal)


## Grand toit japonais à quatre pans aux bords relevés, au-dessus d'un bâtiment [x, y, w, d] (px)
## dont les murs font h mètres. etages = 2 : un second toit plus petit par-dessus (donjon).
## Le toit s'efface quand le ninja entre (scripts/toit.gd), pour voir l'intérieur.
func toit_japonais(nom: String, x: float, y: float, w: float, d: float, h: float, etages := 1, matiere := "tuiles") -> void:
	var noeud := Node3D.new()
	noeud.name = nom
	noeud.set_script(load("res://scripts/toit.gd"))
	var c := P(x + w / 2.0, y + d / 2.0)
	noeud.set("emprise", Rect2(c.x - w * ECHELLE / 2.0, c.z - d * ECHELLE / 2.0, w * ECHELLE, d * ECHELLE))
	ajouter(racine, noeud)
	var lx := w * ECHELLE + 1.4
	var lz := d * ECHELLE + 1.4
	var bas := h + 0.4  # au-dessus des tuiles qui coiffent les murs
	if etages == 1:
		_pan_de_toit(noeud, c + Vector3(0, bas, 0), lx, lz, 1.0, matiere)
		return
	# donjon (tenshu) : trois étages blancs de plus en plus petits, fenêtres éclairées,
	# pignons triangulaires (chidori-hafu) sur la façade et toits de tuiles rouges
	var demi := Vector2(lx / 2.0, lz / 2.0)
	var niveau_y := bas
	var coupes := [0.42, 0.5]
	for etage in 2:
		var court := minf(demi.x, demi.y)
		var hauteur := minf(court * 0.6, 3.6)
		var coupe: float = coupes[etage]
		_pan_de_toit(noeud, c + Vector3(0, niveau_y, 0), demi.x * 2.0, demi.y * 2.0, coupe, matiere)
		# pignon sur la façade sud (côté caméra), posé sur la pente du toit
		var pente_z := demi.y - (court - 0.08) * coupe * 0.5
		_pignon(noeud, c + Vector3(0, niveau_y + hauteur * pow(coupe * 0.5, 1.7), pente_z), minf(demi.x * 0.5, 4.0), 1.3 - etage * 0.2, matiere)
		var rentre := (court - 0.08) * coupe
		demi = Vector2(demi.x - rentre - 0.35, demi.y - rentre - 0.35)
		# les étages du haut sont plus carrés et plus hauts : une vraie tour, pas une longue halle
		demi.x = minf(demi.x, demi.y * (1.7 if etage == 0 else 1.25))
		niveau_y += hauteur * pow(coupe, 1.7) - 0.15
		var h_corps := 2.6 - etage * 0.3
		_corps_tenshu(noeud, c + Vector3(0, niveau_y, 0), demi, h_corps)
		niveau_y += h_corps
		demi = Vector2(demi.x + 0.7, demi.y + 0.7)
	_pan_de_toit(noeud, c + Vector3(0, niveau_y, 0), demi.x * 2.0, demi.y * 2.0, 1.0, matiere)


## Étage du donjon : murs blancs, bandeau de bois sombre, rangée de fenêtres éclairées.
func _corps_tenshu(parent: Node3D, base: Vector3, demi: Vector2, h: float) -> void:
	var murs := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(demi.x * 2.0, h, demi.y * 2.0)
	murs.mesh = b
	murs.material_override = materiaux["mur"]
	murs.position = base + Vector3(0, h / 2.0, 0)
	ajouter(parent, murs)
	var bande := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(demi.x * 2.0 + 0.06, 0.16, demi.y * 2.0 + 0.06)
	bande.mesh = bb
	bande.material_override = materiaux["bois_sombre"]
	bande.position = base + Vector3(0, h * 0.25, 0)
	ajouter(parent, bande)
	# fenêtres éclairées sur les quatre faces
	var vitre := BoxMesh.new()
	vitre.size = Vector3(0.6, 0.55, 0.05)
	for face in 4:
		var le_long_x := face < 2
		var longueur := demi.x * 2.0 if le_long_x else demi.y * 2.0
		var n := maxi(int(longueur / 1.6), 1)
		var signe := 1.0 if face % 2 == 0 else -1.0
		for k in n:
			var t := ((k + 0.5) / n - 0.5) * longueur
			var f := MeshInstance3D.new()
			f.mesh = vitre
			f.material_override = materiaux["shoji"]
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if le_long_x:
				f.position = base + Vector3(t, h * 0.62, signe * (demi.y + 0.02))
			else:
				f.position = base + Vector3(signe * (demi.x + 0.02), h * 0.62, t)
				f.rotation.y = PI / 2.0
			ajouter(parent, f)


## Pignon triangulaire (chidori-hafu) : petit toit à deux pans tourné vers le sud, face blanche.
func _pignon(parent: Node3D, base: Vector3, largeur: float, hauteur: float, matiere: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var demi := largeur / 2.0
	var prof := 1.6
	var g := Vector3(-demi - 0.25, -0.1, prof * 0.5)
	var d := Vector3(demi + 0.25, -0.1, prof * 0.5)
	var h := Vector3(0, hauteur, prof * 0.5 + 0.1)
	var g2 := g - Vector3(0, -0.6, prof)
	var d2 := d - Vector3(0, -0.6, prof)
	var h2 := h - Vector3(0, 0, prof)
	var tri := [g, h, h2, g, h2, g2, h, d, d2, h, d2, h2]
	for v in tri:
		st.add_vertex(v)
	tri.reverse()  # les deux faces, pour ne pas dépendre du sens des triangles
	for v in tri:
		st.add_vertex(v)
	st.generate_normals()
	var toit := MeshInstance3D.new()
	toit.mesh = st.commit()
	toit.material_override = materiaux[matiere]
	toit.position = base
	ajouter(parent, toit)
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-demi, 0, 0), Vector3(demi, 0, 0), Vector3(0, hauteur - 0.18, 0)]:
		face.set_normal(Vector3.BACK)
		face.add_vertex(v)
	for v in [Vector3(-demi, 0, 0), Vector3(0, hauteur - 0.18, 0), Vector3(demi, 0, 0)]:
		face.set_normal(Vector3.BACK)
		face.add_vertex(v)
	var mur_face := MeshInstance3D.new()
	mur_face.mesh = face.commit()
	mur_face.material_override = materiaux["mur"]
	mur_face.position = base + Vector3(0, -0.05, prof * 0.45)
	ajouter(parent, mur_face)
	# petit ornement doré au sommet
	var orne := MeshInstance3D.new()
	var bo := BoxMesh.new()
	bo.size = Vector3(0.3, 0.12, 0.1)
	orne.mesh = bo
	orne.material_override = materiaux["or"]
	orne.position = base + Vector3(0, hauteur * 0.62, prof * 0.5 + 0.05)
	ajouter(parent, orne)


## Un toit à quatre pans en courbe (plus raide en haut, presque plat au bord, coins relevés),
## posé en `base`, de taille lx × lz au bord ; coupe < 1 : seulement le bas (toit tronqué).
func _pan_de_toit(parent: Node3D, base: Vector3, lx: float, lz: float, coupe: float, matiere := "tuiles") -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := lx / 2.0
	var hz := lz / 2.0
	var court := minf(hx, hz)
	var hauteur := minf(court * 0.6, 3.6)
	var n := 6
	var anneaux := []
	for k in n + 1:
		var s := float(k) / n * coupe
		var rentre := (court - 0.08) * s
		var y := hauteur * pow(s, 1.7)
		var anneau := [Vector3(-hx + rentre, y, -hz + rentre), Vector3(hx - rentre, y, -hz + rentre),
			Vector3(hx - rentre, y, hz - rentre), Vector3(-hx + rentre, y, hz - rentre)]
		if k == 0:
			# coins relevés au bord du toit
			for i in 4:
				var coin: Vector3 = anneau[i]
				anneau[i] = coin + Vector3(signf(coin.x) * 0.25, 0.32, signf(coin.z) * 0.25)
		anneaux.append(anneau)
	for k in n:
		var a: Array = anneaux[k]
		var b: Array = anneaux[k + 1]
		for i in 4:
			var j := (i + 1) % 4
			for v in [a[i], b[j], b[i], a[i], a[j], b[j]]:  # sens horaire vu du dessus : face visible
				st.add_vertex(base + v)
	var haut: Array = anneaux[n]
	for v in [haut[0], haut[2], haut[1], haut[0], haut[3], haut[2]]:
		st.add_vertex(base + v)
	st.generate_normals()
	var toit := MeshInstance3D.new()
	toit.mesh = st.commit()
	var m: ShaderMaterial = materiaux[matiere].duplicate()
	toit.material_override = m
	ajouter(parent, toit)
	if coupe < 1.0:
		return
	# faîtage noir et deux ornements dorés (shachihoko) au bout
	var y_haut: float = haut[0].y
	var long_x := hx >= hz
	var faite := MeshInstance3D.new()
	var bf := BoxMesh.new()
	var l := (hx - court + 0.08) * 2.0 + 0.3 if long_x else (hz - court + 0.08) * 2.0 + 0.3
	bf.size = Vector3(l, 0.22, 0.3) if long_x else Vector3(0.3, 0.22, l)
	faite.mesh = bf
	faite.material_override = materiaux["noir"]
	faite.position = base + Vector3(0, y_haut + 0.1, 0)
	ajouter(parent, faite)
	for sgn in [-1.0, 1.0]:
		var orne := MeshInstance3D.new()
		var bo := BoxMesh.new()
		bo.size = Vector3(0.18, 0.45, 0.14)
		orne.mesh = bo
		orne.material_override = materiaux["or"]
		orne.position = base + (Vector3(sgn * l / 2.0, y_haut + 0.4, 0) if long_x else Vector3(0, y_haut + 0.4, sgn * l / 2.0))
		orne.rotation.z = -sgn * 0.3 if long_x else 0.0
		orne.rotation.x = sgn * 0.3 if not long_x else 0.0
		ajouter(parent, orne)


## Habitants du village (scripts/habitant.gd) : une liste de dictionnaires
## {nom, x, y, regard (deg), allure, kimono, obi, cheveux, chapeau, chignon, barbe, baton, noeud,
##  journee: [[x, y, activite, duree, (regard deg)]...]}.
func habitants(liste: Array) -> void:
	var script := load("res://scripts/habitant.gd")
	for h: Dictionary in liste:
		var n := Node3D.new()
		n.name = h.get("noeud", "Habitant_" + String(h["nom"]).replace(" ", ""))
		n.set_script(script)
		n.position = P(h["x"], h["y"])
		n.rotation.y = deg_to_rad(h.get("regard", 0.0))
		ajouter(racine, n)
		n.set("nom_affiche", h["nom"])
		for cle in ["allure", "chapeau", "chignon", "barbe", "baton", "vitesse"]:
			if h.has(cle):
				n.set(cle, h[cle])
		for cle in ["kimono", "obi", "cheveux"]:
			if h.has(cle):
				n.set(cle, Color(h[cle]))
		var journee := []
		for e in h.get("journee", []):
			var etape := [P(e[0], e[1]), e[2], e[3]]
			if e.size() > 4:
				etape.append(e[4])
			journee.append(etape)
		n.set("journee", journee)


## Maison du village en bois : murs de planches, poteaux et poutres sombres, fenêtres de papier
## éclairées, porte, petite véranda (engawa) devant, et toit de tuiles rouges. Toit escaladable.
## `face` : côté de la porte (0 sud, 1 nord, 2 est, 3 ouest).
func maison_bois(nom: String, x: float, y: float, w: float, d: float, h := 1.9, face := 0, toit := "bardeaux") -> void:
	boite(nom, x, y, w, d, h, "planches")
	boite(nom + "Socle", x - 4, y - 4, w + 8, d + 8, 0.22, "pierre")
	toit_japonais(nom + "Toit", x, y, w, d, h - 0.4, 1, toit)
	var c := P(x + w / 2.0, y + d / 2.0)
	var lx := w * ECHELLE
	var lz := d * ECHELLE
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			plaque("Poteaux", c + Vector3(sx * lx / 2.0, h / 2.0, sz * lz / 2.0), Vector3(0.2, h, 0.2), "bois_sombre")
	plaque("Poutres", c + Vector3(0, h - 0.12, 0), Vector3(lx + 0.08, 0.18, lz + 0.08), "bois_sombre")
	plaque("Poutres", c + Vector3(0, 0.32, 0), Vector3(lx + 0.06, 0.12, lz + 0.06), "bois_sombre")
	# les quatre faces : fenêtres de papier, et la porte avec sa véranda sur la face choisie
	var faces := [[Vector3(0, 0, lz / 2.0 + 0.03), lx, true], [Vector3(0, 0, -lz / 2.0 - 0.03), lx, true],
		[Vector3(lx / 2.0 + 0.03, 0, 0), lz, false], [Vector3(-lx / 2.0 - 0.03, 0, 0), lz, false]]
	for k in 4:
		var f: Array = faces[k]
		var le_long_x: bool = f[2]
		var largeur: float = f[1]
		var n := maxi(int(largeur / 2.4), 1)
		for i in n:
			var t := ((i + 0.5) / n - 0.5) * largeur
			var pos: Vector3 = c + f[0] + (Vector3(t, h * 0.55, 0) if le_long_x else Vector3(0, h * 0.55, t))
			var porte := k == face and i == n / 2
			if porte:
				var taille_porte := Vector3(0.9, 1.35, 0.05) if le_long_x else Vector3(0.05, 1.35, 0.9)
				plaque("PortesMaison", pos + Vector3(0, -h * 0.55 + 0.68 + 0.2, 0), taille_porte, "shoji", false)
				plaque("Croisillons", pos + Vector3(0, -h * 0.55 + 0.9, 0), Vector3(0.05, 1.35, 0.07) if le_long_x else Vector3(0.07, 1.35, 0.05), "bois_sombre", false)
				continue
			var taille := Vector3(0.7, 0.5, 0.04) if le_long_x else Vector3(0.04, 0.5, 0.7)
			plaque("Shoji", pos, taille, "shoji", false)
			var montant := Vector3(0.04, 0.5, 0.06) if le_long_x else Vector3(0.06, 0.5, 0.04)
			var traverse := Vector3(0.7, 0.04, 0.06) if le_long_x else Vector3(0.06, 0.04, 0.7)
			for m in [-0.17, 0.17]:
				plaque("Croisillons", pos + (Vector3(m, 0, 0) if le_long_x else Vector3(0, 0, m)), montant, "bois_sombre", false)
			plaque("Croisillons", pos, traverse, "bois_sombre", false)
		if k == face:
			# véranda en planches et marche de pierre devant la porte
			var dehors: Vector3 = (f[0] as Vector3).normalized()
			var veranda := Vector3(largeur * 0.8, 0.12, 0.9) if le_long_x else Vector3(0.9, 0.12, largeur * 0.8)
			plaque("Verandas", c + f[0] + dehors * 0.45 + Vector3(0, 0.3, 0), veranda, "parquet")
			plaque("Marches", c + f[0] + dehors * 1.15 + Vector3(0, 0.1, 0), Vector3(0.9, 0.2, 0.5) if le_long_x else Vector3(0.5, 0.2, 0.9), "pierre")


## Chemin de terre qui serpente par les points donnés (px) : un ruban posé sur l'herbe, avec des cailloux et un bord irrégulier où l'herbe mord (assets/shaders/chemin.gdshader).
func chemin_terre(nom: String, points: Array, largeur: float) -> void:
	var pts: Array[Vector3] = []
	for p in points:
		pts.append(P(p[0], p[1], 0.022))
	var courbe: Array[Vector3] = []
	for i in pts.size() - 1:
		var a := pts[maxi(i - 1, 0)]
		var d := pts[mini(i + 2, pts.size() - 1)]
		var n := maxi(int(pts[i].distance_to(pts[i + 1]) / 0.6), 2)
		for k in n:
			courbe.append(pts[i].cubic_interpolate(pts[i + 1], a, d, float(k) / n))
	courbe.append(pts[pts.size() - 1])
	var demi := largeur * ECHELLE / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := 0.0
	var bords := []
	for k in courbe.size():
		var dir := (courbe[mini(k + 1, courbe.size() - 1)] - courbe[maxi(k - 1, 0)]).normalized()
		var cote := dir.cross(Vector3.UP).normalized()
		if k > 0:
			v += courbe[k].distance_to(courbe[k - 1])
		bords.append([courbe[k] - cote * demi * 1.25, courbe[k] + cote * demi * 1.25, v])
		var r := Rect2(courbe[k].x / ECHELLE + origine.x, courbe[k].z / ECHELLE + origine.y, 0, 0).grow(largeur * 0.55)
		_occupe.append(r)
	for k in bords.size() - 1:
		var a: Array = bords[k]
		var b: Array = bords[k + 1]
		var quad := [[a[0], Vector2(0, a[2])], [b[0], Vector2(0, b[2])], [b[1], Vector2(1, b[2])],
			[a[0], Vector2(0, a[2])], [b[1], Vector2(1, b[2])], [a[1], Vector2(1, a[2])]]
		for q in quad:
			st.set_normal(Vector3.UP)
			st.set_uv(q[1])
			st.add_vertex(q[0])
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = st.commit()
	mi.material_override = _shader("chemin")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ajouter(racine, mi)
	# touffes d'herbe et petites pierres le long des bords
	_hasard.seed = int(largeur * 7)
	for k in range(0, courbe.size(), 2):
		var dir := (courbe[mini(k + 1, courbe.size() - 1)] - courbe[maxi(k - 1, 0)]).normalized()
		var cote := dir.cross(Vector3.UP).normalized()
		for s in [-1.0, 1.0]:
			if _hasard.randf() < 0.55:
				touffes(courbe[k] + cote * s * demi * _hasard.randf_range(0.95, 1.2), 0.15, 1)
			if _hasard.randf() < 0.18:
				var t := _hasard.randf_range(0.08, 0.2)
				var p: Vector3 = courbe[k] + cote * s * demi * _hasard.randf_range(0.85, 1.15)
				deco("Galets", _sphere(), Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(t * 1.3, t * 0.5, t)), Vector3(p.x, 0.02, p.z)), materiaux["rocher"])


## Chats qui dorment ou se lèchent la patte : [x, y, regard (deg)]. Ils miaulent quand on passe.
func chats(liste: Array) -> void:
	var script := load("res://scripts/chat.gd")
	for i in liste.size():
		var c := Node3D.new()
		c.name = "Chat%d" % i
		c.set_script(script)
		c.position = P(liste[i][0], liste[i][1])
		c.rotation.y = deg_to_rad(liste[i][2])
		c.set("pelage", i % 3)
		ajouter(racine, c)


## Gros buissons où l'on peut se cacher même debout : [x, y, diamètre en m].
func cachettes(liste: Array) -> void:
	var script := load("res://scripts/buisson.gd")
	for i in liste.size():
		var b: Array = liste[i]
		var z := Area3D.new()
		z.set_script(script)
		z.name = "Cachette%d" % i
		z.position = P(b[0], b[1])
		z.set("diametre", b[2])
		ajouter(racine, z)
		_occupe.append(Rect2(b[0], b[1], 0, 0).grow(b[2] / ECHELLE * 0.5))


## Torii rouge au-dessus d'un chemin : centre (x, y) en px, largeur en m.
func torii(x: float, y: float, largeur := 4.0, h := 3.6, angle := 0.0) -> void:
	var c := P(x, y)
	var tourne := Basis(Vector3.UP, deg_to_rad(angle))
	var morceau := func(nom: String, local: Vector3, taille: Vector3, materiau: String) -> void:
		deco(nom, _boite_unite(), Transform3D(tourne * Basis().scaled(taille), c + tourne * local), materiaux[materiau])
	if not racine.has_node("Torii"):
		var corps := StaticBody3D.new()
		corps.name = "Torii"
		ajouter(racine, corps)
	for s in [-1.0, 1.0]:
		morceau.call("ToriiPiliers", Vector3(s * largeur / 2.0, h / 2.0, 0), Vector3(0.28, h, 0.28), "laque_vive")
		morceau.call("ToriiSocles", Vector3(s * largeur / 2.0, 0.15, 0), Vector3(0.4, 0.3, 0.4), "noir")
		# les piliers arrêtent le ninja
		var forme := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.2
		cyl.height = h
		forme.shape = cyl
		forme.position = c + tourne * Vector3(s * largeur / 2.0, h / 2.0, 0)
		ajouter(racine.get_node("Torii"), forme)
	morceau.call("ToriiNuki", Vector3(0, h - 0.7, 0), Vector3(largeur + 0.6, 0.2, 0.18), "laque_vive")
	morceau.call("ToriiKasagi", Vector3(0, h + 0.05, 0), Vector3(largeur + 1.4, 0.26, 0.34), "noir")
	morceau.call("ToriiShimaki", Vector3(0, h - 0.18, 0), Vector3(largeur + 1.0, 0.22, 0.26), "laque_vive")
	morceau.call("ToriiGakuzuka", Vector3(0, h - 0.4, 0), Vector3(0.18, 0.4, 0.16), "laque_vive")


## Allée de torii (senbon torii) le long d'un chemin [[x, y]...] (px) : un portail tous les `pas` px,
## chacun tourné face au chemin.
func allee_torii(chemin: Array, pas: float, largeur := 3.2, h := 3.3) -> void:
	var reste := 0.0
	for k in chemin.size() - 1:
		var a := Vector2(chemin[k][0], chemin[k][1])
		var b := Vector2(chemin[k + 1][0], chemin[k + 1][1])
		var l := a.distance_to(b)
		var t := reste
		while t <= l:
			var p := a.lerp(b, t / l)
			var dir := (b - a) / l
			torii(p.x, p.y, largeur, h, rad_to_deg(atan2(dir.x, dir.y)))
			t += pas
		reste = t - l


## Grande porte du château : deux vantaux qui s'ouvrent avec E, entre x et x + w (px), à la ligne y.
func grande_porte(x: float, y: float, w: float, h := 4.2, nom := "GrandePorte", texte := "Ouvrir la grande porte") -> void:
	var porte := Node3D.new()
	porte.set_script(load("res://scripts/porte.gd"))
	porte.name = nom
	porte.set("texte", texte)
	porte.position = P(x + w / 2.0, y)
	porte.set("genre", 0)
	porte.set("largeur", w * ECHELLE)
	porte.set("hauteur", h)
	ajouter(racine, porte)


## Herse levée au-dessus d'une ouverture (x à x + w, ligne y) ; elle tombe quand le combat commence.
func herse(nom: String, x: float, y: float, w: float, h: float) -> void:
	var porte := Node3D.new()
	porte.set_script(load("res://scripts/porte.gd"))
	porte.name = nom
	porte.position = P(x + w / 2.0, y)
	porte.set("genre", 1)
	porte.set("largeur", w * ECHELLE)
	porte.set("hauteur", h)
	porte.set("epaisseur", 0.2)
	ajouter(racine, porte)


## Le seigneur Oni (scripts/boss.gd), qui attend au fond du donjon, et le coffre caché au centre.
func seigneur(x: float, y: float, coffre_x: float, coffre_y: float) -> void:
	var boss := CharacterBody3D.new()
	boss.set_script(load("res://scripts/boss.gd"))
	boss.name = "Seigneur"
	boss.position = P(x, y)
	ajouter(racine, boss)
	var coffre := Node3D.new()
	coffre.set_script(load("res://scripts/coffre.gd"))
	coffre.name = "Coffre"
	coffre.position = P(coffre_x, coffre_y)
	ajouter(racine, coffre)


## Zone qui déclenche un événement quand le ninja y entre (scripts/declencheur.gd) : rectangle en px.
func declencheur(nom: String, x: float, y: float, w: float, d: float) -> void:
	var z := Area3D.new()
	z.set_script(load("res://scripts/declencheur.gd"))
	z.name = nom
	z.position = P(x + w / 2.0, y + d / 2.0, 1.0)
	ajouter(racine, z)
	var forme := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(w * ECHELLE, 2.0, d * ECHELLE)
	forme.shape = b
	ajouter(z, forme)


## Guirlandes de lanternes en papier (chōchin) rouges, peintes du kanji 福 (bonheur), avec bagues
## dorées et pompon rouge, tendues entre deux poteaux : [x1, y1, x2, y2] en px.
## Purement décoratives : pas de collision, pas de vraie lumière (elles brillent par elles-mêmes).
func guirlandes(liste: Array) -> void:
	var poteau := CylinderMesh.new()
	poteau.top_radius = 0.06
	poteau.bottom_radius = 0.08
	poteau.height = 1.0
	poteau.radial_segments = 6
	poteau.rings = 1
	var corde := CylinderMesh.new()
	corde.top_radius = 0.012
	corde.bottom_radius = 0.012
	corde.height = 1.0
	corde.radial_segments = 4
	corde.rings = 1
	var bague := CylinderMesh.new()
	bague.top_radius = 0.5
	bague.bottom_radius = 0.5
	bague.height = 1.0
	bague.radial_segments = 10
	bague.rings = 1
	var pompon := CylinderMesh.new()
	pompon.top_radius = 0.012
	pompon.bottom_radius = 0.045
	pompon.height = 1.0
	pompon.radial_segments = 6
	pompon.rings = 1
	var papier := StandardMaterial3D.new()
	var texture: Texture2D = load("res://assets/textures/chochin.png")
	papier.albedo_texture = texture
	papier.emission_enabled = true
	papier.emission_texture = texture
	papier.emission_energy_multiplier = 1.5
	papier.roughness = 0.8
	var dore := mat("#c9a24a", {"metallic": 0.6, "roughness": 0.4})
	var rouge := mat("#b3201a", {"emission_enabled": true, "emission": Color("#7a1008"), "emission_energy_multiplier": 0.6})
	var noir: Material = materiaux["noir"]
	var lanterne := _mesh_chochin()
	var h := 3.3
	for g in liste:
		var a := P(g[0], g[1])
		var b := P(g[2], g[3])
		for bout in [a, b]:
			deco("GuirlandePoteaux", poteau, Transform3D(Basis().scaled(Vector3(1, h, 1)), bout + Vector3(0, h / 2.0, 0)), materiaux["bois"])
			deco("GuirlandeChapeaux", _boite_unite(), Transform3D(Basis().scaled(Vector3(0.22, 0.06, 0.22)), bout + Vector3(0, h + 0.03, 0)), noir)
		var longueur := a.distance_to(b)
		var n := maxi(int(longueur / 0.62), 3)
		var fleche := 0.12 * longueur + 0.2  # la corde pend au milieu
		var precedent := a + Vector3(0, h - 0.1, 0)
		for k in range(1, n + 1):
			var t := float(k) / n
			var p := a.lerp(b, t) + Vector3(0, h - 0.1 - fleche * 4.0 * t * (1.0 - t), 0)
			# un bout de corde entre deux points de la chaînette
			var milieu := (precedent + p) * 0.5
			var dir := (p - precedent)
			var base := Basis.looking_at(dir.normalized(), Vector3.UP) * Basis(Vector3(1, 0, 0), PI / 2.0)
			deco("GuirlandeCordes", corde, Transform3D(base.scaled(Vector3(1, dir.length(), 1)), milieu), noir, false)
			precedent = p
			if k >= n:
				continue
			# une lanterne sur deux pend plus bas, comme sur les vraies guirlandes
			var attache := 0.1 if k % 2 == 0 else 0.32
			deco("GuirlandeCordes", corde, Transform3D(Basis().scaled(Vector3(1, attache, 1)), p + Vector3(0, -attache / 2.0, 0)), noir, false)
			var haut := p + Vector3(0, -attache, 0)
			var tourne := Basis(Vector3.UP, _hasard.randf_range(-0.6, 0.6))
			var corps := haut + Vector3(0, -0.04 - 0.21, 0)
			deco("GuirlandeLanternes", lanterne, Transform3D(tourne, corps), papier, false)
			for dy in [0.215, -0.215]:
				deco("GuirlandeBagues", bague, Transform3D(Basis().scaled(Vector3(0.2, 0.035, 0.2)), corps + Vector3(0, dy, 0)), dore, false)
			deco("GuirlandeBagues", bague, Transform3D(Basis().scaled(Vector3(0.08, 0.04, 0.08)), corps + Vector3(0, -0.255, 0)), dore, false)
			deco("GuirlandePompons", pompon, Transform3D(Basis().scaled(Vector3(1, 0.3, 1)), corps + Vector3(0, -0.43, 0)), rouge, false)


## Lanterne chōchin en tonneau (0,42 m de haut), UV tout autour pour le papier peint de 福.
func _mesh_chochin() -> ArrayMesh:
	if _meshes.has("chochin"):
		return _meshes["chochin"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cotes := 14
	var etages := 8
	var hauteur := 0.42
	var points := []
	for j in etages + 1:
		var v := float(j) / etages
		var y := (0.5 - v) * hauteur
		var r := 0.1 + 0.055 * sin(v * PI)
		var ligne := []
		for i in cotes + 1:
			var a := float(i) / cotes * TAU
			ligne.append([Vector3(cos(a) * r, y, sin(a) * r), Vector2(float(i) / cotes, v)])
		points.append(ligne)
	for j in etages:
		for i in cotes:
			var quad := [points[j][i], points[j + 1][i], points[j + 1][i + 1], points[j][i], points[j + 1][i + 1], points[j][i + 1]]
			for q in quad:
				st.set_uv(q[1])
				st.add_vertex(q[0])
	st.generate_normals()
	var m := st.commit()
	_meshes["chochin"] = m
	return m


## Autour du niveau : sol de forêt, ceinture de cèdres, pins et bambous, montagnes au loin.
## Rien n'y est atteignable (les limites du niveau restent les mêmes) : ça cache juste le vide.
func _alentours() -> void:
	if _sol.size == Vector2.ZERO:
		return
	var noeud := Node3D.new()
	noeud.name = "Alentours"
	ajouter(racine, noeud)
	var marge := 75.0 / ECHELLE  # px
	var dehors := _sol.grow(marge)
	var sol_foret := _matiere(0, "#2f4a2b", "#1d331d")
	# quatre bandes autour du sol du niveau (pas dessous : les douves sont creusées dedans)
	for r in [Rect2(dehors.position, Vector2(dehors.size.x, marge)),
			Rect2(dehors.position.x, _sol.end.y, dehors.size.x, marge),
			Rect2(dehors.position.x, _sol.position.y, marge, _sol.size.y),
			Rect2(_sol.end.x, _sol.position.y, marge, _sol.size.y)]:
		var bande := MeshInstance3D.new()
		var plan := PlaneMesh.new()
		plan.size = r.size * ECHELLE
		bande.mesh = plan
		bande.material_override = sol_foret
		bande.position = P(r.get_center().x, r.get_center().y, -0.01)
		ajouter(noeud, bande)

	var tronc := CylinderMesh.new()
	tronc.top_radius = 0.1
	tronc.bottom_radius = 0.18
	tronc.height = 1.0
	tronc.radial_segments = 6
	tronc.rings = 1
	var cedre := _mesh_cedre()
	var pin := _mesh_pin_rond()
	var feuillages := []
	for c in [["#2c4a33", "#0a1912"], ["#34523a", "#0d1d14"], ["#3e5a35", "#11200f"]]:
		var f: ShaderMaterial = _shader("feuillage")
		f.set_shader_parameter("couleur_claire", Color(c[0]))
		f.set_shader_parameter("couleur_sombre", Color(c[1]))
		f.set_shader_parameter("touffes", 5.0)
		feuillages.append(f)
	# au nord du ruisseau (château), la forêt est en fleurs : cerisiers roses et glycines mauves
	var fleuris := []
	for c in [["#f2b8cc", "#a8506f"], ["#c39ae6", "#5e3a8c"]]:
		var f: ShaderMaterial = _shader("feuillage")
		f.set_shader_parameter("couleur_claire", Color(c[0]))
		f.set_shader_parameter("couleur_sombre", Color(c[1]))
		f.set_shader_parameter("touffes", 7.0)
		fleuris.append(f)
	_hasard.seed = 909
	var pas := 3.8 / ECHELLE
	var largeur := 22.0 / ECHELLE
	var foret := _sol.grow(largeur)
	var x := foret.position.x
	while x < foret.end.x:
		var y := foret.position.y
		while y < foret.end.y:
			var px := x + _hasard.randf_range(-0.45, 0.45) * pas
			var py := y + _hasard.randf_range(-0.45, 0.45) * pas
			if not _sol.grow(8.0).has_point(Vector2(px, py)):
				var h := _hasard.randf_range(5.0, 9.5)
				var pos := P(px, py)
				var tourne := Basis(Vector3.UP, _hasard.randf() * TAU)
				var k := _hasard.randi() % 3
				if py > _sol.end.y and (py - _sol.end.y) * ECHELLE < 16.0:
					# côté caméra : rien de haut, sinon les arbres cacheraient le ninja
					if _hasard.randf() < 0.55:
						var s := _hasard.randf_range(0.8, 1.7)
						deco("ForetBuissons", _sphere(), Transform3D(tourne.scaled(Vector3(s * 1.3, s * 0.8, s * 1.3)), pos + Vector3(0, s * 0.25, 0)), feuillages[k], false)
				elif _hasard.randf() < 0.12:
					bambous(px - 40, py - 40, 80, 80, 7)
				elif py < ZONE_VERTE and _hasard.randf() < 0.6:
					var s := h * _hasard.randf_range(0.5, 0.65)
					var j := _hasard.randi() % 2
					deco("ForetFleuris%d" % j, pin, Transform3D(tourne.scaled(Vector3(s, s * 0.8, s)), pos + Vector3(0, h * 0.42, 0)), fleuris[j], false)
					deco("ForetTroncs", tronc, Transform3D(Basis().scaled(Vector3(0.8, h * 0.5, 0.8)), pos + Vector3(0, h * 0.25, 0)), materiaux["bois"], false)
				elif _hasard.randf() < 0.45:
					var l := h * _hasard.randf_range(0.28, 0.36)
					deco("ForetCedres%d" % k, cedre, Transform3D(tourne.scaled(Vector3(l, h, l)), pos + Vector3(0, h * 0.18, 0)), feuillages[k], false)
					deco("ForetTroncs", tronc, Transform3D(Basis().scaled(Vector3(1, h * 0.3, 1)), pos + Vector3(0, h * 0.15, 0)), materiaux["bois"], false)
				else:
					var s := h * _hasard.randf_range(0.5, 0.65)
					deco("ForetPins%d" % k, pin, Transform3D(tourne.scaled(Vector3(s, s * 0.8, s)), pos + Vector3(0, h * 0.42, 0)), feuillages[k], false)
					deco("ForetTroncs", tronc, Transform3D(Basis().scaled(Vector3(0.8, h * 0.5, 0.8)), pos + Vector3(0, h * 0.25, 0)), materiaux["bois"], false)
			y += pas
		x += pas

	# montagnes bleutées au loin, que la brume estompe
	var mont := _mesh_montagne()
	var m_mont := _shader("montagne")
	var centre := _sol.get_center()
	var rayon := maxf(_sol.size.x, _sol.size.y) * 0.5 + 90.0 / ECHELLE
	for i in 14:
		var a := i * TAU / 14.0 + _hasard.randf_range(-0.15, 0.15)
		var dist := rayon * _hasard.randf_range(1.0, 1.35)
		var hm := _hasard.randf_range(28.0, 55.0)
		var base := Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(hm * 1.6, hm, hm * 1.6))
		deco("Montagnes", mont, Transform3D(base, P(centre.x + cos(a) * dist, centre.y + sin(a) * dist, -2.0)), m_mont, false)


## Cèdre (sugi) : étages de cônes de plus en plus petits, hauteur 1 (de -0.18 à 0.82).
func _mesh_cedre() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for e in 4:
		var bas := -0.1 + e * 0.2
		var r := 1.0 - e * 0.2
		_cone(st, Vector3(0, bas, 0), r * 0.55, 0.38, 8)
	st.generate_normals()
	return st.commit()


## Pin rond : trois boules de feuillage serrées.
func _mesh_pin_rond() -> ArrayMesh:
	var st := SurfaceTool.new()
	for b in [[Vector3(0, 0, 0), 0.5], [Vector3(0.32, -0.12, 0.1), 0.34], [Vector3(-0.28, -0.08, -0.15), 0.36]]:
		var boule := SphereMesh.new()
		boule.radius = b[1]
		boule.height = b[1] * 1.6
		boule.radial_segments = 8
		boule.rings = 4
		st.append_from(boule, 0, Transform3D(Basis(), b[0]))
	return st.commit()


## Montagne : cône irrégulier à 12 côtés, hauteur 1, rayon 1.
func _mesh_montagne() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := RandomNumberGenerator.new()
	h.seed = 5
	var n := 12
	var bords := []
	for i in n:
		var a := i * TAU / n
		bords.append(Vector3(cos(a), 0, sin(a)) * h.randf_range(0.7, 1.1))
	var sommet := Vector3(h.randf_range(-0.1, 0.1), 1.0, h.randf_range(-0.1, 0.1))
	for i in n:
		var a: Vector3 = bords[i]
		var b: Vector3 = bords[(i + 1) % n]
		var milieu := (a + b) * 0.5 * 0.55 + Vector3(0, h.randf_range(0.35, 0.55), 0)
		for v in [a, milieu, b, milieu, sommet, b, a, sommet, milieu]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _cone(st: SurfaceTool, base: Vector3, rayon: float, hauteur: float, cotes: int) -> void:
	var pointe := base + Vector3(0, hauteur, 0)
	for i in cotes:
		var a := i * TAU / cotes
		var b := (i + 1) * TAU / cotes
		var pa := base + Vector3(cos(a), 0, sin(a)) * rayon
		var pb := base + Vector3(cos(b), 0, sin(b)) * rayon
		st.add_vertex(pa)
		st.add_vertex(pointe)
		st.add_vertex(pb)
		st.add_vertex(pb)
		st.add_vertex(base)
		st.add_vertex(pa)


## Fleurs des champs en taches sur l'herbe libre : blanches, bleues (kikyō), jaunes et roses.
func _fleurs_sauvages() -> void:
	if _sol.size == Vector2.ZERO:
		return
	var taches := FastNoiseLite.new()
	taches.seed = 7
	taches.frequency = 0.006
	var teintes := FastNoiseLite.new()
	teintes.seed = 31
	teintes.frequency = 0.003
	var couleurs := [Color("#f4f0e4"), Color("#7a74e0"), Color("#f2c84b"), Color("#f39ac2")]
	var meshes := []
	for c in couleurs:
		meshes.append(_mesh_fleurs(c))
	var m := mat("#ffffff", {"vertex_color_use_as_albedo": true, "cull_mode": BaseMaterial3D.CULL_DISABLED,
		"emission_enabled": true, "emission": Color("#3a3446"), "emission_energy_multiplier": 0.5})
	_hasard.seed = 77
	var pas := 24.0  # px
	var x := _sol.position.x + pas / 2.0
	while x < _sol.end.x:
		var y := _sol.position.y + pas / 2.0
		while y < _sol.end.y:
			var px := x + _hasard.randf_range(-pas, pas) * 0.5
			var py := y + _hasard.randf_range(-pas, pas) * 0.5
			# seulement en taches bien groupées : un pré net, pas des points partout
			if taches.get_noise_2d(px, py) > 0.32:
				var libre := true
				for r in _occupe:
					if r.has_point(Vector2(px, py)):
						libre = false
						break
				if libre:
					var k := clampi(int((teintes.get_noise_2d(px, py) + 0.6) * 3.3), 0, 3)
					var base := Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3.ONE * _hasard.randf_range(0.8, 1.25))
					deco("Fleurs%d" % k, meshes[k], Transform3D(base, P(px, py, 0.0)), m, false)
			y += pas
		x += pas


## Bouquet de 5 petites fleurs : tiges fines et corolles plates en étoile, cœur jaune.
func _mesh_fleurs(couleur: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := RandomNumberGenerator.new()
	h.seed = int(couleur.r * 1000)
	var vert := Color("#3d5e31")
	for f in 5:
		var pied := Vector3(h.randf_range(-0.12, 0.12), 0, h.randf_range(-0.12, 0.12))
		var haut := pied + Vector3(h.randf_range(-0.04, 0.04), h.randf_range(0.14, 0.26), h.randf_range(-0.04, 0.04))
		# tige : deux plans croisés
		st.set_color(vert)
		for e in [Vector3(0.006, 0, 0), Vector3(0, 0, 0.006)]:
			for p in [pied - e, haut - e, haut + e, pied - e, haut + e, pied + e]:
				st.add_vertex(p)
		# corolle : 5 pétales autour du cœur
		var r := h.randf_range(0.045, 0.065)
		var teinte := couleur.lightened(h.randf_range(-0.1, 0.15))
		var tour := h.randf() * TAU
		for k in 5:
			var a := tour + k * TAU / 5.0
			var b := a + TAU / 10.0
			var c := a - TAU / 10.0
			st.set_color(teinte)
			st.add_vertex(haut + Vector3(0, 0.004, 0))
			st.add_vertex(haut + Vector3(cos(c), 0.25, sin(c)) * r * 0.75)
			st.add_vertex(haut + Vector3(cos(a), 0.15, sin(a)) * r)
			st.add_vertex(haut + Vector3(0, 0.004, 0))
			st.add_vertex(haut + Vector3(cos(a), 0.15, sin(a)) * r)
			st.add_vertex(haut + Vector3(cos(b), 0.25, sin(b)) * r * 0.75)
		st.set_color(Color("#f0b533"))
		for k in 3:
			var a := k * TAU / 3.0
			st.add_vertex(haut + Vector3(0, 0.012, 0))
			st.add_vertex(haut + Vector3(cos(a), 0.6, sin(a)) * 0.014)
			st.add_vertex(haut + Vector3(cos(a + TAU / 3.0), 0.6, sin(a + TAU / 3.0)) * 0.014)
	st.generate_normals()
	return st.commit()


func _mesh_touffe() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7
	for k in 8:
		var a := k * TAU / 8.0 + hasard.randf_range(-0.3, 0.3)
		var c := Vector3(cos(a), 0, sin(a)) * hasard.randf_range(0.03, 0.1)
		var cote := Vector3(-sin(a), 0, cos(a)) * 0.035
		var h := hasard.randf_range(0.18, 0.3)
		var bout := c * 2.2 + Vector3(0, h, 0)
		st.set_normal(Vector3.UP)
		st.add_vertex(c - cote)
		st.add_vertex(c + cote)
		st.add_vertex(bout)
	return st.commit()


## Carpes koï qui nagent dans un bassin [x, y, w, d] (px).
func carpes(x: float, y: float, w: float, d: float, nombre := 5) -> void:
	var c := Node3D.new()
	c.set_script(load("res://scripts/carpes.gd"))
	c.name = "Carpes%d" % int(x)
	c.taille = Vector2(w, d) * ECHELLE
	c.nombre = nombre
	c.position = P(x + w / 2.0, y + d / 2.0, 0.0)
	ajouter(racine, c)


func finir(chemin: String) -> void:
	_jardinage()
	# (les flaques des allées et des cours faisaient des taches sombres : retirées)
	_gazon()
	_fleurs_sauvages()
	_alentours()
	var noeud := Node3D.new()
	noeud.name = "DecorJaponais"
	ajouter(racine, noeud)
	# Chaque groupe est découpé en carrés de CARRE m : la caméra ne dessine que ceux qu'elle voit
	# (un seul grand MultiMesh pour tout le niveau serait toujours dessiné en entier).
	for nom in _deco:
		var d: Dictionary = _deco[nom]
		var carres := {}
		# Les montagnes et les petits groupes restent d'un seul tenant (un découpage n'y gagne rien),
		# la forêt du pourtour, loin de la caméra, en plus grands carrés : moins d'appels de dessin.
		var taille := CARRE
		if nom.begins_with("Montagnes") or d["transforms"].size() <= 8:
			taille = 100000.0
		elif nom.begins_with("Foret"):
			taille = CARRE * 2.0
		for tr: Transform3D in d["transforms"]:
			var cle := Vector2i(floori(tr.origin.x / taille), floori(tr.origin.z / taille))
			if not carres.has(cle):
				carres[cle] = []
			carres[cle].append(tr)
		var portee := 0.0
		for petit in PETITS_DETAILS:
			if nom.begins_with(petit):
				portee = PORTEE_DETAILS
		for cle in carres:
			var liste: Array = carres[cle]
			# le carré est placé en son centre : la distance de vue se mesure depuis là
			var centre := Vector3.ZERO
			for tr: Transform3D in liste:
				centre += tr.origin
			centre /= float(liste.size())
			centre.y = 0.0
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = d["mesh"]
			multi.instance_count = liste.size()
			for k in multi.instance_count:
				multi.set_instance_transform(k, (liste[k] as Transform3D).translated(-centre))
			var rendu := MultiMeshInstance3D.new()
			rendu.position = centre
			if portee > 0.0:
				# herbe, fleurs, galets... : inutile de les dessiner loin, la brume les cache déjà
				rendu.visibility_range_end = portee
				rendu.visibility_range_end_margin = 4.0
			rendu.name = "%s_%d_%d" % [nom, cle.x, cle.y] if carres.size() > 1 else nom
			rendu.multimesh = multi
			if d["materiau"]:
				rendu.material_override = d["materiau"]
			var ombre: bool = d["ombre"]
			for petit in SANS_OMBRE:
				if nom.begins_with(petit):
					ombre = false
			if not ombre:
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
func mur(nom: String, x: float, y: float, w: float, d: float, h: float, enduit := "mur") -> void:
	boite(nom, x, y, w, d, h, enduit)
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


## Rempart du château : grosse base de pierres en fruit (ishigaki), mur de planches sombres,
## bandeau d'enduit blanc sous le toit de tuiles rouges, meurtrières.
func rempart(nom: String, x: float, y: float, w: float, d: float, h: float) -> void:
	mur(nom, x, y, w, d, h, "bois_rempart")
	var centre := P(x + w / 2.0, y + d / 2.0)
	var long := maxf(w, d) * ECHELLE
	var epais := minf(w, d) * ECHELLE
	var le_long_x := w >= d
	var taille := func(l: float, haut: float, e: float) -> Vector3:
		return Vector3(l, haut, e) if le_long_x else Vector3(e, haut, l)
	# base de pierre évasée : 0,3 m de plus de chaque côté au pied, presque rien à 1,8 m
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hb := 1.8
	var bas := Vector2(long / 2.0 + 0.3, epais / 2.0 + 0.3)
	var haut := Vector2(long / 2.0 + 0.05, epais / 2.0 + 0.04)
	var coins_bas := [Vector3(-bas.x, 0, -bas.y), Vector3(bas.x, 0, -bas.y), Vector3(bas.x, 0, bas.y), Vector3(-bas.x, 0, bas.y)]
	var coins_haut := [Vector3(-haut.x, hb, -haut.y), Vector3(haut.x, hb, -haut.y), Vector3(haut.x, hb, haut.y), Vector3(-haut.x, hb, haut.y)]
	for i in 4:
		var j := (i + 1) % 4
		for v in [coins_bas[i], coins_haut[j], coins_bas[j], coins_bas[i], coins_haut[i], coins_haut[j]]:
			st.add_vertex(v if le_long_x else Vector3(v.z, v.y, v.x))
	for v in [coins_haut[0], coins_haut[2], coins_haut[1], coins_haut[0], coins_haut[3], coins_haut[2]]:
		st.add_vertex(v if le_long_x else Vector3(v.z, v.y, v.x))
	st.generate_normals()
	var base := MeshInstance3D.new()
	base.name = nom + "Ishigaki"
	base.mesh = st.commit()
	base.material_override = materiaux["ishigaki"]
	base.position = centre
	ajouter(racine, base)
	# bandeau blanc sous le toit, et meurtrières rondes et carrées en alternance
	plaque("Bandeaux", centre + Vector3(0, h - 0.42, 0), taille.call(long + 0.03, 0.5, epais + 0.05), "mur")
	var n := int(long / 2.2)
	for k in n:
		var t := ((k + 0.5) / n - 0.5) * long
		for cote in [-1.0, 1.0]:
			var decal := Vector3(t, h * 0.62, cote * (epais / 2.0 + 0.02))
			if not le_long_x:
				decal = Vector3(cote * (epais / 2.0 + 0.02), h * 0.62, t)
			var cote_l := 0.22 if k % 2 == 0 else 0.16
			plaque("Meurtrieres", centre + decal, taille.call(cote_l, cote_l * (1.0 if k % 2 == 0 else 1.6), 0.05), "noir", false)


## Tourelle (yagura) centrée en (x, y), de w × d px, posée à `base` m (sur le rempart) :
## socle de pierre jusque-là (si `socle`), étage blanc aux fenêtres éclairées, toit rouge.
func yagura(nom: String, x: float, y: float, w := 110.0, d := 110.0, base := 3.4, socle := true) -> void:
	var noeud := Node3D.new()
	noeud.name = nom
	ajouter(racine, noeud)
	var c := P(x, y)
	var lx := w * ECHELLE
	var lz := d * ECHELLE
	if socle:
		boite(nom + "Socle", x - w / 2.0, y - d / 2.0, w, d, base, "ishigaki")
	plaque("YaguraCorps", c + Vector3(0, base + 0.8, 0), Vector3(lx - 0.4, 1.6, lz - 0.4), "mur")
	plaque("Poutres", c + Vector3(0, base + 0.05, 0), Vector3(lx - 0.2, 0.14, lz - 0.2), "bois_sombre")
	plaque("Poutres", c + Vector3(0, base + 1.55, 0), Vector3(lx - 0.3, 0.12, lz - 0.3), "bois_sombre")
	for s in [-1.0, 1.0]:
		var nx := maxi(int((lx - 0.4) / 1.4), 1)
		for k in nx:
			var t := ((k + 0.5) / nx - 0.5) * (lx - 0.4)
			plaque("Shoji", c + Vector3(t, base + 0.85, s * (lz / 2.0 - 0.18)), Vector3(0.5, 0.42, 0.04), "shoji", false)
		var nz := maxi(int((lz - 0.4) / 1.4), 1)
		for k in nz:
			var t := ((k + 0.5) / nz - 0.5) * (lz - 0.4)
			plaque("Shoji", c + Vector3(s * (lx / 2.0 - 0.18), base + 0.85, t), Vector3(0.04, 0.42, 0.5), "shoji", false)
	_pan_de_toit(noeud, c + Vector3(0, base + 1.6, 0), lx + 0.9, lz + 0.9, 1.0)


## Pagode à cinq étages, centrée en (x, y), de `cote` px au sol : socle de pierre, étages
## de bois rouge sombre aux fenêtres éclairées, toits rouges et flèche dorée.
func pagode(nom: String, x: float, y: float, cote := 140.0, etages := 5) -> void:
	var noeud := Node3D.new()
	noeud.name = nom
	ajouter(racine, noeud)
	var c := P(x, y)
	boite(nom + "Socle", x - cote / 2.0 - 10, y - cote / 2.0 - 10, cote + 20, cote + 20, 0.45, "pierre")
	boite(nom + "Corps", x - cote * 0.35, y - cote * 0.35, cote * 0.7, cote * 0.7, 1.6, "bois_sombre", null, 0.45)
	var l := cote * ECHELLE * 0.7
	var y_niv := 0.45
	for e in etages:
		var h := 1.5 if e == 0 else 1.15
		plaque("PagodeCorps", c + Vector3(0, y_niv + h / 2.0, 0), Vector3(l, h, l), "bois_sombre")
		for s in [-1.0, 1.0]:
			plaque("Shoji", c + Vector3(0, y_niv + h * 0.55, s * (l / 2.0 + 0.02)), Vector3(l * 0.4, h * 0.4, 0.04), "shoji", false)
			plaque("Shoji", c + Vector3(s * (l / 2.0 + 0.02), y_niv + h * 0.55, 0), Vector3(0.04, h * 0.4, l * 0.4), "shoji", false)
		y_niv += h
		var debord := l + 1.8 - e * 0.1
		_pan_de_toit(noeud, c + Vector3(0, y_niv, 0), debord, debord, 0.42 if e < etages - 1 else 1.0)
		y_niv += 0.35
		l *= 0.84
	# flèche dorée (sōrin) à anneaux
	var fleche := CylinderMesh.new()
	fleche.top_radius = 0.03
	fleche.bottom_radius = 0.07
	fleche.height = 2.2
	fleche.radial_segments = 8
	deco("PagodeFleche", fleche, Transform3D(Basis(), c + Vector3(0, y_niv + 1.4, 0)), materiaux["or"])
	for k in 5:
		var anneau := TorusMesh.new()
		anneau.inner_radius = 0.07
		anneau.outer_radius = 0.16 - k * 0.012
		anneau.rings = 12
		anneau.ring_segments = 4
		deco("PagodeAnneaux", anneau, Transform3D(Basis(), c + Vector3(0, y_niv + 0.8 + k * 0.28, 0)), materiaux["or"])


## Grand parterre rond bordé de pierre (centré en x, y, rayon en px) : herbe et fleurs dedans,
## à poser sous un grand arbre au centre d'une cour.
func parterre(x: float, y: float, rayon: float) -> void:
	var r := rayon * ECHELLE
	var bord := CylinderMesh.new()
	bord.top_radius = r
	bord.bottom_radius = r + 0.05
	bord.height = 0.3
	bord.radial_segments = 32
	deco("ParterreBord", bord, Transform3D(Basis(), P(x, y, 0.15)), materiaux["pierre"])
	var herbe := CylinderMesh.new()
	herbe.top_radius = r - 0.25
	herbe.bottom_radius = r - 0.25
	herbe.height = 0.32
	herbe.radial_segments = 32
	deco("ParterreHerbe", herbe, Transform3D(Basis(), P(x, y, 0.17)), materiaux["herbe"])
	_occupe.append(Rect2(x, y, 0, 0).grow(rayon))
	var corps := StaticBody3D.new()
	corps.name = "Parterre%d" % int(x)
	ajouter(racine, corps)
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = 0.3
	forme.shape = cyl
	forme.position = P(x, y, 0.15)
	ajouter(corps, forme)


## Bâtiment : murs blancs à colombages sombres, fenêtres shoji éclairées, toit de tuiles débordant.
func batiment(nom: String, x: float, y: float, w: float, d: float, h: float, toit := "tuiles") -> void:
	# murs et soubassement comme avant, mais un vrai toit japonais à quatre pans à la place du toit plat
	boite(nom, x, y, w, d, h, "mur")
	boite(nom + "Soubassement", x - 2, y - 2, w + 4, d + 4, 0.4, "pierre")
	toit_japonais(nom + "Toit", x, y, w, d, h - 0.4, 1, toit)
	var c := P(x + w / 2.0, y + d / 2.0)
	var lx := w * ECHELLE
	var lz := d * ECHELLE
	# Poteaux d'angle et poutre haute
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			plaque("Poteaux", c + Vector3(sx * lx / 2.0, h / 2.0, sz * lz / 2.0), Vector3(0.18, h, 0.18), "bois")
	plaque("Poutres", c + Vector3(0, h - 0.15, 0), Vector3(lx + 0.06, 0.16, lz + 0.06), "bois")
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

## Buissons touffus (cartes de feuilles, scripts/touffu.gd) : [x, y, diamètre en m].
func buissons(liste: Array) -> void:
	_hasard.seed = 4404
	for b in liste:
		var r: float = b[2] / 2.0
		var c := P(b[0], b[1])
		for k in 2:
			var s := r if k == 0 else r * _hasard.randf_range(0.5, 0.65)
			var a := _hasard.randf() * TAU
			var pos := c if k == 0 else c + Vector3(cos(a), 0, sin(a)) * r * 0.7
			var base := Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(s, s * 0.9, s))
			var variante := _hasard.randi_range(0, 3)
			deco("Buissons%d" % variante, Touffu.maillage(variante), Transform3D(base, pos + Vector3(0, s * 0.5, 0)), Touffu.materiau())
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

## Rochers moussus (formes Kenney, matière dessinée) : [x, y, taille en m, modèle 0-8].
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
		_occupe.append(Rect2(r[0], r[1], 0, 0).grow(r[2] / ECHELLE * 0.5))
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

## Rivière : un lit creusé dans le sol entre les points [[x, y]...] (px), l'eau en contrebas,
## des galets et des rochers sur les berges. On ne peut la traverser que sur les ponts :
## `passages` donne les intervalles [x0, x1] (px) laissés libres.
func ruisseau(nom: String, points: Array, largeur: float, passages := []) -> void:
	var noeud := Node3D.new()
	noeud.name = nom
	ajouter(racine, noeud)
	var bords := StaticBody3D.new()
	bords.name = nom + "Bords"
	ajouter(racine, bords)
	_hasard.seed = int(largeur * 13)
	var large := largeur * ECHELLE
	for k in points.size() - 1:
		_occupe.append(Rect2(Vector2(points[k][0], points[k][1]), Vector2.ZERO).expand(Vector2(points[k + 1][0], points[k + 1][1])).grow(largeur * 0.6))
		var a := P(points[k][0], points[k][1])
		var b := P(points[k + 1][0], points[k + 1][1])
		var angle := -atan2(b.z - a.z, b.x - a.x)
		var longueur := a.distance_to(b)
		# le lit, creusé dans le sol (les segments se chevauchent aux coudes)
		var lit := CSGBox3D.new()
		lit.name = "%sLit%d" % [nom, k]
		lit.operation = CSGShape3D.OPERATION_SUBTRACTION
		lit.size = Vector3(longueur + large * 0.9, 0.9, large)
		lit.position = (a + b) / 2.0 + Vector3(0, -0.35, 0)
		lit.rotation.y = angle
		ajouter(decor, lit)
		var bande := MeshInstance3D.new()
		var plan := PlaneMesh.new()
		plan.size = Vector2(longueur + large, large)
		plan.material = materiaux["eau"]
		bande.mesh = plan
		bande.position = (a + b) / 2.0 + Vector3(0, -0.22, 0)
		bande.rotation.y = angle
		bande.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ajouter(noeud, bande)
		# murs invisibles au-dessus de l'eau, sauf aux ponts
		var x0 := minf(a.x, b.x)
		var x1 := maxf(a.x, b.x)
		var morceaux := [[x0 - 0.2, x1 + 0.2]]
		for passage in passages:
			var p0 := P(passage[0], 0).x
			var p1 := P(passage[1], 0).x
			var suite := []
			for m in morceaux:
				if p1 <= m[0] or p0 >= m[1]:
					suite.append(m)
				else:
					if p0 > m[0]:
						suite.append([m[0], p0])
					if p1 < m[1]:
						suite.append([p1, m[1]])
			morceaux = suite
		for m in morceaux:
			var ta: float = (m[0] - a.x) / (b.x - a.x)
			var tb: float = (m[1] - a.x) / (b.x - a.x)
			var ma := a.lerp(b, ta)
			var mb := a.lerp(b, tb)
			var forme := CollisionShape3D.new()
			var boite_mur := BoxShape3D.new()
			boite_mur.size = Vector3(ma.distance_to(mb), 3.0, large * 0.95)
			forme.shape = boite_mur
			forme.position = (ma + mb) / 2.0 + Vector3(0, 1.0, 0)
			forme.rotation.y = angle
			ajouter(bords, forme)
		# galets le long des berges, et quelques-uns dans l'eau
		var dir := (b - a).normalized()
		var cote := dir.cross(Vector3.UP)
		var n := int(longueur / 0.45)
		for i in n:
			for s in [-1.0, 1.0]:
				var p: Vector3 = a.lerp(b, (i + _hasard.randf()) / n) + cote * s * (large / 2.0 + _hasard.randf_range(-0.12, 0.1))
				var t := _hasard.randf_range(0.14, 0.32)
				deco("Galets", _sphere(), Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(t * 1.3, t * 0.6, t)), Vector3(p.x, 0.0, p.z)), materiaux["rocher"])
			if _hasard.randf() < 0.18:
				var q: Vector3 = a.lerp(b, (i + 0.5) / n) + cote * _hasard.randf_range(-0.4, 0.4) * large
				var t := _hasard.randf_range(0.2, 0.36)
				deco("GaletsEau", _sphere(), Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(t * 1.4, t * 0.7, t)), Vector3(q.x, -0.24, q.z)), materiaux["rocher"])


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
	# derrière, une falaise de grands rochers plus haute que la chute : l'eau en sort au lieu de flotter
	var rocs := [[-0.9, -0.6, 1.4, 4], [0.9, -0.6, 1.3, 5], [0.0, -1.2, 1.6, 0], [-1.5, 0.1, 0.9, 2],
		[1.4, 0.2, 0.8, 3], [-0.6, 0.5, 0.5, 7], [0.7, 0.6, 0.45, 6],
		[-0.75, -1.25, 1.0, 5], [0.75, -1.25, 1.0, 4], [0.0, -2.0, 1.7, 1], [-1.5, -1.6, 1.3, 2],
		[1.5, -1.6, 1.3, 0], [-0.9, -2.6, 1.5, 3], [0.9, -2.6, 1.5, 1]]
	for r in rocs:
		var local := Vector3(r[0], 0, r[1]).rotated(Vector3.UP, deg_to_rad(regard))
		var p := noeud.position + local
		var px := p.x / ECHELLE + origine.x
		var py := p.z / ECHELLE + origine.y
		var s: float = r[2] * (1.0 if r[1] > -1.0 else hauteur / 1.6)
		rochers([[px, py, s, r[3]]])
	# de la verdure par-dessus et derrière la falaise
	for v in [[-1.8, -2.9, 1.4], [1.8, -2.9, 1.3], [0.0, -3.4, 1.6]]:
		var local := Vector3(v[0], 0, v[1]).rotated(Vector3.UP, deg_to_rad(regard))
		var p := noeud.position + local
		buissons([[p.x / ECHELLE + origine.x, p.z / ECHELLE + origine.y, v[2]]])
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


## Pont arqué en bois aux garde-corps laqués, sur le rectangle [x, y, w, d] (px), dans le sens
## de la plus grande longueur. Le tablier monte en pente douce (on y marche sans sauter) et les
## garde-corps empêchent de tomber à l'eau.
func pont_arque(nom: String, x: float, y: float, w: float, d: float, hauteur := 0.55) -> void:
	var le_long_z := d > w
	var c := P(x + w / 2.0, y + d / 2.0)
	var longueur := (d if le_long_z else w) * ECHELLE
	var large := (w if le_long_z else d) * ECHELLE
	var axe := Vector3(0, 0, 1) if le_long_z else Vector3(1, 0, 0)
	var travers := Vector3.UP.cross(axe)
	var n := 10
	var pts: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / n
		pts.append(c + axe * (t - 0.5) * longueur + Vector3(0, hauteur * sin(PI * t), 0))
	var pommeau := SphereMesh.new()
	pommeau.radius = 0.08
	pommeau.height = 0.2
	for i in n:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := (b - a).normalized()
		var haut := dir.cross(travers).normalized()
		var l := a.distance_to(b)
		var planche := CSGBox3D.new()
		planche.name = "%s%d" % [nom, i]
		planche.size = Vector3(large, 0.16, l + 0.06)
		planche.transform = Transform3D(Basis(travers, haut, dir), (a + b) / 2.0 - haut * 0.08)
		planche.material = materiaux["bois"]
		ajouter(decor, planche)
		for s in [-1.0, 1.0]:
			var bord: Vector3 = travers * s * large / 2.0
			for hr in [0.9, 0.5]:
				var rail := Basis(travers * 0.08, haut * (0.08 if hr > 0.6 else 0.05), dir * (l + 0.02))
				deco("GardeCorps", _boite_unite(), Transform3D(rail, (a + b) / 2.0 + bord + Vector3(0, hr, 0)), materiaux["laque_vive"])
			if i % 2 == 0:
				plaque("PoteauxPont", a + bord + Vector3(0, 0.45, 0), Vector3(0.13, 1.1, 0.13), "laque_vive")
				deco("Pommeaux", pommeau, Transform3D(Basis(), a + bord + Vector3(0, 1.05, 0)), materiaux["noir"])
	for s in [-1.0, 1.0]:
		var bout: Vector3 = pts[n] + travers * s * large / 2.0
		plaque("PoteauxPont", bout + Vector3(0, 0.45, 0), Vector3(0.13, 1.1, 0.13), "laque_vive")
		deco("Pommeaux", pommeau, Transform3D(Basis(), bout + Vector3(0, 1.05, 0)), materiaux["noir"])
	# garde-corps solides
	var corps := StaticBody3D.new()
	corps.name = nom + "GardeCorps"
	ajouter(racine, corps)
	for s in [-1.0, 1.0]:
		var forme := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(0.12, 1.8, longueur - 0.3) if le_long_z else Vector3(longueur - 0.3, 1.8, 0.12)
		forme.shape = b
		forme.position = c + travers * s * (large / 2.0 + 0.05) + Vector3(0, 0.7, 0)
		ajouter(corps, forme)


# --- Lumières et objets d'ambiance -----------------------------------------

## Lanternes du jeu : toutes en pierre (tōrō).
func lanternes(points: Array) -> void:
	var noeud := Node3D.new()
	noeud.name = "Lanternes"
	ajouter(racine, noeud)
	for k in points.size():
		var lanterne := instance("res://scenes/objets/lanterne.tscn", "Lanterne%d" % k, P(points[k][0], points[k][1]), noeud)
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
