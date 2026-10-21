extends RefCounted
## Intérieurs des bâtiments, façon Pokémon : on passe une porte (E), l'écran fond au noir et le
## ninja se retrouve dans une pièce à part, construite loin de la carte (à partir de x = 600 m),
## sans toit, au milieu du noir. On en ressort devant la porte.
## Appelé par build_chateau.gd, avec le constructeur en premier paramètre :
##   Interieurs.maison(self, "MaisonHana", 560, 3080, 200, 140, 2, "maison", 1.9)
##   Interieurs.maison(self, "Caserne", 220, 820, 340, 420, 2, "caserne", 1.9, true)
## Pour chaque bâtiment : un vrai battant de porte en bois sur la façade, la porte interactive
## (scripts/porte_batiment.gd), et la pièce : sol, murs (avec collisions), shoji, lumière chaude
## sans ombre et meubles selon le style ("maison", "grenier", "remise", "caserne", "entrepot").

const ECHELLE := 0.04
const X0 := 600.0  ## m : premier intérieur ; bien au-delà des montagnes du pourtour (~210 m)
const PAS := 30.0  ## m entre deux intérieurs
const CALQUE := 1 << 19  ## calque de rendu des intérieurs : la lune ne les éclaire pas (pas de toit !)
const H_MUR := 2.4
const DOMA := 1.2  ## m : sol de terre battue de l'entrée, le long du mur sud
const SCRIPT_PORTE := "res://scripts/porte_batiment.gd"

## Texte de la porte : « Entrer » + ceci.
const LIEUX := {
	"MaisonHana": "chez Hana", "MaisonUme": "chez grand-mère Ume", "MaisonKenji": "chez Kenji",
	"MaisonJiro": "chez Jiro", "Grenier": "dans le grenier", "Remise": "dans la remise",
	"RemiseChateau": "dans la remise", "Caserne": "dans la caserne", "Entrepot": "dans l'entrepôt",
}


## Une porte sur la façade et l'intérieur qui va avec.
## (x, y, w, d) : rectangle du bâtiment en px ; face : 0 sud, 1 nord, 2 est, 3 ouest (comme maison_bois) ;
## h : hauteur des murs du bâtiment (m) ; chateau : bâtiment du château (decor.batiment) plutôt
## qu'une maison de bois (decor.maison_bois), ce qui change la place de la porte sur la façade.
static func maison(c, nom: String, x: float, y: float, w: float, d: float, face := 0, style := "maison",
		h := 1.9, chateau := false) -> void:
	var M := _mats(c)
	var lune := c.racine.get_node_or_null("Lune") as DirectionalLight3D
	if lune:
		lune.light_cull_mask &= ~CALQUE
	var conteneur := _conteneur(c)
	var index: int = conteneur.get_meta("nombre", 0)
	conteneur.set_meta("nombre", index + 1)
	_vide(c, conteneur, index + 1)

	# --- La porte sur la façade -------------------------------------------
	var centre: Vector3 = c.P(x + w / 2.0, y + d / 2.0)
	var lx := w * ECHELLE
	var lz := d * ECHELLE
	var normale: Vector3 = [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT][face]
	var tangente := Vector3.RIGHT if face < 2 else Vector3.BACK
	var longueur := lx if face < 2 else lz
	var t := 0.0
	if not chateau:
		# même calcul que maison_bois : la porte prend la place de la fenêtre du milieu
		var n := maxi(int(longueur / 2.4), 1)
		var i := n / 2
		t = ((i + 0.5) / n - 0.5) * longueur
	var facade := centre + normale * ((lz if face < 2 else lx) / 2.0) + tangente * t
	var angle_facade := atan2(normale.x, normale.z)  # le battant regarde dehors
	var dehors := Atelier.new()
	var bas := 0.02 if chateau else 0.36  # sur la véranda des maisons de bois
	var haut := minf(1.62, h - 0.27) if not chateau else minf(1.55, h - 0.28)
	_porte_facade(dehors, M, facade + normale * 0.04, angle_facade, 0.95, bas, haut, chateau)
	if chateau:
		dehors.boite(facade + normale * 0.42 + Vector3(0, 0.06, 0), _oriente(Vector3(1.2, 0.12, 0.5), face), M["pierre"])
	var noeud_porte := Node3D.new()
	noeud_porte.name = nom + "Porte"
	c.ajouter(conteneur.get_parent(), noeud_porte)
	dehors.finir(c, noeud_porte, 1)

	# --- La pièce, loin de tout ---------------------------------------------
	var rw := clampf(lx, 6.5, 12.0)
	var rd := clampf(lz, 5.0, 8.5)
	if face >= 2:
		rw = clampf(lz, 6.5, 12.0)
		rd = clampf(lx, 5.0, 8.5)
	var origine := Vector3(X0 + index * PAS, 0.0, 0.0)
	var piece := Node3D.new()
	piece.name = "Interieur" + nom
	piece.position = origine
	c.ajouter(conteneur, piece)
	_collisions(c, piece, rw, rd)
	_ombre(c, piece, rw, rd)
	var a := Atelier.new()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(nom)
	_sol(a, M, rw, rd, style)
	_meubler(a, M, rw, rd, style, nom, hasard)  # avant les murs : les grands meubles réservent leur pan de mur
	_murs(a, M, rw, rd, style)
	# lumière chaude au-dessus de la pièce (sans ombre), plus douce dans les grandes salles
	var grand := maxf(rw, rd)
	if grand > 9.0:
		for sx in [-0.25, 0.25]:
			a.lumiere(Vector3(sx * rw, 2.3, -0.1 * rd), Color("#ffb874"), 1.0, grand * 0.75)
	else:
		a.lumiere(Vector3(0, 2.3, -0.15), Color("#ffb874"), 1.15, grand * 0.95)
	a.finir(c, piece, CALQUE)

	# --- Les deux portes interactives ---------------------------------------
	var lieu: String = LIEUX.get(nom, "")
	var interieur := origine + Vector3(0, 0.1, rd / 2.0 - 1.0)
	# dehors, on réapparaît tout près de la porte : elle reste l'objet le plus proche (Sora et Aiko
	# bavardent juste devant la porte de Kenji)
	var exterieur := facade + normale * 1.1 + Vector3(0, 0.1, 0)
	_interactif(c, conteneur.get_parent(), nom + "Entree", facade + normale * 0.45,
		("Entrer " + lieu) if lieu != "" else "Entrer", interieur, PI)
	_interactif(c, piece, "Sortie", Vector3(0, 0, rd / 2.0 - 0.3), "Sortir", exterieur, angle_facade)


# --- Outils -------------------------------------------------------------------

static func _oriente(taille: Vector3, face: int) -> Vector3:
	return taille if face < 2 else Vector3(taille.z, taille.y, taille.x)


static func _conteneur(c) -> Node3D:
	var n := c.racine.get_node_or_null("Interieurs") as Node3D
	if n == null:
		n = Node3D.new()
		n.name = "Interieurs"
		c.ajouter(c.racine, n)
	return n


## Une grande boîte noire retournée autour de tous les intérieurs : au-delà des murs, on ne voit
## que du noir, quelle que soit la vue de la caméra (même la vue d'épaule, qui voit l'horizon).
static func _vide(c, conteneur: Node3D, nombre: int) -> void:
	var vide := conteneur.get_node_or_null("Vide") as MeshInstance3D
	if vide == null:
		vide = MeshInstance3D.new()
		vide.name = "Vide"
		var noir := StandardMaterial3D.new()
		noir.albedo_color = Color("#050507")
		noir.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		noir.disable_fog = true
		var boite := BoxMesh.new()
		boite.flip_faces = true
		boite.material = noir
		vide.mesh = boite
		vide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vide.layers = CALQUE
		c.ajouter(conteneur, vide)
	var debut := X0 - 45.0
	var fin := X0 + (nombre - 1) * PAS + 45.0
	(vide.mesh as BoxMesh).size = Vector3(fin - debut, 40.0, 100.0)
	vide.position = Vector3((debut + fin) / 2.0, 19.8, 0.0)


