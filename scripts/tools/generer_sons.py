"""Génère toutes les musiques et tous les bruitages de KAGE par synthèse (aucun fichier extérieur).

Lancer depuis la racine du projet :  python3 scripts/tools/generer_sons.py [nom ...]
(sans nom : tout est refait ; avec des noms, seulement ceux-là, par exemple « pluie »).
Les musiques « menu » et « jeu » ne sont plus synthétisées : ce sont des morceaux CC0 (voir CREDITS.md).
Il faut numpy et ffmpeg (pour l'encodage en .ogg).

Instruments imités :
- koto : corde pincée (algorithme de Karplus-Strong) ;
- shakuhachi : flûte douce avec du souffle ;
- taiko : grosse caisse grave ;
- hyoshigi : claquoirs en bois (alerte).
Gamme miyako-bushi (ré, mi bémol, sol, la, si bémol), typique de la musique japonaise.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
RACINE = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
hasard = np.random.default_rng(1350)

# Ré, mi bémol, sol, la, si bémol : demi-tons au-dessus de ré
GAMME = [0, 1, 5, 7, 8]


def note(degre, octave=0, base=146.83):
    """Fréquence d'un degré de la gamme (0 = ré3), sur plusieurs octaves."""
    o, d = divmod(degre, len(GAMME))
    return base * 2 ** ((GAMME[d] + 12 * (o + octave)) / 12)


def silence(duree):
    return np.zeros(int(duree * SR))


def enveloppe(n, attaque=0.005, extinction=0.3):
    t = np.arange(n) / SR
    env = np.minimum(t / max(attaque, 1e-4), 1.0) * np.exp(-t / max(extinction, 1e-4))
    return env


def koto(freq, duree=2.5, eclat=0.6):
    """Corde pincée : Karplus-Strong, calculé bloc par bloc pour aller vite."""
    n = int(duree * SR)
    periode = max(int(SR / freq), 2)
    sortie = np.zeros(n + periode)
    sortie[:periode] = hasard.uniform(-1, 1, periode) * eclat + np.sin(np.linspace(0, 2 * np.pi, periode)) * (1 - eclat)
    amorti = 0.996
    i = periode
    while i < n + periode:
        fin = min(i + periode, n + periode)
        prec = sortie[i - periode:fin - periode]
        prec2 = sortie[i - periode - 1:fin - periode - 1] if i - periode - 1 >= 0 else np.concatenate(([0], prec[:-1]))
        if len(prec2) < len(prec):
            prec2 = np.concatenate(([0], prec2))
        sortie[i:fin] = amorti * 0.5 * (prec + prec2[:len(prec)])
        i = fin
    son = sortie[periode:]
    return son * enveloppe(n, 0.002, duree * 0.6)


def flute(freq, duree, volume=0.5):
    """Shakuhachi : sinus avec vibrato lent et souffle filtré."""
    n = int(duree * SR)
    t = np.arange(n) / SR
    vibrato = 1 + 0.004 * np.sin(2 * np.pi * 5 * t) * np.minimum(t / 0.6, 1)
    phase = 2 * np.pi * np.cumsum(freq * vibrato) / SR
    ton = np.sin(phase) + 0.25 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    souffle = passe_bas(hasard.normal(0, 1, n), 2500) * 0.15
    env = np.minimum(t / 0.35, 1) * np.minimum((duree - t) / 0.5, 1)
    return (ton + souffle) * np.clip(env, 0, 1) * volume


def taiko(duree=0.8, grave=60.0, volume=1.0):
    n = int(duree * SR)
    t = np.arange(n) / SR
    freq = grave * (1 + 1.5 * np.exp(-t * 30))
    corps = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 6)
    frappe = passe_bas(hasard.normal(0, 1, n), 1200) * np.exp(-t * 60) * 0.6
    return (corps + frappe) * volume


