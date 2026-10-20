extends "res://scripts/tools/decor.gd"
## Génère scenes/levels/chateau.tscn : le seul niveau du jeu.
## Au sud, un petit village dans la forêt (départ dans la cabane du maître, ruisseau et pont,
## étang, villageois et chats). Au nord, le château du plan Figma « Niveau 1 · Le château » :
## on ouvre la grande porte, on traverse les cours et, au cœur du donjon, le seigneur Oni garde
## le parchemin. La herse tombe, on le combat, un coffre apparaît. Puis on fuit par le rempart est.
## Lancer : godot --path . -- --construire=res://scripts/tools/build_chateau.gd
## Le centre du plan (900, 1350) devient l'origine.

const H_REMPART := 3.4
const H_MUR := 3.0
const H_DONJON := 3.4


func _init() -> void:
	commencer("Chateau", Vector2(900, 1350), {
		"numero": 1,
		"titre": "LE CHÂTEAU DU SEIGNEUR ONI",
		"lieu": "Le château",
		"objectif": "Traverse la forêt, ouvre la grande porte et reprends le parchemin du clan au seigneur Oni, au cœur du donjon. Puis fuis par le rempart est.",
		"ou_parchemin": "Le parchemin est dans le donjon, gardé par le seigneur Oni.",
		"ou_sortie": "Maintenant, fuis par le rempart est.",
		"niveau_suivant": "",
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
	_village()
	joueur(884, 3337, deg_to_rad(64))
	finir("res://scenes/levels/chateau.tscn")


# --- Construction -------------------------------------------------------

func _sols() -> void:
	# Sol général (herbe) avec la tranchée des douves creusée dedans
	var sol := boite("Sol", 80, 200, 1640, 3300, 2.0, "herbe", null, -2.0)
	var douves := boite("Douves", 80, 1900, 1640, 90, 1.2, "eau", null, -1.2)
	douves.operation = CSGShape3D.OPERATION_SUBTRACTION
	# Cours pavées (légèrement surélevées pour ne pas scintiller)
	boite("CourExterieure", 180, 1360, 1440, 480, 0.02, "herbe")
	boite("CourInterieure", 180, 760, 1440, 560, 0.02, "pave")
	boite("AlleeExterieure", 860, 1360, 80, 480, 0.03, "allee")
	boite("AlleeInterieure", 870, 900, 60, 420, 0.03, "allee")
	boite("PasDePorte", 860, 1320, 80, 40, 0.03, "allee")
	boite("AlleeDepart", 860, 2000, 80, 320, 0.03, "allee")
	boite("CheminForet", 870, 2320, 60, 980, 0.03, "terre")


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
	# La grande porte : fermée au début, E pour l'ouvrir
	grande_porte(840, 1860, 120, H_REMPART + 0.6)
	boite("LinteauSortie", 1615, 450, 50, 120, 0.4, "tuiles", null, H_REMPART)


func _batiments() -> void:
	batiment("Remise", 580, 1680, 160, 110, 1.5)
	batiment("Caserne", 220, 820, 340, 420, 1.9)
	batiment("Entrepot", 1240, 820, 340, 420, 1.9)


func _donjon() -> void:
	var e := 16.0  # épaisseur des murs en px
	# Grand toit à deux étages, qui s'efface quand on entre (on voit alors l'intérieur).
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
	toit_japonais("DonjonToit", 500, 340, 800, 420, H_DONJON, 2)
	# Salle du combat : la herse tombe derrière le ninja, le seigneur Oni attend au fond
	herse("HerseDonjon", 820, 752, 160, H_DONJON)
	seigneur(900, 450, 900, 560)
	declencheur("ArriveeDonjon", 520, 360, 760, 330)


func _douves() -> void:
	eau("Eau", 80, 1900, 1640, 90, -0.45)
	boite("PontLevis", 840, 1890, 120, 110, 0.15, "bois", null, -0.1)
	boite("Etang", 1100, 1630, 180, 130, 0.04, "eau")


## Murs invisibles : bord de la carte et bords des douves (sauf le pont).
func _limites() -> void:
	limites([
		[80, 160, 1640, 40], [80, 3480, 1640, 40], [40, 200, 40, 3300], [1720, 200, 40, 3300],
		[80, 1990, 760, 10], [960, 1990, 760, 10], [80, 1890, 60, 10], [1660, 1890, 60, 10],
	])


func _vegetation() -> void:
	herbes([
		[200, 2100, 260, 170], [1280, 2080, 300, 180], [230, 1620, 220, 160],
		[1330, 1680, 240, 130], [640, 1400, 180, 110], [680, 1200, 180, 100],
	])
	arbres([[1380, 1380, 110, true], [220, 1400, 90, true], [640, 1020, 140], [1030, 960, 150]])
	clair_de_lune("ClairDeLune", 900, 950, 400, 300)
	higanbanas(700, 1350, 100, 1700, 2030, 3450, 900)


func _lanternes() -> void:
	# Les lanternes de la grande porte (rayon 3) laissent un passage sombre le long du mur.
	lanternes([[740, 1790, 3.0], [1060, 1790, 3.0], [480, 1520], [1260, 1460],
		[780, 1380], [1020, 1380], [740, 840], [1060, 840], [900, 1100]])


func _gardes() -> void:
	gardes([
		["GardePorteSud", 1000, 1760, [[1000, 1760], [1400, 1760]]],
		["GardeOuest", 460, 1540, [[380, 1540], [720, 1540]]],
		["GardeEst", 1280, 1530, [[1460, 1530], [1080, 1530]]],
		["GardePorteInterieure", 900, 1395, []],
		["GardeCourNord", 640, 920, [[620, 920], [1160, 920]]],
		["GardeCourSud", 1160, 1160, [[1160, 1160], [700, 1160]]],
		# dehors : la ronde le long des douves et sur le chemin de la forêt
		["GardeDouves", 520, 2090, [[500, 2090], [1300, 2090]]],
		["GardeChemin", 880, 2390, [[880, 2390], [880, 2560]]],
	])


func _objectifs() -> void:
	# Guirlandes de lanternes au-dessus des cours et des allées ; le parchemin est dans le coffre du seigneur.
	guirlandes([[200, 1250, 560, 1250], [1300, 1180, 1600, 1180], [830, 1480, 970, 1480], [830, 1700, 970, 1700]])
	autels([["Depart", 870, 3375], ["AutelPorte", 1060, 2240], ["AutelOuest", 340, 1760], ["AutelEst", 1430, 1280],
		["AutelDonjon", 760, 830]])
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
	carpes(1115, 1650, 150, 100, 4)
	berge(1100, 1630, 180, 130)
	berge(80, 1900, 760, 90)
	berge(960, 1900, 760, 90)
	massif_higanbanas(1290, 1640, 50, 110, 35)
	massif_higanbanas(620, 1170, 60, 50, 22)
	bambous(1560, 1380, 50, 140, 10)
	bambous(185, 1560, 40, 50, 6)
	bambous(190, 770, 280, 40, 12)
	bambous(1330, 770, 270, 40, 12)
	parsemer(100, 2000, 1600, 340, 90)
	parsemer(190, 1370, 1420, 460, 60)
	lucioles([[150, 2020, 600, 300], [1050, 2020, 600, 300], [200, 1600, 300, 200],
		[1300, 1640, 300, 170], [600, 980, 220, 200], [1000, 920, 220, 200]])
	brume([[80, 1880, 800, 130], [920, 1880, 800, 130], [100, 2250, 1600, 110], [1080, 1600, 240, 200]])


# --- Le village de la forêt, au sud des douves ---------------------------------

func _village() -> void:
	# Cabane du maître, ouverte au nord ; mur sud bas pour que la caméra voie dedans
	var e := 12.0
	boite("CabaneSol", 830, 3300, 140, 110, 0.05, "parquet")
	for m in [["CabaneOuest", 830, 3300, e, 110], ["CabaneEst", 970 - e, 3300, e, 110],
			["CabaneNordOuest", 830, 3300, 42, e], ["CabaneNordEst", 928, 3300, 42, e]]:
		boite(m[0], m[1], m[2], m[3], m[4], 2.2, "bois")
	boite("CabaneSud", 830, 3410 - e, 140, e, 0.8, "bois")
	toit_japonais("CabaneToit", 830, 3300, 140, 110, 2.2, 1, "chaume")
	maitre(918, 3351, deg_to_rad(-115))
	# Maisons au toit de chaume, toutes escaladables
	batiment("MaisonPecheur", 380, 2470, 220, 150, 1.6, "chaume")
	batiment("MaisonPotier", 1200, 2470, 220, 150, 1.6, "chaume")
	batiment("Grenier", 400, 2950, 190, 150, 1.9, "chaume")
	batiment("MaisonTisserand", 1220, 3160, 200, 150, 1.7, "chaume")
	boite("Puits", 700, 2860, 50, 50, 0.7, "pierre")
	# Ruisseau qui traverse la forêt d'ouest en est, et le pont rouge du chemin
	ruisseau("Ruisseau", [[80, 2770], [400, 2745], [700, 2770], [900, 2760], [1150, 2775], [1450, 2750], [1720, 2770]], 46)
	boite("PontForet", 865, 2700, 70, 120, 0.12, "bois")
	pont_rouge(865, 2700, 70, 120, 0.1)
	# Étang aux carpes, avec sa petite cascade
	boite("EtangForet", 1180, 2880, 240, 160, 0.04, "eau")
	berge(1180, 2880, 240, 160)
	cascade("CascadeForet", 1300, 2886, 1.4)
	nenuphars(1190, 2940, 220, 90, 10)
	carpes(1200, 2900, 200, 130, 5)
	torii(900, 3235, 3.4)
	guirlandes([[820, 2450, 980, 2450], [820, 2630, 980, 2630], [820, 2930, 980, 2930], [820, 3120, 980, 3120],
		[600, 2545, 820, 2545], [980, 2545, 1200, 2545]])
	herbes([[200, 2850, 250, 120], [1450, 2900, 220, 140],
		[600, 3200, 200, 120], [380, 2650, 260, 80]])
	# Gros buissons où se cacher : devant les douves (la ronde des gardes), dans le village et au château
	cachettes([[620, 2130, 2.4], [1180, 2120, 2.4], [420, 2210, 2.2], [1400, 2200, 2.6], [760, 2330, 2.0],
		[1040, 2330, 2.0], [780, 2470, 2.0], [1020, 2520, 2.0], [200, 2600, 2.4], [1600, 2620, 2.4],
		[250, 3220, 2.6], [1560, 3350, 2.4], [700, 3050, 2.0], [1080, 2660, 2.2],
		[300, 1700, 2.2], [1480, 1460, 2.2], [700, 1480, 2.0], [700, 1250, 2.0], [1120, 1240, 2.0]])
	arbres([[120, 2380, 120], [1560, 2380, 130], [640, 2630, 110, true], [1060, 2830, 120], [240, 3040, 130],
		[1520, 3040, 120, true], [600, 3360, 110], [1180, 3360, 120]])
	lanternes([[830, 2420, 2.5], [970, 2420, 2.5], [620, 2580], [1180, 2650], [640, 3010], [1170, 3120]])
	villageois([
		[560, 2660, 90, "#6d8fb3", "こんばんは、影様。", "Bonsoir, Kage.", 720, 2660],
		[480, 3120, 180, "#a3674a", "鬼の殿には気をつけて…", "Méfie-toi du seigneur Oni…"],
		[1150, 2640, -90, "#8a9a5b", "雨の夜は静かでいいね。", "Les nuits de pluie sont si calmes."],
		[1040, 3200, 0, "#b8836a", "がんばって、影様！", "Bonne chance, Kage !", 1040, 3020],
	])
	chats([[1180, 2640, 200], [610, 3095, 40], [995, 3420, 120]])
	grenouilles([[1300, 2960], [300, 2760], [1500, 2760], [700, 2780]])
	braseros([[530, 3140]])
	bannieres([[840, 3260, 0], [960, 3260, 0]])
	rochers([[1150, 2870, 0.8, 2], [1430, 3040, 0.7, 0], [330, 2760, 0.6, 6], [1500, 2780, 0.6, 7],
		[160, 3400, 1.2, 1], [1650, 3420, 1.1, 0]])
	buissons([[600, 2470, 1.0], [1180, 2470, 0.9], [640, 2950, 0.9], [1440, 3170, 1.0], [800, 3420, 0.9], [1000, 3290, 0.8]])
	bambous(100, 2420, 50, 300, 10)
	bambous(1650, 2420, 50, 300, 10)
	bambous(120, 3250, 300, 50, 10)
	massif_higanbanas(820, 3140, 40, 90, 18)
	massif_higanbanas(940, 3140, 40, 90, 18)
	parsemer(100, 2020, 1600, 1440, 220)
	# Lucioles autour des arbres et au-dessus du ruisseau
	lucioles([[80, 2340, 200, 200], [1520, 2340, 210, 210], [600, 2590, 190, 190], [1020, 2790, 200, 200],
		[200, 3000, 210, 210], [1480, 3000, 200, 200], [560, 3320, 190, 190], [1140, 3320, 200, 200],
		[300, 2720, 500, 100], [1000, 2720, 500, 100], [1180, 2880, 240, 160]])
	brume([[80, 2720, 800, 110], [920, 2720, 800, 110], [1180, 2880, 240, 160], [100, 3380, 1600, 100]])
