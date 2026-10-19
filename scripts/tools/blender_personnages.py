# KAGE : modèles 3D du ninja et du garde, pour Blender (4.2 ou plus récent).
#
# Utilisation : onglet Scripting > Nouveau > coller ce fichier > bouton ▶.
# Le script construit les deux personnages d'après les planches Figma
# (formes lissées, couleurs de la charte, pivots articulés, marche en boucle)
# et exporte ninja.glb et garde.glb dans le dossier EXPORT ci-dessous.
#
# Les pivots (Corps, Tete, BrasG, BrasD, JambeG, JambeD, Foulard/Pans) portent
# les mêmes noms que dans le jeu : scripts/anim_chibi.gd les anime directement.
# Les cotes sont en mètres, notées comme dans Godot (Y vers le haut, +Z devant)
# puis converties pour Blender (Z vers le haut, -Y devant).

import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

EXPORT = os.path.join(os.path.expanduser("~"), "Desktop", "KAGE_modeles")
LISSAGE = 1  # niveaux de subdivision (0 = brut, 2 = très lisse mais lourd)

COULEURS = {
	"peau": ("#F1C7A2", 0.7, 0.0),
	"tissu": ("#24252C", 0.95, 0.0),
	"noir": ("#1B1C22", 0.7, 0.0),
	"armure": ("#1E1F26", 0.55, 0.0),
	"ardoise": ("#4B5160", 0.85, 0.0),
	"gris": ("#5C606B", 0.85, 0.0),
	"rouge": ("#C23B22", 0.75, 0.0),
	"or": ("#D99A4E", 0.4, 0.5),
	"bois": ("#5A3A22", 0.8, 0.0),
	"acier": ("#C9CCD2", 0.3, 0.7),
	"oni": ("#B5281C", 0.6, 0.0),
	"blanc": ("#FFFFFF", 0.4, 0.0),
	"jaune": ("#FFC531", 0.5, 0.0),
}

# Motif de texture peint sur chaque matériau (les autres restent unis)
MOTIFS = {
	"tissu": "tissu", "rouge": "tissu", "gris": "tissu", "ardoise": "tissu",
	"noir": "laque", "armure": "armure", "bois": "bois",
	"acier": "metal", "or": "metal", "oni": "grain", "peau": "grain",
}
TAILLE_TEXTURE = 256


# --- Outils -----------------------------------------------------------------