static func _interactif(c, parent: Node3D, nom: String, position: Vector3, texte: String,
		arrivee: Vector3, regard: float) -> void:
	var p := Node3D.new()
	p.name = nom
	p.set_script(load(SCRIPT_PORTE))
	p.position = position
	p.set("texte", texte)
	p.set("arrivee", arrivee)
	p.set("regard", regard)
	c.ajouter(parent, p)


## Sol et murs solides de la pièce. Les murs montent haut (6 m) : on ne peut pas s'y hisser
## pour sauter dans le noir, et le mur sud, bas à l'image, arrête quand même le ninja.
static func _collisions(c, piece: Node3D, rw: float, rd: float) -> void:
	var corps := StaticBody3D.new()
	corps.name = "Murs"
	corps.collision_layer = 1
	c.ajouter(piece, corps)
	var e := 0.4
	for r in [[Vector3(0, -0.15, 0), Vector3(rw + 2 * e, 0.3, rd + 2 * e)],
			[Vector3(0, 3.0, -rd / 2.0 - e / 2.0), Vector3(rw + 2 * e, 6.0, e)],
			[Vector3(0, 3.0, rd / 2.0 + e / 2.0), Vector3(rw + 2 * e, 6.0, e)],
			[Vector3(-rw / 2.0 - e / 2.0, 3.0, 0), Vector3(e, 6.0, rd)],
			[Vector3(rw / 2.0 + e / 2.0, 3.0, 0), Vector3(e, 6.0, rd)]]:
		var forme := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = r[1]
		forme.shape = b
		forme.position = r[0]
		c.ajouter(corps, forme)


## Toute la pièce est une zone d'ombre : le HUD montre le ninja caché (personne ne le voit ici).
static func _ombre(c, piece: Node3D, rw: float, rd: float) -> void:
	var z := Area3D.new()
	z.name = "Ombre"
	z.set_script(load("res://scripts/zone.gd"))
	z.set("type", 0)
	c.ajouter(piece, z)
	var forme := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(rw, 3.0, rd)
	forme.shape = b
	forme.position.y = 1.5
	c.ajouter(z, forme)


