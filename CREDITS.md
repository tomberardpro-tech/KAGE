# Crédits

## Musiques et bruitages

Tous les sons de KAGE sont **créés par synthèse**, sans aucun enregistrement ni fichier extérieur :
le script `scripts/tools/generer_sons.py` (Python, numpy et ffmpeg) les fabrique à partir de zéro.
Ils sont donc libres de droits et appartiennent au projet.

- Instruments imités : koto (corde pincée, algorithme de Karplus-Strong), shakuhachi (flûte et souffle),
  taiko (tambour grave), hyoshigi (claquoirs en bois), clochettes.
- Gamme miyako-bushi (ré, mi bémol, sol, la, si bémol).
- Musiques : menu, jeu (ambiance de nuit), chasse (tambours de poursuite), victoire, défaite.
- Bruitages : pas, saut, escalade, dash, sabre, lanterne, garde à terre, alerte, coup du garde,
  plancher qui grince, clochettes, fil coupé, parchemin, autel, clic du menu.

## Modèles 3D

Ninja et garde générés avec TRELLIS (trellis3d.net) à partir des planches Figma du projet.

## Décor (ticket 4.4)

Tous les éléments ci-dessous sont sous licence **CC0** (domaine public) : libres d'usage, même commercial,
sans obligation de citer. On les cite quand même pour remercier leurs auteurs.

- **Textures : [Poly Haven](https://polyhaven.com)** (CC0), réduites en 512 × 512 dans `assets/textures/polyhaven/` :
  leafy_grass (herbe), patterned_cobblestone (pavés des cours), stone_tiles_02 (allées de dalles),
  white_plaster_02 (murs blancs), grey_roof_tiles (tuiles), dark_wooden_planks (bois),
  cobblestone_floor_04 (soubassements de pierre), mossy_rock (rochers et lanternes),
  gravel_floor (sable du jardin zen, terre battue).
- **Rochers : [Nature Kit de Kenney](https://kenney.nl/assets/nature-kit)** (CC0), formes `stone_*` dans
  `assets/models/nature/`, recouvertes de la texture mossy_rock.
- Le reste du décor est **fait dans le projet** (scripts `scripts/tools/decor.gd`, shaders `assets/shaders/`) :
  buissons et pins taillés, bambous, herbes hautes, higanbanas, eau animée, ruisseau, cascade,
  nénuphars, murs à tuiles et fenêtres, lanternes en pierre et sur poteau, pont rouge, bannières,
  braseros, palissade, rizières, lucioles et brume.

## Polices

Anton, IBM Plex Sans JP et Noto Serif JP (Google Fonts, licence SIL Open Font License).
