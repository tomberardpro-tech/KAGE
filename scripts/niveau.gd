class_name Niveau
extends Node3D
## Règles du niveau : cinématique d'ouverture avec le maître, grande porte du château,
## combat contre le seigneur Oni, coffre du parchemin, points de reprise, sortie, mort et victoire.
## Le HUD et les écrans (tutoriel, pause, défaite, victoire) sont des enfants du niveau.

signal parchemin_pris
signal victoire(temps: float)
signal mort

@export var numero := 1
@export var titre := ""  ## ex. « LE CHÂTEAU », affiché au tutoriel
@export var lieu := ""  ## ex. « Le château », pour la phrase de victoire
@export_multiline var objectif := ""  ## dernière ligne du tutoriel
@export var ou_parchemin := ""  ## rappel si on arrive à la sortie sans le parchemin
@export var ou_sortie := ""  ## message quand on prend le parchemin
@export_file("*.tscn", "*.scn") var niveau_suivant := ""  ## vide : dernier niveau, on revient au menu
@export var cycle_nuages := 14.0  ## secondes entre deux passages de nuages
@export var duree_nuages := 5.0

var lune_visible := true
var a_le_parchemin := false
var temps := 0.0
var fois_repere := 0
var gardes_tues := 0
var decouvert := false  ## entre le moment où un garde nous voit et la reprise
var en_cinematique := false
var combat_en_cours := false

var _conseils_donnes: Array[String] = []
var _point_reprise: Vector3
var _fini := false
var _horloge_lune := 0.0
var _cinema: Cinema
var _camera_cine: Camera3D
var _tween_cine: Tween

@onready var ninja: Ninja = $Ninja
@onready var _camera: Camera3D = $Camera
@onready var _messages: Messages = $Messages
@onready var _ecrans: EcransJeu = $Ecrans
@onready var _lune: DirectionalLight3D = $Lune
@onready var _seigneur: Boss = get_node_or_null("Seigneur")
@onready var _coffre: Coffre = get_node_or_null("Coffre")
@onready var _herse: Porte = get_node_or_null("HerseDonjon")


func _ready() -> void:
	_point_reprise = ninja.global_position
	for garde in get_tree().get_nodes_in_group("gardes"):
		garde.joueur_repere.connect(func(_g): ninja_vaincu())
		garde.chasse_commencee.connect(_sur_chasse)
	for autel in find_children("*", "Autel"):
		autel.active.connect(_sur_autel)
	var parchemin := get_node_or_null("Parchemin")
	if parchemin:
		parchemin.touche.connect(_sur_parchemin)
	$Sortie.touche.connect(_sur_sortie)
	var porte := get_node_or_null("GrandePorte")
	if porte:
		porte.ouverture.connect(_sur_grande_porte)
	var arrivee := get_node_or_null("ArriveeDonjon")
	if arrivee:
		arrivee.entre.connect(_combat)
	if _seigneur:
		_seigneur.vie_changee.connect(_sur_coup_au_seigneur)
		_seigneur.tombe.connect(_sur_seigneur_tombe)
		_seigneur.vaincu.connect(_sur_seigneur_vaincu)
	if _coffre:
		_coffre.ouvert.connect(_cinematique_coffre)
	_cinema = Cinema.new()
	add_child(_cinema)
	_camera_cine = Camera3D.new()
	_camera_cine.fov = 40.0
	_camera_cine.far = 400.0
	add_child(_camera_cine)
	Sons.musique("jeu")
	# ambiance : pluie, esprits et oiseaux qui passent autour du ninja
	for script in [preload("res://scripts/pluie.gd"), preload("res://scripts/esprits.gd"), preload("res://scripts/oiseaux.gd")]:
		var effet = script.new()
		effet.cible = ninja
		add_child(effet)
	_debut()


func _process(delta: float) -> void:
	if not _fini and not en_cinematique:
		temps += delta
		Sons.chasse(en_chasse() and not decouvert and not combat_en_cours)
	# Les nuages passent devant la lune de temps en temps.
	_horloge_lune = fmod(_horloge_lune + delta, cycle_nuages)
	var visible := _horloge_lune < cycle_nuages - duree_nuages
	if visible != lune_visible:
		lune_visible = visible
		for zone in find_children("*", "Zone"):
			if zone.type == Zone.Type.LUNE:
				zone.active = visible
				for lumiere in zone.find_children("*", "Light3D"):
					create_tween().tween_property(lumiere, "light_energy", 2.0 if visible else 0.0, 1.5)
		create_tween().tween_property(_lune, "light_energy", 0.9 if visible else 0.25, 1.5)


func peut_mettre_en_pause() -> bool:
	return not _fini and not decouvert and not en_cinematique


# --- Caméra de cinéma ------------------------------------------------------