static func _mat(couleur: String, extra := {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(couleur)
	m.roughness = 0.85
	for cle in extra:
		m.set(cle, extra[cle])
	return m


static func _lumineux(couleur: String, lueur: String, force: float) -> StandardMaterial3D:
	return _mat(couleur, {"emission_enabled": true, "emission": Color(lueur), "emission_energy_multiplier": force})


static func _mats(c) -> Dictionary:
	if c.has_meta("mats_interieurs"):
		return c.get_meta("mats_interieurs")
	var M: Dictionary = c.materiaux.duplicate()
	M.merge({
		"shoji_lune": _lumineux("#ece6d6", "#aab9de", 0.32),
		"papier_chaud": _lumineux("#f6dfb0", "#ffb35c", 1.5),
		"braise": _lumineux("#a8321a", "#ff6a2a", 2.4),
		"rouge_tissu": _mat("#a8432f"), "indigo": _mat("#2f3f6e"), "ocre": _mat("#c48b2c"),
		"creme": _mat("#e8dfcb"), "vert_tissu": _mat("#4f6b4a"), "heri": _mat("#2c3326"),
		"cendre": _mat("#8c8780"), "fer": _mat("#2a2a2e", {"metallic": 0.5, "roughness": 0.5}),
		"ceramique": _mat("#cdbb9e", {"roughness": 0.4}), "ceramique_bleue": _mat("#3e5f8a", {"roughness": 0.35}),
		"laque_noire": _mat("#24171a", {"roughness": 0.35}), "encre": _mat("#26221f"),
		"papier": _mat("#efe8d6"), "feuille": _mat("#4d7a3a"), "rose": _mat("#e9a0b8"),
		"kaki": _mat("#e07a2a"), "paille": _mat("#cdb478"), "paille_claire": _mat("#e6dcc0"),
		"acier": _mat("#a3a9b2", {"metallic": 0.7, "roughness": 0.3}), "blanc": _mat("#f1ece2"),
		"filet": _mat("#3f4d3a"), "porte_bois": _mat("#b07a4c"), "laque_rouge": _mat("#9e2d1f", {"roughness": 0.4}),
	}, true)
	c.set_meta("mats_interieurs", M)
	return M


## Position décalée par `off`, tourné de `angle` autour de la verticale, depuis `p`.
static func _r(p: Vector3, angle: float, off: Vector3) -> Vector3:
	return p + off.rotated(Vector3.UP, angle)


# --- La porte de la façade --------------------------------------------------------

## Battant de bois à planches verticales, deux traverses et une poignée, dans un cadre sombre
## (montants, linteau, seuil). `p` : pied de la porte sur la façade ; le battant regarde vers `angle`.
static func _porte_facade(a: Atelier, M: Dictionary, p: Vector3, angle: float, larg: float, bas: float,
		haut: float, chateau: bool) -> void:
	var h := haut - bas
	var cadre: Material = M["bois_sombre"] if not chateau else M["laque_noire"]
	# encadrement
	for s in [-1.0, 1.0]:
		a.boite(_r(p, angle, Vector3(s * (larg / 2.0 + 0.05), bas + (h + 0.1) / 2.0, 0.02)), Vector3(0.1, h + 0.1, 0.12), cadre, angle)
	a.boite(_r(p, angle, Vector3(0, haut + 0.07, 0.03)), Vector3(larg + 0.34, 0.12, 0.14), cadre, angle)
	a.boite(_r(p, angle, Vector3(0, bas + 0.025, 0.04)), Vector3(larg + 0.2, 0.05, 0.14), cadre, angle)
	# battant : planches, joints, traverses
	a.boite(_r(p, angle, Vector3(0, bas + h / 2.0, 0.01)), Vector3(larg, h, 0.06), M["porte_bois"], angle)
	for k in 4:
		var x := (k + 1) / 5.0 * larg - larg / 2.0
		a.boite(_r(p, angle, Vector3(x, bas + h / 2.0, 0.042)), Vector3(0.014, h - 0.02, 0.006), M["bois_sombre"], angle)
	for f in [0.2, 0.78]:
		a.boite(_r(p, angle, Vector3(0, bas + h * f, 0.045)), Vector3(larg - 0.06, 0.07, 0.02), M["bois"], angle)
	# poignée de fer et petit judas grillagé en haut
	a.boite(_r(p, angle, Vector3(larg * 0.32, bas + h * 0.5, 0.055)), Vector3(0.05, 0.2, 0.03), M["fer"], angle)
	a.boite(_r(p, angle, Vector3(0, bas + h * 0.89, 0.035)), Vector3(larg * 0.3, h * 0.08, 0.02), M["fenetre"], angle)
	for k in 3:
		a.boite(_r(p, angle, Vector3((k - 1) * larg * 0.08, bas + h * 0.89, 0.045)), Vector3(0.02, h * 0.08, 0.02), M["bois_sombre"], angle)
	if chateau:
		# rideau noren indigo à l'emblème blanc, sous le linteau
		for s in [-1.0, 1.0]:
			a.boite(_r(p, angle, Vector3(s * larg * 0.24, haut - 0.2, 0.09)), Vector3(larg * 0.46, 0.38, 0.015), M["indigo"], angle)
		a.boite(_r(p, angle, Vector3(0, haut - 0.17, 0.1)), Vector3(0.14, 0.14, 0.01), M["blanc"], angle)


# --- Sol --------------------------------------------------------------------------

static func _sol(a: Atelier, M: Dictionary, rw: float, rd: float, style: String) -> void:
	var zs := rd / 2.0
	var zn := -rd / 2.0
	# plancher de base sous tout, et entrée en terre battue avec sa marche
	a.boite(Vector3(0, -0.02, 0), Vector3(rw, 0.04, rd), M["parquet"])
	a.boite(Vector3(0, -0.005, zs - DOMA / 2.0), Vector3(rw, 0.02, DOMA), M["terre"])
	a.boite(Vector3(0, 0.05, zs - DOMA), Vector3(rw, 0.1, 0.12), M["bois_sombre"])  # agari-kamachi
	a.boite(Vector3(0, 0.03, zs - DOMA / 2.0), Vector3(0.7, 0.06, 0.4), M["pierre"])  # pierre à chaussures
	# geta devant la marche
	for s in [-1.0, 1.0]:
		a.boite(Vector3(0.45 + s * 0.07, 0.03, zs - DOMA + 0.35), Vector3(0.1, 0.03, 0.24), M["bois"])
	match style:
		"maison":
			_tatamis(a, M, -rw / 2.0 + 0.3, rw / 2.0 - 0.3, zn + 0.3, zs - DOMA - 0.06)
		"caserne":
			_tatamis(a, M, -rw / 2.0 + 0.3, rw / 2.0 - 0.3, zn + 0.3, zn + 2.6)
		_:
			# nattes de paille (mushiro) posées sur les planches
			a.boite(Vector3(-rw * 0.12, 0.012, -rd * 0.08), Vector3(2.0, 0.02, 1.4), M["chaume"])


## Tatamis de 1,8 × 0,9 m en rangées décalées, avec leur bordure de tissu sombre.
static func _tatamis(a: Atelier, M: Dictionary, x0: float, x1: float, z0: float, z1: float) -> void:
	var rang := 0
	var z := z0
	while z + 0.3 < z1:
		var dz := minf(0.9, z1 - z)
		var x := x0 - (0.9 if rang % 2 == 1 else 0.0)
		while x < x1:
			var a0 := maxf(x, x0)
			var a1 := minf(x + 1.8, x1)
			if a1 - a0 > 0.3:
				var cx := (a0 + a1) / 2.0
				var cz := z + dz / 2.0
				a.boite(Vector3(cx, 0.017, cz), Vector3(a1 - a0 - 0.025, 0.034, dz - 0.025), M["tatami"])
				for s in [-1.0, 1.0]:
					a.boite(Vector3(cx, 0.036, cz + s * (dz / 2.0 - 0.04)), Vector3(a1 - a0 - 0.03, 0.006, 0.05), M["heri"])
			x += 1.8
		z += 0.9
		rang += 1


# --- Murs -------------------------------------------------------------------------

## Murs nord, est et ouest hauts (on les voit de face ou de biais), mur sud bas pour que la
## caméra voie dedans, avec l'encadrement de la porte de sortie et son rideau.
static func _murs(a: Atelier, M: Dictionary, rw: float, rd: float, style: String) -> void:
	var bois := style in ["grenier", "remise", "entrepot"]
	var e := 0.16
	var murs := [
		[Vector3(0, 0, -rd / 2.0 - e / 2.0), rw + 2 * e, true, H_MUR],
		[Vector3(-rw / 2.0 - e / 2.0, 0, 0), rd, false, H_MUR],
		[Vector3(rw / 2.0 + e / 2.0, 0, 0), rd, false, H_MUR],
	]
	for m in murs:
		var c: Vector3 = m[0]
		var long_: float = m[1]
		var le_long_x: bool = m[2]
		var h: float = m[3]
		var taille := func(l: float, hh: float, ep: float) -> Vector3:
			return Vector3(l, hh, ep) if le_long_x else Vector3(ep, hh, l)
		var le_long := func(t: float) -> Vector3:
			return Vector3(t, 0, 0) if le_long_x else Vector3(0, 0, t)
		if bois:
			a.boite(c + Vector3(0, h / 2.0, 0), taille.call(long_, h, e), M["planches"])
		else:
			a.boite(c + Vector3(0, 0.35, 0), taille.call(long_, 0.7, e + 0.02), M["planches"])
			a.boite(c + Vector3(0, 0.7 + (h - 0.7) / 2.0, 0), taille.call(long_, h - 0.7, e), M["mur"])
		# poutres : nageshi et sablière, plinthe
		a.boite(c + Vector3(0, 1.85, 0), taille.call(long_, 0.12, e + 0.06), M["bois_sombre"])
		a.boite(c + Vector3(0, h - 0.08, 0), taille.call(long_, 0.16, e + 0.08), M["bois_sombre"])
		a.boite(c + Vector3(0, 0.05, 0), taille.call(long_, 0.1, e + 0.05), M["bois_sombre"])
		# poteaux tous les ~1,8 m
		var n := maxi(int(round(long_ / 1.8)), 2)
		for k in n + 1:
			var t := (float(k) / n - 0.5) * (long_ - 0.1)
			a.boite(c + le_long.call(t) + Vector3(0, h / 2.0, 0), taille.call(0.14, h, e + 0.1), M["bois_sombre"])
		# fenêtres entre les poteaux : shoji au clair de lune, ou petites fenêtres à barreaux
		var dedans := -c.normalized() * (e / 2.0 + 0.01)
		var cote := "n" if le_long_x else ("o" if c.x < 0.0 else "e")
		for k in n:
			if not le_long_x and k % 2 == 1:
				continue  # moins de fenêtres sur les côtés
			var t := ((k + 0.5) / n - 0.5) * (long_ - 0.1)
			if a.occupe(cote, t, 0.5):
				continue  # un grand meuble (alcôve, étagère, armure...) est contre ce pan de mur
			if bois:
				var pos: Vector3 = c + dedans + le_long.call(t) + Vector3(0, 1.95, 0)
				a.boite(pos, taille.call(0.6, 0.3, 0.02), M["fenetre"])
				for b in 4:
					a.boite(pos + le_long.call((b - 1.5) * 0.14) + dedans * 0.3, taille.call(0.03, 0.3, 0.03), M["bois"])
			else:
				_shoji(a, M, c + dedans + le_long.call(t) + Vector3(0, 1.25, 0), le_long_x, 0.9, 0.95)
	# mur sud : bas, en planches, avec l'encadrement de la porte au milieu
	var zs := rd / 2.0 + e / 2.0
	# (montants courts : un linteau cacherait le ninja quand il arrive, juste devant)
	for s in [-1.0, 1.0]:
		var l := rw / 2.0 + e - 0.6
		a.boite(Vector3(s * (0.6 + l / 2.0), 0.28, zs), Vector3(l, 0.56, e), M["planches"])
		a.boite(Vector3(s * (0.6 + l / 2.0), 0.6, zs), Vector3(l, 0.08, e + 0.06), M["bois_sombre"])
		a.boite(Vector3(s * 0.62, 0.42, zs), Vector3(0.14, 0.84, e + 0.1), M["bois_sombre"])
		a.boite(Vector3(s * 0.62, 0.86, zs), Vector3(0.2, 0.05, e + 0.16), M["bois_sombre"])
		# la porte coulissante, ouverte, glissée derrière le mur
		a.boite(Vector3(s * 1.05, 0.3, zs + e / 2.0 + 0.03), Vector3(0.9, 0.6, 0.04), M["planches"])
	a.boite(Vector3(0, 0.02, zs), Vector3(1.1, 0.04, e + 0.04), M["bois_sombre"])  # seuil
	a.boite(Vector3(0, 0.05, zs + 0.45), Vector3(0.9, 0.1, 0.5), M["pierre"])  # marche dehors
	# paillasson indigo à l'emblème blanc, sur la terre battue de l'entrée
	a.boite(Vector3(0, 0.008, zs - 0.45), Vector3(1.0, 0.012, 0.6), M["indigo"])
	a.boite(Vector3(0, 0.016, zs - 0.45), Vector3(0.18, 0.006, 0.18), M["blanc"], PI / 4.0)


## Shoji : papier éclairé de l'extérieur par la lune, cadre et croisillons sombres.
static func _shoji(a: Atelier, M: Dictionary, p: Vector3, le_long_x: bool, larg: float, haut: float) -> void:
	var taille := func(l: float, hh: float, ep: float) -> Vector3:
		return Vector3(l, hh, ep) if le_long_x else Vector3(ep, hh, l)
	var le_long := func(t: float) -> Vector3:
		return Vector3(t, 0, 0) if le_long_x else Vector3(0, 0, t)
	a.boite(p, taille.call(larg, haut, 0.02), M["shoji_lune"])
	a.boite(p + Vector3(0, haut / 2.0, 0), taille.call(larg + 0.06, 0.05, 0.05), M["bois_sombre"])
	a.boite(p - Vector3(0, haut / 2.0, 0), taille.call(larg + 0.06, 0.05, 0.05), M["bois_sombre"])
	for k in 5:
		var t := (k / 4.0 - 0.5) * larg
		a.boite(p + le_long.call(t), taille.call(0.025 if k % 4 != 0 else 0.05, haut, 0.035), M["bois_sombre"])
	for k in 3:
		var y := ((k + 1) / 4.0 - 0.5) * haut
		a.boite(p + Vector3(0, y, 0), taille.call(larg, 0.02, 0.035), M["bois_sombre"])


# --- Meubles ------------------------------------------------------------------------

## Abscisse du k-ième pan de fenêtre du mur nord (même découpage que _murs).
static func _creneau(rw: float, k: int) -> float:
	var l := rw + 0.32
	var n := maxi(int(round(l / 1.8)), 2)
	return ((k + 0.5) / n - 0.5) * (l - 0.1)


static func _meubler(a: Atelier, M: Dictionary, rw: float, rd: float, style: String, nom: String,
		hasard: RandomNumberGenerator) -> void:
	var xa := -rw / 2.0
	var xb := rw / 2.0
	var zn := -rd / 2.0
	var zs := rd / 2.0 - DOMA  # bord du plancher, côté entrée
	match style:
		"maison":
			var variante: int = {"MaisonHana": 0, "MaisonUme": 1, "MaisonKenji": 2, "MaisonJiro": 3}.get(nom, hasard.randi() % 4)
			match variante:
				0:
					_tokonoma(a, M, Vector3(xa + 1.0, 0, zn), 0.0, 1.5, "ikebana")
					_tansu(a, M, Vector3(xb - 0.8, 0, zn + 0.25), 0.0)
					a.reserver("n", xa + 1.0, 0.85)
					a.reserver("n", xb - 0.8, 0.5)
					_table_basse(a, M, Vector3(-0.3, 0, -0.1), 0.0)
					for p in [[-1.15, -0.1, "rouge_tissu"], [0.55, -0.1, "indigo"], [-0.3, 0.6, "ocre"]]:
						_coussin(a, M, Vector3(p[0], 0, p[1]), M[p[2]])
					_futon(a, M, Vector3(xb - 0.8, 0, 0.1), 0.0, M["indigo"])
					_andon(a, M, Vector3(xa + 0.45, 0, zs - 0.45))
					_hibachi(a, M, Vector3(-1.9, 0, 0.6))
				1:
					_tokonoma(a, M, Vector3(0.6, 0, zn), 0.0, 1.5, "bonsai")
					_tansu(a, M, Vector3(xa + 0.75, 0, zn + 0.25), 0.0)
					_irori(a, M, Vector3(-0.2, 0, 0.0))
					for p in [[-1.25, 0.0, "vert_tissu"], [0.85, 0.0, "rouge_tissu"], [-0.2, -1.0, "ocre"]]:
						_coussin(a, M, Vector3(p[0], 0, p[1]), M[p[2]])
					_futon(a, M, Vector3(xb - 0.8, 0, 0.0), 0.0, M["rouge_tissu"])
					_etagere(a, M, Vector3(xa + 0.22, 0, 0.2), PI / 2.0, hasard)
					_andon(a, M, Vector3(xb - 0.45, 0, zs - 0.4))
					a.reserver("n", 0.6, 0.85)
					a.reserver("n", xa + 0.75, 0.5)
					a.reserver("o", 0.2, 0.6)
				2:
					_tokonoma(a, M, Vector3(xb - 1.1, 0, zn), 0.0, 1.4, "ikebana")
					_etagere(a, M, Vector3(xa + 1.0, 0, zn + 0.22), 0.0, hasard)
					_table_basse(a, M, Vector3(xa + 1.6, 0, 0.2), 0.0)
					for p in [[xa + 0.75, 0.2, "indigo"], [xa + 2.45, 0.2, "ocre"]]:
						_coussin(a, M, Vector3(p[0], 0, p[1]), M[p[2]])
					_futon(a, M, Vector3(1.0, 0, 0.0), PI / 2.0, M["vert_tissu"])
					_byobu(a, M, Vector3(1.0, 0, -0.95), 0.0)
					_coffre(a, M, Vector3(xb - 0.55, 0, 0.5), -PI / 2.0)
					_andon(a, M, Vector3(xa + 0.45, 0, zs - 0.45))
					a.reserver("n", xb - 1.1, 0.8)
					a.reserver("n", xa + 1.0, 0.6)
				_:
					_tokonoma(a, M, Vector3(xa + 1.0, 0, zn), 0.0, 1.4, "carpe")
					_filet(a, M, Vector3(1.0, 0, zn), 0.0)
					_cannes(a, M, Vector3(xb - 0.25, 0, zn + 0.5))
					_irori(a, M, Vector3(-0.6, 0, 0.1))
					for p in [[-1.6, 0.1, "indigo"], [0.4, 0.1, "vert_tissu"]]:
						_coussin(a, M, Vector3(p[0], 0, p[1]), M[p[2]])
					_futon(a, M, Vector3(xb - 0.8, 0, 0.25), 0.0, M["ocre"])
					_tonneau(a, M, Vector3(xa + 0.45, 0, zs - 0.5), 0.28, 0.6)
					_panier(a, M, Vector3(xa + 1.1, 0, zs - 0.4))
					a.reserver("n", xa + 1.0, 0.8)
					a.reserver("n", 1.0, 0.8)
					a.reserver("n", xb - 0.4, 0.4)
		"grenier":
			for k in int((rw - 2.4) / 0.75):
				var x := xa + 0.6 + k * 0.75
				_tawara(a, M, Vector3(x, 0.25, zn + 0.55), PI / 2.0)
				_tawara(a, M, Vector3(x, 0.25, zn + 1.1), PI / 2.0)
				if k % 2 == 0 or k < 3:
					_tawara(a, M, Vector3(x, 0.72, zn + 0.82), PI / 2.0)
			_hoshigaki(a, M, Vector3(xb - 1.0, 0, zn), 4)
			_echelle(a, M, Vector3(xa + 0.15, 0, -0.4), PI / 2.0)
			_tonneau(a, M, Vector3(xb - 0.45, 0, -0.2), 0.3, 0.7)
			_tonneau(a, M, Vector3(xb - 0.5, 0, 0.5), 0.26, 0.6)
			_caisse(a, M, Vector3(xb - 1.25, 0, 0.45), Vector3(0.7, 0.55, 0.6), 0.2)
			_panier(a, M, Vector3(-0.6, 0, -0.1))
			_panier(a, M, Vector3(0.2, 0, 0.25))
			_andon(a, M, Vector3(xa + 0.9, 0, zs - 0.4))
			a.reserver("n", xb - 1.0, 0.9)
			a.reserver("o", -0.4, 0.3)
		"remise":
			_bois_de_chauffe(a, M, Vector3(-0.4, 0, zn + 0.3), 2.4)
			_etabli(a, M, Vector3(xa + 0.45, 0, -0.2), PI / 2.0)
			_outils(a, M, Vector3(xb - 0.12, 0, -0.9), -PI / 2.0)
			_mino(a, M, Vector3(xb, 0, 0.6), -PI / 2.0)
			_tonneau(a, M, Vector3(xb - 0.5, 0, zn + 0.5), 0.28, 0.65)
			_caisse(a, M, Vector3(1.4, 0, zn + 0.45), Vector3(0.7, 0.6, 0.6), -0.1)
			_caisse(a, M, Vector3(1.4, 0.6, zn + 0.45), Vector3(0.5, 0.4, 0.45), 0.25)
			_panier(a, M, Vector3(0.6, 0, 0.3))
			_andon(a, M, Vector3(xa + 0.5, 0, zs - 0.4))
		"caserne":
			# futons alignés sur le tatami du fond, armures et râteliers sur les côtés
			var nb := int((rw - 1.6) / 1.25)
			var couleurs := ["indigo", "vert_tissu", "rouge_tissu", "ocre"]
			for k in nb:
				var x := (k - (nb - 1) / 2.0) * 1.25
				_futon(a, M, Vector3(x, 0, zn + 1.35), 0.0, M[couleurs[k % 4]])
			var n_nord := maxi(int(round((rw + 0.32) / 1.8)), 2)
			for k in [1, n_nord - 2]:
				_banniere(a, M, Vector3(_creneau(rw, k), 0, zn), 0.0)
				a.reserver("n", _creneau(rw, k), 0.35)
			_armure(a, M, Vector3(xa + 0.45, 0, zn + 3.4), PI / 2.0)
			_armure(a, M, Vector3(xa + 0.45, 0, zn + 4.5), PI / 2.0)
			_ratelier(a, M, Vector3(xb - 0.2, 0, zn + 3.9), -PI / 2.0)
			_ratelier(a, M, Vector3(xb - 0.2, 0, zn + 5.5), -PI / 2.0)
			_hibachi(a, M, Vector3(-0.5, 0, zn + 4.4))
			_table_basse(a, M, Vector3(1.1, 0, zn + 4.4), 0.0)
			for p in [[0.25, "indigo"], [1.95, "rouge_tissu"]]:
				_coussin(a, M, Vector3(p[0], 0, zn + 4.4), M[p[1]])
			_coffre(a, M, Vector3(xa + 0.5, 0, zs - 0.5), PI / 2.0)
			_andon(a, M, Vector3(xb - 0.45, 0, zs - 0.4))
			_andon(a, M, Vector3(xa + 0.4, 0, zn + 2.85))
			for z in [zn + 3.4, zn + 4.5]:
				a.reserver("o", z, 0.35)
			for z in [zn + 3.9, zn + 5.5]:
				a.reserver("e", z, 0.75)
		"entrepot":
			# allées de caisses, ballots de riz et tonneaux de saké
			for k in 4:
				var x := xa + 0.6 + k * 0.8
				for j in 2:
					_caisse(a, M, Vector3(x, j * 0.62, zn + 0.45), Vector3(0.7, 0.6, 0.65), hasard.randf_range(-0.08, 0.08))
			for k in 5:
				_tawara(a, M, Vector3(0.6 + k * 0.72, 0.25, zn + 0.55), PI / 2.0)
				_tawara(a, M, Vector3(0.6 + k * 0.72, 0.25, zn + 1.1), PI / 2.0)
				if k < 4:
					_tawara(a, M, Vector3(0.96 + k * 0.72, 0.72, zn + 0.82), PI / 2.0)
			for k in 3:
				_komodaru(a, M, Vector3(xb - 0.5, 0, zn + 2.6 + k * 0.6))
				if k < 2:
					_komodaru(a, M, Vector3(xb - 0.5, 0.58, zn + 2.9 + k * 0.6))
			_etagere(a, M, Vector3(xa + 0.22, 0, zn + 3.0), PI / 2.0, hasard)
			_etagere(a, M, Vector3(xa + 0.22, 0, zn + 4.4), PI / 2.0, hasard)
			for p in [[-0.8, zn + 3.6], [-0.2, zn + 3.9], [1.6, zn + 4.8]]:
				_tonneau(a, M, Vector3(p[0], 0, p[1]), 0.3, 0.7)
			_caisse(a, M, Vector3(0.6, 0, zn + 3.4), Vector3(0.8, 0.6, 0.7), 0.3)
			_caisse(a, M, Vector3(0.6, 0.6, zn + 3.4), Vector3(0.6, 0.45, 0.5), 0.1)
			_andon(a, M, Vector3(xa + 0.45, 0, zs - 0.45))
			_andon(a, M, Vector3(xb - 0.45, 0, zs - 0.45))


static func _table_basse(a: Atelier, M: Dictionary, p: Vector3, angle: float) -> void:
	a.boite(p + Vector3(0, 0.31, 0), Vector3(1.1, 0.05, 0.7), M["laque_noire"], angle)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			a.boite(_r(p, angle, Vector3(sx * 0.48, 0.145, sz * 0.28)), Vector3(0.06, 0.29, 0.06), M["bois_sombre"], angle)
	# théière et deux tasses
	a.sphere(_r(p, angle, Vector3(-0.15, 0.42, 0)), Vector3(0.2, 0.16, 0.2), M["ceramique_bleue"])
	a.cyl(_r(p, angle, Vector3(-0.15, 0.51, 0)), 0.025, 0.04, M["ceramique_bleue"])
	for x in [0.15, 0.3]:
		a.cyl(_r(p, angle, Vector3(x, 0.365, 0.1)), 0.035, 0.06, M["ceramique"])
	a.boite(_r(p, angle, Vector3(0.2, 0.34, -0.15)), Vector3(0.3, 0.012, 0.18), M["vert_tissu"], angle)


static func _coussin(a: Atelier, M: Dictionary, p: Vector3, m: Material) -> void:
	a.boite(p + Vector3(0, 0.035, 0), Vector3(0.52, 0.07, 0.52), m)
	a.boite(p + Vector3(0, 0.07, 0), Vector3(0.44, 0.04, 0.44), m)


static func _futon(a: Atelier, M: Dictionary, p: Vector3, angle: float, couverture: Material) -> void:
	a.boite(p + Vector3(0, 0.05, 0), Vector3(1.0, 0.1, 2.0), M["creme"], angle)
	a.boite(_r(p, angle, Vector3(0, 0.13, 0.3)), Vector3(1.04, 0.07, 1.35), couverture, angle)
	a.boite(_r(p, angle, Vector3(0, 0.168, 0.3)), Vector3(1.05, 0.006, 0.08), M["creme"], angle)
	a.cyl_couche(_r(p, angle, Vector3(0, 0.17, -0.72)), 0.08, 0.46, M["ocre"], angle)


static func _tansu(a: Atelier, M: Dictionary, p: Vector3, angle: float) -> void:
	var l := 1.0
	var h := 1.1
	a.boite(p + Vector3(0, h / 2.0, 0), Vector3(l, h, 0.45), M["bois"], angle)
	a.boite(p + Vector3(0, h + 0.02, 0), Vector3(l + 0.04, 0.04, 0.48), M["laque_noire"], angle)
	for k in 4:
		var y := (k + 0.5) / 4.0 * h
		var demi := k == 3
		for s in ([-1.0, 1.0] if demi else [0.0]):
			var lt := (l - 0.1) / (2.0 if demi else 1.0) - 0.02
			a.boite(_r(p, angle, Vector3(s * (l - 0.1) / 4.0, y, 0.228)), Vector3(lt, h / 4.0 - 0.05, 0.015), M["planches"], angle)
			for hx in ([0.0] if demi else [-0.25, 0.25]):
				a.boite(_r(p, angle, Vector3(s * (l - 0.1) / 4.0 + hx, y, 0.24)), Vector3(0.1, 0.025, 0.02), M["fer"], angle)


static func _etagere(a: Atelier, M: Dictionary, p: Vector3, angle: float, hasard: RandomNumberGenerator) -> void:
	var l := 1.2
	var h := 1.5
	for s in [-1.0, 1.0]:
		a.boite(_r(p, angle, Vector3(s * l / 2.0, h / 2.0, 0)), Vector3(0.05, h, 0.36), M["bois_sombre"], angle)
	for k in 4:
		var y := 0.06 + k * 0.46
		a.boite(_r(p, angle, Vector3(0, y, 0)), Vector3(l, 0.04, 0.36), M["bois"], angle)
		if k == 3:
			break
		# bols, pots et petites boîtes sur chaque planche
		var x := -l / 2.0 + 0.15
		while x < l / 2.0 - 0.15:
			var choix := hasard.randi() % 4
			var q := _r(p, angle, Vector3(x, y + 0.02, 0))
			match choix:
				0:
					a.cyl(q + Vector3(0, 0.12, 0), 0.08, 0.24, M["ceramique"])
				1:
					a.sphere(q + Vector3(0, 0.09, 0), Vector3(0.18, 0.18, 0.18), M["ceramique_bleue"])
				2:
					a.boite(q + Vector3(0, 0.08, 0), Vector3(0.2, 0.16, 0.22), M["laque_rouge"], angle)
				_:
					a.cyl(q + Vector3(0, 0.04, 0), 0.1, 0.08, M["ceramique"])
			x += hasard.randf_range(0.24, 0.34)


## Alcôve : estrade, pilier de bois naturel, rouleau suspendu et un objet posé.
static func _tokonoma(a: Atelier, M: Dictionary, p_mur: Vector3, angle: float, l: float, objet: String) -> void:
	var p := p_mur + Vector3(0, 0, 0.32)
	a.boite(p + Vector3(0, 0.07, 0), Vector3(l, 0.14, 0.62), M["bois_sombre"], angle)
	a.boite(p + Vector3(0, 0.145, 0), Vector3(l - 0.04, 0.01, 0.58), M["bois"], angle)
	a.cyl(p + Vector3(l / 2.0 + 0.04, H_MUR / 2.0, -0.25), 0.065, H_MUR, M["bois"])
	_kakejiku(a, M, p_mur + Vector3(0, 0, 0.02), objet)
	match objet:
		"ikebana":
			a.cyl(p + Vector3(0.35, 0.28, 0.05), 0.08, 0.26, M["ceramique_bleue"])
			for k in 3:
				var b := Basis(Vector3.BACK, (k - 1) * 0.5) * Basis.from_scale(Vector3(0.02, 0.45, 0.02))
				a.boite_b(p + Vector3(0.35 + (k - 1) * 0.08, 0.6, 0.05), b, M["bois_sombre"])
				a.sphere(p + Vector3(0.35 + (k - 1) * 0.2, 0.8 - absf(k - 1) * 0.08, 0.05), Vector3(0.1, 0.1, 0.1), M["rose"])
		"bonsai":
			a.boite(p + Vector3(0.3, 0.2, 0.05), Vector3(0.36, 0.1, 0.24), M["ceramique_bleue"])
			a.boite_b(p + Vector3(0.3, 0.33, 0.05), Basis(Vector3.BACK, 0.4) * Basis.from_scale(Vector3(0.04, 0.22, 0.04)), M["bois_sombre"])
			for o in [Vector3(0.22, 0.45, 0.05), Vector3(0.38, 0.5, 0.02), Vector3(0.3, 0.56, 0.08)]:
				a.sphere(p + o, Vector3(0.2, 0.1, 0.16), M["feuille"])
		_:
			a.sphere(p + Vector3(0.35, 0.24, 0.05), Vector3(0.2, 0.2, 0.2), M["ceramique"])


## Rouleau suspendu : tissu, papier, tiges, peinture à l'encre (montagnes ou carpe) et sceau rouge.
static func _kakejiku(a: Atelier, M: Dictionary, p_mur: Vector3, motif: String) -> void:
	var c := p_mur + Vector3(0, 1.35, 0.01)
	a.boite(c, Vector3(0.6, 1.25, 0.012), M["vert_tissu"] if motif != "carpe" else M["indigo"])
	a.boite(c + Vector3(0, -0.02, 0.008), Vector3(0.46, 0.92, 0.01), M["papier"])
	for y in [0.64, -0.64]:
		a.cyl_couche(c + Vector3(0, y, 0.01), 0.018, 0.7, M["bois_sombre"], 0.0)
	if motif == "carpe":
		a.sphere(c + Vector3(0, 0.0, 0.015), Vector3(0.22, 0.09, 0.01), M["laque_rouge"])
		a.boite(c + Vector3(0.13, 0.0, 0.015), Vector3(0.06, 0.06, 0.008), M["laque_rouge"], 0.0)
	else:
		for k in 3:
			var b := Basis(Vector3.BACK, 0.7 if k % 2 == 0 else -0.7) * Basis.from_scale(Vector3(0.02, 0.26, 0.008))
			a.boite_b(c + Vector3(-0.1 + k * 0.1, -0.15 + (k % 2) * 0.05, 0.016), b, M["encre"])
		a.cyl_b(c + Vector3(0.1, 0.25, 0.016), Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(0.12, 0.01, 0.12)), M["encre"])
	a.boite(c + Vector3(0.15, -0.38, 0.016), Vector3(0.04, 0.05, 0.006), M["rouge"])


## Lanterne de papier posée au sol, avec sa petite lumière chaude.
static func _andon(a: Atelier, M: Dictionary, p: Vector3) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			a.boite(p + Vector3(sx * 0.15, 0.35, sz * 0.15), Vector3(0.03, 0.7, 0.03), M["laque_noire"])
	a.boite(p + Vector3(0, 0.45, 0), Vector3(0.28, 0.44, 0.28), M["papier_chaud"])
	a.boite(p + Vector3(0, 0.69, 0), Vector3(0.34, 0.03, 0.34), M["laque_noire"])
	a.boite(p + Vector3(0, 0.22, 0), Vector3(0.32, 0.02, 0.32), M["laque_noire"])
	a.lumiere(p + Vector3(0, 0.55, 0), Color("#ffa65a"), 0.9, 3.2)


## Braséro de céramique et ses braises.
static func _hibachi(a: Atelier, M: Dictionary, p: Vector3) -> void:
	a.cyl(p + Vector3(0, 0.17, 0), 0.28, 0.34, M["ceramique_bleue"])
	a.cyl(p + Vector3(0, 0.345, 0), 0.24, 0.02, M["cendre"])
	for k in 6:
		var o := Vector3(0.12, 0, 0).rotated(Vector3.UP, k * TAU / 6.0 + 0.3) * (0.4 + 0.6 * (k % 2))
		a.sphere(p + o + Vector3(0, 0.36, 0), Vector3(0.08, 0.05, 0.07), M["braise"])
	a.lumiere(p + Vector3(0, 0.6, 0), Color("#ff7a35"), 0.7, 2.4)


## Foyer creusé dans le plancher, cendres, braises, marmite de fonte sur un trépied.
static func _irori(a: Atelier, M: Dictionary, p: Vector3) -> void:
	for s in [-1.0, 1.0]:
		a.boite(p + Vector3(0, 0.05, s * 0.6), Vector3(1.32, 0.1, 0.12), M["bois_sombre"])
		a.boite(p + Vector3(s * 0.6, 0.05, 0), Vector3(0.12, 0.1, 1.1), M["bois_sombre"])
	a.boite(p + Vector3(0, 0.03, 0), Vector3(1.1, 0.04, 1.1), M["cendre"])
	for k in 7:
		var o := Vector3(0.18, 0, 0).rotated(Vector3.UP, k * TAU / 7.0) * (0.5 + 0.5 * (k % 2))
		a.sphere(p + o + Vector3(0, 0.06, 0), Vector3(0.1, 0.05, 0.08), M["braise"])
	for k in 3:
		var o := Vector3(0.2, 0, 0).rotated(Vector3.UP, k * TAU / 3.0)
		a.boite(p + o + Vector3(0, 0.13, 0), Vector3(0.025, 0.22, 0.025), M["fer"])
	a.sphere(p + Vector3(0, 0.36, 0), Vector3(0.44, 0.32, 0.44), M["fer"])
	a.cyl(p + Vector3(0, 0.52, 0), 0.17, 0.03, M["bois_sombre"])
	a.lumiere(p + Vector3(0, 0.7, 0), Color("#ff7a35"), 1.0, 3.4)


static func _coffre(a: Atelier, M: Dictionary, p: Vector3, angle: float) -> void:
	a.boite(p + Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.5), M["bois"], angle)
	a.boite(p + Vector3(0, 0.54, 0), Vector3(0.94, 0.08, 0.54), M["bois_sombre"], angle)
	for x in [-0.3, 0.3]:
		a.boite(_r(p, angle, Vector3(x, 0.29, 0)), Vector3(0.05, 0.6, 0.56), M["fer"], angle)
	a.boite(_r(p, angle, Vector3(0, 0.42, 0.27)), Vector3(0.1, 0.12, 0.03), M["or"], angle)


