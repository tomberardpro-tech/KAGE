# Crédits

## Musiques et bruitages

- **Musique du menu : « Ninja Theme », par Spring**
  ([OpenGameArt](https://opengameart.org/content/ninja-theme)), licence CC0 (domaine public).
- **Musique en jeu : « Hot Springs Town », par Kistol**
  ([OpenGameArt](https://opengameart.org/content/hot-springs-town)), licence CC0 (domaine public).

Tous les autres sons de KAGE sont **créés par synthèse**, sans aucun enregistrement ni fichier extérieur :
le script `scripts/tools/generer_sons.py` (Python, numpy et ffmpeg) les fabrique à partir de zéro.
Ils sont donc libres de droits et appartiennent au projet.

- Instruments imités : koto (corde pincée, algorithme de Karplus-Strong), shakuhachi (flûte et souffle),
  taiko (tambour grave), hyoshigi (claquoirs en bois), clochettes.
- Gamme miyako-bushi (ré, mi bémol, sol, la, si bémol).
- Musiques : chasse (tambours de poursuite), victoire, défaite.
- Bruitages : pas, saut, escalade, coup de katana, sabre, lanterne, garde à terre, alerte (taiko et cri de shakuhachi), coup du garde,
  plancher qui grince, clochettes, fil coupé, parchemin, autel, clic du menu, pluie douce.

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
