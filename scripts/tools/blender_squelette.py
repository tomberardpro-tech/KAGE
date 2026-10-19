# KAGE : pose un squelette simple sur un personnage généré par IA (un seul maillage).
#
# Utilisation : onglet Scripting > Nouveau > coller ce fichier > ▶.
# Pour chaque personnage (ninja_ia.glb et garde_ia.glb posés sur le Bureau), le script
# importe le .glb, le met à sa taille (pieds au sol, face vers l'avant), lisse les
# facettes, éclaircit un peu la texture, crée les os Corps, Tete, BrasG, BrasD,
# JambeG, JambeD (mêmes noms que dans le jeu), répartit les poids par zones avec des
# fondus doux, et exporte ninja.glb / garde.glb dans KAGE_modeles.

import os

import bpy
import numpy as np
from mathutils import Vector

BUREAU = os.path.join(os.path.expanduser("~"), "Desktop")
LUMIERE = 1.35  # éclaircit la texture (les modèles générés sortent assez sombres)
TEXTURE_MAX = 1024

# Repères du corps en mètres (x = côté, z = hauteur), relevés sur chaque modèle
PROFILS = {
	"ninja": dict(hauteur=1.25, hanche=0.30, epaule=0.56, cou=0.63, ecart_jambes=0.115,
		ecart_bras=0.17, bas_bras=0.22, main=(0.27, 0.30), pan_foulard=True),
	"garde": dict(hauteur=1.40, hanche=0.22, epaule=0.56, cou=0.61, ecart_jambes=0.10,
		ecart_bras=0.22, bas_bras=0.20, main=(0.36, 0.38), pan_foulard=False),
}
FONDU = 0.04  # largeur des zones où deux os se partagent la peau


def importer(nom, p):
	for o in list(bpy.data.objects):
		bpy.data.objects.remove(o)
	bpy.ops.import_scene.gltf(filepath=os.path.join(BUREAU, nom + "_ia.glb"))
	for o in [o for o in bpy.data.objects if o.type in ("LIGHT", "CAMERA")]:
		bpy.data.objects.remove(o)
	maillages = [o for o in bpy.data.objects if o.type == "MESH"]
	bpy.ops.object.select_all(action="DESELECT")
	for o in maillages:
		o.select_set(True)
	bpy.context.view_layer.objects.active = maillages[0]
	if len(maillages) > 1:
		bpy.ops.object.join()
	corps = bpy.context.view_layer.objects.active
	# détache des nœuds vides en gardant la place, puis fige les transformations
	bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
	for o in [o for o in bpy.data.objects if o.type == "EMPTY"]:
		bpy.data.objects.remove(o)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	corps.name = corps.data.name = nom.capitalize()
	# mise à l'échelle : pieds à 0, centré sur la tête (foulard ou lance débordent d'un côté)
	v = np.array([x.co[:] for x in corps.data.vertices])
	h = v[:, 2].max() - v[:, 2].min()
	k = p["hauteur"] / h
	zr = (v[:, 2] - v[:, 2].min()) / h
	tete = v[(zr > 0.55) & (zr < 0.7)]
	cx = (tete[:, 0].max() + tete[:, 0].min()) / 2
	cy = (tete[:, 1].max() + tete[:, 1].min()) / 2
	for x in corps.data.vertices:
		x.co = Vector(((x.co.x - cx) * k, (x.co.y - cy) * k, (x.co.z - v[:, 2].min()) * k))
	corps.data.update()
	lisser(corps)
	return corps


def lisser(corps):
	"""Adoucit les facettes : soude les sommets en double, ombrage lisse, léger lissage."""
	bpy.context.view_layer.objects.active = corps
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.mesh.remove_doubles(threshold=0.0004)
	bpy.ops.object.mode_set(mode="OBJECT")
	for f in corps.data.polygons:
		f.use_smooth = True
	m = corps.modifiers.new("Doux", "CORRECTIVE_SMOOTH")
	m.factor, m.iterations, m.smooth_type = 0.5, 4, "LENGTH_WEIGHTED"
	m.use_only_smooth = True
	bpy.ops.object.modifier_apply(modifier=m.name)
	for img in bpy.data.images:
		if img.size[0] and LUMIERE != 1.0:
			px = np.array(img.pixels[:]).reshape(-1, 4)
			px[:, :3] = np.clip(px[:, :3] * LUMIERE, 0, 1)
			img.pixels.foreach_set(px.astype(np.float32).ravel())
		if img.size[0] > TEXTURE_MAX:  # 1024 px suffit à l'écran et allège le jeu web
			img.scale(TEXTURE_MAX, TEXTURE_MAX)
		if img.size[0]:
			img.pack()