def claquoir(volume=1.0):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    bois = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(1850, 1), (2900, 0.5), (4200, 0.3)])
    return (bois * np.exp(-t * 70) + hasard.normal(0, 0.3, n) * np.exp(-t * 200)) * volume


def cloche(freq, duree=2.0, volume=0.6):
    """Clochette : partiels inharmoniques qui s'éteignent à des vitesses différentes."""
    n = int(duree * SR)
    t = np.arange(n) / SR
    son = np.zeros(n)
    for rapport, ampl, amort in [(1, 1, 2.5), (2.76, 0.5, 4), (5.4, 0.3, 7), (8.9, 0.15, 10)]:
        son += np.sin(2 * np.pi * freq * rapport * t) * ampl * np.exp(-t * amort)
    return son * np.minimum(t / 0.002, 1) * volume


def passe_bas(signal, coupure):
    """Filtre passe-bas simple (un pôle), assez pour adoucir du bruit.
    Appliqué comme une convolution avec sa réponse impulsionnelle, par FFT."""
    a = np.exp(-2 * np.pi * coupure / SR)
    longueur = int(np.ceil(np.log(1e-6) / np.log(a))) + 1
    noyau = (1 - a) * a ** np.arange(longueur)
    taille = len(signal) + longueur - 1
    n = 1 << (taille - 1).bit_length()
    sortie = np.fft.irfft(np.fft.rfft(signal, n) * np.fft.rfft(noyau, n), n)
    return sortie[:len(signal)]


def passe_haut(signal, coupure):
    return signal - passe_bas(signal, coupure)


def poser(piste, son, debut):
    i = int(debut * SR)
    fin = min(i + len(son), len(piste))
    piste[i:fin] += son[:fin - i]


def boucle(piste, fondu=0.05):
    """Raccord doux : le début se fond avec la fin pour une boucle sans clic."""
    n = int(fondu * SR)
    piste[:n] *= np.linspace(0, 1, n)
    piste[-n:] *= np.linspace(1, 0, n)
    return piste


def reverb(signal, temps=1.6, melange=0.25):
    """Réverbération légère : quelques échos qui s'atténuent (salle en bois)."""
    sortie = signal.copy()
    for retard, gain in [(0.031, 0.5), (0.053, 0.4), (0.089, 0.33), (0.137, 0.25), (0.211, 0.18), (0.33, 0.1)]:
        d = int(retard * SR * temps / 1.6)
        sortie[d:] += signal[:-d] * gain * melange * 2
    return sortie


def normaliser(signal, crete=0.85):
    m = np.max(np.abs(signal))
    return signal * (crete / m) if m > 0 else signal


