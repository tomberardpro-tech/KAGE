extends Camera3D
## Caméra haute et dézoomée, orientée plein nord, qui suit le ninja en douceur.
## secouer() la fait trembler un instant (grande porte, coups du boss).
## U change de vue (glissement doux). Toutes regardent plein nord : les touches gardent
## le même sens (haut = nord) dans chaque vue.

@export var target: Node3D
@export var offset := Vector3(0.0, 10.5, 11.0)
@export var smoothing := 6.0

## Vues : [nom, décalage, point visé au-dessus du ninja, champ de vision]. La 1re utilise `offset`.
const VUES := [
	["Vue haute", Vector3.ZERO, Vector3.ZERO, 40.0],
	["Épaule", Vector3(0.8, 2.4, 4.2), Vector3(0.8, 1.1, 0.0), 55.0],
	["Tactique", Vector3(0.0, 21.0, 8.0), Vector3.ZERO, 45.0],
	["Isométrique", Vector3(0.0, 15.0, 27.0), Vector3.ZERO, 24.0],
]

## Vue choisie, gardée pour toute la partie (même après un rechargement du niveau).
static var vue := 0

var _secousse := 0.0
var _base := Vector3.ZERO
var _decalage := Vector3.ZERO  ## décalage et visée de la vue, qui glissent vers la vue choisie
var _visee := Vector3.ZERO
var _titre: Label
var _anim: Tween


func _ready() -> void:
	_decalage = _offset_vue()
	_visee = VUES[vue][2]
	fov = VUES[vue][3]
	if target:
		global_position = target.global_position + _decalage
	_base = global_position
	look_at(global_position - _decalage + _visee, Vector3.UP)
	_creer_titre()


func secouer(force: float) -> void:
	_secousse = maxf(_secousse, force)


## Replace la caméra d'un coup derrière le ninja (fin d'une cinématique).
func recaler() -> void:
	_decalage = _offset_vue()
	_visee = VUES[vue][2]
	fov = VUES[vue][3]
	if target:
		_base = target.global_position + _decalage
		global_position = _base
		look_at(target.global_position + _visee, Vector3.UP)


## Passe à la vue suivante.
func changer_vue() -> void:
	vue = (vue + 1) % VUES.size()
	_montrer_titre(VUES[vue][0])


func _offset_vue() -> Vector3:
	return offset if vue == 0 else VUES[vue][1]


func _physics_process(delta: float) -> void:
	if not target:
		return
	if current and Input.is_action_just_pressed("vue"):
		changer_vue()
	var glisse := 1.0 - exp(-4.0 * delta)
	_decalage = _decalage.lerp(_offset_vue(), glisse)
	_visee = _visee.lerp(VUES[vue][2], glisse)
	fov = lerpf(fov, VUES[vue][3], glisse)
	var goal := target.global_position + _decalage
	_base = _base.lerp(goal, 1.0 - exp(-smoothing * delta))
	_secousse = move_toward(_secousse, 0.0, delta * 1.5)
	var tremble := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _secousse * 0.6
	global_position = _base + tremble
	# on regarde toujours plein nord, vers le point visé de la vue
	look_at(_base - _decalage + _visee + tremble, Vector3.UP)


# --- Nom de la vue, affiché un instant -----------------------------------

func _creer_titre() -> void:
	var calque := CanvasLayer.new()
	calque.layer = 6
	add_child(calque)
	_titre = Label.new()
	_titre.add_theme_font_override("font", load("res://assets/fonts/IBMPlexSansJP-SemiBold.ttf"))
	_titre.add_theme_font_size_override("font_size", 28)
	_titre.add_theme_color_override("font_color", Palette.WASHI)
	_titre.add_theme_color_override("font_outline_color", Color(Palette.NOIR, 0.8))
	_titre.add_theme_constant_override("outline_size", 8)
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titre.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_titre.offset_top = 120
	_titre.modulate.a = 0.0
	calque.add_child(_titre)


func _montrer_titre(texte: String) -> void:
	_titre.text = "VUE · " + texte.to_upper()
	if _anim and _anim.is_valid():
		_anim.kill()
	var t := _titre.create_tween()
	_anim = t
	t.tween_property(_titre, "modulate:a", 1.0, 0.2)
	t.tween_interval(1.2)
	t.tween_property(_titre, "modulate:a", 0.0, 0.5)
