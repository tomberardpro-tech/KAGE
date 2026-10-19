extends SceneTree
## Outils communs aux scripts qui génèrent les niveaux (build_chateau.gd, build_village.gd...).
## Coordonnées du plan en pixels Figma, converties en mètres (1 px = 4 cm),
## le point `origine` du plan devient l'origine du monde. Le nord du plan est -Z.

const ECHELLE := 0.04

var origine := Vector2.ZERO
var reglages_niveau := {}
var racine: Node3D
var decor: CSGCombiner3D
var materiaux := {}


## Crée la racine du niveau, les matériaux, l'ambiance de nuit et le décor (avec collisions).
func commencer(nom: String, centre: Vector2, reglages := {}) -> void:
	origine = centre
	racine = Node3D.new()
	racine.name = nom
	racine.set_script(load("res://scripts/niveau.gd"))
	reglages_niveau = reglages
	_materiaux()
	_ambiance()
	decor = CSGCombiner3D.new()
	decor.name = "Decor"
	decor.use_collision = true
	ajouter(racine, decor)


## Enregistre la scène et quitte Godot.
func finir(chemin: String) -> void:
	var scene := PackedScene.new()
	var err := scene.pack(racine)
	if err == OK:
		err = ResourceSaver.save(scene, chemin)
	racine.free()
	if err == OK and not reglages_niveau.is_empty():
		_ecrire_reglages(chemin)
	print(chemin.get_file(), " -> ", error_string(err))
	quit(err)


## Les réglages du niveau (titre, textes, niveau suivant) sont écrits directement dans le .tscn :
## en mode --script, niveau.gd ne compile pas (il dépend des scripts globaux comme Transition),
## donc racine.set() ne les garderait pas.
func _ecrire_reglages(chemin: String) -> void:
	var lignes := FileAccess.get_file_as_string(chemin).split("\n")
	var sortie := PackedStringArray()
	var fait := false
	var dans_racine := false
	for ligne in lignes:
		sortie.append(ligne)
		if ligne.begins_with("[node ") and not "parent=" in ligne:
			dans_racine = true
		if dans_racine and not fait and ligne.begins_with("script = "):
			for cle in reglages_niveau:
				sortie.append("%s = %s" % [cle, var_to_str(reglages_niveau[cle])])
			fait = true
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string("\n".join(sortie))


# --- Outils -------------------------------------------------------------