def ecrire(nom, signal, dossier):
    chemin = os.path.join(RACINE, dossier, nom + ".ogg")
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    donnees = (np.clip(signal, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(donnees.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "5", chemin], check=True)
    os.unlink(tmp.name)
    print(chemin, f"{len(signal) / SR:.1f} s")


# --- Musiques ---------------------------------------------------------------

def musique_menu():
    """Menu : koto lent sur un bourdon grave, phrase de 8 temps répétée avec variations."""
    tempo = 1.1
    piste = silence(16 * tempo * 2)
    phrases = [[4, 3, 2, 3, 1, 0, 2, -1], [4, 5, 4, 3, 2, 1, 0, 0]]
    t = 0.0
    for phrase in phrases:
        for k, d in enumerate(phrase):
            poser(piste, koto(note(d, 1), 3.0) * 0.7, t)
            if k % 4 == 0:
                poser(piste, koto(note(d - 5, 1), 3.5) * 0.4, t)
            t += tempo * (2 if k in (3, 7) else 1)
    bourdon = flute(note(0, -1), len(piste) / SR, 0.12)
    piste += bourdon
    return boucle(normaliser(reverb(piste), 0.6))


def musique_jeu():
    """En jeu : ambiance nocturne discrète, notes de koto espacées et souffle de shakuhachi."""
    duree = 48.0
    piste = silence(duree)
    t = 0.5
    k = 0
    motif = [2, 1, 0, 3, 2, 4, 1, 0, -1, 0, 2, 1]
    while t < duree - 3:
        poser(piste, koto(note(motif[k % len(motif)], 1), 3.0) * 0.5, t)
        if k % 3 == 2:
            poser(piste, koto(note(motif[k % len(motif)] + 2, 1), 2.0) * 0.3, t + 0.35)
        t += [2.2, 1.6, 2.8, 3.4][k % 4]
        k += 1
    for debut, d, longueur in [(6, 0, 5), (20, 3, 4), (34, 2, 6)]:
        poser(piste, flute(note(d, 1), longueur, 0.22), debut)
    piste += flute(note(0, -1), duree, 0.06)
    vent = passe_bas(hasard.normal(0, 1, len(piste)), 400) * 0.05
    vent *= 0.6 + 0.4 * np.sin(2 * np.pi * np.arange(len(piste)) / SR / 12)
    piste += vent
    return boucle(normaliser(reverb(piste, 2.0, 0.35), 0.45))


def musique_chasse():
    """Poursuite : taiko et koto rapide, 120 battements par minute."""
    temps = 0.5
    piste = silence(16 * temps)
    for i in range(16):
        poser(piste, taiko(0.6, 55 if i % 4 == 0 else 70, 1.0 if i % 4 == 0 else 0.6), i * temps)
        if i % 2 == 1:
            poser(piste, taiko(0.3, 110, 0.35), i * temps + temps / 2)
    motif = [0, 2, 3, 2, 4, 3, 2, 1]
    for i in range(32):
        poser(piste, koto(note(motif[i % 8], 1 if i < 16 else 2), 0.8) * 0.45, i * temps / 2)
    for i in range(4):
        poser(piste, claquoir(0.4), (i * 4 + 3.5) * temps)
    return boucle(normaliser(piste, 0.8), 0.01)


def stinger_victoire():
    piste = silence(4.0)
    for i, d in enumerate([0, 2, 3, 4, 5, 7]):
        poser(piste, koto(note(d, 1), 3.0) * 0.6, i * 0.14)
    poser(piste, cloche(note(5, 2), 3.0, 0.4), 0.9)
    poser(piste, taiko(1.2, 50, 0.8), 0.85)
    return normaliser(reverb(piste), 0.8)


def stinger_defaite():
    piste = silence(3.0)
    poser(piste, taiko(1.5, 45, 1.0), 0.0)
    for i, d in enumerate([3, 1, 0]):
        poser(piste, koto(note(d, 0), 2.5) * 0.6, 0.25 + i * 0.3)
    return normaliser(reverb(piste), 0.8)


# --- Bruitages ----------------------------------------------------------------

def bruit_pas():
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    return normaliser(passe_bas(hasard.normal(0, 1, n), 700) * np.exp(-t * 45), 0.5)


def bruit_saut():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    souffle = passe_haut(passe_bas(hasard.normal(0, 1, n), 3000), 600)
    return normaliser(souffle * np.sin(np.pi * t / t[-1]) ** 2, 0.5)


def bruit_grimpe():
    son = silence(0.3)
    for i, f in enumerate([500, 650]):
        poser(son, bruit_pas() * 0.8, i * 0.12)
    return normaliser(son, 0.5)


def bruit_dash():
    """Coup de vent : bruit dont le filtre monte puis redescend."""
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    bruit = hasard.normal(0, 1, n)
    grave = passe_bas(bruit, 900)
    aigu = passe_bas(bruit, 5000)
    mix = np.sin(np.pi * t / t[-1])
    son = (grave * (1 - mix) + aigu * mix) * np.sin(np.pi * t / t[-1]) ** 1.5
    return normaliser(son, 0.7)


def bruit_tranche():
    """Sabre qui tranche : souffle bref puis éclat métallique aigu."""
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    metal = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(2400, 1), (3710, 0.6), (5230, 0.4), (7020, 0.2)])
    son = metal * np.exp(-t * 9) * 0.5 + passe_haut(hasard.normal(0, 1, n), 2000) * np.exp(-t * 30) * 0.8
    return normaliser(son, 0.7)


