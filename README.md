<div align="center">

# <img src=".github/icons/avion.svg" width="34" height="34" align="top" alt=""> Chacha243

### Pilote l'avion du Congo, de l'Indépendance à aujourd'hui.

**30 juin 1960 → 30 juin 2027** · un vol, soixante-sept ans d'histoire

![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white)
![Flame](https://img.shields.io/badge/Flame-1.38-FF6F00)
![Plateformes](https://img.shields.io/badge/plateformes-Android%20·%20iOS%20·%20Web-007FFF)
![Langue](https://img.shields.io/badge/langue-français%20·%20lingala-CE1021)

[Le jeu](#le-jeu) · [Lancer](#lancer-le-projet) · [Architecture](#architecture) · [Contribuer](#contribuer) · [Depuis 2014](#depuis-2014)

</div>

---

## Le jeu

**Chacha243** apprend l'histoire de la République démocratique du Congo en jouant. Le joueur décolle de Léopoldville le jour de l'Indépendance et traverse les années jusqu'en 2027 aux commandes de l'avion du pays.

| | |
| --- | --- |
| 🏅 **Les médaillons** | Chaque moment marquant (Indépendance, Lumumba, la rumba, le Combat du siècle, les élections…) est un médaillon à attraper, avec sa fiche, sa date et sa ville. |
| <img src=".github/icons/orages.svg" width="18" height="18" align="top" alt=""> **Les orages** | Les moments difficiles sont des zones d'orages à traverser sans casser l'avion. |
| <img src=".github/icons/guerre.svg" width="18" height="18" align="top" alt=""> **Les zones de turbulence** | Les guerres (Katanga, Shaba, AFDL, deuxième guerre, M23…) arrivent en vagues d'avions de chasse, puis vient une étape de paix : *« Kimia ezongi »*. |
| <img src=".github/icons/avion.svg" width="18" height="18" align="top" alt=""> **L'avion de chaque époque** | DC-3 et DC-6 de la Sabena, 707 et DC-10 d'Air Zaïre, A320 de Congo Airways, 787 de la nouvelle Air Congo : l'avion change avec l'histoire, avec sa fiche (places, passagers à bord). |
| <img src=".github/icons/missions.svg" width="18" height="18" align="top" alt=""> **Les missions** | La tour de contrôle confie des passagers à embarquer, à protéger, puis à déposer, parfois dans une ville difficile (Goma, Kananga, Matadi). Le grade monte, d'*Élève pilote* à *Très bon pilote*. |
| <img src=".github/icons/quiz.svg" width="18" height="18" align="top" alt=""> **Le quiz du kérosène** | À court de carburant, une question d'histoire remplit le réservoir. |
| <img src=".github/icons/drapeau.svg" width="18" height="18" align="top" alt=""> **Les grands tournants** | 1965, 1997, 2006, 2019 : le ciel bout et le drapeau change sous les yeux du joueur. |
| <img src=".github/icons/cabine.svg" width="18" height="18" align="top" alt=""> **La cabine** | Le signal *« Attachez vos ceintures »* avant la turbulence, puis le **plat du jour** (fufu, chikwangue ou loso ; madesu, pondu, liboke…) et le chariot des boissons (Primus, Turbo King, Vitalo…). Les passagers parlent, en lingala et en français, quand vient la guerre, l'orage ou la paix. |
| <img src=".github/icons/argent.svg" width="18" height="18" align="top" alt=""> **L'argent du pays** | On gagne en volant et en servant la cabine ; chaque escale coûte 1 000 de droits plus le kérosène. La monnaie suit l'histoire : **franc → zaïre → nouveau zaïre → franc congolais**. |
| <img src=".github/icons/drapeau.svg" width="18" height="18" align="top" alt=""> **L'arrivée du 30 juin 2027** | D'octobre 2026 à juin 2027, les mois défilent sur *Kitisa Moto* d'Alain Moloto : le pilote automatique traverse les derniers orages, puis l'avion se pose calmement à N'djili sur *Indépendance Cha Cha*. Le message au pays s'écrit lettre par lettre, suivi des « Vive le Congo ! », du bilan et de l'historique des vols. |

Un vol complet de 1960 à 2027 dure environ 15 minutes. Plus on avance, plus le ciel est dur : les orages se resserrent, les avions de chasse vont plus vite, et l'avion peut s'écraser. Entre deux épreuves, le ciel se calme : des avions étrangers saluent, des oiseaux passent, la cabine danse. Un point de reprise est posé à chaque décennie et à l'entrée et à la sortie de chaque zone de guerre : après un atterrissage d'urgence, on repart de là.

## Lancer le projet

```bash
flutter pub get
flutter run              # téléphone branché, simulateur, ou -d chrome
```

**Commandes en vol :** inclinaison du téléphone (calibrée au décollage) ou glisser du doigt · **TURBO** maintenu pour accélérer · **photo** pour attirer les médaillons proches. Au clavier : flèches, `espace` = TURBO, `P` = photo.

### Paramètres de test (web)

Ils permettent d'ouvrir le jeu directement au bon endroit, pour tester ou préparer une bande-annonce :

| Paramètre | Effet |
| --- | --- |
| `?demo=1` | pilote automatique |
| `&avion=b747` | avion imposé : `dc3`, `dc6`, `b707`, `caravelle`, `dc10`, `b747`, `b737`, `a320`, `atr72`, `b787` |
| `&annee=1974.6` | commence en vol à cette année |
| `&vitesse=4` | accélère le temps |
| `&avance=20` | simule 20 secondes de vol au chargement |
| `&kerosene=30` | kérosène au départ, pour tester une escale |
| `&quiz=1` | pose une question d'histoire tout de suite |
| `&montrer=fiche` | ouvre un écran : `fiche`, `tournant`, `quiz`, `ceintures`, `repas`, `service` |
| `?ecran=hangar` | ouvre le hangar |

Exemple : `http://localhost:8080/?demo=1&annee=1997&avance=10&montrer=repas`

## Architecture

```text
lib/
├── main.dart              point d'entrée, thème, routes
├── app_state.dart         nom du pilote, missions réussies, grades
├── data/                  le contenu : tout ce qui est historique vit ici
│   ├── history_events.dart   75 moments de 1960 à 2027 (triés par année)
│   ├── war_zones.dart        zones de turbulence et phrases en lingala
│   ├── eras.dart             compagnies, livrées et drapeaux par époque
│   ├── aircraft_types.dart   les 10 avions et leurs dates de service
│   ├── airports.dart         aéroports, noms de villes selon l'époque
│   └── archive.dart          photos, billets, monnaies, chansons, menu de bord
├── game/                  le moteur Flame
│   ├── chacha_game.dart      boucle de jeu : phases de vol, missions, cabine, argent
│   ├── checkpoint.dart       point de reprise
│   ├── scenery.dart          ciel, sol et villes
│   ├── tilt_control.dart     pilotage par inclinaison
│   └── music.dart            musique par moment
├── painting/              avions et drapeaux dessinés en vecteurs
├── theme/                 couleurs du drapeau et de l'interface
└── ui/                    écrans Flutter : accueil, hangar, tableau de bord, frise, à propos
```

Le moteur (`game/`) publie son état dans des `ValueNotifier` ; l'interface (`ui/`) les écoute et dessine les panneaux en verre par-dessus le jeu. Le contenu (`data/`) ne dépend de rien : ajouter un moment ou un avion ne demande pas de toucher au moteur.

Le fonctionnement complet (phases de vol, économie, règles du contenu) est décrit dans le **[guide de contribution](CONTRIBUTING.md)**.

## Contribuer

Les contributions sont les bienvenues : code, dates à vérifier, phrases en lingala, idées de moments. Lis d'abord **[CONTRIBUTING.md](CONTRIBUTING.md)**.

En bref : une branche par changement · `flutter analyze` sans erreur · une pull request relue avant de fusionner dans `main`.

## Depuis 2014

La première version, **« Chacha 243 »**, a été développée en **2014**.
[Voir la version de 2014 sur APKPure](https://apkpure.com/chacha-243/com.overlookdev.BalloonDefense)

Douze ans plus tard, le jeu renaît : nouveaux avions, nouvelles époques, et toute l'histoire du pays jusqu'en 2027.

## À savoir

- **Médias hors du dépôt.** Les photos d'archives, les billets et les chansons (`assets/photos/`, `assets/notes/`, `assets/audio/`) ne sont pas publiés : leurs droits sont réglés à part. Le jeu fonctionne sans eux ; voir le `LISEZMOI.txt` de chaque dossier.
- **Avions et livrées.** Les avions sont dessinés en vecteurs avec un ombrage qui donne du volume, nets en 4K. Les livrées s'inspirent des couleurs de chaque époque, sans les logos des compagnies.
- **Musique.** Chaque moment a sa chanson (Grand Kallé, Franco, Papa Wemba…), une louange douce accompagne les moments difficiles et Alain Moloto la dernière ligne droite. Les extraits montent et s'éteignent en fondu, avec du silence entre eux. Les fichiers ne sont joués que s'ils sont présents dans `assets/audio/` ; sinon le jeu reste silencieux.
- **Relecture.** Les dates sont relues par des historiens et les phrases en lingala par des locuteurs avant chaque version.

## Sources

- [Air Congo (2024)](https://en.wikipedia.org/wiki/Air_Congo) : premiers vols le 1er décembre 2024, flotte de 737-800, ATR 72-600 et 787.
- [Air Zaïre](https://en.wikipedia.org/wiki/Air_Za%C3%AFre) : DC-3, DC-4, DC-6, Boeing 707, DC-10 et 747.
- [Congo Airways](https://en.wikipedia.org/wiki/Congo_Airways) : premier vol le 20 octobre 2015 avec deux A320.
- [Lignes Aériennes Congolaises](https://en.wikipedia.org/wiki/Lignes_A%C3%A9riennes_Congolaises) : liquidées en 2013.

## Droits

© 2014–2026 BBasabana. Tous droits réservés. Le code est partagé pour travailler ensemble sur le jeu, pas pour être réutilisé ailleurs sans accord.

<div align="center">

**Bon vol !**

</div>
