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
	joueur(872, 3345, deg_to_rad(64))
	finir("res://scenes/levels/chateau.tscn")


# --- Construction -------------------------------------------------------

func _sols() -> void:
	# Sol général (herbe) avec la tranchée des douves creusée dedans
	var sol := boite("Sol", 80, 200, 1640, 3300, 2.0, "herbe", null, -2.0)
	var douves := boite("Douves", 80, 1900, 1640, 90, 1.2, "eau", null, -1.2)
	douves.operation = CSGShape3D.OPERATION_SUBTRACTION
	# Cours pavées (légèrement surélevées pour ne pas scintiller)
	# cours du château pavées (plus d'herbe dedans)
	boite("CourExterieure", 180, 1360, 1440, 480, 0.02, "pave")
	boite("CourDonjon", 180, 340, 1440, 420, 0.02, "pave")
	boite("CourInterieure", 180, 760, 1440, 560, 0.02, "pave")
	boite("AlleeExterieure", 860, 1360, 80, 480, 0.03, "allee")
	boite("AlleeInterieure", 870, 900, 60, 420, 0.03, "allee")
	boite("PasDePorte", 860, 1320, 80, 40, 0.03, "allee")
	boite("SeuilInterieur", 740, 1320, 320, 40, 0.02, "pave")


func _remparts() -> void:
	# Remparts : base de pierres, planches sombres, bandeau blanc et toit rouge
	rempart("RempartSudOuest", 140, 1840, 700, 40, H_REMPART)
	rempart("RempartSudEst", 960, 1840, 700, 40, H_REMPART)
	rempart("RempartOuest", 140, 300, 40, 1540, H_REMPART)
	rempart("RempartEstNord", 1620, 300, 40, 150, H_REMPART)
	rempart("RempartEstSud", 1620, 570, 40, 1270, H_REMPART)
	rempart("RempartNord", 180, 300, 1440, 40, H_REMPART)
	# tourelles aux quatre coins, et la tour au-dessus de la grande porte
	yagura("YaguraSudOuest", 160, 1860)
	yagura("YaguraSudEst", 1640, 1860)
	yagura("YaguraNordOuest", 160, 320)
	yagura("YaguraNordEst", 1640, 320)
	yagura("TourPorte", 900, 1860, 190, 70, H_REMPART + 1.0, false)
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
	# une petite ville dans l'enceinte : maisons des serviteurs, pagode, grand cerisier au centre
	batiment("MaisonServiteurs", 200, 1380, 150, 95, 1.6)
	batiment("MaisonCuisine", 385, 1385, 140, 90, 1.6)
	batiment("MaisonArmurier", 1440, 1575, 140, 90, 1.6)
	batiment("Bibliotheque", 220, 600, 220, 130, 1.8)
	batiment("Sanctuaire", 1360, 620, 200, 120, 1.8)
	pagode("Pagode", 330, 455, 140)
	parterre(900, 1040, 72)


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
	# Salle du combat : on ouvre la porte du donjon (E), elle claque derrière le ninja,
	# le seigneur Oni attend au fond
	grande_porte(820, 752, 160, H_DONJON, "PorteDonjon", "Entrer dans le donjon")
	seigneur(900, 450, 900, 560)
	declencheur("ArriveeDonjon", 520, 360, 760, 330)


func _douves() -> void:
	eau("Eau", 80, 1900, 1640, 90, -0.45)
	# pont arqué au-dessus des douves (on monte dessus sans sauter)
	pont_arque("PontLevis", 845, 1884, 110, 124, 0.5)
	boite("Etang", 1100, 1630, 180, 130, 0.04, "eau")


## Murs invisibles : bord de la carte et bords des douves (sauf le pont).
func _limites() -> void:
	limites([
		[80, 160, 1640, 40], [80, 3480, 1640, 40], [40, 200, 40, 3300], [1720, 200, 40, 3300],
		[80, 1990, 760, 10], [960, 1990, 760, 10], [80, 1890, 60, 10], [1660, 1890, 60, 10],
	])


func _vegetation() -> void:
	# herbes hautes seulement dehors ; dans le château, ce sont des buissons taillés pour se cacher
	herbes([[200, 2100, 260, 170], [1280, 2080, 300, 180]])
	cachettes([[340, 1700, 2.2], [1450, 1745, 2.0], [730, 1455, 1.8], [770, 1250, 1.8],
		[560, 1440, 1.8], [1240, 1440, 1.8], [620, 1100, 1.8], [1180, 1100, 1.8], [620, 700, 1.8], [1220, 700, 1.8]])
	arbres([[1380, 1380, 110, true], [820, 960, 160, true]])
	clair_de_lune("ClairDeLune", 900, 950, 400, 300)
	higanbanas(700, 1350, 100, 1700, 2030, 3450, 900)