def bruit_lanterne():
    son = bruit_tranche() * 0.6
    n = len(son)
    t = np.arange(n) / SR
    son += passe_bas(hasard.normal(0, 1, n), 1500) * np.exp(-t * 6) * 0.3  # la flamme qui s'éteint
    return normaliser(son, 0.6)


def bruit_garde_tombe():
    piste = silence(0.6)
    poser(piste, taiko(0.5, 80, 0.7), 0.05)
    poser(piste, claquoir(0.3), 0.0)
    return normaliser(piste, 0.7)


def bruit_alerte():
    """Repéré ! Grand coup de taiko, cri de shakuhachi qui monte et cymbale : on sent la menace."""
    piste = silence(1.6)
    poser(piste, taiko(1.2, 48.0, 1.2), 0.0)
    poser(piste, taiko(0.6, 75.0, 0.6), 0.16)
    # cri de flûte qui glisse vers l'aigu
    n = int(0.9 * SR)
    t_ = np.arange(n) / SR
    f = 440.0 * 2 ** (np.minimum(t_ / 0.25, 1.0) * 7 / 12)
    phase = 2 * np.pi * np.cumsum(f) / SR
    cri = (np.sin(phase) + 0.3 * np.sin(2 * phase)) * np.minimum(t_ / 0.04, 1) * np.exp(-t_ * 3.0)
    cri += passe_bas(hasard.normal(0, 1, n), 3000) * 0.2 * np.exp(-t_ * 6.0)
    poser(piste, cri * 0.45, 0.05)
    # petite cymbale (bruit aigu qui s'éteint)
    m = int(1.2 * SR)
    tm = np.arange(m) / SR
    poser(piste, passe_haut(hasard.normal(0, 1, m), 4000) * np.exp(-tm * 4.0) * 0.18, 0.0)
    return normaliser(reverb(piste, 1.8, 0.3), 0.85)


def bruit_frappe():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    souffle = passe_bas(hasard.normal(0, 1, n), 2500) * np.sin(np.pi * np.minimum(t / 0.3, 1)) * np.exp(-t * 4)
    piste = souffle * 0.6
    poser(piste, taiko(0.3, 90, 0.8), 0.28)
    return normaliser(piste, 0.8)


def bruit_grincement():
    """Plancher rossignol : petit gazouillis aigu qui monte et redescend."""
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    freq = 1400 + 600 * np.sin(np.pi * t / t[-1]) + 150 * np.sin(2 * np.pi * 28 * t)
    son = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.sin(np.pi * t / t[-1])
    son += passe_bas(hasard.normal(0, 1, n), 800) * 0.2 * np.sin(np.pi * t / t[-1])
    return normaliser(son, 0.6)


def bruit_clochettes():
    piste = silence(2.0)
    for i in range(7):
        poser(piste, cloche(hasard.uniform(1800, 2600), 1.6, 0.5), i * 0.07 + hasard.uniform(0, 0.03))
    return normaliser(piste, 0.7)


def bruit_coupe():
    n = int(0.15 * SR)
    t = np.arange(n) / SR
    return normaliser(passe_haut(hasard.normal(0, 1, n), 3000) * np.exp(-t * 40), 0.4)


def bruit_parchemin():
    piste = silence(2.5)
    for i, d in enumerate([2, 4, 5, 7]):
        poser(piste, cloche(note(d, 2), 2.0, 0.5), i * 0.12)
    return normaliser(reverb(piste), 0.6)