## Paravent à quatre feuilles dorées, avec un pin peint.
static func _byobu(a: Atelier, M: Dictionary, p: Vector3, angle: float) -> void:
	for k in 4:
		var ang := angle + (0.35 if k % 2 == 0 else -0.35)
		var c := _r(p, angle, Vector3((k - 1.5) * 0.47, 0.65, 0))
		a.boite(c, Vector3(0.5, 1.3, 0.03), M["or"], ang)
		a.boite(c + Vector3(0, 0.66, 0), Vector3(0.52, 0.04, 0.05), M["laque_noire"], ang)
		a.boite(c - Vector3(0, 0.62, 0), Vector3(0.52, 0.06, 0.05), M["laque_noire"], ang)
		a.sphere(_r(c, ang, Vector3(0.0, 0.2 - (k % 2) * 0.2, 0.025)), Vector3(0.36, 0.16, 0.01), M["feuille"])
	a.boite_b(_r(p, angle, Vector3(-0.3, 0.55, 0.03)), Basis(Vector3.UP, angle) * Basis(Vector3.BACK, -0.9) * Basis.from_scale(Vector3(0.05, 0.8, 0.01)), M["bois_sombre"])


static func _tonneau(a: Atelier, M: Dictionary, p: Vector3, r: float, h: float) -> void:
	a.cyl(p + Vector3(0, h / 2.0, 0), r, h, M["bois"])
	for y in [0.15, 0.85]:
		a.cyl(p + Vector3(0, h * y, 0), r + 0.012, 0.05, M["fer"])
	a.cyl(p + Vector3(0, h + 0.005, 0), r - 0.02, 0.02, M["bois_sombre"])