def lineaire(hexa):
	"""Couleur #RRGGBB (sRGB) vers les valeurs linéaires qu'attend Blender."""
	def canal(c):
		return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
	h = hexa.lstrip("#")
	return tuple(canal(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


def materiau(nom):
	m = bpy.data.materials.get("kage_" + nom)
	if m:
		return m
	hexa, rugosite, metal = COULEURS[nom]
	m = bpy.data.materials.new("kage_" + nom)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = lineaire(hexa)
	if nom in MOTIFS:
		tex = m.node_tree.nodes.new("ShaderNodeTexImage")
		tex.image = texture(nom, hexa, MOTIFS[nom])
		tex.location = (-350, 250)
		m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	bsdf.inputs["Roughness"].default_value = rugosite
	bsdf.inputs["Metallic"].default_value = metal
	if nom == "jaune":  # yeux du garde qui brillent dans la nuit
		bsdf.inputs["Emission Color"].default_value = lineaire(hexa)
		bsdf.inputs["Emission Strength"].default_value = 1.5
	m.diffuse_color = lineaire(hexa)
	return m


def bruit(n, flou, graine):
	"""Bruit doux et raccordable (les bords se rejoignent), centré sur 0."""
	b = np.random.default_rng(graine).random((n, n))
	for _ in range(flou):
		b = (b + np.roll(b, 1, 0) + np.roll(b, -1, 0) + np.roll(b, 1, 1) + np.roll(b, -1, 1)) / 5
	b -= b.mean()
	return b / (np.abs(b).max() + 1e-6)


def texture(nom, hexa, motif):
	"""Peint une petite texture raccordable : couleur de la charte + motif."""
	n = TAILLE_TEXTURE
	v, u = np.mgrid[0:n, 0:n] / n  # u autour de la pièce, v de bas en haut
	h = hexa.lstrip("#")
	base = np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])
	clair = np.zeros((n, n))  # éclaircit (utile sur les tons très sombres)
	fonce = np.zeros((n, n))  # assombrit
	if motif == "tissu":  # tissage fin + fibres
		trame = np.sin(2 * np.pi * 48 * u) * np.sin(2 * np.pi * 48 * v)
		clair += 0.035 * (trame > 0.3) + 0.02 * bruit(n, 2, 1)
		fonce += 0.10 * (trame < -0.3) + 0.08 * np.abs(bruit(n, 6, 2))
	elif motif == "laque":  # noir laqué, légers reflets
		clair += 0.03 * np.maximum(bruit(n, 12, 3), 0)
	elif motif == "armure":  # rangées de plaquettes laquées (kozane)
		rangs, plaques = 8, 24
		dans_rang = (v * rangs) % 1
		decale = (np.floor(v * rangs) % 2) * 0.5
		dans_plaque = (u * plaques + decale) % 1
		clair += 0.10 * (dans_rang > 0.86) + 0.03 * (1 - dans_rang)
		fonce += 0.5 * (dans_rang < 0.06) + 0.35 * (np.abs(dans_plaque - 0.5) > 0.47)
		clair += 0.02 * bruit(n, 8, 4)
	elif motif == "bois":  # veines dans la longueur
		veine = np.sin(2 * np.pi * (14 * u + 1.5 * bruit(n, 10, 5)))
		clair += 0.12 * np.maximum(veine, 0) ** 3
		fonce += 0.18 * np.maximum(-veine, 0) ** 2
	elif motif == "metal":  # brossé
		stries = np.repeat(bruit(n, 1, 6).mean(axis=0, keepdims=True), n, axis=0)
		clair += 0.06 * np.maximum(stries, 0)
		fonce += 0.08 * np.maximum(-stries, 0) + 0.04 * np.abs(bruit(n, 4, 7))
	elif motif == "grain":  # peau, masque : très léger grain
		fonce += 0.05 * np.abs(bruit(n, 10, 8)) + 0.02 * np.abs(bruit(n, 1, 9))
	rgb = base[None, None, :] * (1 - fonce[..., None]) + clair[..., None]
	pixels = np.concatenate([np.clip(rgb, 0, 1), np.ones((n, n, 1))], axis=2)
	img = bpy.data.images.get("tex_" + nom) or bpy.data.images.new("tex_" + nom, n, n)
	img.pixels.foreach_set(pixels.astype(np.float32).ravel())
	img.pack()  # gardée dans le .blend et intégrée au .glb
	return img


def pos(v):
	"""Position Godot (x, y haut, z devant) vers Blender (x, -y devant, z haut)."""
	return Vector((v[0], -v[2], v[1]))


def rot(r):
	"""Rotation Godot en degrés (ordre YXZ) vers une rotation Blender."""
	rx, ry, rz = (math.radians(a) for a in r)
	m = Matrix.Rotation(ry, 3, "Z") @ Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(-rz, 3, "Y")
	return m.to_euler("XYZ")


def placer(obj, parent, position, rotation=(0, 0, 0), echelle=(1, 1, 1)):
	bpy.context.collection.objects.link(obj)
	obj.parent = parent
	obj.location = pos(position)
	obj.rotation_euler = rot(rotation)
	obj.scale = (echelle[0], echelle[2], echelle[1])
	return obj


def pivot(parent, nom, position, rotation=(0, 0, 0)):
	e = bpy.data.objects.new(nom, None)
	e.empty_display_type = "PLAIN_AXES"
	e.empty_display_size = 0.08
	return placer(e, parent, position, rotation)


def finir(obj, mat, arrondi=0.0, lisser=True):
	"""Matériau, ombrage lisse, arrondi des arêtes et subdivision."""
	obj.data.materials.append(materiau(mat))
	for p in obj.data.polygons:
		p.use_smooth = True
	if arrondi > 0:
		b = obj.modifiers.new("Arrondi", "BEVEL")
		b.width = arrondi
		b.segments = 2
		b.limit_method = "NONE"
	if LISSAGE and lisser:
		s = obj.modifiers.new("Lissage", "SUBSURF")
		s.levels = s.render_levels = LISSAGE
	return obj


def maillage_temp(op, **kw):
	"""Crée une primitive Blender et récupère son maillage seul."""
	op(**kw)
	o = bpy.context.active_object
	me = o.data
	bpy.data.objects.remove(o)
	return me


def objet(nom, me):
	me.name = nom
	return bpy.data.objects.new(nom, me)


