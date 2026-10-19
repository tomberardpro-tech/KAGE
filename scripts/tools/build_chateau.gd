extends SceneTree
## Génère scenes/levels/chateau.tscn à partir du plan Figma « Niveau 1 · Le château ».
## Lancer : godot --headless --script res://scripts/tools/build_chateau.gd
## Coordonnées du plan en pixels Figma, converties en mètres (1 px = 4 cm),
## le centre du plan (900, 1350) devient l'origine. Le nord du plan est -Z.

const ECHELLE := 0.04
const ORIGINE := Vector2(900, 1350)

const H_REMPART := 3.4
const H_MUR := 3.0
const H_DONJON := 3.4

var racine: Node3D
var decor: CSGCombiner3D
var materiaux := {}


func _init() -> void:
	racine = Node3D.new()
	racine.name = "Chateau"
	racine.set_script(load("res://scripts/niveau.gd"))

	_materiaux()
	_ambiance()

	decor = CSGCombiner3D.new()
	decor.name = "Decor"
	decor.use_collision = true
	_ajouter(racine, decor)

	_sols()
	_remparts()
	_batiments()
	_donjon()
	_douves()
	_limites()
	_vegetation()
	_lanternes()
	_gardes()
	_objectifs()
	_joueur()

	var scene := PackedScene.new()
	var err := scene.pack(racine)
	if err == OK:
		err = ResourceSaver.save(scene, "res://scenes/levels/chateau.tscn")
	racine.free()
	print("chateau.tscn -> ", error_string(err))
	quit(err)


# --- Outils -------------------------------------------------------------