func _lanternes() -> void:
	# Les lanternes de la grande porte (rayon 3) laissent un passage sombre le long du mur.
	lanternes([[740, 1790, 3.0], [1060, 1790, 3.0], [480, 1520], [1260, 1460],
		[780, 1380], [1020, 1380], [740, 840], [1060, 840], [965, 1110]])


func _gardes() -> void:
	gardes([
		["GardePorteSud", 1000, 1760, [[1000, 1760], [1400, 1760]]],
		["GardeOuest", 460, 1540, [[380, 1540], [720, 1540]]],
		["GardeEst", 1280, 1530, [[1460, 1530], [1080, 1530]]],
		["GardePorteInterieure", 900, 1395, []],
		["GardeCourNord", 640, 920, [[620, 920], [1160, 920]]],
		["GardeCourSud", 1160, 1160, [[1160, 1160], [700, 1160]]],
	])


func _objectifs() -> void:
	# Guirlandes de lanternes au-dessus des cours et des allées ; le parchemin est dans le coffre du seigneur.
	guirlandes([[830, 1480, 970, 1480], [830, 1700, 970, 1700]])
	autels([["Depart", 870, 3380], ["AutelPorte", 1060, 2240], ["AutelOuest", 340, 1760], ["AutelEst", 1430, 1280],
		["AutelDonjon", 760, 830]])
	sortie(1650, 510, Vector3(2.0, 2.0, 4.8))


## Décor d'ambiance (ticket 4.4) : rien de tout ça ne gêne le passage ni la vue des gardes.
func _decor() -> void:
	# Devant le château : pont rouge, bannières, berges des douves
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
	bambous(1130, 1560, 140, 40, 9)
	bambous(185, 1040, 40, 200, 8)
	bambous(1575, 1000, 40, 220, 8)
	bambous(1350, 350, 260, 40, 10)
	parsemer(100, 2000, 1600, 340, 35)
	lucioles([[150, 2020, 600, 300], [1050, 2020, 600, 300], [200, 1600, 300, 200],
		[1300, 1640, 300, 170], [600, 980, 220, 200], [1000, 920, 220, 200]])
	brume([[80, 1880, 800, 130], [920, 1880, 800, 130], [100, 2250, 1600, 110], [1080, 1600, 240, 200]])


# --- Le village de la forêt, au sud des douves ---------------------------------

