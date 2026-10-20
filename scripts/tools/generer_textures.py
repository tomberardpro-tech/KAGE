"""Textures dessinées par programme (Python + Pillow) : rien de récupéré ailleurs.
- chochin.png : papier rouge d'une lanterne chōchin, avec ses côtes et le kanji 福 (bonheur) deux fois.
Lancer : python3 scripts/tools/generer_textures.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.join(ICI, "..", "..")
POLICE = os.path.join(RACINE, "assets", "fonts", "NotoSerifJP-Black-subset.ttf")
POLICE_SECOURS = os.path.join(RACINE, "assets", "fonts", "IBMPlexSansJP-Bold.ttf")


# Les polices du jeu sont réduites aux caractères du jeu : 福 n'y est pas. On prend la Noto Serif CJK
# du système (paquet fonts-noto-cjk) juste pour peindre la texture ; elle n'est pas livrée avec le jeu.
POLICE_SYSTEME = "/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"


def police(taille):
    for chemin in (POLICE_SYSTEME, POLICE, POLICE_SECOURS):
        if os.path.exists(chemin):
            f = ImageFont.truetype(chemin, taille)
            if f.getmask("福").getbbox():
                return f
    raise SystemExit("aucune police avec 福 : installer fonts-noto-cjk")


def chochin():
    w, h = 512, 256
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        # plus clair au milieu (la flamme), plus sombre près des bagues
        v = 1.0 - abs(y / (h - 1) - 0.5) * 1.1
        for x in range(w):
            px[x, y] = (int(200 + 55 * v), int(40 + 60 * v), int(18 + 20 * v))
    d = ImageDraw.Draw(img)
    # côtes de bambou du papier
    for y in range(6, h, 14):
        d.line([(0, y), (w, y)], fill=(150, 26, 12), width=2)
    f = police(170)
    for cx in (w * 0.25, w * 0.75):
        calque = Image.new("L", (w, h), 0)
        ImageDraw.Draw(calque).text((cx, h / 2 + 4), "福", font=f, fill=255, anchor="mm")
        # bord un peu flou : le kanji est peint sur le papier, l'encre bave légèrement
        flou = calque.filter(ImageFilter.GaussianBlur(1.2))
        img = Image.composite(Image.new("RGB", (w, h), (28, 10, 8)), img, flou)
    img.save(os.path.join(RACINE, "assets", "textures", "chochin.png"))
    print("chochin.png")


def portrait(nom, kanji, fond, encre, anneau):
    """Médaillon rond du personnage qui parle : un grand kanji au pinceau sur un disque laqué."""
    t = 512
    img = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([8, 8, t - 8, t - 8], fill=anneau)
    d.ellipse([30, 30, t - 30, t - 30], fill=fond)
    d.ellipse([44, 44, t - 44, t - 44], outline=anneau, width=4)
    calque = Image.new("L", (t, t), 0)
    ImageDraw.Draw(calque).text((t / 2, t / 2 + 10), kanji, font=police(300), fill=255, anchor="mm")
    img.paste(Image.new("RGBA", (t, t), encre), mask=calque.filter(ImageFilter.GaussianBlur(1.5)))
    img = img.resize((256, 256), Image.LANCZOS)
    img.save(os.path.join(RACINE, "assets", "textures", "portrait_%s.png" % nom))
    print("portrait_%s.png" % nom)


if __name__ == "__main__":
    chochin()
    portrait("maitre", "師", (32, 38, 58, 255), (234, 227, 214, 255), (217, 154, 78, 255))
    portrait("oni", "鬼", (150, 30, 20, 255), (20, 12, 10, 255), (217, 154, 78, 255))