static func _caisse(a: Atelier, M: Dictionary, p: Vector3, taille: Vector3, angle: float) -> void:
	a.boite(p + Vector3(0, taille.y / 2.0, 0), taille, M["planches"], angle)
	for y in [0.06, taille.y - 0.06]:
		a.boite(p + Vector3(0, y, 0), taille + Vector3(0.02, -taille.y + 0.07, 0.02), M["bois_sombre"], angle)


## Ballot de riz en paille, couché, serré par trois cordes.
static func _tawara(a: Atelier, M: Dictionary, centre: Vector3, angle: float) -> void:
	a.cyl_couche(centre, 0.25, 0.72, M["chaume"], angle)
	for k in 3:
		a.cyl_couche(_r(centre, angle, Vector3((k - 1) * 0.24, 0, 0)), 0.258, 0.04, M["paille"], angle)
	for s in [-1.0, 1.0]:
		a.cyl_couche(_r(centre, angle, Vector3(s * 0.36, 0, 0)), 0.2, 0.03, M["paille"], angle)


## Tonneau de saké emmailloté de paille, à l'étiquette rouge.
static func _komodaru(a: Atelier, M: Dictionary, p: Vector3) -> void:
	a.cyl(p + Vector3(0, 0.28, 0), 0.27, 0.56, M["paille_claire"])
	a.cyl(p + Vector3(0, 0.565, 0), 0.24, 0.02, M["bois"])
	for y in [0.08, 0.48]:
		a.cyl(p + Vector3(0, y, 0), 0.28, 0.03, M["paille"])
	a.boite(p + Vector3(0, 0.3, 0.27), Vector3(0.24, 0.22, 0.02), M["laque_rouge"])
	a.boite(p + Vector3(0, 0.3, 0.282), Vector3(0.05, 0.16, 0.006), M["encre"])


