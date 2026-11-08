# Angel OS — système natif (étape 10)

Objectif : le vrai Angel OS installable sur le HP EliteBook Folio 9480m, avec une interface
**native en QML (Quickshell)**, à l'allure de Windows 11.

## Exigences (Michel, 8 nov. 2026)
1. **Fluide** — animations soignées, allure moderne.
2. **Très économe en batterie.**
3. **Ne pas épuiser le processeur** — CPU bas au repos, pas de chauffe.

Pour tenir les trois à la fois : les effets (animations, flou) sont **réglés par le mode d'énergie**,
exactement comme les 4 modes du prototype (Performances / Équilibré / Autonomie / Éco max).

## Pile technique (optimisée i5 Haswell + HD 4400 + 10 Go + SSD)
- **Arch Linux + Wayland** (plus léger que X11).
- **Hyprland** — compositeur animé ; animations/flou coupés automatiquement en mode économie.
- **Quickshell (QtQuick / QML)** — barre des tâches, menu Démarrer, notifications, widgets,
  Paramètres, panneau Élyane. (C'est le « QML » choisi.)
- **SDDM** (connexion façon Win11) + **Plymouth** (logo au démarrage).
- **power-profiles-daemon + tlp + hypridle** — modes d'énergie, assombrir → verrouiller → suspendre.
- **VA-API (intel-media-driver)** — décodage vidéo par le GPU (fluide, peu de CPU).
- **mpv + VLC** (lecture de tous les formats), **zram** (mémoire).
- **Élyane hors ligne** : llama.cpp + Qwen2.5-3B Q4, Piper (voix), Vosk (écoute) ; interface en QML.

## Construction SANS le BIOS
L'ISO se construit **dans le nuage avec GitHub Actions** (un conteneur Arch lance `mkarchiso`).
Pas besoin de la virtualisation du BIOS de Michel. GitHub produit l'ISO ; Michel la télécharge,
la met sur une clé USB (Ventoy) et démarre l'EliteBook dessus (touche F9).

## Jalons
1. [ ] Pipeline de build ISO sur GitHub Actions (ISO Arch minimale qui démarre).
2. [ ] Démarrage sur Hyprland + SDDM (base Win11).
3. [ ] Barre des tâches Quickshell (premier morceau Angel visible).
4. [ ] Menu Démarrer, notifications, réglages rapides (énergie, Wi-Fi, volume, luminosité).
5. [ ] Paramètres, Fichiers, panneau Élyane.
6. [ ] Réglage fin batterie + 4 modes (gouverneur CPU, animations).
7. [ ] Installateur sur l'EliteBook.

## Note honnête sur la méthode de travail
Pour le prototype web, Claude voit le résultat (captures automatiques). Ici, pour le QML, Claude
**ne voit pas** le rendu (pas d'écran/Qt côté Claude, et le BIOS/VM de Michel est bloqué). On avance
donc par : **logs de GitHub Actions** (Claude les lit pour corriger le build) + **Michel qui lance
l'ISO et envoie des captures/erreurs**. C'est plus lent que le prototype : il faudra des allers-retours.