def boule(parent, nom, position, taille, mat, rotation=(0, 0, 0)):
	"""Ellipsoïde de diamètres `taille`."""
	me = maillage_temp(bpy.ops.mesh.primitive_uv_sphere_add, segments=20, ring_count=10, radius=0.5)
	return finir(placer(objet(nom, me), parent, position, rotation, taille), mat)


def boite(parent, nom, position, taille, mat, rotation=(0, 0, 0)):
	"""Pavé aux coins arrondis."""
	me = maillage_temp(bpy.ops.mesh.primitive_cube_add, size=1.0)
	me.transform(Matrix.Diagonal((taille[0], taille[2], taille[1], 1.0)))
	o = placer(objet(nom, me), parent, position, rotation)
	return finir(o, mat, arrondi=min(taille) * 0.3)


def tube(parent, nom, position, rayon, hauteur, mat, rayon_haut=None, rotation=(0, 0, 0)):
	"""Cylindre vertical (ou tronc de cône si rayon_haut est donné)."""
	haut = rayon if rayon_haut is None else rayon_haut
	me = maillage_temp(bpy.ops.mesh.primitive_cone_add, vertices=32, radius1=rayon,
		radius2=haut, depth=hauteur)
	# pas de subdivision : elle rétrécirait le cylindre et décollerait les liserés
	return finir(placer(objet(nom, me), parent, position, rotation), mat,
		arrondi=min(rayon, haut, hauteur) * 0.2, lisser=False)


def croc(parent, nom, position, rayon, hauteur, mat):
	"""Petit cône pointe en bas."""
	me = maillage_temp(bpy.ops.mesh.primitive_cone_add, vertices=8, radius1=0.0,
		radius2=rayon, depth=hauteur)
	o = placer(objet(nom, me), parent, position)
	o.data.materials.append(materiau(mat))
	return o


def anneau(parent, nom, position, interieur, exterieur, epaisseur, mat, rotation=(0, 0, 0)):
	"""Tore horizontal (ceinture, foulard, liens)."""
	r = (interieur + exterieur) / 2
	me = maillage_temp(bpy.ops.mesh.primitive_torus_add, major_segments=32, minor_segments=10,
		major_radius=r, minor_radius=(exterieur - interieur) / 2)
	e = epaisseur / (exterieur - interieur)
	return finir(placer(objet(nom, me), parent, position, rotation, (1, e, 1)), mat)


def vider_scene():
	for o in list(bpy.data.objects):
		bpy.data.objects.remove(o)
	for coll in (bpy.data.meshes, bpy.data.actions, bpy.data.materials, bpy.data.images):
		for d in list(coll):
			if d.users == 0:
				coll.remove(d)


# --- Ninja ------------------------------------------------------------------