func P(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3((x - origine.x) * ECHELLE, h, (y - origine.y) * ECHELLE)


## Rectangle du plan (x, y, largeur, profondeur en px) → boîte de hauteur h posée au sol.
func boite(nom: String, x: float, y: float, w: float, d: float, h: float, mat: String,
		parent: Node = null, base := 0.0) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = nom
	b.size = Vector3(w * ECHELLE, h, d * ECHELLE)
	b.position = P(x + w / 2.0, y + d / 2.0, base + h / 2.0)
	b.material = materiaux[mat]
	ajouter(parent if parent else decor, b)
	return b


func mur(nom: String, x: float, y: float, w: float, d: float, h: float) -> void:
	boite(nom, x, y, w, d, h, "mur")
	# Petit toit de tuiles sur le mur, comme sur les maquettes
	boite(nom + "Tuiles", x - 6, y - 6, w + 12, d + 12, 0.25, "tuiles", null, h)


## Bâtiment à toit escaladable : murs en washi, toit de tuiles qui déborde.
func batiment(nom: String, x: float, y: float, w: float, d: float, h: float, toit := "tuiles") -> void:
	boite(nom, x, y, w, d, h, "mur")
	boite(nom + "Soubassement", x - 2, y - 2, w + 4, d + 4, 0.4, "pierre")
	boite(nom + "Toit", x - 14, y - 14, w + 28, d + 28, 0.3, toit, null, h)


func ajouter(parent: Node, enfant: Node) -> void:
	parent.add_child(enfant)
	enfant.owner = racine


func instance(chemin: String, nom: String, position: Vector3, parent: Node = null) -> Node3D:
	var n: Node3D = load(chemin).instantiate()
	n.name = nom
	n.position = position
	ajouter(parent if parent else racine, n)
	return n


func mat(couleur: String, extra := {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(couleur)
	m.roughness = 0.9
	for cle in extra:
		m.set(cle, extra[cle])
	return m


func _materiaux() -> void:
	materiaux = {
		"herbe": mat("#24352a"),
		"pave": mat("#3a3b42"),
		"allee": mat("#4b4d56"),
		"mur": mat("#b9b1a3"),
		"pierre": mat("#5a5d66"),
		"tuiles": mat("#2b2d33"),
		"bois": mat("#5a3e2b"),
		"tatami": mat("#6b6440"),
		"parquet": mat("#3b3a30"),
		"eau": mat("#22324a", {"roughness": 0.15, "metallic": 0.3}),
		"rouge": mat("#c23b22"),
		"terre": mat("#3b3328"),
		"chaume": mat("#6e5a3a"),
		"sable": mat("#5e5a52"),
		"laque": mat("#8e2a1a"),
	}


func _ambiance() -> void:
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("#0e0f12")
	ciel.sky_horizon_color = Color("#4b5160")
	ciel.ground_bottom_color = Color("#0e0f12")
	ciel.ground_horizon_color = Color("#4b5160")
	var sky := Sky.new()
	sky.sky_material = ciel
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#4b5a78")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#2a3040")
	env.fog_density = 0.008
	var monde := WorldEnvironment.new()
	monde.name = "Ambiance"
	monde.environment = env
	ajouter(racine, monde)

	var lune := DirectionalLight3D.new()
	lune.name = "Lune"
	lune.light_color = Color("#c9d0e8")
	lune.light_energy = 0.9
	lune.shadow_enabled = true
	lune.rotation_degrees = Vector3(-55, 25, 0)
	ajouter(racine, lune)


# --- Éléments de niveau ---------------------------------------------------

## Plan d'eau plat (douves, rivière, étang) posé à la hauteur h.
func eau(nom: String, x: float, y: float, w: float, d: float, h: float) -> void:
	var e := MeshInstance3D.new()
	e.name = nom
	var plan := PlaneMesh.new()
	plan.size = Vector2(w * ECHELLE, d * ECHELLE)
	plan.material = materiaux["eau"]
	e.mesh = plan
	e.position = P(x + w / 2.0, y + d / 2.0, h)
	ajouter(racine, e)


## Murs invisibles : [x, y, largeur, profondeur] en px.
func limites(rects: Array) -> void:
	var corps := StaticBody3D.new()
	corps.name = "Limites"
	ajouter(racine, corps)
	for r in rects:
		var forme := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(r[2] * ECHELLE, 4.0, r[3] * ECHELLE)
		forme.shape = b
		forme.position = P(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0, 2.0)
		ajouter(corps, forme)


## Touffes d'herbes hautes : [x, y, largeur, profondeur] en px.
func herbes(touffes: Array) -> void:
	var script := load("res://scripts/herbes.gd")
	for i in touffes.size():
		var t: Array = touffes[i]
		var z := Area3D.new()
		z.set_script(script)
		z.name = "Herbes%d" % i
		z.taille = Vector2(t[2], t[3]) * ECHELLE
		z.position = P(t[0] + t[2] / 2.0, t[1] + t[3] / 2.0)
		ajouter(racine, z)


## Arbres dont l'ombre cache le ninja : [x, y, diamètre] en px.
func arbres(liste: Array) -> void:
	var script := load("res://scripts/arbre.gd")
	for i in liste.size():
		var a: Array = liste[i]
		var z := Area3D.new()
		z.set_script(script)
		z.name = "Arbre%d" % i
		z.rayon = a[2] / 2.0 * ECHELLE
		z.position = P(a[0] + a[2] / 2.0, a[1] + a[2] / 2.0)
		ajouter(racine, z)


## Clair de lune : zone éclairée quand la lune n'est pas cachée, centrée en (x, y).
func clair_de_lune(nom: String, x: float, y: float, w: float, d: float) -> void:
	var z := Area3D.new()
	z.set_script(load("res://scripts/zone.gd"))
	z.name = nom
	z.type = 3
	z.position = P(x, y)
	ajouter(racine, z)
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5
	cyl.height = 2.0
	forme.shape = cyl
	forme.scale = Vector3(w * ECHELLE, 1, d * ECHELLE)
	forme.position.y = 1.0
	ajouter(z, forme)
	var spot := SpotLight3D.new()
	spot.name = "Rayon"
	spot.light_color = Color("#ded0c9")
	spot.light_energy = 2.0
	spot.spot_range = 20.0
	spot.spot_angle = 26.0
	spot.position = Vector3(0, 14, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	ajouter(z, spot)


## Fleurs rouges éparpillées dans un rectangle, en laissant un couloir libre autour de x = chemin.
func higanbanas(nombre: int, graine: int, x0: float, x1: float, y0: float, y1: float, chemin: float) -> void:
	var fleur := SphereMesh.new()
	fleur.radius = 0.12
	fleur.height = 0.16
	fleur.material = materiaux["rouge"]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = fleur
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine
	var points := []
	while points.size() < nombre:
		var x := hasard.randf_range(x0, x1)
		var y := hasard.randf_range(y0, y1)
		if absf(x - chemin) < 70:
			continue  # on laisse le chemin libre
		points.append(P(x, y, hasard.randf_range(0.25, 0.45)))
	multi.instance_count = points.size()
	for k in points.size():
		multi.set_instance_transform(k, Transform3D(Basis(), points[k]))
	var rendu := MultiMeshInstance3D.new()
	rendu.name = "Higanbanas"
	rendu.multimesh = multi
	ajouter(racine, rendu)


## Lanternes : [x, y] ou [x, y, rayon] en px (rayon en mètres, 4 par défaut).
func lanternes(points: Array) -> void:
	var noeud := Node3D.new()
	noeud.name = "Lanternes"
	ajouter(racine, noeud)
	for k in points.size():
		var lanterne := instance("res://scenes/objets/lanterne.tscn", "Lanterne%d" % k, P(points[k][0], points[k][1]), noeud)
		if points[k].size() > 2:
			lanterne.set("rayon", points[k][2])


## Gardes : [nom, x, y, ronde [[x, y]...], réglages {regard, vitesse, portee...}].
func gardes(liste: Array, communs := {}) -> void:
	var noeud := Node3D.new()
	noeud.name = "Gardes"
	ajouter(racine, noeud)
	for g in liste:
		var garde := instance("res://scenes/characters/garde.tscn", g[0], P(g[1], g[2]), noeud)
		var ronde := PackedVector3Array()
		for p in g[3]:
			ronde.append(P(p[0], p[1]))
		garde.set("ronde", ronde)
		var reglages: Dictionary = communs.duplicate()
		if g.size() > 4:
			reglages.merge(g[4], true)
		for cle in reglages:
			garde.set(cle, reglages[cle])


## Autels : [nom, x, y]. Le premier s'appelle « Depart » et a déjà sa flamme.
func autels(liste: Array) -> void:
	var autel_script := load("res://scripts/autel.gd")
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
		var socle := CSGBox3D.new()
		socle.name = "Socle"
		socle.size = Vector3(0.9, 0.6, 0.6)
		socle.position.y = 0.3
		socle.material = materiaux["pierre"]
		ajouter(autel, socle)
		var toit := CSGBox3D.new()
		toit.name = "Toit"
		toit.size = Vector3(1.2, 0.15, 0.8)
		toit.position.y = 0.95
		toit.material = materiaux["rouge"]
		ajouter(autel, toit)
		var flamme := OmniLight3D.new()
		flamme.name = "Flamme"
		flamme.light_color = Color("#d99a4e")
		flamme.light_energy = 0.8
		flamme.omni_range = 2.0
		flamme.position.y = 0.8
		flamme.visible = a[0] == "Depart"
		ajouter(autel, flamme)


## Planchers rossignol (grincent si on marche debout) : [x, y, largeur, profondeur] en px.
func rossignols(rects: Array) -> void:
	var script := load("res://scripts/rossignol.gd")
	for i in rects.size():
		var r: Array = rects[i]
		var z := Area3D.new()
		z.set_script(script)
		z.name = "Rossignol%d" % i
		z.taille = Vector2(r[2], r[3]) * ECHELLE
		z.position = P(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0)
		ajouter(racine, z)


## Fils à clochettes tendus entre deux points : [x1, y1, x2, y2] en px.
func clochettes(fils: Array) -> void:
	var script := load("res://scripts/clochettes.gd")
	for i in fils.size():
		var f: Array = fils[i]
		var a := P(f[0], f[1])
		var b := P(f[2], f[3])
		var z := Area3D.new()
		z.set_script(script)
		z.name = "Clochettes%d" % i
		z.longueur = a.distance_to(b)
		z.position = (a + b) / 2.0
		z.rotation.y = -atan2(b.z - a.z, b.x - a.x)
		ajouter(racine, z)


func parchemin(x: float, y: float) -> void:
	var p := Area3D.new()
	p.set_script(load("res://scripts/ramassable.gd"))
	p.name = "Parchemin"
	p.position = P(x, y, 0.6)
	p.set("tourne", true)
	ajouter(racine, p)
	var forme := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	forme.shape = sphere
	ajouter(p, forme)
	var rouleau := MeshInstance3D.new()
	rouleau.name = "Rouleau"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 0.7
	cyl.material = mat("#eae3d6", {"emission_enabled": true, "emission": Color("#d99a4e"), "emission_energy_multiplier": 0.6})
	rouleau.mesh = cyl
	rouleau.rotation_degrees = Vector3(0, 0, 90)
	ajouter(p, rouleau)
	var halo := OmniLight3D.new()
	halo.name = "Halo"
	halo.light_color = Color("#d99a4e")
	halo.light_energy = 1.2
	halo.omni_range = 2.5
	ajouter(p, halo)


## Zone de sortie centrée en (x, y), taille en mètres.
func sortie(x: float, y: float, taille: Vector3) -> void:
	var s := Area3D.new()
	s.set_script(load("res://scripts/ramassable.gd"))
	s.name = "Sortie"
	s.position = P(x, y, 1.0)
	ajouter(racine, s)
	var forme := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = taille
	forme.shape = b
	ajouter(s, forme)


## Ninja, caméra qui le suit, messages, HUD et écrans. `regard` : rotation du ninja (PI = vers le nord).
func joueur(x: float, y: float, regard := PI) -> void:
	var ninja := instance("res://scenes/characters/ninja.tscn", "Ninja", P(x, y))
	ninja.get_node("Visuel").rotation.y = regard
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.set_script(load("res://scripts/follow_camera.gd"))
	camera.fov = 40.0
	camera.current = true
	camera.position = ninja.position + Vector3(0, 10.5, 11)
	ajouter(racine, camera)
	camera.set("target", ninja)
	var messages: Node = load("res://scenes/ui/messages.tscn").instantiate()
	messages.name = "Messages"
	ajouter(racine, messages)
	for nom in ["Hud", "Ecrans"]:
		var calque := CanvasLayer.new()
		calque.name = nom
		calque.set_script(load("res://scripts/%s.gd" % ("hud" if nom == "Hud" else "ecrans_jeu")))
		ajouter(racine, calque)
