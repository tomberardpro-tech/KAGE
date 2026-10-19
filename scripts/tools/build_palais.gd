extends "res://scripts/tools/constructeur.gd"
## Génère scenes/levels/palais.tscn : niveau 3, le palais du seigneur.
## Lancer : godot --headless --script res://scripts/tools/build_palais.gd
## Le plus difficile : 10 gardes qui voient plus loin et marchent plus vite,
## beaucoup de lanternes, peu d'ombre et un seul autel en route.
## On part du jardin zen au sud, on traverse le jardin du bassin et la cour,
## on reprend le parchemin dans la salle du seigneur et on sort par la brèche ouest.

const H_REMPART := 3.4
const H_MUR := 3.0


func _init() -> void:
	commencer("Palais", Vector2(900, 1200), {
		"numero": 3,
		"titre": "LE PALAIS",
		"lieu": "Le palais",
		"objectif": "Reprends le dernier parchemin du clan dans la salle du seigneur, puis sors par la brèche du rempart ouest.",
		"ou_parchemin": "Il est dans la salle du seigneur, au nord.",
		"ou_sortie": "Maintenant, file par la brèche du rempart ouest.",
		"niveau_suivant": "",
	})

	_sols()
	_remparts()
	_batiments()
	_salle_du_seigneur()
	_jardins()
	limites([
		[-40, 160, 1880, 40], [-40, 2240, 1880, 40], [-40, 200, 40, 2040], [1800, 200, 40, 2040],
	])
	_vegetation()
	lanternes([
		[800, 1840, 3.0], [1000, 1840, 3.0], [500, 2060], [1300, 2060],
		[620, 1300], [1180, 1300], [620, 1720], [1180, 1720], [900, 1780],
		[800, 1160, 3.0], [1000, 1160, 3.0], [420, 960], [1380, 960], [700, 780], [1100, 780],
		[600, 420], [1200, 420],
	])
	gardes([
		["GardePorteSud", 900, 1820, []],
		["GardeZen", 1100, 1980, [[1050, 1980], [1500, 1980]]],
		["GardeJardinOuest", 560, 1250, [[560, 1250], [560, 1750]]],
		["GardeJardinEst", 1240, 1750, [[1240, 1750], [1240, 1250]]],
		["GardePont", 900, 1290, []],
		["GardePorteInterieure", 900, 1030, []],
		["GardeCourOuest", 200, 1010, [[200, 1010], [780, 1010]]],
		["GardeCourEst", 1600, 1010, [[1600, 1010], [1020, 1010]]],
		["GardeCourNord", 300, 730, [[300, 730], [1500, 730]]],
		["GardeSalle", 1200, 560, [[1200, 560], [600, 560]]],
	], {"vitesse": 1.8, "portee": 8.5, "demi_angle": 30.0, "portee_penombre": 2.4})
	autels([["Depart", 900, 2150], ["AutelJardin", 1540, 1790]])
	parchemin(900, 420)
	sortie(80, 440, Vector3(2.0, 2.0, 4.8))
	joueur(900, 2090)
	finir("res://scenes/levels/palais.tscn")


func _sols() -> void:
	boite("Sol", -40, 200, 1880, 2040, 2.0, "herbe", null, -2.0)
	boite("JardinZen", 140, 1920, 1520, 260, 0.02, "sable")
	boite("Cour", 140, 300, 1520, 780, 0.02, "pave")
	boite("AlleeSud", 860, 1920, 80, 300, 0.03, "allee")
	boite("AlleeCour", 860, 700, 80, 380, 0.03, "allee")


func _remparts() -> void:
	mur("RempartSudOuest", 100, 1880, 740, 40, H_REMPART)
	mur("RempartSudEst", 960, 1880, 740, 40, H_REMPART)
	mur("RempartOuestSud", 100, 500, 40, 1380, H_REMPART)
	mur("RempartOuestNord", 100, 260, 40, 120, H_REMPART)
	mur("RempartEst", 1660, 260, 40, 1620, H_REMPART)
	mur("RempartNord", 140, 260, 1520, 40, H_REMPART)
	mur("MurInterieurOuest", 140, 1080, 700, 40, H_MUR)
	mur("MurInterieurEst", 960, 1080, 700, 40, H_MUR)
	# Montants des portes, en laque rouge
	for x in [830, 960]:
		boite("PorteSud%d" % x, x, 1870, 10, 60, H_REMPART + 0.6, "laque")
		boite("PorteInterieure%d" % x, x, 1070, 10, 60, H_MUR + 0.6, "laque")
	boite("LinteauSud", 830, 1870, 140, 60, 0.4, "tuiles", null, H_REMPART + 0.6)
	boite("LinteauInterieur", 830, 1070, 140, 60, 0.4, "tuiles", null, H_MUR + 0.6)
	boite("LinteauBreche", 95, 380, 50, 120, 0.4, "tuiles", null, H_REMPART)


func _batiments() -> void:
	# Remise contre le rempart : son toit permet de passer par-dessus.
	batiment("Remise", 220, 1930, 160, 100, 1.5)
	# Galeries du jardin, collées au mur intérieur : on peut passer de leur toit à la cour.
	batiment("GalerieOuest", 140, 1120, 260, 560, 1.9)
	batiment("GalerieEst", 1400, 1120, 260, 560, 1.9)
	batiment("Cuisines", 250, 770, 260, 190, 1.9)
	batiment("PavillonThe", 1300, 770, 220, 170, 1.8)


## Salle du seigneur : sans toit pour voir l'intérieur, porte au sud.
func _salle_du_seigneur() -> void:
	var e := 16.0
	boite("SalleSol", 500, 320, 800, 380, 0.04, "parquet")
	for i in 5:
		boite("Tatami%d" % i, 560 + i * 140, 380, 120, 260, 0.06, "tatami")
	boite("TapisRouge", 880, 380, 40, 300, 0.07, "laque")
	var murs := [
		["SalleMurNord", 500, 320, 800, e], ["SalleMurOuest", 500, 320, e, 380],
		["SalleMurEst", 1300 - e, 320, e, 380], ["SalleMurSudOuest", 500, 700 - e, 340, e],
		["SalleMurSudEst", 960, 700 - e, 340, e],
	]
	for m in murs:
		mur(m[0], m[1], m[2], m[3], m[4], H_REMPART)


## Bassin aux carpes avec son pont rouge, et rochers du jardin zen.
func _jardins() -> void:
	boite("Bassin", 700, 1350, 400, 260, 0.04, "eau")
	boite("Pont", 860, 1330, 80, 300, 0.2, "laque")
	boite("Rocher0", 450, 2000, 60, 60, 0.6, "pierre")
	boite("Rocher1", 1250, 2050, 80, 60, 0.7, "pierre")
	boite("Rocher2", 650, 2120, 50, 50, 0.5, "pierre")


func _vegetation() -> void:
	herbes([[480, 1200, 160, 100], [1160, 1780, 160, 80], [560, 880, 140, 90], [160, 2180, 300, 50]])
	arbres([[450, 1450, 120], [1300, 1500, 120], [300, 400, 130]])
	clair_de_lune("ClairDeLune", 900, 880, 500, 300)
	clair_de_lune("ClairDeLuneJardin", 900, 1480, 400, 300)
	higanbanas(120, 2200, 0, 1800, 2190, 2240, 900)