def ninja(racine=None):
	corps = pivot(racine, "Corps", (0, 0.30, 0))
	# Veste noire croisée, revers ardoise, ceinture grise nouée devant
	boule(corps, "Tronc", (0, 0.14, 0), (0.50, 0.48, 0.40), "tissu")
	boule(corps, "Col", (0, 0.30, 0), (0.36, 0.14, 0.30), "tissu")
	boite(corps, "Revers1", (-0.04, 0.17, 0.19), (0.05, 0.26, 0.04), "ardoise", (-12, 0, -28))
	boite(corps, "Revers2", (0.04, 0.17, 0.19), (0.05, 0.26, 0.04), "ardoise", (-12, 0, 28))
	anneau(corps, "Ceinture", (0, 0.03, 0), 0.215, 0.258, 0.07, "gris")
	boule(corps, "Noeud", (0, 0.03, 0.245), (0.09, 0.07, 0.06), "gris")
	boite(corps, "PanG", (-0.035, -0.05, 0.25), (0.04, 0.11, 0.02), "gris", (0, 0, 12))
	boite(corps, "PanD", (0.035, -0.05, 0.25), (0.04, 0.11, 0.02), "gris", (0, 0, -12))

	# Katana dans le dos en diagonale : fourreau noir, garde dorée, poignée rouge
	sabre = pivot(corps, "Sabre", (0, 0.12, -0.24), (0, 0, -52))
	tube(sabre, "Fourreau", (0, -0.02, 0), 0.026, 0.62, "noir")
	tube(sabre, "Kojiri", (0, -0.335, 0), 0.03, 0.03, "or")
	tube(sabre, "Tsuba", (0, 0.30, 0), 0.055, 0.016, "or")
	tube(sabre, "Poignee", (0, 0.39, 0), 0.023, 0.17, "rouge")
	for i in range(3):
		boite(sabre, "Tresse%d" % i, (0, 0.34 + i * 0.05, 0.0), (0.05, 0.012, 0.05), "or", (0, 45, 0))
	tube(sabre, "Kashira", (0, 0.485, 0), 0.027, 0.022, "or")

	# Tête : grosse capuche ronde avec pointe, visage, bandeau gris, masque noir
	tete = pivot(racine, "Tete", (0, 0.88, 0))
	boule(tete, "Capuche", (0, 0.02, 0), (0.80, 0.76, 0.76), "tissu")
	boule(tete, "Pointe", (0, 0.26, -0.33), (0.20, 0.28, 0.24), "tissu", (-50, 0, 0))
	boule(tete, "Visage", (0, 0.02, 0.19), (0.60, 0.27, 0.43), "peau")
	boule(tete, "Bandeau", (0, 0.155, 0.185), (0.63, 0.09, 0.44), "gris")
	boule(tete, "Masque", (0, -0.135, 0.20), (0.64, 0.17, 0.43), "tissu")
	for cote, s in ((-1, "G"), (1, "D")):
		oeil = boule(tete, "Oeil" + s, (cote * 0.11, 0.025, 0.395), (0.095, 0.12, 0.04), "noir")
		boule(oeil, "Reflet" + s, (-0.15, 0.22, 0.45), (0.32, 0.30, 0.3), "blanc")
		boule(oeil, "Reflet2" + s, (0.18, -0.2, 0.45), (0.14, 0.13, 0.2), "blanc")

	# Foulard rouge au cou, deux pans qui flottent derrière
	foulard = pivot(racine, "Foulard", (0, 0.62, 0))
	anneau(foulard, "Tour", (0, 0, 0), 0.16, 0.27, 0.11, "rouge")
	pans = pivot(foulard, "Pans", (0.12, 0.0, -0.22))
	boite(pans, "Pan1", (0.04, -0.02, -0.17), (0.11, 0.035, 0.34), "rouge", (-10, 25, 0))
	boite(pans, "Pan2", (0.12, -0.08, -0.12), (0.09, 0.03, 0.26), "rouge", (-22, 50, 0))

	# Bras : manche noire, protège-bras gris, main avec pouce
	for cote, s in ((-1, "G"), (1, "D")):
		bras = pivot(racine, "Bras" + s, (cote * 0.25, 0.55, 0), (0, 0, cote * 18))
		boule(bras, "Manche" + s, (0, -0.08, 0), (0.16, 0.22, 0.16), "tissu")
		tube(bras, "Protege" + s, (0, -0.19, 0), 0.066, 0.10, "gris", 0.072)
		boule(bras, "Main" + s, (0, -0.27, 0), (0.12, 0.12, 0.12), "peau")
		boule(bras, "Pouce" + s, (-cote * 0.045, -0.255, 0.035), (0.045, 0.06, 0.045), "peau")

	# Jambes : pantalon bouffant, bandes grises aux mollets, chaussons noirs
	for cote, s in ((-1, "G"), (1, "D")):
		jambe = pivot(racine, "Jambe" + s, (cote * 0.11, 0.24, 0))
		boule(jambe, "Cuisse" + s, (0, -0.06, 0), (0.19, 0.18, 0.19), "tissu")
		tube(jambe, "Bande" + s, (0, -0.15, 0), 0.068, 0.08, "gris", 0.072)
		anneau(jambe, "Lien" + s, (0, -0.135, 0), 0.066, 0.078, 0.012, "ardoise")
		boule(jambe, "Pied" + s, (0, -0.215, 0.03), (0.15, 0.09, 0.21), "noir")
	return {"tete": tete, "corps": corps, "pans": pans}


# --- Garde ------------------------------------------------------------------

