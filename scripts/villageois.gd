extends Node3D
## Villageois de la forêt : il vaque à ses occupations (va et vient, ou reste là), se tourne vers
## le ninja quand il passe, le salue et lui dit un mot (bulle + voix en japonais).

@export var replique_jp := ""
@export var replique := ""
@export var voix := ""  ## nom du fichier son dans assets/audio/voix/
@export var aller := Vector3.ZERO  ## autre bout de son trajet ; zéro : il reste sur place

var _depart: Vector3
var _vers_aller := true
var _pause := 0.0
var _a_parle := 0.0
var _modele: Node3D
var _animations: AnimationPlayer
var _bulle: Label3D
var _son: AudioStreamPlayer3D


func _ready() -> void:
	_depart = position
	_modele = get_node("Modele")
	_animations = _modele.get_node_or_null("Animations")
	_bulle = Label3D.new()
	_bulle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bulle.no_depth_test = true
	_bulle.font_size = 30
	_bulle.outline_size = 10
	_bulle.modulate = Color(Palette.WASHI)
	_bulle.outline_modulate = Color(Palette.NOIR, 0.9)
	_bulle.position.y = 2.0
	_bulle.width = 380.0
	_bulle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bulle.text = replique_jp + "\n" + replique
	_bulle.modulate.a = 0.0
	# les kanji viennent de la police des dialogues, le reste de la police du jeu
	var police: FontFile = load("res://assets/fonts/NotoSerifJP-Bold-dialogues.otf").duplicate()
	police.fallbacks = [load("res://assets/fonts/IBMPlexSansJP-SemiBold.ttf")]
	_bulle.font = police
	add_child(_bulle)
	_son = AudioStreamPlayer3D.new()
	var chemin := "res://assets/audio/voix/%s.ogg" % voix
	if ResourceLoader.exists(chemin):
		_son.stream = load(chemin)
	_son.unit_size = 6.0
	_son.volume_db = -2.0
	add_child(_son)
	_jouer("repos")


func _process(delta: float) -> void:
	var ninja: Node3D = get_tree().get_first_node_in_group("ninja")
	var proche := ninja != null and ninja.global_position.distance_to(global_position) < 3.2
	_a_parle -= delta
	if proche:
		# il s'arrête et se tourne vers le ninja
		var vers := ninja.global_position - global_position
		_tourner(atan2(vers.x, vers.z), delta * 5.0)
		_jouer("repos")
		if _a_parle <= 0.0:
			_a_parle = 14.0
			_parler()
		return
	if aller == Vector3.ZERO:
		_jouer("repos")
		return
	if _pause > 0.0:
		_pause -= delta
		_jouer("repos")
		return
	var but := aller if _vers_aller else _depart
	var ecart := but - position
	ecart.y = 0.0
	if ecart.length() < 0.2:
		_vers_aller = not _vers_aller
		_pause = randf_range(2.0, 4.0)
		return
	position += ecart.normalized() * 0.9 * delta
	_tourner(atan2(ecart.x, ecart.z), delta * 4.0)
	_jouer("marche")


func _parler() -> void:
	if _animations and _animations.has_animation("salut"):
		_animations.play("salut", 0.2)
	if _son.stream:
		_son.play()
	var t := create_tween()
	t.tween_property(_bulle, "modulate:a", 1.0, 0.3)
	t.tween_interval(3.5)
	t.tween_property(_bulle, "modulate:a", 0.0, 0.6)


func _jouer(nom: String) -> void:
	if _animations == null or not _animations.has_animation(nom):
		return
	if _animations.current_animation == "salut" and _animations.is_playing():
		return
	if _animations.current_animation != nom:
		_animations.play(nom, 0.25)


func _tourner(angle: float, poids: float) -> void:
	_modele.rotation.y = lerp_angle(_modele.rotation.y, angle, clampf(poids, 0.0, 1.0))