static func _panier(a: Atelier, M: Dictionary, p: Vector3) -> void:
	a.cyl(p + Vector3(0, 0.14, 0), 0.22, 0.28, M["paille"])
	a.cyl(p + Vector3(0, 0.28, 0), 0.2, 0.01, M["kaki"])
	for k in 4:
		var o := Vector3(0.09, 0, 0).rotated(Vector3.UP, k * 1.7)
		a.sphere(p + o + Vector3(0, 0.3, 0), Vector3(0.09, 0.08, 0.09), M["kaki"])


static func _echelle(a: Atelier, M: Dictionary, p: Vector3, angle: float) -> void:
	for s in [-1.0, 1.0]:
		a.boite(_r(p, angle, Vector3(s * 0.22, 1.1, 0)), Vector3(0.06, 2.2, 0.06), M["bois"], angle)
	for k in 7:
		a.boite(_r(p, angle, Vector3(0, 0.25 + k * 0.3, 0)), Vector3(0.44, 0.04, 0.04), M["bois"], angle)


## Kakis qui sèchent, enfilés sur des cordes pendues à une perche contre le mur.
static func _hoshigaki(a: Atelier, M: Dictionary, p_mur: Vector3, n: int) -> void:
	var p := p_mur + Vector3(0, 0, 0.15)
	a.cyl_couche(p + Vector3(0, 2.0, 0), 0.025, n * 0.35 + 0.3, M["bois"], 0.0)
	for k in n:
		var x := (k - (n - 1) / 2.0) * 0.35
		a.boite(p + Vector3(x, 1.55, 0), Vector3(0.01, 0.9, 0.01), M["paille"])
		for j in 5:
			a.sphere(p + Vector3(x, 1.95 - 0.18 - j * 0.16, 0), Vector3(0.09, 0.11, 0.09), M["kaki"])