func _village() -> void:
	# Le chemin de terre qui serpente de la cabane du maître jusqu'au pont du château
	# (coupé à la rivière : le pont arqué passe au-dessus)
	chemin_terre("Chemin", [[900, 3300], [905, 3200], [870, 3080], [935, 2950], [905, 2830], [885, 2805]], 64)
	chemin_terre("CheminNord", [[880, 2712], [880, 2690], [925, 2560], [900, 2420], [880, 2250], [900, 2100], [900, 1992]], 64)

	# Cabane du maître, en bois, ouverte au nord ; mur sud bas pour que la caméra voie dedans
	var e := 12.0
	boite("CabaneSol", 820, 3290, 160, 120, 0.06, "parquet")
	for m in [["CabaneOuest", 820, 3290, e, 120], ["CabaneEst", 980 - e, 3290, e, 120],
			["CabaneNordOuest", 820, 3290, 50, e], ["CabaneNordEst", 930, 3290, 50, e]]:
		boite(m[0], m[1], m[2], m[3], m[4], 2.1, "planches")
	boite("CabaneSud", 820, 3410 - e, 160, e, 0.8, "planches")
	toit_japonais("CabaneToit", 820, 3290, 160, 120, 2.1, 1, "bardeaux")
	for px in [[820, 3290], [980, 3290], [820, 3410], [980, 3410], [870, 3290], [930, 3290]]:
		plaque("Poteaux", P(px[0], px[1], 1.05), Vector3(0.2, 2.1, 0.2), "bois_sombre")
	plaque("Poutres", P(900, 3290, 2.0), Vector3(6.5, 0.18, 0.24), "bois_sombre")
	# dedans : un futon, une table basse et un rouleau suspendu
	plaque("Futon", P(950, 3330, 0.1), Vector3(0.9, 0.08, 1.8), "shoji", false)
	plaque("TableBasse", P(900, 3395, 0.22), Vector3(1.0, 0.08, 0.5), "bois_sombre")
	plaque("Kakejiku", P(900, 3400, 1.2), Vector3(0.6, 1.0, 0.03), "shoji", false)

	# Maisons de bois aux toits rouges, autour de la petite place et le long du chemin
	maison_bois("MaisonHana", 560, 3080, 200, 140, 1.9, 2)
	maison_bois("MaisonUme", 1100, 3120, 200, 140, 1.9, 3)
	maison_bois("MaisonKenji", 500, 2560, 210, 140, 2.0, 2)
	maison_bois("MaisonJiro", 1180, 2600, 190, 130, 1.8, 3)
	maison_bois("Grenier", 290, 2890, 170, 130, 2.2, 2)
	maison_bois("Remise", 1290, 3290, 150, 110, 1.7, 3)
	boite("Puits", 720, 2945, 46, 46, 0.7, "pierre")
	plaque("PuitsToit", P(743, 2968, 1.6), Vector3(1.6, 0.1, 1.4), "bardeaux")
	for sx in [-1.0, 1.0]:
		plaque("Poteaux", P(743, 2968, 1.15) + Vector3(sx * 0.7, 0, 0), Vector3(0.1, 0.9, 0.1), "bois_sombre")

	# Ruisseau qui traverse la forêt d'ouest en est, et le pont rouge du chemin
	# Rivière creusée qui coupe la forêt d'ouest en est : on la traverse par le pont du chemin
	# ou par le petit pont de l'ouest, derrière la maison de Kenji
	ruisseau("Ruisseau", [[80, 2770], [400, 2745], [700, 2770], [900, 2760], [1150, 2775], [1450, 2750], [1720, 2770]], 46,
		[[850, 910], [380, 430]])
	pont_arque("PontForet", 845, 2700, 70, 120, 0.55)
	pont_arque("PontOuest", 375, 2690, 60, 110, 0.5)
	bambous(170, 2700, 150, 25, 8)
	bambous(1500, 2700, 160, 25, 8)
	bambous(600, 2800, 120, 25, 6)
	# Étang aux carpes, avec sa petite cascade (le pêcheur s'assoit au bord)
	boite("EtangForet", 1180, 2880, 240, 160, 0.04, "eau")
	berge(1180, 2880, 240, 160)
	cascade("CascadeForet", 1300, 2886, 1.4)
	nenuphars(1190, 2940, 220, 90, 10)
	carpes(1200, 2900, 200, 130, 5)
	# Une seule guirlande, au-dessus du chemin, loin des lanternes
	guirlandes([[790, 2580, 1040, 2580]])
	herbes([[130, 2620, 180, 100], [1460, 2880, 200, 140], [600, 3250, 180, 100], [300, 2650, 200, 60]])
	# Gros buissons où se cacher : devant les douves (la ronde des gardes), dans le village et au château
	cachettes([[620, 2130, 2.4], [1180, 2120, 2.4], [420, 2210, 2.2], [1400, 2200, 2.6], [760, 2330, 2.0],
		[1040, 2330, 2.0], [780, 2470, 2.0], [1020, 2500, 2.0], [200, 2600, 2.4], [1600, 2620, 2.4],
		[250, 3220, 2.6], [1560, 3350, 2.4], [620, 2990, 2.0], [1080, 2660, 2.2],
		[300, 1700, 2.2], [1480, 1460, 2.2], [700, 1480, 2.0], [700, 1250, 2.0], [1120, 1240, 2.0]])
	# arbres en fleurs (roses ou mauves) au nord de la rivière ; verts dans la première zone, au sud
	arbres([[120, 2380, 120, true], [1560, 2380, 130, true], [380, 2400, 110, true], [1420, 2420, 120, true], [1060, 2830, 120],
		[180, 3120, 130], [1520, 3040, 120], [600, 3390, 110], [1180, 3430, 120], [150, 2760, 110], [1650, 2900, 120]])
	# Lanternes de pierre par paires, de chaque côté du chemin
	lanternes([[850, 3205, 2.5], [960, 3195, 2.5], [815, 3030, 2.5], [945, 3060, 2.5], [850, 2880, 2.5], [975, 2900, 2.5],
		[825, 2650, 2.5], [945, 2660, 2.5], [850, 2440, 2.5], [965, 2420, 2.5], [825, 2210, 2.5], [945, 2230, 2.5]])
	_habitants()
	chats([[790, 3180, 200], [1240, 2840, 40], [1000, 3420, 120]])
	rochers([[1150, 2870, 0.8, 2], [1430, 3040, 0.7, 0], [330, 2800, 0.6, 6], [1500, 2790, 0.6, 7],
		[160, 3400, 1.2, 1], [1650, 3420, 1.1, 0]])
	buissons([[470, 3250, 1.0], [1460, 3170, 1.0], [790, 3440, 0.9], [1030, 3300, 0.8], [480, 2705, 0.8], [1150, 2470, 0.9]])
	bambous(100, 2420, 50, 300, 10)
	bambous(1650, 2420, 50, 300, 10)
	bambous(120, 3250, 300, 50, 10)
	massif_higanbanas(820, 3140, 40, 90, 18)
	massif_higanbanas(980, 3140, 40, 90, 18)
	parsemer(100, 2020, 1600, 1440, 80)
	# Lucioles autour des arbres et au-dessus du ruisseau
	lucioles([[80, 2340, 200, 200], [1520, 2340, 210, 210], [600, 2590, 190, 190], [1020, 2790, 200, 200],
		[200, 3000, 210, 210], [1480, 3000, 200, 200], [560, 3320, 190, 190], [1140, 3320, 200, 200],
		[300, 2720, 500, 100], [1000, 2720, 500, 100], [1180, 2880, 240, 160]])
	# brume au ras du sol, plus épaisse au départ
	brume([[80, 2720, 800, 110], [920, 2720, 800, 110], [1180, 2880, 240, 160], [100, 3380, 1600, 100]])