## Fait glisser la caméra de cinéma d'un plan à l'autre (position et point visé).
func _glisser(depuis: Vector3, vise_depuis: Vector3, vers: Vector3, vise_vers: Vector3, duree: float) -> void:
	_camera_cine.current = true
	if _tween_cine:
		_tween_cine.kill()  # un seul mouvement de caméra à la fois
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_cine = t
	t.tween_method(func(v: float):
		_camera_cine.global_position = depuis.lerp(vers, v)
		_camera_cine.look_at(vise_depuis.lerp(vise_vers, v), Vector3.UP), 0.0, 1.0, duree)
	if not _cinema.passee.is_connected(_couper_cine):
		_cinema.passee.connect(_couper_cine)


func _couper_cine() -> void:
	if _tween_cine:
		_tween_cine.kill()


func _plan(position: Vector3, vise: Vector3) -> void:
	_couper_cine()
	_camera_cine.current = true
	_camera_cine.global_position = position
	_camera_cine.look_at(vise, Vector3.UP)


## Retour en douceur à la caméra de jeu, au-dessus du ninja.
func _retour_camera(duree := 1.0) -> void:
	_camera.recaler()
	var vise := ninja.global_position + Vector3(0, 0, -0.01)
	if duree > 0.0 and not _cinema.passe:
		var depuis := _camera_cine.global_position
		var vise_depuis := _camera_cine.global_position - _camera_cine.global_basis.z * 10.0
		_glisser(depuis, vise_depuis, _camera.global_position, vise, duree)
		await _cinema.attendre(duree)
	_camera.current = true


func _pret_a_jouer() -> void:
	_cinema.sortir()
	_cinema.cacher_titre()
	ninja.bloque = false
	en_cinematique = false


# --- Ouverture : le maître dans sa cabane ---------------------------------

func _debut() -> void:
	var maitre := get_node_or_null("Maitre") as Node3D
	if maitre == null:
		_ecrans.tutoriel()
		return
	var anim := maitre.get_node_or_null("Animations") as AnimationPlayer
	if anim:
		anim.play("repos")
	ninja.bloque = true
	en_cinematique = true
	_cinema.entrer()
	var donjon := _centre_de("DonjonToit", Vector3(0, 0, -30))
	var porte := _centre_de("GrandePorte", Vector3(0, 0, 20))
	var cabane := _centre_de("CabaneToit", maitre.global_position)
	# 1. le château dans la nuit, puis la grande porte
	_glisser(donjon + Vector3(-14, 24, 30), donjon + Vector3(0, 3, 0), porte + Vector3(6, 13, 18), porte + Vector3(0, 2, 0), 5.0)
	_cinema.titre("KAGE  影", "Le parchemin du clan", 3.0)
	var passe := await _cinema.attendre(5.0)
	# 2. on survole la forêt jusqu'à la cabane du maître
	if not passe:
		_glisser(porte + Vector3(6, 13, 18), porte + Vector3(0, 2, 0), cabane + Vector3(-5, 9, 11), cabane, 4.5)
		passe = await _cinema.attendre(4.5)
	# 3. dans la cabane, le maître salue Kage et lui parle
	if not passe:
		# par-dessus l'épaule de Kage, face au maître
		var dos := (ninja.global_position - maitre.global_position).normalized()
		var cote := dos.cross(Vector3.UP)
		var oeil := ninja.global_position + dos * 1.3 - cote * 1.1 + Vector3(0, 1.6, 0)
		var visage := maitre.global_position + Vector3(0, 0.85, 0)
		_glisser(cabane + Vector3(-5, 9, 11), cabane, oeil, visage, 1.8)
		passe = await _cinema.attendre(1.8)
	if not passe:
		if anim and anim.has_animation("salut"):
			anim.play("salut", 0.3)
			anim.queue("repos")
		passe = await _cinema.attendre(0.8)
	if not passe:
		var dialogue := Dialogue.new()
		add_child(dialogue)
		passe = await dialogue.jouer("intro")
		dialogue.queue_free()
		if passe:
			_cinema.passe = true
	await _retour_camera(1.2)
	_pret_a_jouer()
	_ecrans.tutoriel()


func _centre_de(nom: String, defaut: Vector3) -> Vector3:
	var n := get_node_or_null(nom) as Node3D
	if n == null:
		return defaut
	var emprise = n.get("emprise")
	if emprise is Rect2 and emprise.size != Vector2.ZERO:
		var c: Vector2 = emprise.get_center()
		return Vector3(c.x, 0.0, c.y)
	return n.global_position


# --- La grande porte -------------------------------------------------------

func _sur_grande_porte() -> void:
	ninja.bloque = true
	en_cinematique = true
	_cinema.entrer(false)
	_camera.secouer(0.25)
	await get_tree().create_timer(2.7).timeout
	_camera.secouer(0.5)
	_pret_a_jouer()
	_messages.afficher("LE CHÂTEAU DU SEIGNEUR ONI", "Le parchemin est au cœur du donjon.", 2.5)


