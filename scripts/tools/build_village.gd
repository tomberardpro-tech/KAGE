extends "res://scripts/tools/decor.gd"
## Génère scenes/levels/village.tscn : niveau 1, le village au pied du château.
## Lancer : godot --headless --script res://scripts/tools/build_village.gd
## Niveau d'apprentissage : peu de gardes, myopes et lents, beaucoup d'ombre.
## Un premier fil à clochettes sur le chemin et un plancher qui grince chez le chef.
## On part des rizières au sud, on traverse le village et on prend le plan du château
## chez le chef, puis on sort par le portail nord-est.

const H_PALISSADE := 2.0  # assez bas pour qu'on l'escalade


func _init() -> void:
	commencer("Village", Vector2(600, 850), {
		"numero": 1,
		"titre": "LE VILLAGE",
		"lieu": "Le village",
		"objectif": "Vole le plan du château chez le chef du village, au nord, puis file par le portail nord-est.",
		"ou_parchemin": "Le plan est chez le chef, au nord du village.",
		"ou_sortie": "Maintenant, file par le portail nord-est.",
		"niveau_suivant": "res://scenes/levels/chateau.tscn",
	})

	_sols()
	_palissade()
	_maisons()
	_maison_du_chef()
	_rizieres()
	limites([
		[-40, -40, 1280, 40], [-40, 1700, 1280, 40], [-40, 0, 40, 1700], [1200, 0, 40, 1700],
	])
	_vegetation()
	lanternes([[540, 1290, 3.0], [660, 1290, 3.0], [530, 1060], [700, 860], [520, 620],
		[1000, 160, 3.0]])
	gardes([
		["GardePortail", 600, 1210, []],
		["GardeRiziere", 260, 1480, [[180, 1480], [470, 1480]], {"regard": Vector3.RIGHT}],
		["GardeRue", 420, 950, [[420, 950], [780, 950]]],
		["GardeChef", 600, 470, []],
	], {"vitesse": 1.3, "portee": 6.0, "portee_penombre": 1.6})
	rossignols([[436, 176, 328, 188]])
	clochettes([[540, 560, 660, 560]])
	autels([["Depart", 600, 1640], ["AutelGrenier", 1010, 520]])
	parchemin(600, 260)
	sortie(1050, 60, Vector3(4.0, 2.0, 2.0))
	_decor()
	joueur(600, 1590)
	finir("res://scenes/levels/village.tscn")


func _sols() -> void:
	boite("Sol", -40, -40, 1280, 1780, 2.0, "herbe", null, -2.0)
	boite("Chemin", 560, 100, 80, 1600, 0.03, "terre")
	boite("Place", 380, 720, 440, 300, 0.02, "terre")
	boite("CheminNord", 640, 120, 420, 60, 0.03, "terre")


## Palissade en bois autour du village, avec le portail sud et le portail nord-est.
func _palissade() -> void:
	var e := 20.0
	var pieux := [
		["PalissadeSudOuest", 60, 1250, 480, e], ["PalissadeSudEst", 660, 1250, 480, e],
		["PalissadeOuest", 60, 100, e, 1170], ["PalissadeEst", 1120, 100, e, 1170],
		["PalissadeNordOuest", 60, 100, 940, e], ["PalissadeNordEst", 1100, 100, 40, e],
	]
	for p in pieux:
		boite(p[0], p[1], p[2], p[3], p[4], H_PALISSADE, "bois")
	for x in [530, 660]:
		boite("Portail%d" % x, x, 1240, 10, 40, H_PALISSADE + 0.8, "laque")
	boite("LinteauSud", 520, 1240, 160, 40, 0.3, "tuiles", null, H_PALISSADE + 0.8)
	for x in [990, 1100]:
		boite("PortailNord%d" % x, x, 90, 10, 40, H_PALISSADE + 0.8, "laque")


## Maisons au toit de chaume, toutes escaladables.
func _maisons() -> void:
	batiment("MaisonPecheur", 140, 1020, 220, 160, 1.6, "chaume")
	batiment("MaisonPotier", 840, 1040, 220, 150, 1.6, "chaume")
	batiment("MaisonTisserand", 150, 640, 200, 180, 1.8, "chaume")
	batiment("Grenier", 860, 640, 200, 160, 1.9, "chaume")
	# Le puits sur la place
	boite("Puits", 690, 760, 50, 50, 0.7, "pierre")