def bruit_autel():
    return normaliser(reverb(cloche(note(0, 1), 2.5, 0.6)), 0.5)


def bruit_pluie():
    """Pluie fine et légère en boucle : un souffle aigu très doux et de minuscules gouttes."""
    duree = 12.0
    n = int(duree * SR)
    piste = passe_bas(passe_haut(hasard.normal(0, 1, n), 2600), 7000) * 0.22
    # le souffle respire lentement, comme une averse qui va et vient
    piste *= 0.8 + 0.2 * np.sin(np.arange(n) / SR * 2 * np.pi / 6.0)
    goutte_n = int(0.015 * SR)
    tg = np.arange(goutte_n) / SR
    for _ in range(int(duree * 26)):
        f = hasard.uniform(3000, 6500)
        g = np.sin(2 * np.pi * f * tg) * np.exp(-tg * hasard.uniform(300, 500))
        poser(piste, g * hasard.uniform(0.01, 0.035), hasard.uniform(0, duree - 0.05))
    # fondu enchaîné : la fin se mélange au début pour une boucle sans raccord audible
    f = int(1.0 * SR)
    piste[:f] = piste[:f] * np.linspace(0, 1, f) + piste[-f:] * np.linspace(1, 0, f)
    return normaliser(piste[:-f], 0.3)


def musique_boss():
    """Combat contre le seigneur Oni : gros taiko à 132 battements, koto grave et menaçant, cri de flûte."""
    temps = 60 / 132
    mesures = 8
    piste = silence(mesures * 4 * temps)
    for i in range(mesures * 4):
        poser(piste, taiko(0.7, 48 if i % 2 == 0 else 62, 1.0 if i % 4 == 0 else 0.7), i * temps)
        poser(piste, taiko(0.25, 120, 0.3), i * temps + temps / 2)
        if i % 8 == 7:
            for k in range(3):
                poser(piste, taiko(0.3, 90, 0.5), i * temps + temps * (0.25 + k * 0.25))
    motif = [0, 0, 1, 0, 3, 2, 1, -1]
    for i in range(mesures * 8):
        d = motif[i % 8] + (2 if (i // 16) % 2 else 0)
        poser(piste, koto(note(d, 0), 0.7) * 0.5, i * temps / 2)
    for debut, d in [(0, 4), (8, 5), (16, 4), (24, 7)]:
        poser(piste, flute(note(d, 1), temps * 6, 0.25), debut * temps)
    for i in range(mesures):
        poser(piste, claquoir(0.5), (i * 4 + 3) * temps)
    return boucle(normaliser(reverb(piste, 1.2, 0.2), 0.82), 0.01)


def stinger_tresor():
    """Le parchemin est retrouvé : montée de koto, accord tenu et grande cloche (fanfare originale)."""
    piste = silence(4.5)
    for i, d in enumerate([0, 2, 4, 5]):
        poser(piste, koto(note(d, 1), 2.0) * 0.6, i * 0.16)
    for d in [5, 7, 9]:
        poser(piste, koto(note(d, 1), 3.5) * 0.45, 0.8)
        poser(piste, flute(note(d, 1), 2.6, 0.18), 0.8)
    poser(piste, cloche(note(7, 2), 3.5, 0.5), 0.8)
    poser(piste, taiko(1.4, 52, 0.9), 0.78)
    return normaliser(reverb(piste, 2.2, 0.35), 0.85)


def bruit_porte():
    """Grande porte : grincement grave du bois et des gonds, puis un coup sourd."""
    duree = 3.0
    n = int(duree * SR)
    t = np.arange(n) / SR
    f = 70 + 25 * np.sin(2 * np.pi * 0.7 * t) + 8 * hasard.normal(0, 1, n).cumsum() / np.sqrt(n)
    grince = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 9 * t)))
    grince = passe_bas(grince + hasard.normal(0, 0.3, n), 900) * np.minimum(t / 0.3, 1) * np.clip((2.6 - t) / 0.4, 0, 1)
    piste = grince * 0.8
    poser(piste, taiko(1.2, 38, 1.2), 2.55)
    return normaliser(reverb(piste, 2.0, 0.3), 0.8)


