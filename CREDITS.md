# Crédits

## Musiques et bruitages

Musiques et sons enregistrés, tous sous **licence CC0** (domaine public) :

| Dans le jeu | Œuvre | Auteur |
| --- | --- | --- |
| Musique du menu | [Asianoriental1](https://opengameart.org/content/asianoriental1) | Tozan |
| Musique du village | [Hot Springs Town](https://opengameart.org/content/hot-springs-town) | Kistol |
| Musique du château | [Deliberate Concealment](https://opengameart.org/content/deliberate-concealment) | northivanastan (Ivan Stanton) |
| Pluie | [Rain (loopable)](https://opengameart.org/content/rain-loopable) | Ylmir |
| Saut | [RPG Audio](https://kenney.nl/assets/rpg-audio) (cloth3) | Kenney |
| Pas | [Impact Sounds](https://kenney.nl/assets/impact-sounds) (footstep_grass) | Kenney |
| Porte qui claque | [Impact Sounds](https://kenney.nl/assets/impact-sounds) (impactWood_heavy, ralenti avec écho) | Kenney |
| Buisson | [20 Rustles of dry leaves](https://opengameart.org/content/20-rustles-of-dry-leaves) | qubodup |
| Sortir et ranger le katana | [Fantasy Weapons and Apparel SFX Library](https://opengameart.org/content/fantasy-weapons-and-apparel-sfx-library) | Jan Schupke (vehicle) |
| Coup de katana | [Swishes Sound Pack](https://opengameart.org/content/swishes-sound-pack) | artisticdude |
| Grande porte | [Creaky Door Hinge Spooky](https://opengameart.org/content/creaky-door-hinge-spooky) | wforster1 |

Les autres sons de KAGE sont **créés par synthèse**, sans enregistrement : le script
`scripts/tools/generer_sons.py` (Python, numpy et ffmpeg) les fabrique à partir de zéro.
Ils sont libres de droits et appartiennent au projet.

- Instruments imités : koto (corde pincée, algorithme de Karplus-Strong), shakuhachi (flûte et souffle),
  taiko (tambour grave), hyoshigi (claquoirs en bois), clochettes.
- Gamme miyako-bushi (ré, mi bémol, sol, la, si bémol).
- Musiques : chasse (tambours de poursuite), boss, victoire, défaite.
- Bruitages : escalade, sabre, lanterne, garde à terre, alerte (taiko et cri de shakuhachi), coup du garde,
  plancher qui grince, clochettes, fil coupé, parchemin, autel, clic du menu, jingle du trésor, herse, coffre,
  cris et charge du seigneur Oni, onde, miaou, corbeaux.

## Modèles 3D

Ninja et garde générés avec TRELLIS (trellis3d.net) à partir des planches Figma du projet.

## Décor (ticket 4.4)

- **Rochers : [Nature Kit de Kenney](https://kenney.nl/assets/nature-kit)** (licence CC0, domaine public),
  formes `stone_*` dans `assets/models/nature/`, recolorées par le shader du projet.
- Tout le reste du décor est **fait dans le projet**, sans fichier extérieur :
  - matières dessinées (herbe, dalles, pavés, enduit, tuiles rondes, bois, pierre de taille, sable ratissé,
    terre, chaume, tatami) calculées par le shader `assets/shaders/matiere.gdshader` ;
  - gazon, herbes hautes, pins et cerisiers en fleurs, buissons, bambous, higanbanas, eau animée, carpes koï,
    nénuphars, ruisseau, cascades, murs à tuiles, lanternes, pont rouge, bannières, braseros, palissade,
    rizières, jardin zen, pétales, lucioles et brume (`scripts/tools/decor.gd` et `assets/shaders/`).

## Polices

Anton, IBM Plex Sans JP et Noto Serif JP (Google Fonts, licence SIL Open Font License).

## Images faites dans le projet

`scripts/tools/generer_textures.py` dessine le papier des lanternes 福 et la texture des feuilles des buissons.
Les villageois, le katana, les cabanes en bois et le chemin de terre sont construits par le code
(`scripts/habitant.gd`, `scripts/tools/articuler.gd`, `scripts/tools/decor.gd`, `assets/shaders/chemin.gdshader`).
