"""Textures dessinées par programme (Python + Pillow) : rien de récupéré ailleurs.
- chochin.png : papier rouge d'une lanterne chōchin, avec ses côtes et le kanji 福 (bonheur) deux fois.
Lancer : python3 scripts/tools/generer_textures.py
"""
import os
import random
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


def feuilles():
    """Touffe de feuilles en niveaux de gris sur fond transparent, pour les buissons (teintée par le shader)."""
    import math
    taille = 512
    img = Image.new("RGBA", (taille, taille), (0, 0, 0, 0))
    hasard = random.Random(44)
    c = taille / 2
    for k in range(260):
        # plus de feuilles vers le centre : la touffe a un contour arrondi et irrégulier
        r = (hasard.random() ** 0.7) * taille * 0.44
        a = hasard.random() * math.tau
        x, y = c + math.cos(a) * r, c + math.sin(a) * r
        long_ = hasard.uniform(34, 58)
        large = long_ * hasard.uniform(0.38, 0.5)
        angle = a + hasard.uniform(-0.9, 0.9)
        clair = hasard.uniform(0.55, 1.0) * (1.0 - 0.35 * r / (taille * 0.44))
        feuille = Image.new("RGBA", (int(long_ * 2.2), int(long_ * 2.2)), (0, 0, 0, 0))
        d = ImageDraw.Draw(feuille)
        fx, fy = feuille.size[0] / 2, feuille.size[1] / 2
        pts = []
        for t in range(21):
            u = t / 20
            pts.append((fx - long_ / 2 + u * long_, fy - math.sin(u * math.pi) ** 0.8 * large / 2))
        for t in range(20, -1, -1):
            u = t / 20
            pts.append((fx - long_ / 2 + u * long_, fy + math.sin(u * math.pi) ** 0.8 * large / 2))
        g = int(255 * clair)
        d.polygon(pts, fill=(g, g, g, 255))
        # moitié éclairée, moitié ombrée, et la nervure
        g2 = int(g * 0.78)
        d.polygon(pts[21:], fill=(g2, g2, g2, 255))
        d.line([(fx - long_ / 2, fy), (fx + long_ / 2, fy)], fill=(int(g * 0.6),) * 3 + (255,), width=2)
        feuille = feuille.rotate(math.degrees(-angle), resample=Image.BICUBIC, expand=False)
        img.alpha_composite(feuille, (int(x - feuille.size[0] / 2), int(y - feuille.size[1] / 2)))
    img.save(os.path.join(RACINE, "assets", "textures", "feuilles.png"))
    print("feuilles.png")


if __name__ == "__main__":
    chochin()
    feuilles()