def bruit_herse():
    """Herse qui tombe : chaînes qui cliquettent puis choc lourd de bois et de fer."""
    piste = silence(1.6)
    for k in range(10):
        poser(piste, cloche(hasard.uniform(1800, 3200), 0.15, 0.15), k * 0.025)
    poser(piste, taiko(1.0, 42, 1.3), 0.3)
    choc = passe_bas(hasard.normal(0, 1, int(0.3 * SR)), 2500) * np.exp(-np.arange(int(0.3 * SR)) / SR * 25)
    poser(piste, choc * 0.8, 0.3)
    return normaliser(reverb(piste, 1.8, 0.3), 0.85)


def bruit_coffre():
    """Couvercle du coffre : craquement de bois, puis scintillement doré qui monte."""
    piste = silence(2.4)
    poser(piste, passe_bas(hasard.normal(0, 1, int(0.5 * SR)), 700) * np.linspace(0.6, 0, int(0.5 * SR)), 0.0)
    for i, d in enumerate([4, 5, 7, 9, 10, 12]):
        poser(piste, cloche(note(d, 2), 1.6, 0.25), 0.5 + i * 0.12)
    return normaliser(reverb(piste, 2.0, 0.35), 0.75)


def bruit_coffre_apparait():
    piste = silence(2.0)
    souffle = passe_haut(hasard.normal(0, 1, int(1.2 * SR)), 2000) * np.linspace(0, 1, int(1.2 * SR)) ** 2 * 0.3
    poser(piste, souffle, 0.0)
    poser(piste, cloche(note(7, 2), 1.8, 0.5), 1.15)
    poser(piste, cloche(note(9, 2), 1.6, 0.3), 1.2)
    return normaliser(reverb(piste, 2.0, 0.3), 0.75)


def bruit_boss_cri():
    """Grondement du seigneur Oni avant de charger."""
    duree = 0.9
    n = int(duree * SR)
    t = np.arange(n) / SR
    f = 85 + 30 * np.sin(np.pi * t / duree)
    voix = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.5 + np.sin(2 * np.pi * np.cumsum(f * 2) / SR) * 0.3
    voix = passe_bas(voix + hasard.normal(0, 0.4, n), 1100) * np.minimum(t / 0.08, 1) * np.clip((duree - t) / 0.25, 0, 1)
    return normaliser(reverb(voix, 1.4, 0.25), 0.8)


def bruit_boss_charge():
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    souffle = passe_bas(hasard.normal(0, 1, n), 1500) * np.exp(-t * 5)
    piste = souffle * 0.7
    poser(piste, taiko(0.5, 70, 0.6), 0.0)
    return normaliser(piste, 0.75)


def bruit_boss_touche():
    piste = silence(0.6)
    poser(piste, taiko(0.5, 95, 0.8), 0.0)
    poser(piste, cloche(620, 0.4, 0.35), 0.0)
    return normaliser(piste, 0.75)


def bruit_boss_onde():
    piste = silence(1.6)
    poser(piste, taiko(1.5, 34, 1.4), 0.0)
    gronde = passe_bas(hasard.normal(0, 1, int(1.2 * SR)), 180) * np.exp(-np.arange(int(1.2 * SR)) / SR * 3)
    poser(piste, gronde * 1.2, 0.02)
    return normaliser(reverb(piste, 1.6, 0.25), 0.9)


def bruit_buisson():
    """Bruissement de feuilles quand on entre dans un buisson."""
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    feuilles = passe_haut(hasard.normal(0, 1, n), 1500) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 18 * t)))
    return normaliser(passe_bas(feuilles, 6000) * np.minimum(t / 0.03, 1) * np.exp(-t * 6), 0.5)