def garde(racine=None):
	corps = pivot(racine, "Corps", (0, 0.34, 0))
	# Armure noire à lacets rouges, cordon rouge noué à la taille
	boule(corps, "Tronc", (0, 0.14, 0), (0.60, 0.52, 0.46), "armure")
	for i in range(3):
		boite(corps, "Lacet%d" % i, (0, 0.25 - i * 0.085, 0.225 - i * 0.004), (0.30, 0.02, 0.025), "rouge", (-8 + i * 6, 0, 0))
	anneau(corps, "Cordon", (0, 0.0, 0), 0.25, 0.295, 0.05, "rouge")
	boule(corps, "Noeud", (0, -0.01, 0.285), (0.10, 0.07, 0.06), "rouge")
	boite(corps, "BoutG", (-0.03, -0.07, 0.29), (0.035, 0.10, 0.02), "rouge", (0, 0, 10))
	boite(corps, "BoutD", (0.03, -0.07, 0.29), (0.035, 0.10, 0.02), "rouge", (0, 0, -10))
	# Jupe d'armure à lignes rouges
	tube(corps, "Jupe", (0, -0.10, 0), 0.30, 0.16, "armure", 0.24)
	for i in range(2):
		anneau(corps, "LigneJupe%d" % i, (0, -0.07 - i * 0.07, 0), 0.265 + i * 0.02, 0.29 + i * 0.02, 0.014, "rouge")
	# Épaulières
	for cote, s in ((-1, "G"), (1, "D")):
		sode = boite(corps, "Sode" + s, (cote * 0.33, 0.26, 0), (0.12, 0.20, 0.30), "armure", (0, 0, cote * 20))
		for j in range(2):
			boite(sode, "LacetSode%s%d" % (s, j), (0, 0.03 - j * 0.07, 0), (0.128, 0.016, 0.31), "rouge")

	# Tête : masque oni rouge, yeux jaunes en colère, sourcils, crocs
	tete = pivot(racine, "Tete", (0, 0.98, 0))
	boule(tete, "Visage", (0, -0.04, 0.06), (0.62, 0.56, 0.52), "oni")
	boule(tete, "Nuque", (0, -0.02, -0.06), (0.60, 0.56, 0.50), "noir")
	boule(tete, "Nez", (0, -0.06, 0.315), (0.09, 0.06, 0.05), "oni")
	for cote, s in ((-1, "G"), (1, "D")):
		boule(tete, "Oeil" + s, (cote * 0.12, 0.0, 0.29), (0.14, 0.085, 0.04), "jaune", (0, 0, cote * 15))
		boite(tete, "Sourcil" + s, (cote * 0.12, 0.075, 0.30), (0.16, 0.04, 0.035), "noir", (0, 0, -cote * 22))
		boule(tete, "Joue" + s, (cote * 0.17, -0.11, 0.25), (0.12, 0.09, 0.08), "oni")
		croc(tete, "Croc" + s, (cote * 0.075, -0.185, 0.295), 0.024, 0.055, "blanc")
	boite(tete, "Bouche", (0, -0.155, 0.305), (0.20, 0.025, 0.02), "noir")

	# Casque noir arrondi, couvre-nuque à lignes rouges, cimier en U doré
	casque = pivot(tete, "Casque", (0, 0.20, -0.02))
	boule(casque, "Bol", (0, 0.08, 0), (0.72, 0.46, 0.70), "noir")
	tube(casque, "CouvreNuque", (0, -0.10, -0.13), 0.40, 0.24, "noir", 0.32)
	for i in range(3):
		anneau(casque, "Ligne%d" % i, (0, -0.03 - i * 0.065, -0.13), 0.33 + i * 0.02, 0.35 + i * 0.02, 0.014, "rouge")
	boule(casque, "Visiere", (0, -0.10, 0.22), (0.66, 0.08, 0.30), "noir")
	cimier = pivot(casque, "Cimier", (0, 0.06, 0.34))
	tube(cimier, "Rosace", (0, 0, 0), 0.055, 0.03, "or", None, (90, 0, 0))
	boite(cimier, "Base", (0, 0.01, 0), (0.17, 0.05, 0.035), "or")
	for cote, s in ((-1, "G"), (1, "D")):
		boite(cimier, "Corne" + s, (cote * 0.10, 0.12, 0), (0.05, 0.25, 0.035), "or", (0, 0, -cote * 18))
		boule(cimier, "Pointe" + s, (cote * 0.14, 0.245, 0), (0.06, 0.06, 0.04), "or")

	# Bras : le droit tient la lance (hampe en bois, lame argentée, pompon rouge)
	for cote, s in ((-1, "G"), (1, "D")):
		bras = pivot(racine, "Bras" + s, (cote * 0.30, 0.60, 0), (0, 0, cote * 14))
		boule(bras, "Manche" + s, (0, -0.09, 0), (0.17, 0.24, 0.17), "noir")
		anneau(bras, "Brassard" + s, (0, -0.16, 0), 0.07, 0.085, 0.02, "rouge")
		boule(bras, "Gant" + s, (0, -0.24, 0), (0.13, 0.12, 0.13), "noir")
		if cote > 0:
			lance = pivot(bras, "Lance", (0, -0.24, 0.02), (0, 0, -14))
			tube(lance, "Hampe", (0, 0.30, 0), 0.022, 1.6, "bois")
			tube(lance, "Talon", (0, -0.50, 0), 0.026, 0.05, "noir")
			tube(lance, "Bague", (0, 1.09, 0), 0.03, 0.04, "or")
			boule(lance, "Pompon", (0, 1.02, 0), (0.10, 0.12, 0.10), "rouge")
			boule(lance, "Lame", (0, 1.27, 0), (0.07, 0.34, 0.025), "acier")

	# Jambes : pantalon noir, liens rouges, pieds noirs
	for cote, s in ((-1, "G"), (1, "D")):
		jambe = pivot(racine, "Jambe" + s, (cote * 0.12, 0.22, 0))
		boule(jambe, "Cuisse" + s, (0, -0.06, 0), (0.20, 0.18, 0.20), "noir")
		anneau(jambe, "Lien" + s, (0, -0.125, 0), 0.07, 0.09, 0.025, "rouge")
		boule(jambe, "Pied" + s, (0, -0.195, 0.03), (0.16, 0.09, 0.22), "noir")
	return {"tete": tete, "corps": corps, "pans": None}


