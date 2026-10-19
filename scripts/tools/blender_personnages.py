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

import bmesh
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
	"gris": ("#7E828C", 0.85, 0.0),
	"rouge": ("#C23B22", 0.75, 0.0),
	"or": ("#D99A4E", 0.4, 0.5),
	"bois": ("#5A3A22", 0.8, 0.0),
	"acier": ("#C9CCD2", 0.3, 0.7),
	"oni": ("#B5281C", 0.6, 0.0),
	"blanc": ("#FBF7F0", 0.2, 0.0),
	"iris": ("#3B2216", 0.15, 0.0),
	"jaune": ("#FFC531", 0.5, 0.0),
}

# Motif de texture peint sur chaque matériau (les autres restent unis)
MOTIFS = {
	"armure": "armure", "bois": "bois", "acier": "metal", "or": "metal",
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
		bsdf.inputs["Emission Strength"].default_value = 0.6
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


def placer(obj, parent, position, rotation=(0, 0, 0)):
	bpy.context.collection.objects.link(obj)
	obj.parent = parent
	obj.location = pos(position)
	obj.rotation_euler = rot(rotation)
	return obj


def pivot(parent, nom, position, rotation=(0, 0, 0)):
	e = bpy.data.objects.new(nom, None)
	e.empty_display_type = "PLAIN_AXES"
	e.empty_display_size = 0.08
	return placer(e, parent, position, rotation)


def etirer(me, taille):
	"""Donne au maillage (unité 1) les dimensions `taille`, notées façon Godot."""
	me.transform(Matrix.Diagonal((taille[0], taille[2], taille[1], 1.0)))


def uv_boite(me, pas=0.25):
	"""UV par projection cubique : la texture garde la même finesse partout."""
	bm = bmesh.new()
	bm.from_mesh(me)
	couche = bm.loops.layers.uv.verify()
	for f in bm.faces:
		n = f.normal
		axe = max(range(3), key=lambda i: abs(n[i]))
		for l in f.loops:
			c = l.vert.co
			l[couche].uv = ((c.y, c.z), (c.x, c.z), (c.x, c.y))[axe]
			l[couche].uv = (l[couche].uv[0] / pas, l[couche].uv[1] / pas)
	bm.to_mesh(me)
	bm.free()


def finir(obj, mat, arrondi=0.0, lisser=True, doux=True):
	"""Matériau, UV, ombrage lisse, arrondi des arêtes et subdivision."""
	uv_boite(obj.data)
	obj.data.materials.append(materiau(mat))
	for p in obj.data.polygons:
		p.use_smooth = doux
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
	me = maillage_temp(bpy.ops.mesh.primitive_uv_sphere_add, segments=24, ring_count=12, radius=0.5)
	etirer(me, taille)
	return finir(placer(objet(nom, me), parent, position, rotation), mat)


def boite(parent, nom, position, taille, mat, rotation=(0, 0, 0)):
	"""Pavé aux coins arrondis."""
	me = maillage_temp(bpy.ops.mesh.primitive_cube_add, size=1.0)
	etirer(me, taille)
	return finir(placer(objet(nom, me), parent, position, rotation), mat, arrondi=min(taille) * 0.3)


def tube(parent, nom, position, rayon, hauteur, mat, rayon_haut=None, rotation=(0, 0, 0)):
	"""Cylindre vertical (ou tronc de cône si rayon_haut est donné)."""
	haut = rayon if rayon_haut is None else rayon_haut
	me = maillage_temp(bpy.ops.mesh.primitive_cone_add, vertices=32, radius1=rayon,
		radius2=haut, depth=hauteur)
	# pas de subdivision : elle rétrécirait le cylindre
	return finir(placer(objet(nom, me), parent, position, rotation), mat,
		arrondi=min(rayon, haut, hauteur) * 0.2, lisser=False)


def anneau(parent, nom, position, interieur, exterieur, epaisseur, mat, rotation=(0, 0, 0)):
	"""Tore horizontal (ceinture, foulard, liens)."""
	me = maillage_temp(bpy.ops.mesh.primitive_torus_add, major_segments=40, minor_segments=12,
		major_radius=(interieur + exterieur) / 2, minor_radius=(exterieur - interieur) / 2)
	me.transform(Matrix.Diagonal((1, 1, epaisseur / (exterieur - interieur), 1)))
	return finir(placer(objet(nom, me), parent, position, rotation), mat)


def pointe(parent, nom, position, longueur, largeur, epaisseur, mat, rotation=(0, 0, 0), talon=0.3):
	"""Lame en losange, arêtes vives (lance, crocs)."""
	g = [(0, longueur, 0), (0, 0, 0), (largeur / 2, longueur * talon, 0), (-largeur / 2, longueur * talon, 0),
		(0, longueur * talon, epaisseur / 2), (0, longueur * talon, -epaisseur / 2)]
	faces = [(0, 2, 4), (0, 4, 3), (0, 3, 5), (0, 5, 2), (1, 4, 2), (1, 3, 4), (1, 5, 3), (1, 2, 5)]
	me = bpy.data.meshes.new(nom)
	me.from_pydata([pos(v) for v in g], [], faces)
	me.update()
	return finir(placer(objet(nom, me), parent, position, rotation), mat, lisser=False, doux=False)


def courbe(parent, nom, points, rayon, mat, ferme=False, effile=None):
	"""Tube souple qui suit des points (cordons, foulard, cimier).
	`effile` donne une épaisseur relative par point."""
	cu = bpy.data.curves.new(nom, "CURVE")
	cu.dimensions = "3D"
	cu.bevel_depth = rayon
	cu.bevel_resolution = 3
	cu.use_fill_caps = True
	cu.resolution_u = 8
	sp = cu.splines.new("BEZIER")
	sp.bezier_points.add(len(points) - 1)
	for i, p in enumerate(points):
		bp = sp.bezier_points[i]
		bp.co = pos(p)
		bp.handle_left_type = bp.handle_right_type = "AUTO"
		bp.radius = effile[i] if effile else 1.0
	sp.use_cyclic_u = ferme
	o = bpy.data.objects.new(nom, cu)
	placer(o, parent, (0, 0, 0))
	bpy.context.view_layer.update()
	me = bpy.data.meshes.new_from_object(o.evaluated_get(bpy.context.evaluated_depsgraph_get()))
	bpy.data.objects.remove(o)
	bpy.data.curves.remove(cu)
	o = placer(objet(nom, me), parent, (0, 0, 0))
	return finir(o, mat, lisser=False)


def ruban(parent, nom, points, largeurs, mat, epaisseur=0.012, haut=(0, 1, 0)):
	"""Bande de tissu plate qui suit des points ; sa largeur se tient le long de `haut`."""
	verts, faces = [], []
	h = Vector(haut)
	for i, p in enumerate(points):
		a, b = Vector(points[max(i - 1, 0)]), Vector(points[min(i + 1, len(points) - 1)])
		t = (b - a).normalized()
		cote = (h - t * h.dot(t)).normalized() * largeurs[i] / 2
		verts += [pos(Vector(p) - cote), pos(Vector(p) + cote)]
		if i:
			faces.append((2 * i - 2, 2 * i - 1, 2 * i + 1, 2 * i))
	me = bpy.data.meshes.new(nom)
	me.from_pydata(verts, [], faces)
	me.update()
	o = placer(objet(nom, me), parent, (0, 0, 0))
	s = o.modifiers.new("Epaisseur", "SOLIDIFY")
	s.thickness = epaisseur
	s.offset = 0
	return finir(o, mat)


def spirale(r_haut, r_bas, haut, bas, tours, n=10):
	"""Points d'une bande enroulée (bandages)."""
	pts = []
	for i in range(int(n * tours) + 1):
		t = i / (n * tours)
		a = 2 * math.pi * tours * t
		r = r_haut + (r_bas - r_haut) * t
		pts.append((r * math.sin(a), haut + (bas - haut) * t, r * math.cos(a)))
	return pts


def plaque(parent, nom, centre, r_haut, r_bas, haut, bas, a0, a1, mat, epaisseur=0.02, rangs=1):
	"""Plaque d'armure courbe : morceau de cône évasé, de l'angle a0 à a1
	(degrés autour de l'axe vertical, 0 = devant)."""
	n = max(4, int(abs(a1 - a0) / 8))
	verts, faces = [], []
	for j in range(rangs + 1):
		t = j / rangs
		y, r = haut + (bas - haut) * t, r_haut + (r_bas - r_haut) * t
		for i in range(n + 1):
			a = math.radians(a0 + (a1 - a0) * i / n)
			verts.append(pos((centre[0] + r * math.sin(a), centre[1] + y, centre[2] + r * math.cos(a))))
	for j in range(rangs):
		for i in range(n):
			k = j * (n + 1) + i
			faces.append((k, k + 1, k + n + 2, k + n + 1))
	me = bpy.data.meshes.new(nom)
	me.from_pydata(verts, [], faces)
	me.update()
	o = placer(objet(nom, me), parent, (0, 0, 0))
	s = o.modifiers.new("Epaisseur", "SOLIDIFY")
	s.thickness = epaisseur
	s.offset = 0
	return finir(o, mat)


def fondre(parent, nom, pieces, mat, voxel=0.008, cible=3000, creux=(), lissage=6, garder=()):
	"""Fond plusieurs pièces en une seule forme continue (remaillage par voxels),
	creuse éventuellement des ouvertures (`creux`) ou ne garde que ce qui est
	dans une forme (`garder`), puis allège le maillage."""
	bpy.context.view_layer.update()
	dg = bpy.context.evaluated_depsgraph_get()
	bm = bmesh.new()
	for p in pieces:
		me = bpy.data.meshes.new_from_object(p.evaluated_get(dg))
		me.transform(p.matrix_basis)
		bm.from_mesh(me)
		bpy.data.meshes.remove(me)
	me = bpy.data.meshes.new(nom)
	bm.to_mesh(me)
	bm.free()
	for p in pieces:
		bpy.data.objects.remove(p)
	o = placer(objet(nom, me), parent, (0, 0, 0))
	r = o.modifiers.new("Fusion", "REMESH")
	r.mode = "VOXEL"
	r.voxel_size = voxel
	l = o.modifiers.new("Raccords", "SMOOTH")
	l.factor, l.iterations = 0.7, lissage
	for c in creux:
		b = o.modifiers.new("Creux", "BOOLEAN")
		b.operation, b.object, b.solver = "DIFFERENCE", c, "EXACT"
	for c in garder:
		b = o.modifiers.new("Garder", "BOOLEAN")
		b.operation, b.object, b.solver = "INTERSECT", c, "EXACT"
	cuire(o)
	for c in list(creux) + list(garder):
		bpy.data.objects.remove(c)
	if len(o.data.polygons) > cible:
		d = o.modifiers.new("Allege", "DECIMATE")
		d.ratio = cible / len(o.data.polygons)
		cuire(o)
	o.data.materials.clear()  # le creusage peut laisser un emplacement vide
	for p in o.data.polygons:
		p.material_index = 0
	return finir(o, mat, lisser=False)


def cuire(o):
	"""Applique les modificateurs de l'objet dans son maillage."""
	bpy.context.view_layer.update()
	me = bpy.data.meshes.new_from_object(o.evaluated_get(bpy.context.evaluated_depsgraph_get()))
	vieux = o.data
	o.modifiers.clear()
	o.data = me
	bpy.data.meshes.remove(vieux)


def gabarit(nom, position, taille, parent=None):
	"""Forme invisible qui sert à creuser (bouche, ouverture du visage)."""
	me = maillage_temp(bpy.ops.mesh.primitive_uv_sphere_add, segments=32, ring_count=16, radius=0.5)
	etirer(me, taille)
	return placer(objet(nom, me), parent, position)


def prisme(parent, nom, contour, z0, z1):
	"""Forme de découpe : contour (x, y) vu de face, tiré en profondeur de z0 à z1."""
	n = len(contour)
	verts = [(x, y, z) for z in (z0, z1) for x, y in contour]
	faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
	faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
	me = bpy.data.meshes.new(nom)
	me.from_pydata([pos(v) for v in verts], [], faces)
	me.update()
	bm = bmesh.new()
	bm.from_mesh(me)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(me)
	bm.free()
	return placer(objet(nom, me), parent, (0, 0, 0))


def sur_ellipsoide(centre, rayons, x, y, decol=0.006):
	"""Point (et normale) à la surface avant d'un ellipsoïde, en x, y donnés."""
	dx, dy = (x - centre[0]) / rayons[0], (y - centre[1]) / rayons[1]
	dz = math.sqrt(max(0.0, 1 - dx * dx - dy * dy))
	z = centre[2] + rayons[2] * dz
	n = Vector((dx / rayons[0], dy / rayons[1], dz / rayons[2])).normalized()
	return (x + n.x * decol, y + n.y * decol, z + n.z * decol)


def anneau_points(centre, rx, rz, n=16, y=0.0, a0=0, a1=360, penche=0.0):
	"""Points d'un cercle (ou arc) horizontal, penché vers l'avant de `penche` mètres."""
	pts = []
	for i in range(n + 1 if a1 - a0 < 360 else n):
		a = math.radians(a0 + (a1 - a0) * i / n)
		z = rz * math.cos(a)
		pts.append((centre[0] + rx * math.sin(a), centre[1] + y + penche * z / rz, centre[2] + z))
	return pts


def vider_scene():
	for o in list(bpy.data.objects):
		bpy.data.objects.remove(o)
	for coll in (bpy.data.meshes, bpy.data.curves, bpy.data.actions, bpy.data.materials, bpy.data.images):
		for d in list(coll):
			if d.users == 0:
				coll.remove(d)


# --- Ninja ------------------------------------------------------------------

def ninja():
	# Proportions relevées sur la référence : 1,25 m, tête 45 %, jambes jusqu'aux genoux bouffants
	corps = pivot(None, "Corps", (0, 0.27, 0))
	# Veste noire croisée d'un seul tenant, col en V gris, ceinture nouée devant
	tronc = (0, 0.17, 0), (0.20, 0.17, 0.15)
	fondre(corps, "Veste", [
		boule(corps, "a", (0, 0.17, 0), (0.40, 0.34, 0.30), "tissu"),
		boule(corps, "b", (0, 0.31, 0), (0.26, 0.10, 0.22), "tissu"),
		boule(corps, "c", (0, 0.06, 0), (0.42, 0.14, 0.32), "tissu"),
	], "tissu", cible=2500)
	boule(corps, "ColV", sur_ellipsoide(*tronc, 0, 0.29, -0.01), (0.08, 0.08, 0.025), "gris", (-25, 0, 0))
	courbe(corps, "ReversG", [sur_ellipsoide(*tronc, -0.08 + 0.14 * t, 0.32 - 0.17 * t, 0.005)
		for t in (0, 0.33, 0.66, 1)], 0.013, "tissu")
	courbe(corps, "ReversD", [sur_ellipsoide(*tronc, 0.08 - 0.09 * t, 0.32 - 0.10 * t, 0.005)
		for t in (0, 0.5, 1)], 0.013, "tissu")
	anneau(corps, "Ceinture", (0, 0.15, 0), 0.175, 0.222, 0.065, "gris")
	boule(corps, "Noeud", (0, 0.15, 0.21), (0.08, 0.065, 0.05), "gris")
	ruban(corps, "PanG", [(-0.01, 0.14, 0.22), (-0.03, 0.08, 0.225), (-0.045, 0.01, 0.215)],
		[0.04, 0.036, 0.032], "gris", haut=(1, 0, 0))
	ruban(corps, "PanD", [(0.01, 0.14, 0.22), (0.035, 0.09, 0.228), (0.055, 0.03, 0.22)],
		[0.04, 0.036, 0.032], "gris", haut=(1, 0, 0))
	boule(corps, "NoeudDos", (0, 0.15, -0.215), (0.05, 0.045, 0.035), "gris")
	courbe(corps, "Cordon", [(0, 0.14, -0.22), (0, 0.09, -0.225), (0.01, 0.06, -0.22)], 0.007, "gris")

	# Katana dans le dos en diagonale : fourreau noir, garde dorée, poignée rouge tressée
	sabre = pivot(corps, "Sabre", (0, 0.20, -0.17), (0, 0, -52))
	courbe(sabre, "Fourreau", [(0, -0.26, 0), (0, -0.02, -0.01), (0, 0.23, 0)], 0.022, "noir")
	tube(sabre, "Kojiri", (0, -0.275, 0), 0.025, 0.025, "or")
	tube(sabre, "Tsuba", (0, 0.24, 0), 0.048, 0.014, "or")
	tube(sabre, "Poignee", (0, 0.31, 0), 0.02, 0.13, "rouge")
	for i in range(3):
		boite(sabre, "Tresse%d" % i, (0, 0.27 + i * 0.035, 0), (0.03, 0.01, 0.03), "or", (0, 45, 0))
	tube(sabre, "Kashira", (0, 0.385, 0), 0.023, 0.018, "or")

	# Tête : capuche ronde d'un seul tenant, grande ouverture pour le visage
	tete = pivot(None, "Tete", (0, 0.91, 0))
	# ouverture en rectangle arrondi, juste à la hauteur des yeux
	ouverture = boite(tete, "Ouverture", (0, -0.05, 0.22), (0.45, 0.17, 0.30), "noir")
	fondre(tete, "Capuche", [
		boule(tete, "a", (0, 0.0, 0), (0.54, 0.58, 0.52), "tissu"),
		boule(tete, "b", (0, -0.10, 0.0), (0.50, 0.32, 0.47), "tissu"),
	], "tissu", voxel=0.004, cible=8000, creux=[ouverture])
	boule(tete, "Visage", (0, -0.04, 0.10), (0.50, 0.24, 0.31), "peau")
	# Bandeau gris posé sur la capuche au-dessus des yeux, en pointe vers le haut
	fondre(tete, "Bandeau", [boule(tete, "a", (0, 0, 0.004), (0.556, 0.596, 0.536), "gris")], "gris",
		voxel=0.004, cible=3000, lissage=0, garder=[prisme(tete, "Pointe",
			[(-0.29, 0.027), (0.29, 0.027), (0.29, 0.10), (0, 0.215), (-0.29, 0.10)], 0.07, 0.4)])
	# Grands yeux sombres et brillants, fin liseré blanc
	for cote, s in ((-1, "G"), (1, "D")):
		x, y, r = cote * 0.094, -0.05, (0, cote * 22, 0)
		boule(tete, "Blanc" + s, (x, y, 0.234), (0.112, 0.152, 0.03), "blanc", r)
		boule(tete, "Iris" + s, (x * 1.01, y - 0.003, 0.242), (0.096, 0.138, 0.026), "iris", r)
		boule(tete, "Pupille" + s, (x * 1.02, y - 0.006, 0.249), (0.062, 0.098, 0.016), "noir", r)
		boule(tete, "Reflet" + s, (x * 1.02 - cote * 0.014, y + 0.025, 0.256), (0.018, 0.045, 0.01), "blanc", r)

	# Foulard rouge épais au cou, long pan plat qui flotte sur le côté
	foulard = pivot(None, "Foulard", (0, 0.635, 0))
	boule(foulard, "Cou", (0, 0, 0), (0.24, 0.08, 0.22), "rouge")
	tour = anneau_points((0, 0, 0.005), 0.155, 0.15, 24, penche=-0.012)
	ruban(foulard, "Tour", tour + tour[:2], [0.075] * 26, "rouge", epaisseur=0.035)
	pans = pivot(foulard, "Pans", (0.14, 0.0, -0.09))
	boule(pans, "Noeud", (0, 0, 0), (0.08, 0.08, 0.07), "rouge")
	ruban(pans, "Pan1", [(0, 0, 0), (0.07, -0.03, -0.04), (0.15, -0.06, -0.05), (0.22, -0.11, -0.03),
		(0.27, -0.17, -0.05)], [0.085, 0.095, 0.095, 0.085, 0.06], "rouge", epaisseur=0.016)
	ruban(pans, "Pan2", [(0, -0.02, 0), (0.04, -0.06, -0.04), (0.08, -0.11, -0.05)],
		[0.07, 0.06, 0.045], "rouge", epaisseur=0.014)

	# Bras : manche courte, avant-bras bandé de gris, main ronde
	for cote, s in ((-1, "G"), (1, "D")):
		bras = pivot(None, "Bras" + s, (cote * 0.20, 0.555, 0), (0, 0, cote * 10))
		fondre(bras, "Manche" + s, [
			boule(bras, "a", (0, -0.04, 0), (0.14, 0.12, 0.14), "tissu"),
			boule(bras, "b", (0, -0.10, 0), (0.165, 0.07, 0.165), "tissu"),
		], "tissu", voxel=0.005, cible=1200)
		tube(bras, "Bandes" + s, (0, -0.15, 0), 0.046, 0.09, "gris", 0.052)
		courbe(bras, "Spirale" + s, spirale(0.05, 0.047, -0.11, -0.19, 2.5), 0.004, "ardoise")
		fondre(bras, "Main" + s, [
			boule(bras, "a", (0, -0.235, 0), (0.10, 0.105, 0.095), "peau"),
			boule(bras, "b", (-cote * 0.038, -0.222, 0.03), (0.04, 0.055, 0.04), "peau", (0, 0, cote * 30)),
		], "peau", voxel=0.004, cible=1000)

	# Jambes : pantalon bouffant aux genoux, mollets bandés, chaussons noirs
	for cote, s in ((-1, "G"), (1, "D")):
		jambe = pivot(None, "Jambe" + s, (cote * 0.10, 0.30, 0))
		fondre(jambe, "Pantalon" + s, [
			boule(jambe, "a", (0, -0.03, 0), (0.19, 0.16, 0.19), "tissu"),
			boule(jambe, "b", (cote * 0.008, -0.10, 0), (0.21, 0.13, 0.21), "tissu"),
		], "tissu", voxel=0.005, cible=1200)
		tube(jambe, "Bandes" + s, (0, -0.19, 0), 0.045, 0.08, "gris", 0.05)
		courbe(jambe, "Spirale" + s, spirale(0.049, 0.046, -0.155, -0.225, 2), 0.004, "ardoise")
		fondre(jambe, "Pied" + s, [
			boule(jambe, "a", (0, -0.255, 0.025), (0.14, 0.09, 0.20), "noir"),
			boule(jambe, "b", (0, -0.225, 0), (0.11, 0.05, 0.11), "noir"),
		], "noir", voxel=0.004, cible=1000)
	return {"tete": tete, "corps": corps, "pans": pans}


# --- Garde ------------------------------------------------------------------

def garde():
	corps = pivot(None, "Corps", (0, 0.34, 0))
	# Cuirasse laquée d'un seul tenant, lacets rouges qui suivent sa courbe
	tronc = (0, 0.14, 0.01), (0.30, 0.26, 0.23)
	fondre(corps, "Cuirasse", [
		boule(corps, "a", (0, 0.14, 0), (0.60, 0.52, 0.46), "armure"),
		boule(corps, "b", (0, 0.20, 0.03), (0.56, 0.36, 0.46), "armure"),
	], "armure", cible=2500)
	for i in range(3):
		y = 0.26 - i * 0.085
		courbe(corps, "Lacet%d" % i, [sur_ellipsoide(*tronc, x, y, 0.008) for x in (-0.17, -0.06, 0.06, 0.17)],
			0.011, "rouge")
	courbe(corps, "Cordon", anneau_points((0, 0, 0), 0.275, 0.25, 24), 0.024, "rouge", ferme=True)
	boule(corps, "Noeud", (0, -0.005, 0.265), (0.10, 0.075, 0.07), "rouge")
	courbe(corps, "BoutG", [(-0.02, -0.01, 0.27), (-0.05, -0.07, 0.28), (-0.06, -0.13, 0.26)], 0.014,
		"rouge", effile=[1, 1, 0.7])
	courbe(corps, "BoutD", [(0.02, -0.01, 0.27), (0.05, -0.06, 0.285), (0.08, -0.12, 0.27)], 0.014,
		"rouge", effile=[1, 1, 0.7])
	# Jupe d'armure en quatre plaques lacées de rouge
	for k, (a0, a1) in enumerate(((-40, 40), (50, 130), (140, 220), (230, 310))):
		plaque(corps, "Jupe%d" % k, (0, 0, 0), 0.25, 0.32, -0.03, -0.20, a0, a1, "armure", 0.022)
		for j in range(2):
			y = -0.07 - j * 0.07
			r = 0.25 + 0.07 * (-0.03 - y) / 0.17 + 0.014
			courbe(corps, "LigneJupe%d%d" % (k, j), anneau_points((0, 0, 0), r, r, 8, y, a0 + 3, a1 - 3), 0.008, "rouge")
	# Épaulières courbes, rangs lacés
	for cote, s in ((-1, "G"), (1, "D")):
		sode = pivot(corps, "Sode" + s, (cote * 0.31, 0.30, 0), (0, 0, cote * 22))
		plaque(sode, "Plaque" + s, (-cote * 0.10, 0, 0), 0.12, 0.15, 0.0, -0.20, cote * 50, cote * 130,
			"armure", 0.02)
		for j in range(3):
			y = -0.04 - j * 0.06
			r = 0.12 + 0.03 * -y / 0.2 + 0.012
			courbe(sode, "LacetSode%s%d" % (s, j),
				anneau_points((-cote * 0.10, 0, 0), r, r, 6, y, cote * 55, cote * 125), 0.007, "rouge")

	# Tête : masque oni d'un seul tenant (joues, nez, menton), bouche creusée
	tete = pivot(None, "Tete", (0, 0.98, 0))
	bouche = gabarit("Bouche", (0, -0.155, 0.30), (0.20, 0.07, 0.10), tete)
	fondre(tete, "Masque", [
		boule(tete, "a", (0, -0.04, 0.06), (0.62, 0.56, 0.52), "oni"),
		boule(tete, "b", (-0.15, -0.10, 0.22), (0.17, 0.15, 0.14), "oni"),
		boule(tete, "c", (0.15, -0.10, 0.22), (0.17, 0.15, 0.14), "oni"),
		boule(tete, "d", (0, -0.05, 0.31), (0.10, 0.075, 0.07), "oni"),
		boule(tete, "e", (0, -0.20, 0.20), (0.26, 0.10, 0.16), "oni"),
		boule(tete, "f", (-0.12, 0.06, 0.26), (0.18, 0.08, 0.10), "oni", (0, 0, 15)),
		boule(tete, "g", (0.12, 0.06, 0.26), (0.18, 0.08, 0.10), "oni", (0, 0, -15)),
	], "oni", voxel=0.006, cible=5000, creux=[bouche])
	boule(tete, "Gueule", (0, -0.155, 0.255), (0.19, 0.06, 0.08), "noir")
	boule(tete, "Nuque", (0, -0.02, -0.06), (0.60, 0.56, 0.50), "noir")
	for cote, s in ((-1, "G"), (1, "D")):
		boule(tete, "Oeil" + s, (cote * 0.12, 0.0, 0.283), (0.13, 0.075, 0.05), "jaune", (0, cote * 18, cote * 14))
		boule(tete, "Pupille" + s, (cote * 0.11, -0.003, 0.305), (0.03, 0.04, 0.012), "noir", (0, cote * 18, 0))
		courbe(tete, "Sourcil" + s, [(cote * 0.04, 0.03, 0.335), (cote * 0.12, 0.07, 0.315),
			(cote * 0.20, 0.10, 0.27)], 0.022, "noir", effile=[1.2, 1.0, 0.6])
		pointe(tete, "Croc" + s, (cote * 0.07, -0.13, 0.31), 0.06, 0.035, 0.02, "blanc", (180, 0, 0), 0.2)

	# Casque noir arrondi, visière, couvre-nuque en trois rangs lacés, cimier en U doré
	casque = pivot(tete, "Casque", (0, 0.20, -0.02))
	fondre(casque, "Bol", [
		boule(casque, "a", (0, 0.08, 0), (0.72, 0.46, 0.70), "noir"),
		boule(casque, "b", (0, -0.08, 0.23), (0.66, 0.06, 0.32), "noir", (-12, 0, 0)),
	], "noir", voxel=0.007, cible=3500)
	for i in range(12):
		a = math.radians(i * 30)
		boule(casque, "Rivet%d" % i, (0.355 * math.sin(a), -0.02, 0.345 * math.cos(a)), (0.03, 0.03, 0.03), "or")
	for j in range(3):
		haut, bas = -0.03 - j * 0.07, -0.12 - j * 0.07
		r0, r1 = 0.33 + j * 0.03, 0.37 + j * 0.03
		plaque(casque, "Shikoro%d" % j, (0, 0, -0.03), r0, r1, haut, bas, 75, 285, "noir", 0.02)
		courbe(casque, "Ligne%d" % j, anneau_points((0, 0, -0.03), r1 + 0.008, r1 + 0.008, 16, bas + 0.02, 78, 282),
			0.008, "rouge")
	for cote, s in ((-1, "G"), (1, "D")):
		plaque(casque, "Fukigaeshi" + s, (cote * 0.02, 0, 0), 0.37, 0.43, -0.02, -0.12,
			cote * 52, cote * 78, "noir", 0.02)
	cimier = pivot(casque, "Cimier", (0, 0.06, 0.34))
	tube(cimier, "Rosace", (0, 0, 0), 0.055, 0.03, "or", None, (90, 0, 0))
	boule(cimier, "Coeur", (0, 0, 0.02), (0.05, 0.05, 0.03), "rouge")
	for cote, s in ((-1, "G"), (1, "D")):
		courbe(cimier, "Corne" + s, [(cote * 0.03, 0.0, 0.0), (cote * 0.10, 0.06, 0.01), (cote * 0.14, 0.18, 0.02),
			(cote * 0.15, 0.27, 0.0)], 0.022, "or", effile=[1.0, 1.0, 0.8, 0.5])

	# Bras : le droit tient la lance (hampe en bois, lame argentée, pompon rouge)
	for cote, s in ((-1, "G"), (1, "D")):
		bras = pivot(None, "Bras" + s, (cote * 0.30, 0.60, 0), (0, 0, cote * 14))
		fondre(bras, "Manche" + s, [
			boule(bras, "a", (0, -0.07, 0), (0.16, 0.20, 0.16), "noir"),
			boule(bras, "b", (0, -0.15, 0), (0.18, 0.12, 0.18), "noir"),
		], "noir", voxel=0.006, cible=1200)
		tube(bras, "Kote" + s, (0, -0.20, 0), 0.07, 0.06, "armure", 0.08)
		anneau(bras, "Brassard" + s, (0, -0.175, 0), 0.075, 0.09, 0.02, "rouge")
		fondre(bras, "Gant" + s, [
			boule(bras, "a", (0, -0.255, 0), (0.13, 0.12, 0.13), "noir"),
			boule(bras, "b", (-cote * 0.05, -0.25, 0.04), (0.05, 0.07, 0.05), "noir"),
		], "noir", voxel=0.005, cible=1000)
		if cote > 0:
			lance = pivot(bras, "Lance", (0, -0.25, 0.02), (0, 0, -14))
			tube(lance, "Hampe", (0, 0.30, 0), 0.022, 1.6, "bois")
			tube(lance, "Talon", (0, -0.50, 0), 0.026, 0.05, "noir")
			tube(lance, "Bague", (0, 1.10, 0), 0.03, 0.05, "or")
			tube(lance, "Habaki", (0, 1.14, 0), 0.02, 0.03, "acier")
			pompon = boule(lance, "Pompon", (0, 1.04, 0), (0.12, 0.14, 0.12), "rouge")
			poils = pompon.modifiers.new("Poils", "DISPLACE")
			poils.texture = bpy.data.textures.get("pompon") or bpy.data.textures.new("pompon", "CLOUDS")
			poils.texture.noise_scale = 0.03
			poils.strength = 0.015
			pointe(lance, "Lame", (0, 1.15, 0), 0.36, 0.07, 0.025, "acier", talon=0.25)

	# Jambes : pantalon bouffant, guêtres lacées de rouge, pieds noirs
	for cote, s in ((-1, "G"), (1, "D")):
		jambe = pivot(None, "Jambe" + s, (cote * 0.12, 0.22, 0))
		fondre(jambe, "Pantalon" + s, [
			boule(jambe, "a", (0, -0.03, 0), (0.18, 0.14, 0.18), "noir"),
			boule(jambe, "b", (cote * 0.01, -0.08, 0), (0.21, 0.13, 0.21), "noir"),
		], "noir", voxel=0.006, cible=1200)
		tube(jambe, "Suneate" + s, (0, -0.15, 0), 0.07, 0.07, "armure", 0.078)
		anneau(jambe, "Lien" + s, (0, -0.13, 0), 0.072, 0.09, 0.022, "rouge")
		fondre(jambe, "Pied" + s, [
			boule(jambe, "a", (0, -0.195, 0.03), (0.16, 0.09, 0.22), "noir"),
			boule(jambe, "b", (-cote * 0.035, -0.20, 0.11), (0.065, 0.06, 0.07), "noir"),
		], "noir", voxel=0.005, cible=1000)
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