# --- Le combat contre le seigneur Oni -------------------------------------

func _combat() -> void:
	if _seigneur == null or _seigneur.etat == Boss.Etat.MORT:
		return
	combat_en_cours = true
	ninja.bloque = true
	en_cinematique = true
	_herse.fermer()
	_camera.secouer(0.4)
	Sons.musique("boss")
	_cinema.entrer(false)
	await get_tree().create_timer(0.6).timeout
	var boss := _seigneur.global_position
	var devant := boss + Vector3(0, 0, 1.0)
	_glisser(_camera.global_position, ninja.global_position, devant + Vector3(1.6, 2.4, 5.0), boss + Vector3(0, 2.2, 0), 1.4)
	await get_tree().create_timer(1.5).timeout
	Sons.jouer("boss_cri", 0.0, 0.85)
	var dialogue := Dialogue.new()
	add_child(dialogue)
	await dialogue.jouer("oni_debut")
	dialogue.queue_free()
	_cinema.passe = false
	await _retour_camera(0.9)
	_pret_a_jouer()
	_seigneur.reveiller()
	_messages.afficher("ESQUIVE SA CHARGE", "Frappe-le quand il reprend son souffle. Saute par-dessus l'onde.", 3.0)


## Ralenti sur le dernier coup.
func _sur_coup_au_seigneur(vie: int, _vie_max: int) -> void:
	if vie > 0:
		return
	Engine.time_scale = 0.3
	await get_tree().create_timer(0.9, true, false, true).timeout
	Engine.time_scale = 1.0


func _sur_seigneur_tombe() -> void:
	ninja.bloque = true
	en_cinematique = true
	Sons.musique("")
	var dialogue := Dialogue.new()
	add_child(dialogue)
	await dialogue.jouer("oni_fin")
	dialogue.queue_free()
	_seigneur.disparaitre()


func _sur_seigneur_vaincu() -> void:
	combat_en_cours = false
	ninja.bloque = false
	en_cinematique = false
	_herse.ouvrir()
	_coffre.apparaitre()
	Sons.musique("jeu")
	_messages.afficher("LE SEIGNEUR ONI EST VAINCU", "Un coffre est apparu. Ouvre-le (E).", 3.0)


# --- Le coffre et le parchemin --------------------------------------------

