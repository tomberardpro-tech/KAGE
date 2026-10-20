"""Police japonaise des dialogues : Noto Serif CJK JP Bold (OFL), réduite aux seuls caractères
des répliques de assets/dialogues.json (et du nom du seigneur), pour rester légère dans la version web.
Lancer : python3 scripts/tools/sous_police.py   (paquets fonts-noto-cjk et fonttools)
"""
import json
import os
import subprocess

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.join(ICI, "..", "..")
SOURCE = "/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"
INDEX_JP = "0"
SORTIE = os.path.join(RACINE, "assets", "fonts", "NotoSerifJP-Bold-dialogues.otf")

with open(os.path.join(RACINE, "assets", "dialogues.json"), encoding="utf-8") as f:
    d = json.load(f)
textes = [l["jp"] for s in ("intro", "oni_debut", "oni_fin") for l in d[s]["lignes"]]
textes += [l["jp"] for l in d["villageois"]]
caracteres = sorted(set("".join(textes)) | set("鬼師影巻…！？、。「」 "))
subprocess.run(["pyftsubset", SOURCE, "--font-number=" + INDEX_JP, "--text=" + "".join(caracteres),
                "--output-file=" + SORTIE, "--layout-features=*"], check=True)
print(os.path.basename(SORTIE), len(caracteres), "caractères", os.path.getsize(SORTIE) // 1024, "Ko")
