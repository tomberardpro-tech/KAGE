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
| S'accroupir | Ctrl ou C |
| Dash au sabre | Clic gauche (vers la souris) |
| Interagir | E |
| Pause | Échap |

Les touches sont réglées par position physique, donc ZQSD sur un clavier AZERTY et WASD sur un QWERTY.

## Écrans

- **Menu principal** (`scenes/ui/menu.tscn`, scène de départ) : Nouvelle partie lance le jeu avec un fondu, Continuer s'active quand une sauvegarde existe, Options règle le volume et le plein écran, Quitter est masqué dans la version web.
- **Jeu** (`scenes/jeu.tscn`) : terrain de test avec un muret, des caisses, une maison et un rempart. Échap ramène au menu.

## Le ninja

`scenes/characters/ninja.tscn` et `scripts/ninja.gd` (forme provisoire en attendant le modèle 3D).

- Marche à 5,5 m/s, accroupi à 2,2 m/s.
- Saut d'environ 1,2 m : assez pour monter sur un muret.
- En sautant contre un mur ou un toit jusqu'à 2,4 m, il s'accroche et se hisse dessus.
- Dash au sabre de 5 m vers la souris, rechargé en 0,6 s.
- Tous les réglages sont modifiables dans l'inspecteur de Godot.

![Menu principal](docs/menu.png)

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

- Scripts globaux : `Transition` (fondu entre écrans), `Reglages` (volume, plein écran), `Sauvegarde`.

- Affichage en 1920 × 1080, adapté à la taille de la fenêtre.
- Rendu « Compatibility », le seul qui marche dans le navigateur.
- Export **Web** prêt dans `export_presets.cfg`, sortie dans `build/web/`.
- Caméra haute et dézoomée, orientée plein nord, qui suit le ninja (`scripts/follow_camera.gd`).
- Couleurs de la charte dans `scripts/palette.gd`, thème Godot (polices et styles) dans `assets/ui/kage_theme.tres`. Détails dans [docs/design.md](docs/design.md).

## Captures

```
godot --path . -- --capture=res://scenes/ui/menu.tscn --sortie=capture.png
```

## Design

Maquettes et charte graphique sur Figma : https://www.figma.com/design/PuRaFypYJ9RKAvVU2PYy2m