## Maison du chef : murs sans toit pour voir l'intérieur, porte au sud.
func _maison_du_chef() -> void:
	var e := 16.0
	boite("ChefSol", 420, 160, 360, 220, 0.04, "parquet")
	for i in 2:
		boite("ChefTatami%d" % i, 500 + i * 120, 200, 100, 140, 0.06, "tatami")
	var murs := [
		["ChefMurNord", 420, 160, 360, e], ["ChefMurOuest", 420, 160, e, 220],
		["ChefMurEst", 780 - e, 160, e, 220], ["ChefMurSudOuest", 420, 380 - e, 140, e],
		["ChefMurSudEst", 640, 380 - e, 140, e],
	]
	for m in murs:
		mur(m[0], m[1], m[2], m[3], m[4], 2.6)


## Rizières inondées au sud : à découvert, mais bordées d'herbes hautes.
func _rizieres() -> void:
	boite("RiziereOuest", 100, 1340, 380, 100, 0.04, "eau")
	boite("RiziereEst", 720, 1340, 380, 100, 0.04, "eau")
	boite("RiziereOuestSud", 100, 1540, 380, 60, 0.04, "eau")
	boite("RiziereEstSud", 720, 1540, 380, 60, 0.04, "eau")


func _vegetation() -> void:
	herbes([
		[100, 1450, 380, 80], [720, 1450, 380, 80], [380, 1100, 140, 100],
		[960, 820, 140, 110], [200, 450, 180, 120], [820, 200, 160, 140],
	])
	arbres([[400, 840, 120], [720, 1110, 110, true], [940, 880, 110], [160, 860, 100], [880, 420, 130, true]])
	clair_de_lune("ClairDeLune", 600, 860, 300, 220)
	higanbanas(140, 850, 0, 1200, 1620, 1700, 600)


## Décor d'ambiance (ticket 4.4) : rien de tout ça ne gêne le passage ni la vue des gardes.
func _decor() -> void:
	# Rondins pointus sur les deux faces de la palissade
	pieux(60, 1250, 480, 20, H_PALISSADE)
	pieux(660, 1250, 480, 20, H_PALISSADE)
	pieux(60, 100, 20, 1170, H_PALISSADE)
	pieux(1120, 100, 20, 1170, H_PALISSADE)
	pieux(60, 100, 940, 20, H_PALISSADE)
	pieux(1100, 100, 40, 20, H_PALISSADE)
	# Ruisseau qui traverse le village, avec son petit pont rouge sur le chemin
	ruisseau("Ruisseau", [[70, 1225], [300, 1208], [520, 1220], [700, 1212], [900, 1224], [1110, 1210]], 30)
	pont_rouge(570, 1182, 60, 70, 0.05)
	for r in [[100, 1340, 380, 100], [720, 1340, 380, 100], [100, 1540, 380, 60], [720, 1540, 380, 60]]:
		riz(r[0], r[1], r[2], r[3])
	bannieres([[490, 1305, 0], [710, 1305, 0]])
	buissons([
		[100, 1150, 1.0], [1090, 1150, 1.0], [820, 1070, 0.8], [130, 600, 1.0], [1080, 600, 1.0],
		[400, 400, 0.9], [800, 400, 0.9], [370, 1010, 0.8], [90, 1300, 1.1], [1110, 1300, 1.1],
	])
	rochers([[250, 1300, 0.7, 2], [950, 1305, 0.8, 0], [745, 790, 0.4, 7], [180, 940, 0.5, 6]])
	bambous(90, 130, 300, 50, 12)
	bambous(1075, 200, 35, 280, 10)
	parsemer(60, 1270, 1080, 70, 40)
	parsemer(80, 120, 1040, 1120, 110)
	lucioles([[100, 1340, 500, 260], [600, 1340, 500, 260], [120, 820, 200, 200], [860, 380, 200, 200]])
	brume([[100, 1330, 500, 280], [600, 1330, 500, 280], [60, 1190, 1080, 60]])
