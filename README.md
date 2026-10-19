# KAGE

Jeu d'infiltration ninja en 3D, style chibi. Le joueur se faufile de nuit, de l'entrée du château jusqu'au donjon, sans se faire repérer par les gardes.

Projet scolaire, réalisé avec Godot 4 et publié en version web sur itch.io.

## Ouvrir le projet

1. Installer [Godot 4.4 ou plus](https://godotengine.org/download) (version standard, pas .NET).
2. Dans Godot : **Importer**, puis choisir `project.godot`.
3. Lancer avec **F5**.

## Commandes

| Action | Touches |
| --- | --- |
| Se déplacer | ZQSD (ou WASD) / flèches |
| Sauter | Espace |
| Se faufiler | Maj |
| Interagir | E |
| Pause | Échap |

Les touches sont réglées par position physique, donc ZQSD sur un clavier AZERTY et WASD sur un QWERTY.

## Dossiers

| Dossier | Contenu |
| --- | --- |
| `scenes/` | Scène principale, niveaux (`levels/`), interface (`ui/`), personnages (`characters/`) |
| `scripts/` | Scripts GDScript |
| `assets/models/` | Modèles 3D (.glb) |
| `assets/textures/` | Textures |
| `assets/audio/` | Musiques et bruitages |
| `assets/fonts/` | Polices de la charte : Anton, IBM Plex Sans JP, Noto Serif JP |
| `assets/ui/` | Éléments d'interface (parchemins, sceaux) |
| `docs/` | Notes pour le rapport |

## Réglages

- Affichage en 1920 × 1080, adapté à la taille de la fenêtre.
- Rendu « Compatibility », le seul qui marche dans le navigateur.
- Export **Web** prêt dans `export_presets.cfg`, sortie dans `build/web/`.
- Caméra haute et dézoomée, orientée plein nord, qui suit le ninja (`scripts/follow_camera.gd`).
- Couleurs de la charte dans `scripts/palette.gd`.

## Design

Maquettes et charte graphique sur Figma : https://www.figma.com/design/PuRaFypYJ9RKAvVU2PYy2m