# --- Marche en boucle (25 images) ---------------------------------------------

def animer_marche(pieces):
	scene = bpy.context.scene
	scene.frame_start, scene.frame_end = 1, 25
	scene.render.fps = 24
	objets = bpy.data.objects
	repos = {}
	for i, (image, phase) in enumerate(((1, 0), (7, 1), (13, 0), (19, -1), (25, 0))):
		for nom, signe, ampleur in (("JambeG", 1, 35), ("JambeD", -1, 35), ("BrasG", -1, 28), ("BrasD", 1, 28)):
			o = objets.get(nom)
			if o is None:
				continue
			repos.setdefault(o, o.rotation_euler.copy())
			r = repos[o].copy()
			r.x += math.radians(ampleur * signe * phase)
			o.rotation_euler = r
			o.keyframe_insert("rotation_euler", frame=image)
		# petit rebond : le corps et la tête montent quand les jambes se croisent
		for o in (pieces["corps"], pieces["tete"]):
			repos.setdefault((o, "z"), o.location.z)
			o.location.z = repos[(o, "z")] + (0.0 if phase else 0.03)
			o.keyframe_insert("location", index=2, frame=image)
		if pieces["pans"]:
			o = pieces["pans"]
			repos.setdefault(o, o.rotation_euler.copy())
			r = repos[o].copy()
			r.z += math.radians(12 * phase)
			o.rotation_euler = r
			o.keyframe_insert("rotation_euler", frame=image)
	for action in bpy.data.actions:
		action.name = action.name.replace("Action", "Marche")
	scene.frame_set(1)


def exporter(nom):
	os.makedirs(EXPORT, exist_ok=True)
	chemin = os.path.join(EXPORT, nom + ".glb")
	bpy.ops.export_scene.gltf(
		filepath=chemin,
		export_format="GLB",
		export_apply=True,
		export_yup=True,
		export_animations=True,
		export_animation_mode="SCENE",
		export_lights=False,
		export_cameras=False,
	)
	print("KAGE : exporté", chemin)


def construire():
	if bpy.context.object and bpy.context.object.mode != "OBJECT":
		bpy.ops.object.mode_set(mode="OBJECT")
	# Un personnage à la fois, pour que les pivots gardent leurs noms exacts
	for nom, fabrique in (("garde", garde), ("ninja", ninja)):
		vider_scene()
		animer_marche(fabrique())
		exporter(nom)
	# Le ninja reste dans la scène ; on règle la vue pour voir les couleurs
	for zone in bpy.context.screen.areas if bpy.context.screen else []:
		if zone.type == "VIEW_3D":
			zone.spaces.active.shading.type = "MATERIAL"


construire()