def squelette(p):
	donnees = bpy.data.armatures.new("Squelette")
	arm = bpy.data.objects.new("Squelette", donnees)
	bpy.context.collection.objects.link(arm)
	bpy.context.view_layer.objects.active = arm
	bpy.ops.object.mode_set(mode="EDIT")
	os_ = donnees.edit_bones

	def os_neuf(nom, tete, queue, parent=None):
		b = os_.new(nom)
		b.head, b.tail, b.roll = Vector(tete), Vector(queue), 0.0
		b.parent = parent
		return b

	racine = os_neuf("Racine", (0, 0, 0), (0, 0.15, 0))
	corps = os_neuf("Corps", (0, 0, p["hanche"]), (0, 0, p["cou"] - 0.03), racine)
	os_neuf("Tete", (0, 0, p["cou"]), (0, 0, p["hauteur"] - 0.05), corps)
	for cote, s in ((-1, "G"), (1, "D")):
		os_neuf("Bras" + s, (cote * p["ecart_bras"], 0, p["epaule"]),
			(cote * p["main"][0], 0, p["main"][1]), corps)
		os_neuf("Jambe" + s, (cote * p["ecart_jambes"], 0, p["hanche"]),
			(cote * p["ecart_jambes"], 0, 0.03), racine)
	bpy.ops.object.mode_set(mode="OBJECT")
	return arm


def rampe(x, debut, fin):
	"""0 avant `debut`, 1 après `fin`, fondu doux entre les deux."""
	t = np.clip((x - debut) / (fin - debut), 0, 1)
	return t * t * (3 - 2 * t)


def poids(corps, arm, p):
	v = np.array([x.co[:] for x in corps.data.vertices])
	x, y, z = v[:, 0], v[:, 1], v[:, 2]
	ax = np.abs(x)
	# jambes : sous la hanche
	jambe = 1 - rampe(z, p["hanche"] - FONDU, p["hanche"] + FONDU)
	# bras : sur les côtés, entre la main et l'épaule
	bras = rampe(ax, p["ecart_bras"], p["ecart_bras"] + FONDU) * (1 - rampe(z, p["epaule"], p["epaule"] + FONDU))
	bras *= rampe(z, p["bas_bras"], p["bas_bras"] + FONDU)
	if p["pan_foulard"]:  # le pan du foulard (derrière, en haut) reste au corps
		bras[(y > 0.03) & (z > 0.40) & (ax > 0.24)] = 0
	else:  # la lance suit la main qui la tient, sur toute sa hauteur
		bras[(x < -0.29)] = 1
	bras *= 1 - jambe
	# tête : au-dessus du cou
	tete = rampe(z, p["cou"] - FONDU, p["cou"] + FONDU) * (1 - bras)
	reste = np.clip(1 - jambe - bras - tete, 0, 1)
	groupes = {nom: corps.vertex_groups.new(name=nom) for nom in
		("Corps", "Tete", "BrasG", "BrasD", "JambeG", "JambeD")}
	for i in range(len(v)):
		g, d = x[i] < 0, x[i] >= 0
		for nom, w in (("Corps", reste[i]), ("Tete", tete[i]),
				("BrasG" if g else "BrasD", bras[i]), ("JambeG" if g else "JambeD", jambe[i])):
			if w > 0.001:
				groupes[nom].add([i], float(w), "REPLACE")
	m = corps.modifiers.new("Squelette", "ARMATURE")
	m.object = arm
	corps.parent = arm


def exporter(nom):
	dossier = os.path.join(BUREAU, "KAGE_modeles")
	os.makedirs(dossier, exist_ok=True)
	chemin = os.path.join(dossier, nom + ".glb")
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(filepath=chemin, export_format="GLB", export_yup=True,
		export_skins=True, export_animations=False, export_lights=False, export_cameras=False)
	print("KAGE : exporté", chemin)


def preparer(nom):
	p = PROFILS[nom]
	corps = importer(nom, p)
	arm = squelette(p)
	poids(corps, arm, p)
	return arm


if __name__ == "__main__":
	if bpy.context.object and bpy.context.object.mode != "OBJECT":
		bpy.ops.object.mode_set(mode="OBJECT")
	for nom in PROFILS:
		if os.path.exists(os.path.join(BUREAU, nom + "_ia.glb")):
			preparer(nom)
			exporter(nom)