static func _bois_de_chauffe(a: Atelier, M: Dictionary, p: Vector3, l: float) -> void:
	var rangs := 5
	for r in rangs:
		var n := int(l / 0.15) - r
		for k in n:
			var x := (k - (n - 1) / 2.0) * 0.15
			a.cyl_b(p + Vector3(x, 0.07 + r * 0.13, 0), Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(0.14, 0.45, 0.14)),
				M["bois"] if (k + r) % 3 != 0 else M["planches"])


static func _etabli(a: Atelier, M: Dictionary, p: Vector3, angle: float) -> void:
	a.boite(p + Vector3(0, 0.72, 0), Vector3(1.6, 0.08, 0.6), M["planches"], angle)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			a.boite(_r(p, angle, Vector3(sx * 0.7, 0.34, sz * 0.22)), Vector3(0.08, 0.68, 0.08), M["bois_sombre"], angle)
	a.boite(_r(p, angle, Vector3(-0.3, 0.77, 0)), Vector3(0.5, 0.01, 0.12), M["acier"], angle + 0.2)  # scie
	a.boite(_r(p, angle, Vector3(-0.05, 0.77, 0.05)), Vector3(0.05, 0.03, 0.3), M["bois"], angle + 0.2)
	a.boite(_r(p, angle, Vector3(0.35, 0.79, -0.1)), Vector3(0.25, 0.06, 0.06), M["fer"], angle - 0.4)  # marteau
	a.boite(_r(p, angle, Vector3(0.45, 0.78, 0.05)), Vector3(0.04, 0.03, 0.28), M["bois"], angle - 0.4)


## Outils appuyés contre le mur : râteau, houe et faux.
static func _outils(a: Atelier, M: Dictionary, p: Vector3, angle: float) -> void:
	for k in 3:
		var q := _r(p, angle, Vector3((k - 1) * 0.4, 0, 0))
		var b := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, -0.15)
		a.boite_b(q + Vector3(0, 0.75, 0), b * Basis.from_scale(Vector3(0.04, 1.5, 0.04)), M["bois"])
		var tete := q + Vector3(0, 1.45, 0) + b.z * -0.1
		match k:
			0:
				a.boite(tete, Vector3(0.4, 0.04, 0.05), M["bois_sombre"], angle)
			1:
				a.boite(tete, Vector3(0.2, 0.18, 0.02), M["fer"], angle)
			_:
				a.boite(tete, Vector3(0.45, 0.03, 0.02), M["acier"], angle + 0.3)


## Manteau de paille (mino) et chapeau conique accrochés au mur.
static func _mino(a: Atelier, M: Dictionary, p_mur: Vector3, angle: float) -> void:
	var p := _r(p_mur, angle, Vector3(0, 0, 0.1))
	a.boite(_r(p, angle, Vector3(0, 1.75, 0)), Vector3(0.08, 0.08, 0.12), M["bois_sombre"], angle)
	a.cone(_r(p, angle, Vector3(0, 1.1, 0.04)), 0.35, 0.8, M["chaume"])
	a.cone(_r(p, angle, Vector3(0.6, 1.4, 0.05)), 0.3, 0.16, M["paille"])


static func _filet(a: Atelier, M: Dictionary, p_mur: Vector3, angle: float) -> void:
	var p := p_mur + Vector3(0, 0, 0.03)
	a.boite(p + Vector3(0, 1.4, 0), Vector3(1.6, 0.9, 0.02), M["filet"], angle)
	for k in 6:
		a.boite(p + Vector3(-0.7 + k * 0.28, 1.4, 0.012), Vector3(0.01, 0.9, 0.01), M["paille"], angle)
	for k in 4:
		a.boite(p + Vector3(0, 1.05 + k * 0.23, 0.012), Vector3(1.6, 0.01, 0.01), M["paille"], angle)
	for k in 5:
		a.sphere(p + Vector3(-0.64 + k * 0.32, 1.88, 0.03), Vector3(0.08, 0.08, 0.08), M["ocre"])


