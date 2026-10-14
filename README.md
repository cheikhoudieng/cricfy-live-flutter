# ⚡ Cricfy Live Flutter (Multi-Source Sports Player & CI/CD)

Application Flutter moderne reproduisant le mécanisme d'ingénierie inverse de **Crickfy TV**, avec déchiffrement natif AES-128-CBC, synchronisation temps réel des matchs et **lecteur vidéo multi-sources** intégré.

---

## 🚀 Fonctionnalités Clés

- 🔐 **Déchiffrement AES-128-CBC Embarqué :** Déchiffrement direct des réponses chiffrées de l'API avec les clés statiques extraites de `libnative-lib.so`.
- 📺 **Lecteur Vidéo Intégré (Chewie / ExoPlayer) :**
  - Prise en charge des flux HLS (`.m3u8`) et MP4.
  - Sélecteur interactif multi-sources en direct (Sources 1 à N, Serveurs HD / Low, feeds Sky / TNT).
  - Mode Plein écran, contrôles vidéo complets, gestion du buffer réseau.
- ⏱ **Chronos & Statuts Temps Réel :**
  - Matchs en direct avec chrono écoulé dynamique mis à jour chaque seconde.
  - Compte à rebours avant le coup d'envoi ("Début dans MM:SS").
  - Badges visuels interactifs (`EN DIRECT`, `BIENTÔT`, `À VENIR`).
- 🔄 **Filtres Dynamiques :** Filtrage instantané (Tous, En direct, À venir).
- 🤖 **CI/CD Automatique GitHub Actions :**
  - Compilation automatique de l'APK Release sur chaque commit/push.
  - Téléchargement direct de l'APK depuis l'onglet **Actions > Artifacts**.

---

## 🛠 Compilation Locale

```bash
# Récupérer les dépendances
flutter pub get

# Lancer sur émulateur ou appareil connecté
flutter run

# Compiler l'APK Release
flutter build apk --release
```

---

## 📦 Téléchargement de l'APK depuis GitHub Actions

1. Rendez-vous sur l'onglet **Actions** du repository : [GitHub Actions Runs](https://github.com/cheikhoudieng/cricfy-live-flutter/actions).
2. Cliquez sur le dernier run de compilation.
3. Téléchargez l'archive **`CricfyLive-APK`** dans la section **Artifacts**.
