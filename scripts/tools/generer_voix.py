"""Voix japonaises des dialogues, fabriquées par synthèse vocale (Open JTalk, voix « m001 »
du Nagoya Institute of Technology, licence CC BY 3.0), puis retouchées avec ffmpeg :
le vieux maître parle bas et lentement, le seigneur Oni gronde, les villageois sont plus aigus.
Les textes viennent de assets/dialogues.json (les mêmes que dans le jeu).
Lancer : python3 scripts/tools/generer_voix.py   (paquets open-jtalk, open-jtalk-mecab-naist-jdic,
hts-voice-nitech-jp-atr503-m001 et ffmpeg)
"""
import json
import os
import subprocess
import tempfile

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.join(ICI, "..", "..")
SORTIE = os.path.join(RACINE, "assets", "audio", "voix")
DICO = "/var/lib/mecab/dic/open-jtalk/naist-jdic"
VOIX = "/usr/share/hts-voice/nitech-jp-atr503-m001/nitech_jp_atr503_m001.htsvoice"

# hauteur (demi-tons), vitesse, filtre ffmpeg
STYLES = {
    "maitre": (-3.0, 0.86, "lowpass=f=6500,aecho=0.8:0.6:45:0.18,volume=1.6"),
    "oni": (-8.0, 0.82, "lowpass=f=5000,acompressor=threshold=0.1:ratio=6,aecho=0.8:0.7:70|140:0.35|0.2,volume=2.2"),
    "villageois0": (3.0, 1.0, "volume=1.4"),
    "villageois1": (-1.0, 0.95, "volume=1.4"),
    "villageois2": (5.0, 1.0, "volume=1.4"),
    "villageois3": (7.0, 1.08, "volume=1.4"),
}


def dire(texte, nom, style):
    hauteur, vitesse, filtre = STYLES[style]
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "v.wav")
        subprocess.run(["open_jtalk", "-x", DICO, "-m", VOIX, "-fm", str(hauteur), "-r", str(vitesse), "-ow", wav],
                       input=texte.encode("utf-8"), check=True)
        sortie = os.path.join(SORTIE, nom + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-af", filtre + ",loudnorm=I=-17:TP=-2,apad=pad_dur=0.25",
                        "-ac", "1", "-ar", "32000", "-q:a", "3", sortie], check=True)
        print(nom)


def main():
    os.makedirs(SORTIE, exist_ok=True)
    with open(os.path.join(RACINE, "assets", "dialogues.json"), encoding="utf-8") as f:
        d = json.load(f)
    for scene, style in [("intro", "maitre"), ("oni_debut", "oni"), ("oni_fin", "oni")]:
        for ligne in d[scene]["lignes"]:
            dire(ligne["jp"], ligne["id"], style)
    for ligne in d["villageois"]:
        dire(ligne["jp"], ligne["id"], ligne["id"])


if __name__ == "__main__":
    main()
