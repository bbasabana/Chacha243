# Contribuer à Chacha243

Merci de rejoindre le projet. Ce guide explique **ce qu'est le jeu**, **comment il fonctionne**, et **comment proposer un changement** sans casser l'expérience du joueur ni l'exactitude historique. Lis-le en entier avant ta première pull request : la plupart des questions y trouvent leur réponse.

## Sommaire

1. [L'intention du produit](#1-lintention-du-produit)
2. [Mettre en place le projet](#2-mettre-en-place-le-projet)
3. [Vue d'ensemble de l'architecture](#3-vue-densemble-de-larchitecture)
4. [La logique du jeu](#4-la-logique-du-jeu)
5. [Le contenu historique](#5-le-contenu-historique)
6. [Images, logos, musiques et droits](#6-images-logos-musiques-et-droits)
7. [Tester un changement](#7-tester-un-changement)
8. [Style du code](#8-style-du-code)
9. [Le flux de travail Git](#9-le-flux-de-travail-git)
10. [Recettes : ajouter un moment, un avion, un aéroport…](#10-recettes)
11. [Ce qu'il ne faut pas faire](#11-ce-quil-ne-faut-pas-faire)

---

## 1. L'intention du produit

Chacha243 apprend l'histoire de la RD Congo **par le jeu**, à des élèves, des familles et à la diaspora. Le joueur pilote l'avion du pays du **30 juin 1960** au **30 juin 2027**. Chaque décision de conception découle de trois principes :

| Principe | Ce que cela veut dire pour une contribution |
| --- | --- |
| **Apprendre sans s'en rendre compte** | L'histoire passe par le jeu : un médaillon, une fiche courte, une question, un drapeau qui change. Pas de longs textes à lire en vol : une fiche tient en deux ou trois phrases. |
| **Exact et neutre** | Chaque date a une source. Les conflits sont montrés sans désigner de camp : avions de guerre abstraits, sans insignes ni tirs, et jamais de personnes en obstacle. |
| **Congolais dans le détail** | Les compagnies de chaque époque, les villes selon leur nom d'alors, le plat du jour, les bières et les sodas du pays, la monnaie qui change, le lingala de la tour de contrôle. Un détail juste vaut mieux qu'une fonction de plus. |

La langue du jeu est le **français**, avec des phrases en **lingala**. Les textes visibles par le joueur restent simples : phrases courtes, mots de tous les jours.

## 2. Mettre en place le projet

**Prérequis :** Flutter 3.41 ou plus récent (Dart 3.11), Xcode pour iOS, Android Studio ou le SDK Android pour Android.

```bash
git clone https://github.com/bbasabana/Chacha243.git
cd Chacha243
flutter pub get
flutter run -d chrome        # le plus rapide pour itérer
flutter run                  # téléphone ou simulateur
```

Le dépôt ne contient **ni photos, ni billets, ni chansons** (voir [§ 6](#6-images-logos-musiques-et-droits)). Le jeu est conçu pour fonctionner sans eux : les vignettes ne s'affichent pas et la musique reste silencieuse. Tu n'as rien à ajouter pour contribuer.

| Dépendance | Rôle |
| --- | --- |
| `flame` | moteur 2D : boucle de jeu, rendu sur canvas |
| `shared_preferences` | nom du pilote, missions réussies, point de reprise |
| `audioplayers` | musique par moment (si le fichier existe) |
| `sensors_plus` | pilotage par inclinaison du téléphone |
| `url_launcher` | liens de la page « À propos » |

N'ajoute pas de dépendance sans en avoir parlé dans une issue.

## 3. Vue d'ensemble de l'architecture

```text
lib/
├── main.dart          point d'entrée, thème, routes
├── app_state.dart     état durable du joueur : nom, missions, grade
├── data/              LE CONTENU — dates, avions, villes, monnaies, menus
├── game/              LE MOTEUR — boucle Flame, physique, règles
├── painting/          avions et drapeaux dessinés en vecteurs
├── theme/             couleurs
└── ui/                LES ÉCRANS — Flutter par-dessus le jeu
```

### Trois couches, une seule direction

```text
 data/  ──►  game/  ──►  ValueNotifier  ──►  ui/
(contenu)   (règles)     (état publié)     (affichage)
```

- **`data/`** ne dépend de rien. Ce sont des listes `const` de classes simples (`HistoryEvent`, `WarZone`, `AircraftType`, `AirlineEra`, `Airport`, `ArchivePhoto`, `Banknote`). On y ajoute du contenu **sans toucher au moteur**.
- **`game/chacha_game.dart`** (`ChachaGame extends FlameGame`) lit ce contenu, fait avancer le temps, applique les règles et dessine le monde sur le canvas (ciel, avion, orages, médaillons, particules).
- Le moteur **publie** son état dans des `ValueNotifier` : `hud`, `card`, `banner`, `radio`, `stopover`, `planeCard`, `mission`, `quiz`, `turningPoint`, `cabin`, `meal`. Il ne connaît aucun widget.
- **`ui/game_screen.dart`** écoute ces notifiers avec des `ValueListenableBuilder` et dessine les panneaux en verre (`ui/glass.dart`). Les actions du joueur reviennent au moteur par des méthodes publiques : `acceptStopover()`, `answerQuiz()`, `fastenBelts()`, `serveMeal()`, `changeAircraft()`.

Garde cette séparation : pas de widget dans `game/`, pas de règle de jeu dans `ui/`.

### Les écrans

| Fichier | Écran |
| --- | --- |
| `ui/home_screen.dart` | accueil : décoller, reprendre, hangar, frise, à propos |
| `ui/hangar_screen.dart` | les 10 avions, leurs années de service et leurs fiches |
| `ui/game_screen.dart` | le vol : jeu Flame + tous les panneaux |
| `ui/cockpit_panel.dart` | tableau de bord (kérosène, état, vies, argent) |
| `ui/timeline_screen.dart` | « Dates à retenir » : les médaillons attrapés |
| `ui/about_screen.dart` | à propos, version de 2014, soutenir le projet |

### Une particularité de Flame à connaître

Flame appelle `game.update(0)` pendant la construction du `GameWidget`. Modifier un `ValueNotifier` à ce moment provoque l'erreur *« setState() called during build »*. C'est pourquoi :

- `update()` **sort tout de suite si `dt == 0`** ;
- l'initialisation qui publie un état (préchauffage, écrans de démonstration) se fait dans `_firstStep()`, au premier vrai pas de temps, **jamais dans `onLoad()`**.

Le temps de jeu avance par pas fixes de 1/60 s : une même partie se rejoue à l'identique quelle que soit la machine.

## 4. La logique du jeu

### 4.1 Le temps et l'année

L'année courante est un nombre décimal : `1974.83` = fin octobre 1974. Hors zones de guerre, une année dure **6,5 secondes** de vol (`_yearSeconds`) ; le vol se termine à `2027.5`. Tout dans le jeu se déduit de l'année : l'avion disponible, la compagnie, la livrée, le drapeau, le nom des villes, la monnaie, les moments qui arrivent.

### 4.2 Les phases de vol

```text
ready → rolling → climbing → cruising ⇄ approach → ground → (rolling …)
                                 │
                                 ├──► crashed  → reprise au dernier point
                                 └──► finished → 30 juin 2027
```

| Phase | Ce qui se passe |
| --- | --- |
| `ready` | l'avion attend au bout de la piste ; tutoriel de décollage au premier vol |
| `rolling` | roulage et prise de vitesse, puis rotation |
| `climbing` | montée jusqu'à l'altitude de croisière |
| `cruising` | le cœur du jeu : médaillons, orages, guerres, cabine, radio |
| `approach` | descente vers un aéroport (escale, embarquement, débarquement) |
| `ground` | au sol : facture de l'escale, plein, changement d'avion possible, puis redécollage |
| `crashed` | atterrissage d'urgence ; on reprend au dernier point de reprise |
| `finished` | arrivée en 2027 : bilan et finale musicale |

### 4.3 Vies, état de l'avion et kérosène

- On part avec **3 vies** (maximum 9). Un orage ou un avion de chasse touché retire une vie et 20 % d'état ; l'avion est ensuite invulnérable 2 secondes.
- Le **kérosène** baisse en continu, plus vite en TURBO et dans une zone de guerre (× 1,8), moins vite avec un grand réservoir (`AircraftType.tank`).
- Ramassables en vol : **médaillon** (+1 vie, +15 kérosène, +150 d'argent), **étoile** (+10 points), **bidon** (+32 kérosène), **kit d'entretien** (plein et entretien faits en vol).
- Kérosène sous 35 ou état sous 30 % : la tour propose une **escale** à l'aéroport le plus proche.
- Kérosène sous 14 : une **question d'histoire** (au plus **3 par vol**). Bonne réponse : réservoir rempli. Le jeu se met en pause pendant la question.

### 4.4 Les moments d'histoire

Chaque `HistoryEvent` a un type (`EventKind`) :

| Type | En jeu |
| --- | --- |
| `life` | médaillon à attraper, avec sa fiche |
| `glory` | médaillon doré, confettis aux couleurs du drapeau |
| `obstacle` | zone d'orages à traverser |
| `memory` | moment de recueillement, sans médaillon, fiche affichée plus longtemps |

Options : `war` (déclenche une zone de turbulence), `volcano` (le Nyiragongo crache sa lave sous l'avion), `photo` et `song` (clés vers `archive.dart`), `big` (**grand tournant** : le ciel bout et le drapeau change sous les yeux du joueur).

### 4.5 Les zones de turbulence (guerres)

Définies dans `data/war_zones.dart`. Dans une zone, **le temps n'avance qu'avec les vagues passées** : la vague *n* envoie *n* avions de chasse, annoncés par un signal rouge. Après la dernière vague vient l'étape de paix (`peaceTitle`, `peaceText`). Un point de reprise est posé à l'entrée, après chaque vague et à la sortie. Pas d'escale pendant une zone.

### 4.6 Les avions et les compagnies

- `data/aircraft_types.dart` : les 10 avions (DC-3, DC-6, 707, Caravelle, DC-10, 747, 737, A320, ATR 72, 787), leurs moteurs, leurs places, leur réservoir et leurs **années de service**.
- `data/eras.dart` : les compagnies par époque (Sabena, Air Congo, Air Zaïre, LAC, Congo Airways, nouvelle Air Congo), leurs livrées et les drapeaux (`FlagEra`).
- Le joueur **ne choisit pas librement** : il vole sur un avion de l'époque. Quand l'époque change, l'avion change, avec une fiche (nom, places, passagers). À l'escale, il peut prendre un autre avion de la même époque.

### 4.7 Les missions et les grades

La tour confie une `Mission` : atterrir dans une ville pour **embarquer** des passagers, les **protéger** (chaque coup reçu pendant la mission compte), puis les **déposer**. Une ville difficile du moment (Goma pendant le volcan ou le M23, Kananga pendant Kamuina Nsapu, Matadi pendant Bundu dia Kongo) ajoute des rafales à l'approche. Une mission réussie rapporte 300 points par étoile et 40 d'argent par passager.

Le nombre de missions réussies est gardé sur le téléphone et donne le grade : *Élève pilote* → *Copilote* (1) → *Commandant* (3) → *Bon pilote* (8) → *Très bon pilote* (15).

### 4.8 La cabine

`CabinMode` : `beltsAsk → beltsFastening → beltsDone`, puis `serving → served`.

- **Ceintures.** Avant une turbulence ou une zone de guerre, la tour demande d'allumer le signal *« Attachez vos ceintures »* ; les sièges passent au vert un par un. Trop tard, les passagers sont secoués et la mission perd une étoile.
- **Le plat du jour.** Il y a un seul plat pour tout l'avion, comme dans un vrai vol. Le pilote choisit un accompagnement (fufu, chikwangue, loso), un plat (madesu, fumbwa, pondu, makayabu…) et les boissons du chariot (bières, sucrés, liqueurs). Chaque passager prend une des boissons proposées ; la vente rapporte de l'argent (liqueur 60, bière 25, autre 15). L'équipage mange aussi, **sans alcool aux commandes**.
- Le jeu se met en pause pendant le choix ; le pilote automatique sert seul au bout de 1,2 s.

### 4.9 L'argent et la monnaie

- On part avec **3 000**. On gagne en volant (un peu par seconde, plus avec des passagers), avec les médaillons, les missions et le service à bord.
- Chaque escale coûte **1 000 de droits** (`landingFee`) plus le kérosène (`fuelPrice` = 8 par point). Pas assez d'argent pour faire le plein : plein partiel. Pas assez pour les droits : les points sont convertis en argent, sinon la tour demande de continuer.
- La monnaie suit l'histoire (`currencyAt(year)` dans `archive.dart`) : **franc** (1960), **zaïre** (24 juin 1967), **nouveau zaïre** (22 octobre 1993), **franc congolais** (30 juin 1998). Un bandeau annonce chaque changement.

### 4.10 La musique et la cabine qui parle

- **Les chansons des moments** (`momentSongs`) : un extrait monte en fondu jusqu'à son niveau (`level`, 0,75 par défaut : la musique ne couvre jamais le vol), dure `seconds`, puis s'éteint. Entre deux chansons, le silence laisse le vol au calme.
- **La louange** (`louange`) accompagne les moments difficiles (orages, entrée en guerre) : très douce, elle monte en 6 secondes, et ne revient pas avant 75 secondes.
- **La cabine parle** (`lib/data/cabin_talk.dart`) : à la guerre, à l'orage, au volcan, à la paix, au repas, des passagers et l'équipage échangent deux ou trois répliques, en lingala avec la traduction. Les bulles sortent de l'avion, l'une après l'autre.

### 4.11 La dernière ligne droite et l'arrivée

1. **Octobre 2026** (`_finaleFrom`) : *Kitisa Moto* d'Alain Moloto commence bas. Le pilote automatique prend les commandes, les mois défilent en grand avec le compte à rebours (« J-120 avant le 30 juin 2027 »).
2. **Quand la chanson remonte** (9 s), trois murs d'orages arrivent avec un seul passage : l'avion dévie au dernier moment, au ralenti, sans perdre de vie.
3. **Le calme** (31 s) : le ciel s'ouvre, la cabine se rassure.
4. **Début juin 2027** (40 s) : *Indépendance Cha Cha* prend le relais et l'avion descend seul, calmement, vers N'djili.
5. **Posé le 30 juin 2027** : les années d'indépendance comptent jusqu'à 67, le message au pays s'écrit lettre par lettre, puis les « Vive… » éclatent avec les confettis. Le bilan suit : badges, score, historique des vols (`flights` dans `app_state.dart`), et « Recommencer en 1960 ».

Pour tester : `?demo=1&annee=2026.74`, et `&avance=56` pour arriver directement à la fête.

### 4.12 Les points de reprise

`game/checkpoint.dart` garde l'année, le score et les médaillons à chaque décennie et à l'entrée et à la sortie de chaque zone. Après un atterrissage d'urgence, on redécolle de là.

## 5. Le contenu historique

C'est la partie la plus précieuse du jeu, et la plus fragile. Règles :

1. **Une source par date.** Toute date ajoutée ou modifiée dans `data/` est accompagnée de sa source dans la pull request (article, livre, archive de presse). Wikipédia est un point de départ, pas une preuve suffisante pour un moment sensible.
2. **Les listes restent triées par année.** Le moteur parcourt `historyEvents` dans l'ordre ; une liste mal triée fait sauter des moments.
3. **Années décimales.** `1997.38` = mi-mai 1997. Calcule `année + (jour de l'année / 365)` et garde deux décimales. Le champ `date` donne la date lisible (« 17 mai 1997 »).
4. **Fiches courtes.** Titre de quelques mots, texte de deux ou trois phrases, au présent, sans jugement.
5. **Neutralité.** Les faits, pas les opinions. Aucun camp n'est désigné dans une guerre. Les victimes sont évoquées avec respect (type `memory`).
6. **Noms d'époque.** Une ville porte le nom de son époque (Léopoldville avant 1966, Kinshasa après) : utilise `Airport.cityAt(year)` et `titleAt(year)`, jamais un nom figé.
7. **Le lingala** (classe `Lingala` dans `war_zones.dart`) est relu par un locuteur avant chaque version. Si tu n'es pas sûr d'une phrase, signale-le dans la pull request.

## 6. Images, logos, musiques et droits

- **Aucune photo, aucun logo, aucun billet, aucune chanson dans le dépôt.** Les droits sont réglés par l'auteur ; ces fichiers restent en local. Le `.gitignore` les exclut ; ne force jamais leur ajout.
- Une nouvelle image se déclare dans `data/archive.dart` (`ArchivePhoto`) avec `cleared: false`. Elle ne s'affiche qu'en mode développement (`kDebugMode`) tant que ses droits ne sont pas confirmés. Le code doit toujours supporter un fichier absent (`errorBuilder`).
- Une chanson se déclare dans `momentSongs` ; le jeu ne la joue que si le fichier sous licence est présent.
- Les **vrais logos de compagnies** ne sont pas utilisés : les livrées s'inspirent seulement des couleurs de l'époque.
- Le dossier `design/` (sources, captures, références) n'est pas publié.

## 7. Tester un changement

### Analyse statique (obligatoire)

```bash
flutter analyze        # doit afficher « No issues found! »
```

La CI (`.github/workflows/analyze.yml`) lance la même commande sur chaque pull request.

### Ouvrir le jeu au bon endroit

Sur le web, des paramètres d'URL évitent de rejouer toute la partie :

| Paramètre | Effet |
| --- | --- |
| `?demo=1` | pilote automatique |
| `&annee=1997.3` | commence en vol à cette année |
| `&avion=b707` | impose un avion |
| `&vitesse=4` | accélère le temps |
| `&avance=20` | simule 20 s de vol au chargement |
| `&kerosene=30` | kérosène de départ (tester une escale) |
| `&quiz=1` | pose une question tout de suite |
| `&montrer=…` | `fiche`, `tournant`, `quiz`, `ceintures`, `repas`, `service` |
| `?ecran=hangar` | ouvre le hangar |

Exemples :

```text
/?demo=1&annee=1967.4&avance=8                # changement de monnaie (zaïre)
/?demo=1&annee=1997.3&avance=6&montrer=tournant
/?demo=1&annee=2010&kerosene=30               # escale et facture
/?demo=1&annee=1985&montrer=repas
```

### Rendu des avions

```bash
flutter test test/render_aircraft_test.dart
```

Rend les 10 avions en PNG 4K dans `design/avions/` (dossier local) pour vérifier les dessins.

### Vérifier sur téléphone

Le pilotage par inclinaison, les vibrations et les performances ne se vérifient vraiment que sur un appareil. Pour un changement de jeu, teste au moins une fois sur Android ou iOS.

## 8. Style du code

- **Commentaires et textes en français.** Les noms de code (classes, variables) restent en anglais, comme dans le reste du projet.
- Un commentaire `///` explique **pourquoi** et ce que voit le joueur, pas ce que fait la ligne.
- Garde le style du fichier autour : même découpage, mêmes conventions. Le formatage suit `dart format`.
- Les constantes de réglage (prix, durées, seuils) sont des `static const` nommées en haut de `ChachaGame`, pas des nombres perdus dans le code.
- Les textes du joueur ne contiennent pas de jargon technique.
- Les couleurs viennent de `theme/chacha_colors.dart` (`ChachaColors`).

## 9. Le flux de travail Git

1. Ouvre ou choisis une **issue** qui décrit le changement.
2. Crée une branche depuis `main`, au nom parlant :
   ```bash
   git switch -c repas-plat-du-jour
   ```
3. Des commits courts, avec un message en français qui dit ce que **le joueur** gagne :
   > *Laisser le pilote choisir les boissons du chariot, une par passager.*
4. Avant de pousser : `flutter analyze` propre, jeu testé.
5. Ouvre une **pull request** vers `main` :
   - ce qui change pour le joueur ;
   - une capture ou une courte vidéo si l'écran change ;
   - la source de chaque date ajoutée ;
   - ce qui reste à vérifier (lingala, dates, droits).
6. **Pas de fusion sans relecture.** Le mainteneur relit le jeu, le texte et l'histoire.

## 10. Recettes

### Ajouter un moment d'histoire

1. Dans `lib/data/history_events.dart`, insère un `HistoryEvent` **à sa place dans l'ordre des années** :
   ```dart
   HistoryEvent(1974.83, EventKind.glory, '30 octobre 1974', 'Kinshasa', 'Le Combat du siècle',
       'Ali et Foreman s\'affrontent au stade du 20-Mai. Le monde entier regarde Kinshasa.'),
   ```
2. Choisis le bon type (`life`, `glory`, `obstacle`, `memory`) et les options (`war`, `big`, `photo`…).
3. Donne la source dans la pull request.
4. Teste : `?demo=1&annee=1974.6&avance=2`.

### Ajouter une zone de guerre

Ajoute une `WarZone` dans `lib/data/war_zones.dart` (`from`, `to`, `name`, `place`, `waves`, `peaceTitle`, `peaceText`) et marque le moment correspondant `war: true`. Garde un nombre de vagues raisonnable (3 à 5) : une zone ne doit pas durer plus d'une minute.

### Ajouter un avion

1. Ajoute un `AircraftType` dans `lib/data/aircraft_types.dart` (moteurs, places, réservoir, années de service).
2. Rattache-le à la ou les compagnies de l'époque dans `lib/data/eras.dart`.
3. Vérifie son dessin dans `lib/painting/aircraft_painter.dart` et dans le hangar (`?ecran=hangar`).

### Ajouter un aéroport ou un nom de ville

Ajoute un `Airport` dans `lib/data/airports.dart`. Si la ville a changé de nom, donne les deux noms et l'année du changement : `cityAt(year)` choisit le bon.

### Ajouter un plat ou une boisson

Les listes `mealBases`, `mealDishes`, `mealBeers`, `mealSodas` et `mealSpirits` sont dans `lib/data/archive.dart`. Le prix d'une boisson se règle dans `drinkPrice()`.

### Ajouter une chanson

Déclare-la dans `momentSongs` (`lib/data/archive.dart`) et relie-la au moment par `song: 'cle'`. En vol, on n'entend qu'un **extrait** : il part de `start` (en secondes, pour tomber sur le refrain), monte en fondu, dure `seconds` (40 s par défaut), puis s'éteint en fondu sur 4 s. Quand un autre moment arrive avec sa chanson, la précédente baisse d'abord, puis la nouvelle monte : rien ne coupe net. À l'accueil, *Indépendance Cha Cha* tourne en boucle ; elle revient pour l'arrivée en 2027. Le fichier lui-même reste hors du dépôt.

### Ajouter une photo d'archive

Déclare-la dans `archivePhotos` (`lib/data/archive.dart`) avec `cleared: false` et sa provenance, puis relie-la au moment par `photo: 'cle'`. **N'ajoute pas le fichier au dépôt** : envoie-le au mainteneur avec ses droits.

## 11. Ce qu'il ne faut pas faire

- Pousser des photos, logos, billets ou chansons.
- Ajouter une date sans source, ou casser l'ordre des listes.
- Désigner un camp dans un conflit, montrer des personnes comme obstacles, ajouter des tirs.
- Publier un état dans un `ValueNotifier` depuis `onLoad()` ou pendant `update(0)`.
- Mettre une règle de jeu dans un widget, ou un widget dans le moteur.
- Ajouter une dépendance sans discussion.
- Fusionner dans `main` sans relecture.

---

Une question ? Ouvre une issue. Merci de faire voler l'histoire du pays.
