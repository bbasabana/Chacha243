# Icône Tchatcha 243 — concept A « La diagonale »

## Installer dans le projet Flutter

Les dossiers `android/` et `ios/` reprennent la structure d'un projet Flutter : copie-les à la racine du projet (ils remplacent les icônes par défaut).

- `android/app/src/main/res/mipmap-*/` : icônes adaptatives (fond, premier plan, monochrome pour les icônes à thème d'Android 13+), plus les anciennes icônes carrée et ronde.
- `android/app/src/main/res/mipmap-anydpi-v26/` : déclaration de l'icône adaptative.
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` : une seule image 1024 px en trois apparences, claire, sombre et teintée (Xcode 16 ou plus récent ; les autres tailles sont générées par Xcode).

Vérifie que `AndroidManifest.xml` contient `android:icon="@mipmap/ic_launcher"` et `android:roundIcon="@mipmap/ic_launcher_round"`.

## Autres fichiers

| Dossier | Contenu |
| --- | --- |
| `master/` | SVG vectoriels et PNG 1024 px (claire, sombre, teintée) + PNG 4K (4096 px) |
| `calques/` | fond, bande, étoile, avion séparés (SVG et PNG transparents) pour Icon Composer, le motion design et l'écran de démarrage |
| `stores/` | Google Play 512 px, App Store 1024 px (sans transparence) |
| `android-src/` | sources du dessin Android resserré dans la zone sûre |

Couleurs : bleu `#007FFF`, rouge `#CE1021`, jaune `#F7D618`.