def bruit_miaou():
    duree = 0.7
    n = int(duree * SR)
    t = np.arange(n) / SR
    f = 520 + 280 * np.sin(np.pi * np.minimum(t / 0.45, 1)) - 120 * t
    ton = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    # « mi-a-ou » : la bouche s'ouvre puis se ferme
    ouvert = np.sin(np.pi * np.clip(t / duree, 0, 1)) ** 0.7
    return normaliser(passe_bas(ton, 1200 + 2400 * ouvert[len(ouvert) // 2]) * ouvert, 0.5)


def bruit_grenouilles():
    """Coassements de grenouilles au bord de l'eau, en boucle."""
    duree = 9.0
    piste = silence(duree)
    for _ in range(26):
        debut = hasard.uniform(0, duree - 0.5)
        f = hasard.uniform(180, 320)
        for k in range(hasard.integers(2, 5)):
            n = int(0.07 * SR)
            t = np.arange(n) / SR
            c = np.sign(np.sin(2 * np.pi * f * t)) * np.sin(np.pi * t / 0.07) * hasard.uniform(0.2, 0.5)
            poser(piste, passe_bas(c, 1400), debut + k * 0.11)
    f = int(0.5 * SR)
    piste[:f] = piste[:f] * np.linspace(0, 1, f) + piste[-f:] * np.linspace(1, 0, f)
    return normaliser(piste[:-f], 0.5)


def bruit_corbeau():
    """Croassement lointain de corbeau (deux ou trois « kaa »)."""
    piste = silence(1.6)
    for k in range(3):
        n = int(0.28 * SR)
        t = np.arange(n) / SR
        f = 420 - 120 * t / 0.28
        ton = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.4 + np.sin(2 * np.pi * np.cumsum(f * 3) / SR) * 0.2
        ton = passe_bas(ton + hasard.normal(0, 0.35, n), 1800) * np.sin(np.pi * t / 0.28) ** 0.5
        poser(piste, ton * (1.0 - k * 0.2), k * 0.42)
    return normaliser(reverb(piste, 2.4, 0.4), 0.45)


def bruit_clic():
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    bois = np.sin(2 * np.pi * 900 * t) * np.exp(-t * 90)
    return normaliser(bois, 0.4)


if __name__ == "__main__":
    import sys
    choix = set(sys.argv[1:])
    for nom, f in [("chasse", musique_chasse), ("victoire", stinger_victoire), ("defaite", stinger_defaite),
                   ("boss", musique_boss), ("tresor", stinger_tresor)]:
        if not choix or nom in choix:
            ecrire(nom, f(), "music")
    for nom, f in [("pas", bruit_pas), ("saut", bruit_saut), ("grimpe", bruit_grimpe), ("dash", bruit_dash),
                   ("tranche", bruit_tranche), ("lanterne", bruit_lanterne), ("garde_tombe", bruit_garde_tombe),
                   ("alerte", bruit_alerte), ("frappe", bruit_frappe), ("grincement", bruit_grincement),
                   ("clochettes", bruit_clochettes), ("coupe", bruit_coupe), ("parchemin", bruit_parchemin),
                   ("autel", bruit_autel), ("clic", bruit_clic), ("pluie", bruit_pluie),
                   ("porte", bruit_porte), ("herse", bruit_herse), ("coffre", bruit_coffre),
                   ("coffre_apparait", bruit_coffre_apparait), ("boss_cri", bruit_boss_cri),
                   ("boss_charge", bruit_boss_charge), ("boss_touche", bruit_boss_touche),
                   ("boss_onde", bruit_boss_onde), ("buisson", bruit_buisson), ("miaou", bruit_miaou),
                   ("grenouilles", bruit_grenouilles), ("corbeau", bruit_corbeau)]:
        if not choix or nom in choix:
            ecrire(nom, f(), "sfx")
