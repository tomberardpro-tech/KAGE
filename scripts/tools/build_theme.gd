extends SceneTree
## Génère assets/ui/kage_theme.tres à partir de la charte Figma.
## Lancer : godot --headless --script res://scripts/tools/build_theme.gd

const FONTS := "res://assets/fonts/"


func _init() -> void:
	var anton: FontFile = load(FONTS + "Anton-Regular.ttf")
	var plex: FontFile = load(FONTS + "IBMPlexSansJP-Regular.ttf")
	var plex_medium: FontFile = load(FONTS + "IBMPlexSansJP-Medium.ttf")
	var plex_semibold: FontFile = load(FONTS + "IBMPlexSansJP-SemiBold.ttf")
	var plex_bold: FontFile = load(FONTS + "IBMPlexSansJP-Bold.ttf")
	var kanji: FontFile = load(FONTS + "NotoSerifJP-Black-subset.ttf")

	var theme := Theme.new()
	theme.default_font = plex
	theme.default_font_size = 22

	# Textes courants
	theme.set_color("font_color", "Label", Palette.WASHI)
	theme.set_color("font_color", "RichTextLabel", Palette.WASHI)

	# Variantes de titres (tailles relevées dans Figma)
	_label(theme, "TitreLogo", anton, 210, Palette.WASHI)       # KAGE
	_label(theme, "TitreEcran", anton, 140, Palette.WASHI)      # PAUSE, VICTOIRE…
	_label(theme, "TitreHud", anton, 51, Palette.WASHI)         # CACHÉ, 0 / 1
	_label(theme, "TitreParchemin", anton, 32, Palette.ENCRE)   # SE CACHER
	_label(theme, "SousTitre", plex_medium, 22, Palette.GRIS)   # THE SHADOW · …
	_label(theme, "Consigne", plex_semibold, 30, Palette.WASHI) # TRANCHER LA LANTERNE
	_label(theme, "TexteParchemin", plex, 22, Palette.ENCRE)    # textes des tutoriels
	_label(theme, "Etiquette", plex_semibold, 20, Palette.LAQUE)# TUTORIEL, DIALOGUE
	_label(theme, "Aide", plex_medium, 18, Palette.GRIS)        # CHOISIR, VALIDER
	_label(theme, "Touche", plex_bold, 18, Palette.ENCRE)       # ↑ ↓, ENTRÉE
	_label(theme, "Version", plex, 16, Palette.GRIS)
	_label(theme, "Kanji", kanji, 48, Palette.LAQUE)            # 影 忍
	_label(theme, "KanjiFond", kanji, 600, Color(Palette.WASHI, 0.06)) # grand 休 en fond

	# Boutons du menu : texte Anton sur fond transparent, parchemin au survol
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 28
	empty.content_margin_right = 28
	var parchemin := _parchemin_box()
	theme.set_type_variation("BoutonMenu", "Button")
	theme.set_font("font", "BoutonMenu", anton)
	theme.set_font_size("font_size", "BoutonMenu", 50)
	theme.set_color("font_color", "BoutonMenu", Palette.WASHI)
	theme.set_color("font_hover_color", "BoutonMenu", Palette.ENCRE)
	theme.set_color("font_focus_color", "BoutonMenu", Palette.ENCRE)
	theme.set_color("font_pressed_color", "BoutonMenu", Palette.LAQUE)
	theme.set_color("font_disabled_color", "BoutonMenu", Palette.GRIS)
	theme.set_stylebox("normal", "BoutonMenu", empty)
	theme.set_stylebox("disabled", "BoutonMenu", empty)
	theme.set_stylebox("hover", "BoutonMenu", parchemin)
	theme.set_stylebox("focus", "BoutonMenu", parchemin)
	theme.set_stylebox("pressed", "BoutonMenu", parchemin)
	theme.set_constant("h_separation", "BoutonMenu", 16)

	# Panneaux parchemin (tutoriels, dialogues, bannières)
	theme.set_type_variation("Parchemin", "PanelContainer")
	theme.set_stylebox("panel", "Parchemin", _parchemin_box(32, 24))

	# Panneau sombre (fond des écrans pause / défaite)
	var voile := StyleBoxFlat.new()
	voile.bg_color = Color(Palette.NOIR, 0.82)
	theme.set_type_variation("Voile", "PanelContainer")
	theme.set_stylebox("panel", "Voile", voile)

	# Touche de clavier (petite étiquette claire)
	var touche := StyleBoxFlat.new()
	touche.bg_color = Palette.WASHI
	touche.set_corner_radius_all(4)
	touche.content_margin_left = 10
	touche.content_margin_right = 10
	touche.content_margin_top = 4
	touche.content_margin_bottom = 4
	theme.set_type_variation("ToucheCadre", "PanelContainer")
	theme.set_stylebox("panel", "ToucheCadre", touche)

	var err := ResourceSaver.save(theme, "res://assets/ui/kage_theme.tres")
	print("kage_theme.tres -> ", error_string(err))
	quit(err)


func _label(theme: Theme, name: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


func _parchemin_box(h_margin := 28, v_margin := 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.WASHI
	box.border_color = Palette.OR
	box.border_width_left = 8      # bout du rouleau
	box.border_width_right = 8
	box.set_corner_radius_all(3)
	box.content_margin_left = h_margin
	box.content_margin_right = h_margin
	box.content_margin_top = v_margin
	box.content_margin_bottom = v_margin
	box.shadow_color = Color(Palette.NOIR, 0.45)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 4)
	return box