## Comme dans les vieux jeux d'aventure : on ouvre le coffre, on brandit le trésor.
func _cinematique_coffre() -> void:
	ninja.bloque = true
	en_cinematique = true
	_cinema.entrer(false)
	var coffre := _coffre.global_position
	# le ninja se place devant le coffre et le regarde
	var place := coffre + Vector3(0, 0, 1.25)
	var visuel: Node3D = ninja.get_node("Visuel")
	var t := create_tween().set_parallel()
	t.tween_property(ninja, "global_position", Vector3(place.x, ninja.global_position.y, place.z), 0.5)
	t.tween_property(visuel, "rotation:y", PI, 0.3)
	_glisser(_camera.global_position, ninja.global_position, coffre + Vector3(2.8, 1.7, 2.6), coffre + Vector3(0, 0.6, 0.5), 1.0)
	await get_tree().create_timer(1.0).timeout
	await _coffre.ouvrir_couvercle(1.2)
	# il se retourne vers nous et brandit le parchemin
	visuel.rotation.y = 0.0
	_plan(ninja.global_position + Vector3(0.5, 1.5, 4.4), ninja.global_position + Vector3(0, 1.3, 0))
	ninja.pose_forcee = "brandir"
	var rouleau := _rouleau_brandi()
	ninja.add_child(rouleau)
	rouleau.position = Vector3(0, 1.7, 0.05)
	rouleau.scale = Vector3.ONE * 0.01
	create_tween().tween_property(rouleau, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sons.jingle("tresor")
	_cinema.titre("PARCHEMIN DU CLAN", "Tu as repris le parchemin volé par le seigneur Oni !", 2.6, 0.72)
	await get_tree().create_timer(3.8).timeout
	rouleau.queue_free()
	ninja.pose_forcee = ""
	_coffre.eteindre_rayon()
	_cinema.cacher_titre()
	_sur_parchemin()
	_camera.recaler()
	_camera.current = true
	_pret_a_jouer()
	Sons.musique("jeu")


## Rouleau de papier washi aux embouts laqués, avec un halo et des rayons dorés derrière lui.
func _rouleau_brandi() -> Node3D:
	var n := Node3D.new()
	var papier := StandardMaterial3D.new()
	papier.albedo_color = Palette.WASHI
	papier.emission_enabled = true
	papier.emission = Color(1.0, 0.9, 0.7)
	papier.emission_energy_multiplier = 0.5
	var laque := StandardMaterial3D.new()
	laque.albedo_color = Palette.LAQUE
	var corps := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.height = 0.62
	corps.mesh = cyl
	corps.material_override = papier
	corps.rotation.z = PI / 2.0
	n.add_child(corps)
	for s in [-1.0, 1.0]:
		var bout := MeshInstance3D.new()
		var b := CylinderMesh.new()
		b.top_radius = 0.085
		b.bottom_radius = 0.085
		b.height = 0.06
		bout.mesh = b
		bout.material_override = laque
		bout.rotation.z = PI / 2.0
		bout.position.x = s * 0.33
		n.add_child(bout)
	var rayons := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 2.2)
	rayons.mesh = q
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x);
	float rais = pow(abs(sin(a * 6.0 + TIME * 0.8)), 6.0);
	ALBEDO = vec3(1.0, 0.8, 0.4) * (rais * smoothstep(1.0, 0.1, r) * 0.7 + smoothstep(0.5, 0.0, r) * 0.6);
}
"""
	rayons.material_override = m
	rayons.position.z = -0.12
	rayons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(rayons)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.85, 0.55)
	lumiere.light_energy = 2.0
	lumiere.omni_range = 4.0
	n.add_child(lumiere)
	return n


# --- Reprise, parchemin, sortie --------------------------------------------

func _sur_autel(autel: Autel) -> void:
	if _point_reprise.distance_to(autel.global_position) > 1.0:
		_point_reprise = autel.global_position + Vector3(0, 0, 1.2)
		if autel.name != "Depart":
			Sons.jouer("autel")
			_messages.afficher("AUTEL", "Tu repartiras d'ici.", 1.6)


func _sur_parchemin() -> void:
	if a_le_parchemin:
		return
	a_le_parchemin = true
	var parchemin := get_node_or_null("Parchemin")
	if parchemin:
		parchemin.queue_free()
	parchemin_pris.emit()
	Sons.jouer("parchemin")
	_messages.afficher("PARCHEMIN RÉCUPÉRÉ", ou_sortie, 3.0)


func _sur_sortie() -> void:
	if _fini:
		return
	if not a_le_parchemin:
		_messages.afficher("PAS SANS LE PARCHEMIN", ou_parchemin, 2.0)
		return
	_fini = true
	ninja.bloque = true
	victoire.emit(temps)
	Sons.jingle("victoire")
	if not niveau_suivant.is_empty():
		Sauvegarde.atteindre(niveau_suivant)
	_ecrans.victoire(temps, fois_repere == 0, gardes_tues == 0)


## Un garde nous a vus : il nous prend en chasse. Le bonus Fantôme est perdu.
func _sur_chasse(garde: Garde) -> void:
	var deja := get_tree().get_nodes_in_group("gardes").any(
		func(g: Garde): return g != garde and g.etat == Garde.Etat.CHASSE)
	if not deja:
		_messages.afficher("REPÉRÉ", "Sème-le, cache-toi ou tranche-le.", 1.6)
		Sons.jouer("alerte")
	fois_repere += 1


## Vrai tant qu'au moins un garde nous poursuit.
func en_chasse() -> bool:
	for garde: Garde in get_tree().get_nodes_in_group("gardes"):
		if garde.etat == Garde.Etat.CHASSE:
			return true
	return false


## Bruit à un endroit (plancher qui grince, clochettes) : les gardes à portée viennent voir.
func bruit(point: Vector3, rayon: float, conseil := "") -> void:
	Onde.emettre(self, point, rayon)
	for garde: Garde in get_tree().get_nodes_in_group("gardes"):
		if garde.global_position.distance_to(point) < rayon:
			garde.entendre(point)
	if not conseil.is_empty() and conseil not in _conseils_donnes:
		_conseils_donnes.append(conseil)
		_messages.afficher("CHUT !", conseil, 2.5)


## Le ninja n'a plus de vie (un garde ou le seigneur Oni a porté le dernier coup).
func ninja_vaincu() -> void:
	if decouvert:
		return
	ninja.bloque = true
	decouvert = true
	Sons.jingle("defaite")
	mort.emit()
	await get_tree().create_timer(0.8).timeout
	_ecrans.defaite()


## Les gardes reprennent leur ronde et le ninja repart du dernier autel.
func recommencer_a_l_autel() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	for garde in get_tree().get_nodes_in_group("gardes"):
		garde.reinitialiser()
	if combat_en_cours and _seigneur:
		# le combat reprend depuis le début : herse levée, seigneur en pleine forme
		combat_en_cours = false
		_seigneur.reinitialiser()
		_herse.relever()
		get_node("ArriveeDonjon").rearmer()
	ninja.reapparaitre(_point_reprise)
	ninja.bloque = false
	decouvert = false
	Sons.musique("jeu")


func compter_garde_tue() -> void:
	gardes_tues += 1