## Les habitants et leur journée (scripts/habitant.gd) : [x, y, activité, durée (s), regard].
func _habitants() -> void:
	var A := Habitant.Activite
	var V := Habitant.Allure
	habitants([
		{"nom": "Maître Kagemaru", "noeud": "Maitre", "x": 918, "y": 3351, "regard": -115, "allure": V.VIEUX,
			"kimono": "#4a4f6a", "obi": "#c9a24a", "cheveux": "#e8e6e0", "barbe": true, "baton": true},
		{"nom": "Hana", "x": 800, "y": 3150, "allure": V.ADULTE, "kimono": "#c0394b", "obi": "#f2d38a", "chignon": true,
			"journee": [[800, 3150, A.BALAYER, 7, 90], [770, 3000, A.REPOS, 4, 180], [860, 2965, A.DISCUTER, 6, 90], [800, 3150, A.REPOS, 2]]},
		{"nom": "Grand-mère Ume", "x": 1060, "y": 3190, "allure": V.VIEUX, "kimono": "#7a5a3a", "obi": "#3a5a40", "cheveux": "#cfcac2", "chignon": true,
			"journee": [[1060, 3190, A.BALAYER, 10, -90], [1010, 3070, A.REPOS, 5, 180], [1060, 3190, A.REPOS, 3]]},
		{"nom": "Kenji", "x": 1270, "y": 3340, "allure": V.ADULTE, "kimono": "#3d5a80", "obi": "#e8e0cc", "chapeau": true,
			"journee": [[480, 2960, A.PORTER, 3, -90], [1270, 3340, A.REPOS, 5, -90]]},
		{"nom": "Jiro le pêcheur", "x": 1250, "y": 2862, "allure": V.ADULTE, "kimono": "#5b6b4a", "chapeau": true,
			"journee": [[1250, 2862, A.PECHER, 999, 0]]},
		{"nom": "Petit Taro", "x": 850, "y": 2930, "allure": V.ENFANT, "kimono": "#e0a030", "obi": "#3d5a80",
			"journee": [[850, 2930, A.JOUER, 3], [1000, 3050, A.JOUER, 2], [700, 2900, A.REPOS, 2], [960, 2900, A.JOUER, 2]]},
		{"nom": "Sora", "x": 760, "y": 2650, "allure": V.ADULTE, "kimono": "#6a4c8a", "obi": "#e8b04a",
			"journee": [[760, 2650, A.DISCUTER, 999, 90]]},
		{"nom": "Aiko", "x": 812, "y": 2650, "allure": V.ADULTE, "kimono": "#3f8a7a", "obi": "#f0e0c0", "chignon": true,
			"journee": [[812, 2650, A.REPOS, 999, -90]]},
	])
