extends "res://scripts/tools/decor.gd"
## Génère scenes/levels/chateau.tscn à partir du plan Figma « Niveau 1 · Le château ».
## Lancer : godot --headless --script res://scripts/tools/build_chateau.gd
## Le centre du plan (900, 1350) devient l'origine.

const H_REMPART := 3.4
const H_MUR := 3.0
const H_DONJON := 3.4


func _init() -> void:
	commencer("Chateau", Vector2(900, 1350), {
		"numero": 2,
		"titre": "LE CHÂTEAU",
		"lieu": "Le château",
		"objectif": "Récupère le parchemin du clan dans le donjon, puis sors par le rempart est.",
		"ou_parchemin": "Il est dans le donjon.",
		"ou_sortie": "Maintenant, file par la sortie du rempart est.",
		"niveau_suivant": "res://scenes/levels/palais.tscn",
	})

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
	_decor()
	joueur(900, 2240)
	finir("res://scenes/levels/chateau.tscn")


# --- Construction -------------------------------------------------------

func _sols() -> void:
	# Sol général (herbe) avec la tranchée des douves creusée dedans
	var sol := boite("Sol", 80, 200, 1640, 2160, 2.0, "herbe", null, -2.0)
	var douves := boite("Douves", 80, 1900, 1640, 90, 1.2, "eau", null, -1.2)
	douves.operation = CSGShape3D.OPERATION_SUBTRACTION
	# Cours pavées (légèrement surélevées pour ne pas scintiller)
	boite("CourExterieure", 180, 1360, 1440, 480, 0.02, "herbe")
	boite("CourInterieure", 180, 760, 1440, 560, 0.02, "pave")
	boite("AlleeExterieure", 860, 1360, 80, 480, 0.03, "allee")
	boite("AlleeInterieure", 870, 900, 60, 420, 0.03, "allee")
	boite("PasDePorte", 860, 1320, 80, 40, 0.03, "allee")
	boite("AlleeDepart", 860, 2000, 80, 320, 0.03, "allee")


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


func _batiments() -> void:
	batiment("Remise", 580, 1680, 160, 110, 1.5)
	batiment("Caserne", 220, 820, 340, 420, 1.9)
	batiment("Entrepot", 1240, 820, 340, 420, 1.9)


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
	eau("Eau", 80, 1900, 1640, 90, -0.45)
	boite("PontLevis", 840, 1890, 120, 110, 0.15, "bois", null, -0.1)
	boite("Etang", 1100, 1630, 180, 130, 0.04, "eau")


## Murs invisibles : bord de la carte et bords des douves (sauf le pont).
func _limites() -> void:
	limites([
		[80, 160, 1640, 40], [80, 2360, 1640, 40], [40, 200, 40, 2160], [1720, 200, 40, 2160],
		[80, 1990, 760, 10], [960, 1990, 760, 10], [80, 1890, 60, 10], [1660, 1890, 60, 10],
	])


func _vegetation() -> void:
	herbes([
		[200, 2100, 260, 170], [1280, 2080, 300, 180], [230, 1620, 220, 160],
		[1330, 1680, 240, 130], [640, 1400, 180, 110], [680, 1200, 180, 100],
	])
	arbres([[1380, 1380, 110], [220, 1400, 90], [640, 1020, 140], [1030, 960, 150]])
	clair_de_lune("ClairDeLune", 900, 950, 400, 300)
	higanbanas(260, 1350, 100, 1700, 2030, 2340, 900)


func _lanternes() -> void:
	# Les lanternes de la grande porte (rayon 3) laissent un passage sombre le long du mur.
	lanternes([[740, 1790, 3.0], [1060, 1790, 3.0], [480, 1520], [1260, 1460],
		[780, 1380], [1020, 1380], [740, 840], [1060, 840], [900, 1100]])


func _gardes() -> void:
	gardes([
		["GardePorteSud", 900, 1760, []],
		["GardeOuest", 460, 1540, [[380, 1540], [720, 1540]]],
		["GardeEst", 1280, 1530, [[1460, 1530], [1080, 1530]]],
		["GardePorteInterieure", 900, 1395, []],
		["GardeCourNord", 640, 920, [[620, 920], [1160, 920]]],
		["GardeCourSud", 1160, 1160, [[1160, 1160], [700, 1160]]],
		["GardeDonjon", 900, 660, []],
	])


func _objectifs() -> void:
	# Plancher rossignol dans le donjon, fils à clochettes sur les passages discrets des cours.
	rossignols([[516, 356, 768, 388]])
	clochettes([[190, 1250, 560, 1250], [1300, 1180, 1610, 1180], [580, 1000, 580, 1300]])
	autels([["Depart", 900, 2290], ["AutelOuest", 340, 1760], ["AutelEst", 1430, 1280]])
	parchemin(900, 530)
	sortie(1650, 510, Vector3(2.0, 2.0, 4.8))


## Décor d'ambiance (ticket 4.4) : rien de tout ça ne gêne le passage ni la vue des gardes.
func _decor() -> void:
	# Devant le château : pont rouge, bannières, berges des douves
	pont_rouge(840, 1890, 120, 110, 0.05)
	bannieres([[790, 2040, 0], [1010, 2040, 0], [705, 1290, 0], [1095, 1290, 0]])
	braseros([[790, 1800], [1010, 1800], [780, 800], [1020, 800]])
	buissons([
		[300, 2025, 1.2], [420, 2018, 0.9], [1380, 2025, 1.2], [1500, 2018, 0.9],
		[150, 2310, 1.5], [1650, 2310, 1.5], [620, 2030, 0.8], [1180, 2030, 0.8],
		# Cour extérieure, contre les remparts et la remise
		[220, 1812, 1.0], [470, 1812, 0.9], [1150, 1812, 1.0], [1300, 1812, 0.8], [1520, 1812, 1.1],
		[760, 1700, 0.8], [1600, 1400, 1.0],
		# Cour intérieure, devant la caserne et l'entrepôt
		[600, 850, 0.9], [1220, 850, 0.9], [1225, 1290, 0.8], [210, 1290, 0.9],
	])
	rochers([
		[230, 2200, 1.2, 0], [1560, 2180, 1.0, 1], [700, 2300, 0.6, 6], [1120, 2290, 0.5, 7],
		[1300, 1740, 0.6, 2], [1095, 1620, 0.5, 6], [660, 1250, 0.5, 7], [1140, 1255, 0.6, 6],
	])
	# L'étang de la cour extérieure, avec sa cascade
	cascade("Cascade", 1190, 1648, 1.8)
	nenuphars(1110, 1690, 160, 60, 9)
	berge(1100, 1630, 180, 130)
	berge(80, 1900, 760, 90)
	berge(960, 1900, 760, 90)
	massif_higanbanas(1290, 1640, 50, 110, 22)
	massif_higanbanas(620, 1170, 60, 50, 14)
	bambous(1560, 1380, 50, 140, 10)
	bambous(185, 1560, 40, 50, 6)
	bambous(190, 770, 280, 40, 12)
	bambous(1330, 770, 270, 40, 12)
	parsemer(100, 2000, 1600, 340, 90)
	parsemer(190, 1370, 1420, 460, 60)
	lucioles([[150, 2020, 600, 300], [1050, 2020, 600, 300], [200, 1600, 300, 200],
		[1300, 1640, 300, 170], [600, 980, 220, 200], [1000, 920, 220, 200]])
	brume([[80, 1880, 800, 130], [920, 1880, 800, 130], [100, 2250, 1600, 110], [1080, 1600, 240, 200]])
