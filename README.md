# KAGE

Jeu d'infiltration ninja en 3D, style chibi. Le joueur se faufile de nuit, du village au palais du seigneur, sans se faire repérer par les gardes.

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
| Trancher une lanterne proche | E |
| Pause | Échap |

Les touches sont réglées par position physique, donc ZQSD sur un clavier AZERTY et WASD sur un QWERTY.

## Écrans

- **Menu principal** (`scenes/ui/menu.tscn`, scène de départ) : Nouvelle partie lance le jeu avec un fondu, Continuer s'active quand une sauvegarde existe, Options règle le volume et le plein écran, Quitter est masqué dans la version web.
- **Niveau 1 · Le village** (`scenes/levels/village.tscn`) : lancé par Nouvelle partie. On traverse les rizières et le village, on vole le plan du château chez le chef et on sort par le portail nord-est. 4 gardes lents et myopes.
- **Niveau 2 · Le château** (`scenes/levels/chateau.tscn`) : on part devant le château, on traverse la cour extérieure et la cour intérieure, on prend le parchemin dans le donjon et on sort par le rempart est. 7 gardes.
- **Niveau 3 · Le palais** (`scenes/levels/palais.tscn`) : jardin zen, jardin du bassin et cour, parchemin dans la salle du seigneur, sortie par la brèche ouest. 10 gardes plus rapides qui voient plus loin, beaucoup de lanternes, un seul autel.
- Après une victoire, Entrée passe au niveau suivant et Continuer (menu) reprend au dernier niveau débloqué.
- **Terrain d'essai** (`scenes/jeu.tscn`) : terrain de test à l'échelle chibi : muret (0,9 m), caisse, maison (1,9 m) et rempart (2,2 m). Échap ramène au menu.

## Le ninja

`scenes/characters/ninja.tscn` et `scripts/ninja.gd`.

Modèles 3D : le ninja et le garde ont été générés avec TRELLIS (trellis3d.net) à partir des planches.
Les fichiers sont utilisés tels quels (`assets/models/ninja.glb`, `garde.glb`) : les scènes
`*_modele.tscn` règlent seulement la taille et la position, et l'import ignore les lumières du fichier.
`scripts/anim_chibi.gd` leur donne un petit rebond en marchant.

- Marche à 5,5 m/s, accroupi à 2,2 m/s.
- Saut d'environ 1,2 m : assez pour monter sur un muret.
- En sautant contre un mur ou un toit jusqu'à 2,4 m, il s'accroche et se hisse dessus.
- Dash au sabre de 5 m vers la souris : 3 charges, une charge revient toutes les 3 s.
- E près d'une lanterne allumée l'éteint sans dasher.
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

## Les niveaux

Chaque niveau est généré par un script (1 px du plan = 4 cm). Le château suit le plan Figma « Le château » ; le village et le palais ont été dessinés directement dans leur script. Les outils communs sont dans `scripts/tools/constructeur.gd`.

```
godot --headless --script res://scripts/tools/build_village.gd
godot --headless --script res://scripts/tools/build_chateau.gd
godot --headless --script res://scripts/tools/build_palais.gd
```

On peut ensuite retoucher les scènes dans Godot, mais une nouvelle génération écrase les retouches : mieux vaut modifier le script. Le titre, les textes et le niveau suivant se règlent au début de chaque script.

- **Gardes** (`scripts/garde.gd`) : ronde ou faction, cône de vision rouge au sol. Ils voient à 7,3 m si tu es éclairé, à 2 m dans la pénombre. Un garde qui te voit assez longtemps te **prend en chasse** et appelle les gardes proches : sème-le (il court moins vite que toi), cache-toi ou tranche-le d'un dash. S'il te rattrape, il prend son élan et frappe : tu repars du dernier autel.
- **Planchers rossignol** (`scripts/rossignol.gd`, lattes claires) : ils grincent si tu marches debout, et les gardes proches viennent voir. Accroupi, tu passes sans bruit.
- **Fils à clochettes** (`scripts/clochettes.gd`, fil rouge et clochettes dorées) : saute par-dessus ou coupe-les avec E. Si tu les traverses, ils sonnent et les gardes accourent.
- **Se cacher** (`scripts/zone.gd`) : ombre des arbres, herbes hautes (accroupi). La lumière des lanternes et le clair de lune te trahissent, comme la lune sur les toits.
- **Lanternes** : un dash au sabre les éteint, et le garde le plus proche vient voir.
- **Lune** : des nuages passent toutes les 14 s et coupent le clair de lune pendant 5 s.
- **Autels** : points de reprise. **Parchemin** dans le donjon, **sortie** dans le rempart est.
- Fin de partie : temps, bonus Fantôme (jamais repéré) et Pacifiste (aucun garde tué).

## Interface en jeu

D'après les maquettes HUD et les écrans du Figma :

- **HUD** (`scripts/hud.gd`) : œil et jauge de visibilité (CACHÉ, EXPOSÉ, REPÉRÉ, DÉCOUVERT), lune qui pâlit quand les nuages la cachent, parchemin 0 / 1, charges de dash, invite « E · Trancher la lanterne », marqueurs ? et ! au-dessus des gardes méfiants ou alertés, bords rouges quand on est vu.
- **Écrans** (`scripts/ecrans_jeu.gd`, parchemins dessinés par `scripts/rouleau.gd`) : tutoriel au départ, pause (Échap : reprendre, recommencer à l'autel, quitter), défaite (R pour repartir de l'autel) et victoire avec le score (temps, Fantôme, Pacifiste ; Entrée pour le menu, R pour rejouer).
- Il n'y a pas de vies : un garde qui te repère te renvoie au dernier autel, autant de fois qu'il le faut.

## Captures

```
godot --path . -- --capture=res://scenes/ui/menu.tscn --sortie=capture.png
```

## Design

Maquettes et charte graphique sur Figma : https://www.figma.com/design/PuRaFypYJ9RKAvVU2PYy2m