func P(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3((x - ORIGINE.x) * ECHELLE, h, (y - ORIGINE.y) * ECHELLE)


## Rectangle du plan (x, y, largeur, profondeur en px) → boîte de hauteur h posée au sol.
func boite(nom: String, x: float, y: float, w: float, d: float, h: float, mat: String,
		parent: Node = null, base := 0.0) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = nom
	b.size = Vector3(w * ECHELLE, h, d * ECHELLE)
	b.position = P(x + w / 2.0, y + d / 2.0, base + h / 2.0)
	b.material = materiaux[mat]
	_ajouter(parent if parent else decor, b)
	return b


func mur(nom: String, x: float, y: float, w: float, d: float, h: float) -> void:
	boite(nom, x, y, w, d, h, "mur")
	# Petit toit de tuiles sur le mur, comme sur les maquettes
	boite(nom + "Tuiles", x - 6, y - 6, w + 12, d + 12, 0.25, "tuiles", null, h)


func _ajouter(parent: Node, enfant: Node) -> void:
	parent.add_child(enfant)
	enfant.owner = racine


func _instance(chemin: String, nom: String, position: Vector3, parent: Node = null) -> Node3D:
	var n: Node3D = load(chemin).instantiate()
	n.name = nom
	n.position = position
	_ajouter(parent if parent else racine, n)
	return n


func _mat(couleur: String, extra := {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(couleur)
	m.roughness = 0.9
	for cle in extra:
		m.set(cle, extra[cle])
	return m


func _materiaux() -> void:
	materiaux = {
		"herbe": _mat("#24352a"),
		"pave": _mat("#3a3b42"),
		"allee": _mat("#4b4d56"),
		"mur": _mat("#b9b1a3"),
		"pierre": _mat("#5a5d66"),
		"tuiles": _mat("#2b2d33"),
		"bois": _mat("#5a3e2b"),
		"tatami": _mat("#6b6440"),
		"parquet": _mat("#3b3a30"),
		"eau": _mat("#22324a", {"roughness": 0.15, "metallic": 0.3}),
		"rouge": _mat("#c23b22"),
	}


# --- Construction -------------------------------------------------------

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
	_ajouter(racine, monde)

	var lune := DirectionalLight3D.new()
	lune.name = "Lune"
	lune.light_color = Color("#c9d0e8")
	lune.light_energy = 0.9
	lune.shadow_enabled = true
	lune.rotation_degrees = Vector3(-55, 25, 0)
	_ajouter(racine, lune)


func _sols() -> void:
	# Sol général (herbe) avec la tranchée des douves creusée dedans
	var sol := boite("Sol", 80, 200, 1640, 2160, 2.0, "herbe", null, -2.0)
	var douves := boite("Douves", 80, 1900, 1640, 90, 1.2, "eau", null, -1.2)
	douves.operation = CSGShape3D.OPERATION_SUBTRACTION
	# Cours pavées (légèrement surélevées pour ne pas scintiller)
	boite("CourExterieure", 180, 1360, 1440, 480, 0.02, "pave")
	boite("CourInterieure", 180, 760, 1440, 560, 0.02, "pave")
	boite("AlleeExterieure", 860, 1360, 80, 480, 0.03, "allee")
	boite("AlleeInterieure", 870, 900, 60, 420, 0.03, "allee")
	boite("PasDePorte", 860, 1320, 80, 40, 0.03, "allee")


func _remparts() -> void:
	mur("RempartSudOuest", 140, 1840, 700, 40, H_REMPART)
	mur("RempartSudEst", 960, 1840, 700, 40, H_REMPART)
	mur("RempartOuest", 140, 300, 40, 1540, H_REMPART)
	mur("RempartEstNord", 1620, 300, 40, 150, H_REMPART)
	mur("RempartEstSud", 1620, 570, 40, 1270, H_REMPART)
	mur("RempartNord", 180, 300, 1440, 40, H_REMPART)
	mur("MurInterieurOuest", 180, 1320, 560, 40, H_MUR)
	mur("MurInterieurEst", 1060, 1320, 560, 40, H_MUR)
	# Montants des portes
	for x in [830, 960]:
		boite("PorteSud%d" % x, x, 1830, 10, 60, H_REMPART + 0.6, "bois")
	for x in [730, 1060]:
		boite("PorteInterieure%d" % x, x, 1310, 10, 60, H_MUR + 0.6, "bois")
	boite("LinteauSud", 830, 1830, 140, 60, 0.4, "tuiles", null, H_REMPART + 0.6)
	boite("LinteauSortie", 1615, 450, 50, 120, 0.4, "tuiles", null, H_REMPART)


## Bâtiments à toit escaladable : murs en washi, toit de tuiles qui déborde.
func _batiment(nom: String, x: float, y: float, w: float, d: float, h: float) -> void:
	boite(nom, x, y, w, d, h, "mur")
	boite(nom + "Soubassement", x - 2, y - 2, w + 4, d + 4, 0.4, "pierre")
	boite(nom + "Toit", x - 14, y - 14, w + 28, d + 28, 0.3, "tuiles", null, h)


func _batiments() -> void:
	_batiment("Remise", 580, 1680, 160, 110, 1.5)
	_batiment("Caserne", 220, 820, 340, 420, 1.9)
	_batiment("Entrepot", 1240, 820, 340, 420, 1.9)


func _donjon() -> void:
	var e := 16.0  # épaisseur des murs en px
	# Pas de toit : on voit l'intérieur d'en haut.
	boite("DonjonSol", 500, 340, 800, 420, 0.04, "parquet")
	for i in 5:
		boite("Tatami%d" % i, 560 + i * 140, 400, 120, 300, 0.06, "tatami")
	var murs := [
		["DonjonMurNord", 500, 340, 800, e], ["DonjonMurOuest", 500, 340, e, 420],
		["DonjonMurEst", 1300 - e, 340, e, 420], ["DonjonMurSudOuest", 500, 760 - e, 320, e],
		["DonjonMurSudEst", 980, 760 - e, 320, e],
	]
	for m in murs:
		mur(m[0], m[1], m[2], m[3], m[4], H_DONJON)
	# Soubassement de pierre tout autour
	boite("DonjonSocleNord", 488, 328, 824, 14, 0.6, "pierre")
	boite("DonjonSocleOuest", 488, 328, 14, 444, 0.6, "pierre")
	boite("DonjonSocleEst", 1298, 328, 14, 444, 0.6, "pierre")
	boite("DonjonSocleSudOuest", 488, 758, 334, 14, 0.6, "pierre")
	boite("DonjonSocleSudEst", 978, 758, 334, 14, 0.6, "pierre")


func _douves() -> void:
	var eau := MeshInstance3D.new()
	eau.name = "Eau"
	var plan := PlaneMesh.new()
	plan.size = Vector2(1640 * ECHELLE, 90 * ECHELLE)
	plan.material = materiaux["eau"]
	eau.mesh = plan
	eau.position = P(900, 1945, -0.45)
	_ajouter(racine, eau)
	boite("PontLevis", 840, 1890, 120, 110, 0.15, "bois", null, -0.1)
	boite("Etang", 1100, 1630, 180, 130, 0.04, "eau")


## Murs invisibles : bord de la carte et bords des douves (sauf le pont).
func _limites() -> void:
	var corps := StaticBody3D.new()
	corps.name = "Limites"
	_ajouter(racine, corps)
	var rects := [
		[80, 160, 1640, 40], [80, 2360, 1640, 40], [40, 200, 40, 2160], [1720, 200, 40, 2160],
		[80, 1990, 760, 10], [960, 1990, 760, 10], [80, 1890, 60, 10], [1660, 1890, 60, 10],
	]
	for r in rects:
		var forme := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(r[2] * ECHELLE, 4.0, r[3] * ECHELLE)
		forme.shape = b
		forme.position = P(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0, 2.0)
		_ajouter(corps, forme)


func _vegetation() -> void:
	var herbes := load("res://scripts/herbes.gd")
	var arbre := load("res://scripts/arbre.gd")
	var touffes := [
		[200, 2100, 260, 170], [1280, 2080, 300, 180], [230, 1620, 220, 160],
		[1330, 1680, 240, 130], [640, 1400, 180, 110], [680, 1200, 180, 100],
	]
	var i := 0
	for t in touffes:
		var z := Area3D.new()
		z.set_script(herbes)
		z.name = "Herbes%d" % i
		z.taille = Vector2(t[2], t[3]) * ECHELLE
		z.position = P(t[0] + t[2] / 2.0, t[1] + t[3] / 2.0)
		_ajouter(racine, z)
		i += 1
	var arbres := [[1380, 1380, 110], [220, 1400, 90], [640, 1020, 140], [1030, 960, 150]]
	i = 0
	for a in arbres:
		var z := Area3D.new()
		z.set_script(arbre)
		z.name = "Arbre%d" % i
		z.rayon = a[2] / 2.0 * ECHELLE
		z.position = P(a[0] + a[2] / 2.0, a[1] + a[2] / 2.0)
		_ajouter(racine, z)
		i += 1
	_clair_de_lune()
	_higanbanas()


func _clair_de_lune() -> void:
	var z := Area3D.new()
	z.set_script(load("res://scripts/zone.gd"))
	z.name = "ClairDeLune"
	z.type = 3
	z.position = P(900, 950)
	_ajouter(racine, z)
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5
	cyl.height = 2.0
	forme.shape = cyl
	forme.scale = Vector3(400 * ECHELLE, 1, 300 * ECHELLE)
	forme.position.y = 1.0
	_ajouter(z, forme)
	var spot := SpotLight3D.new()
	spot.name = "Rayon"
	spot.light_color = Color("#ded0c9")
	spot.light_energy = 2.0
	spot.spot_range = 20.0
	spot.spot_angle = 26.0
	spot.position = Vector3(0, 14, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	_ajouter(z, spot)


func _higanbanas() -> void:
	var fleur := SphereMesh.new()
	fleur.radius = 0.12
	fleur.height = 0.16
	fleur.material = materiaux["rouge"]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = fleur
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 1350
	var points := []
	while points.size() < 260:
		var x := hasard.randf_range(100, 1700)
		var y := hasard.randf_range(2030, 2340)
		if absf(x - 900) < 70:
			continue  # on laisse le chemin libre
		points.append(P(x, y, hasard.randf_range(0.25, 0.45)))
	multi.instance_count = points.size()
	for k in points.size():
		multi.set_instance_transform(k, Transform3D(Basis(), points[k]))
	var rendu := MultiMeshInstance3D.new()
	rendu.name = "Higanbanas"
	rendu.multimesh = multi
	_ajouter(racine, rendu)


func _lanternes() -> void:
	var noeud := Node3D.new()
	noeud.name = "Lanternes"
	_ajouter(racine, noeud)
	var points := [[740, 1790], [1060, 1790], [480, 1520], [1260, 1460],
		[780, 1380], [1020, 1380], [740, 840], [1060, 840], [900, 1100]]
	for k in points.size():
		var lanterne := _instance("res://scenes/objets/lanterne.tscn", "Lanterne%d" % k, P(points[k][0], points[k][1]), noeud)
		if k < 2:
			lanterne.set("rayon", 3.0)  # les lanternes de la grande porte laissent un passage sombre le long du mur


func _gardes() -> void:
	var noeud := Node3D.new()
	noeud.name = "Gardes"
	_ajouter(racine, noeud)
	var gardes := [
		["GardePorteSud", 900, 1760, []],
		["GardeOuest", 460, 1540, [[380, 1540], [720, 1540]]],
		["GardeEst", 1280, 1530, [[1460, 1530], [1080, 1530]]],
		["GardePorteInterieure", 900, 1395, []],
		["GardeCourNord", 640, 920, [[620, 920], [1160, 920]]],
		["GardeCourSud", 1160, 1160, [[1160, 1160], [700, 1160]]],
		["GardeDonjon", 900, 660, []],
	]
	for g in gardes:
		var garde := _instance("res://scenes/characters/garde.tscn", g[0], P(g[1], g[2]), noeud)
		var ronde := PackedVector3Array()
		for p in g[3]:
			ronde.append(P(p[0], p[1]))
		garde.set("ronde", ronde)


func _objectifs() -> void:
	var autel_script := load("res://scripts/autel.gd")
	var autels := [["Depart", 900, 2290], ["AutelOuest", 340, 1760], ["AutelEst", 1430, 1280]]
	for a in autels:
		var autel := Area3D.new()
		autel.set_script(autel_script)
		autel.name = a[0]
		autel.position = P(a[1], a[2])
		_ajouter(racine, autel)
		var forme := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.6
		forme.shape = sphere
		_ajouter(autel, forme)
		var socle := CSGBox3D.new()
		socle.name = "Socle"
		socle.size = Vector3(0.9, 0.6, 0.6)
		socle.position.y = 0.3
		socle.material = materiaux["pierre"]
		_ajouter(autel, socle)
		var toit := CSGBox3D.new()
		toit.name = "Toit"
		toit.size = Vector3(1.2, 0.15, 0.8)
		toit.position.y = 0.95
		toit.material = materiaux["rouge"]
		_ajouter(autel, toit)
		var flamme := OmniLight3D.new()
		flamme.name = "Flamme"
		flamme.light_color = Color("#d99a4e")
		flamme.light_energy = 0.8
		flamme.omni_range = 2.0
		flamme.position.y = 0.8
		flamme.visible = a[0] == "Depart"
		_ajouter(autel, flamme)

	var ramassable := load("res://scripts/ramassable.gd")
	var parchemin := Area3D.new()
	parchemin.set_script(ramassable)
	parchemin.name = "Parchemin"
	parchemin.position = P(900, 530, 0.6)
	parchemin.set("tourne", true)
	_ajouter(racine, parchemin)
	var forme_p := CollisionShape3D.new()
	var sphere_p := SphereShape3D.new()
	sphere_p.radius = 0.9
	forme_p.shape = sphere_p
	_ajouter(parchemin, forme_p)
	var rouleau := MeshInstance3D.new()
	rouleau.name = "Rouleau"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 0.7
	cyl.material = _mat("#eae3d6", {"emission_enabled": true, "emission": Color("#d99a4e"), "emission_energy_multiplier": 0.6})
	rouleau.mesh = cyl
	rouleau.rotation_degrees = Vector3(0, 0, 90)
	_ajouter(parchemin, rouleau)
	var halo := OmniLight3D.new()
	halo.name = "Halo"
	halo.light_color = Color("#d99a4e")
	halo.light_energy = 1.2
	halo.omni_range = 2.5
	_ajouter(parchemin, halo)

	var sortie := Area3D.new()
	sortie.set_script(ramassable)
	sortie.name = "Sortie"
	sortie.position = P(1650, 510, 1.0)
	_ajouter(racine, sortie)
	var forme_s := CollisionShape3D.new()
	var boite_s := BoxShape3D.new()
	boite_s.size = Vector3(2.0, 2.0, 4.8)
	forme_s.shape = boite_s
	_ajouter(sortie, forme_s)


func _joueur() -> void:
	var ninja := _instance("res://scenes/characters/ninja.tscn", "Ninja", P(900, 2240))
	ninja.get_node("Visuel").rotation.y = PI  # regarde vers le château
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.set_script(load("res://scripts/follow_camera.gd"))
	camera.fov = 40.0
	camera.current = true
	camera.position = ninja.position + Vector3(0, 10.5, 11)
	_ajouter(racine, camera)
	camera.set("target", ninja)
	var messages: Node = load("res://scenes/ui/messages.tscn").instantiate()
	messages.name = "Messages"
	_ajouter(racine, messages)
	for nom in ["Hud", "Ecrans"]:
		var calque := CanvasLayer.new()
		calque.name = nom
		calque.set_script(load("res://scripts/%s.gd" % ("hud" if nom == "Hud" else "ecrans_jeu")))
		_ajouter(racine, calque)
