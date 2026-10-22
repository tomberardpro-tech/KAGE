extends Node3D
## Porte d'un bâtiment, façon Pokémon (construite par scripts/tools/interieurs.gd) :
## E « Entrer chez … » ou « Sortir ». Fondu au noir rapide, le ninja passe d'un coup à
## l'`arrivee` (la pièce, construite loin de la carte, ou dehors devant la porte), la caméra
## se recale, puis fondu retour.
## On ne passe une porte que de face : le ninja doit se tenir DEVANT elle (côté +z local du nœud,
## tourné par scripts/tools/interieurs.gd vers la rue, ou vers la pièce pour la sortie), dans un
## petit passage qui s'évase un peu ; ni de côté le long du mur, ni de derrière.
## Une des portes veille aussi à l'ambiance : tant que le ninja est dans un intérieur, les esprits
## et les oiseaux qui passent autour de lui (niveau.gd) sont mis en sommeil.

const FONDU := 0.35  ## s, dans chaque sens
const X_INTERIEURS := 400.0  ## m : au-delà, le ninja est dans un intérieur
const AMBIANCE := ["res://scripts/esprits.gd", "res://scripts/oiseaux.gd"]
const DEVANT_LARGEUR := 0.6  ## m : demi-largeur du passage, au ras de la porte
const DEVANT_EVASEMENT := 0.3  ## m de demi-largeur en plus par mètre devant la porte
const DEVANT_RECUL := 0.25  ## m : tolérance derrière le plan de la porte (le nœud est un peu devant le mur)
const DEVANT_PROFONDEUR := 2.2

@export var texte := "Entrer"
@export var arrivee := Vector3.ZERO  ## position (monde) où le ninja réapparaît
@export var regard := PI  ## rotation du ninja à l'arrivée (PI : vers le nord)

static var _veilleur: Node = null


func _ready() -> void:
	add_to_group("interactifs")
	if not is_instance_valid(_veilleur):
		_veilleur = self
	set_process(_veilleur == self)


func _exit_tree() -> void:
	if _veilleur == self:
		_veilleur = null


func _process(_delta: float) -> void:
	_veiller(get_tree())


func texte_action() -> String:
	return texte


func peut_interagir() -> bool:
	var niveau := get_tree().current_scene
	if niveau == null:
		return true
	var voile := niveau.get_node_or_null("VoilePortes")
	if voile and voile.get_meta("en_cours", false):
		return false
	if niveau.get("en_cinematique") == true or niveau.get("decouvert") == true:
		return false
	var ninja := get_tree().get_first_node_in_group("ninja") as Node3D
	if ninja and not est_devant(ninja.global_position):
		return false
	# on ne se réfugie pas dans une maison avec un garde aux trousses
	var entree := arrivee.x > X_INTERIEURS
	if entree and niveau.has_method("en_chasse") and niveau.en_chasse():
		return false
	return true


## Vrai si `point` (monde) est devant la porte, face à elle.
func est_devant(point: Vector3) -> bool:
	var local := to_local(point)
	if local.z < -DEVANT_RECUL or local.z > DEVANT_PROFONDEUR:
		return false
	return absf(local.x) <= DEVANT_LARGEUR + maxf(local.z, 0.0) * DEVANT_EVASEMENT


func interagir() -> void:
	if not peut_interagir():
		return
	var niveau := get_tree().current_scene
	var ninja := get_tree().get_first_node_in_group("ninja") as CharacterBody3D
	if ninja == null:
		return
	var voile := _voile(niveau)
	voile.set_meta("en_cours", true)
	var rideau := voile.get_child(0) as ColorRect
	ninja.set("bloque", true)
	Sons.jouer("porte", -12.0, 1.35)
	var t := rideau.create_tween()
	t.tween_property(rideau, "color:a", 1.0, FONDU)
	await t.finished
	if not is_instance_valid(ninja):
		return
	ninja.global_position = arrivee
	ninja.velocity = Vector3.ZERO
	var visuel := ninja.get_node_or_null("Visuel") as Node3D
	if visuel:
		visuel.rotation.y = regard
	_veiller(get_tree())
	var camera := niveau.get_node_or_null("Camera")
	if camera and camera.has_method("recaler"):
		camera.recaler()
	# deux images de physique : le ninja retombe sur le sol, les zones qu'il a quittées le lâchent
	await get_tree().physics_frame
	await get_tree().physics_frame
	if camera and camera.has_method("recaler"):
		camera.recaler()
	ninja.set("bloque", false)
	t = rideau.create_tween()
	t.tween_property(rideau, "color:a", 0.0, FONDU)
	await t.finished
	voile.set_meta("en_cours", false)


## Calque noir plein écran, partagé par toutes les portes du niveau (sous l'écran de chargement).
func _voile(niveau: Node) -> CanvasLayer:
	var voile := niveau.get_node_or_null("VoilePortes") as CanvasLayer
	if voile:
		return voile
	voile = CanvasLayer.new()
	voile.name = "VoilePortes"
	voile.layer = 90
	voile.process_mode = Node.PROCESS_MODE_ALWAYS
	var rideau := ColorRect.new()
	rideau.color = Color(0.03, 0.03, 0.04, 0.0)
	rideau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rideau.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.add_child(rideau)
	niveau.add_child(voile)
	return voile


## Dans un intérieur, les esprits et les oiseaux du niveau dorment (et ne s'affichent pas).
static func _veiller(arbre: SceneTree) -> void:
	var niveau := arbre.current_scene
	var ninja := arbre.get_first_node_in_group("ninja") as Node3D
	if niveau == null or ninja == null:
		return
	var dedans := ninja.global_position.x > X_INTERIEURS
	for enfant in niveau.get_children():
		var script := enfant.get_script() as Script
		if script == null or script.resource_path not in AMBIANCE:
			continue
		var n3 := enfant as Node3D
		if n3 and n3.visible == dedans:
			n3.visible = not dedans
			n3.process_mode = Node.PROCESS_MODE_DISABLED if dedans else Node.PROCESS_MODE_INHERIT