static func _cannes(a: Atelier, M: Dictionary, p: Vector3) -> void:
	for k in 3:
		var b := Basis(Vector3.BACK, -0.12 + k * 0.08) * Basis(Vector3.RIGHT, -0.12)
		a.boite_b(p + Vector3(-k * 0.12, 1.1, 0), b * Basis.from_scale(Vector3(0.025, 2.2, 0.025)), M["bois"] if k != 1 else M["paille"])
	a.cyl(p + Vector3(-0.5, 0.18, 0.2), 0.2, 0.36, M["paille"])  # panier à poissons


static func _banniere(a: Atelier, M: Dictionary, p_mur: Vector3, angle: float) -> void:
	var c := p_mur + Vector3(0, 1.2, 0.04)
	a.boite(c, Vector3(0.6, 1.6, 0.015), M["rouge_tissu"])
	a.cyl_couche(c + Vector3(0, 0.82, 0), 0.02, 0.72, M["laque_noire"], 0.0)
	a.cyl_b(c + Vector3(0, 0.2, 0.012), Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(0.36, 0.01, 0.36)), M["blanc"])
	a.cyl_b(c + Vector3(0, 0.2, 0.016), Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(0.2, 0.01, 0.2)), M["rouge_tissu"])


static func _armure(a: Atelier, M: Dictionary, p: Vector3, angle: float) -> void:
	a.boite(p + Vector3(0, 0.08, 0), Vector3(0.6, 0.16, 0.5), M["bois_sombre"], angle)
	a.boite(p + Vector3(0, 0.45, 0), Vector3(0.05, 0.6, 0.05), M["laque_noire"], angle)
	a.boite(p + Vector3(0, 0.75, 0), Vector3(0.5, 0.26, 0.36), M["laque_noire"], angle)  # kusazuri
	a.boite(p + Vector3(0, 1.02, 0), Vector3(0.44, 0.36, 0.3), M["laque_rouge"], angle)  # dō
	for k in 3:
		a.boite(p + Vector3(0, 0.9 + k * 0.1, 0), Vector3(0.45, 0.012, 0.31), M["or"], angle)
	for s in [-1.0, 1.0]:
		a.boite(_r(p, angle, Vector3(s * 0.3, 1.1, 0)), Vector3(0.14, 0.26, 0.3), M["laque_noire"], angle)  # sode
	a.sphere(p + Vector3(0, 1.36, 0), Vector3(0.3, 0.24, 0.3), M["laque_noire"])  # kabuto
	a.boite(p + Vector3(0, 1.28, 0), Vector3(0.42, 0.04, 0.4), M["laque_noire"], angle)
	for s in [-1.0, 1.0]:
		a.boite_b(_r(p, angle, Vector3(s * 0.07, 1.52, 0.1)), Basis(Vector3.UP, angle) * Basis(Vector3.BACK, s * -0.45) * Basis.from_scale(Vector3(0.03, 0.26, 0.02)), M["or"])


static func _ratelier(a: Atelier, M: Dictionary, p: Vector3, angle: float) -> void:
	for s in [-1.0, 1.0]:
		a.boite(_r(p, angle, Vector3(s * 0.7, 0.8, 0)), Vector3(0.06, 1.6, 0.12), M["bois_sombre"], angle)
	for y in [0.3, 1.5]:
		a.boite(_r(p, angle, Vector3(0, y, 0.02)), Vector3(1.46, 0.06, 0.14), M["bois_sombre"], angle)
	for k in 5:
		var q := _r(p, angle, Vector3(-0.56 + k * 0.28, 0, 0.06))
		a.cyl(q + Vector3(0, 1.05, 0), 0.018, 2.1, M["bois"] if k % 2 == 0 else M["laque_noire"])
		a.cone(q + Vector3(0, 2.18, 0), 0.03, 0.16, M["acier"])


# --- L'atelier : regroupe les pièces par forme et matière en MultiMesh -------------

class Atelier:
	var groupes := {}  # clé -> {"genre", "materiau", "transforms"}
	var lumieres := []  # [position, couleur, énergie, portée]
	var reserve := {"n": [], "o": [], "e": []}  # pans de mur pris par un grand meuble : [début, fin]
	static var _formes := {}

	static func forme(genre: String) -> Mesh:
		if not _formes.has(genre):
			match genre:
				"boite":
					_formes[genre] = BoxMesh.new()
				"cyl":
					var m := CylinderMesh.new()
					m.top_radius = 0.5
					m.bottom_radius = 0.5
					m.height = 1.0
					m.radial_segments = 16
					m.rings = 1
					_formes[genre] = m
				"cone":
					var m := CylinderMesh.new()
					m.top_radius = 0.0
					m.bottom_radius = 0.5
					m.height = 1.0
					m.radial_segments = 14
					m.rings = 1
					_formes[genre] = m
				_:
					var s := SphereMesh.new()
					s.radius = 0.5
					s.height = 1.0
					s.radial_segments = 14
					s.rings = 7
					_formes[genre] = s
		return _formes[genre]

	func ajouter(genre: String, t: Transform3D, m: Material) -> void:
		var cle := "%s_%d" % [genre, m.get_instance_id()]
		if not groupes.has(cle):
			groupes[cle] = {"genre": genre, "materiau": m, "transforms": []}
		groupes[cle]["transforms"].append(t)

	func boite(centre: Vector3, taille: Vector3, m: Material, angle := 0.0) -> void:
		ajouter("boite", Transform3D(Basis(Vector3.UP, angle) * Basis.from_scale(taille), centre), m)

	func boite_b(centre: Vector3, b: Basis, m: Material) -> void:
		ajouter("boite", Transform3D(b, centre), m)

	func cyl(centre: Vector3, rayon: float, hauteur: float, m: Material) -> void:
		ajouter("cyl", Transform3D(Basis.from_scale(Vector3(rayon * 2.0, hauteur, rayon * 2.0)), centre), m)

	func cyl_b(centre: Vector3, b: Basis, m: Material) -> void:
		ajouter("cyl", Transform3D(b, centre), m)

	## Cylindre couché le long de l'axe x (tourné de `angle` autour de la verticale).
	func cyl_couche(centre: Vector3, rayon: float, longueur: float, m: Material, angle: float) -> void:
		var b := Basis(Vector3.UP, angle) * Basis(Vector3.BACK, PI / 2.0) * Basis.from_scale(Vector3(rayon * 2.0, longueur, rayon * 2.0))
		ajouter("cyl", Transform3D(b, centre), m)

	func cone(centre: Vector3, rayon: float, hauteur: float, m: Material) -> void:
		ajouter("cone", Transform3D(Basis.from_scale(Vector3(rayon * 2.0, hauteur, rayon * 2.0)), centre), m)

	func sphere(centre: Vector3, taille: Vector3, m: Material) -> void:
		ajouter("sphere", Transform3D(Basis.from_scale(taille), centre), m)

	func reserver(mur: String, centre: float, demi: float) -> void:
		reserve[mur].append([centre - demi, centre + demi])

	func occupe(mur: String, centre: float, demi: float) -> bool:
		for r in reserve[mur]:
			if centre + demi > r[0] and centre - demi < r[1]:
				return true
		return false

	func lumiere(pos: Vector3, couleur: Color, energie: float, portee: float) -> void:
		lumieres.append([pos, couleur, energie, portee])

	## Crée les MultiMesh (sans ombre) et les lumières sous `parent` (coordonnées locales).
	func finir(c, parent: Node3D, calque: int) -> void:
		var k := 0
		for cle in groupes:
			var g: Dictionary = groupes[cle]
			var liste: Array = g["transforms"]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = forme(g["genre"])
			multi.instance_count = liste.size()
			for i in liste.size():
				multi.set_instance_transform(i, liste[i])
			var rendu := MultiMeshInstance3D.new()
			rendu.name = "Pieces%d" % k
			rendu.multimesh = multi
			rendu.material_override = g["materiau"]
			rendu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rendu.layers = calque
			c.ajouter(parent, rendu)
			k += 1
		for i in lumieres.size():
			var l: Array = lumieres[i]
			var omni := OmniLight3D.new()
			omni.name = "Lumiere%d" % i
			omni.position = l[0]
			omni.light_color = l[1]
			omni.light_energy = l[2]
			omni.omni_range = l[3]
			omni.shadow_enabled = false
			c.ajouter(parent, omni)
