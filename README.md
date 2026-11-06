# Chacha243

Pilote l'avion du Congo, de l'Indépendance (30 juin 1960) au 30 juin 2027. Chaque année marquante est un médaillon à attraper, chaque moment difficile une zone d'orages à traverser, et l'avion change de livrée avec la compagnie nationale de l'époque : Sabena, Air Congo, Air Zaïre, LAC, Congo Airways, puis la nouvelle Air Congo.

Les guerres (Katanga, Shaba, AFDL, deuxième guerre, M23…) sont des **zones de turbulence** : des avions de chasse noirs arrivent en vagues, 1, puis 2, puis 3…, annoncés par un signal rouge. Après la dernière vague vient une étape de paix (« Kimia ezongi »). Un point de reprise est posé à l'entrée et à la sortie de chaque zone et à chaque décennie : après un atterrissage d'urgence, on reprend là où on s'est arrêté.

L'avion n'est pas choisi librement : en 1960 on vole sur les avions de 1960, puis l'avion change avec l'histoire (fiche avion : nom, places, passagers à bord). Pendant une escale on peut prendre un autre avion de l'époque.

Le pilote donne son nom une fois ; il est gardé sur le téléphone. La tour de contrôle propose des **missions** : atterrir pour embarquer des passagers, les protéger quand la guerre arrive à la remontée, puis les déposer, parfois dans une ville difficile (Goma pendant le volcan ou le M23, Kananga pendant Kamuina Nsapu, Matadi pendant Bundu dia Kongo : rafales à l'approche). Chaque mission réussie fait monter le grade, jusqu'à « Bon pilote ». À court de kérosène, une **question d'histoire** (au plus trois par vol) remplit le réservoir. Les grands tournants (Mobutu, l'AFDL, 2006, 2019…) font bouillir le ciel et le drapeau change sous les yeux.

Dans la cabine : quand la tour annonce des turbulences ou une zone de guerre, le pilote allume le signal **« Attachez vos ceintures »** et les sièges passent au vert un par un ; trop tard, les passagers sont secoués. À l'heure du repas, il compose le plateau (fufu, chikwangue ou loso ; madesu, fumbwa, pondu, makayabu, poisson grillé, poulet mayo, dindon, ntaba, liboke ; Primus, Turbo King, Castel, Nkoyi, Tembo, ou un sucré : Vitalo, Fanta, Coca-Cola) et le chariot passe dans l'allée ; le commandant et le copilote mangent aussi.

On **gagne de l'argent** en volant, en livrant des passagers, en vendant les boissons et avec les médaillons. Chaque escale coûte 1 000 de droits, plus le kérosène ; sans assez d'argent, on convertit ses points ou on continue. La monnaie suit l'histoire : franc (1960), zaïre (24 juin 1967), nouveau zaïre (22 octobre 1993), franc congolais (30 juin 1998).

Flutter + [Flame](https://flame-engine.org). Android, iOS et web.

## Lancer

```bash
flutter pub get
flutter run
```

Commandes en vol : inclinaison du téléphone (calibrée au décollage) ou glisser le doigt, bouton **TURBO** maintenu pour accélérer (traînée aux couleurs du drapeau), bouton **photo** pour attirer les médaillons proches. Au clavier : flèches, espace = TURBO, P = photo.

Sur le web, des paramètres servent aux tests et aux bandes-annonces :

| Paramètre | Effet |
| --- | --- |
| `?demo=1` | pilote automatique |
| `&avion=b747` | avion (`dc3`, `dc6`, `b707`, `caravelle`, `dc10`, `b747`, `b737`, `a320`, `atr72`, `b787`) |
| `&annee=1974.6` | commence directement en vol à cette année |
| `&vitesse=4` | accélère le temps |
| `&avance=20` | simule 20 secondes de vol au chargement (captures) |
| `&kerosene=30` | kérosène au départ, pour tester une escale |
| `&montrer=fiche` | montre la fiche avion après l'avance (`tournant`, `quiz`, `ceintures`, `repas`, `service`) |
| `?ecran=hangar` | ouvre le hangar |

## Organisation

| Dossier | Contenu |
| --- | --- |
| `lib/data/` | avions, compagnies et drapeaux par époque, événements 1960-2026, zones de turbulence et textes en lingala |
| `lib/painting/` | dessin vectoriel des avions (effet 3D par ombrage) et des drapeaux |
| `lib/game/` | le jeu Flame : décollage, vol, orages, médaillons, pilotage par inclinaison |
| `lib/ui/` | accueil, hangar, tableau de bord en verre, dates à retenir, à propos et soutien |
| `assets/photos/` | quelques petites photos d'archives et logos (≈ 250 Ko en tout) |
| `assets/notes/` | les billets en vignettes (220 px de large, 80 Ko en tout) |
| `assets/audio/` | les chansons licenciées, à déposer ici (voir `LISEZMOI.txt`) |
| `design/icone-A/` | icône (toutes tailles Android, iOS, stores, 4K) |
| `design/avions/` | les 10 avions en PNG 4K, générés par `flutter test test/render_aircraft_test.dart` |
| `design/captures/` | captures d'écran du jeu |

## À savoir

- Les avions sont dessinés en vecteurs avec un ombrage qui donne du volume : nets en 4K, mais ce ne sont pas des modèles 3D. De vrais modèles 3D (glTF) demanderaient un artiste 3D et un moteur 3D.
- Les livrées sont inspirées des couleurs de chaque époque, sans les vrais logos : ils appartiennent aux compagnies et demandent une autorisation.
- Les phrases en lingala sont à faire valider par des locuteurs.
- Les dates des événements restent à faire valider par des historiens avant la sortie.
- Aucune chanson n'est incluse (*Indépendance Cha Cha*, *Ali bomaye*, OK Jazz, Viva la Musica, Wenge Musica, Kester Emeneya, chants de réveil) : elles sont protégées et demandent une licence. Le jeu les joue dès que le fichier est dans `assets/audio/`, et reste silencieux sinon.
- Les logos de la BCC et de la Banque commerciale du Congo, les billets et les photos d'archives ne s'affichent qu'en mode développement tant que leurs droits ne sont pas confirmés (`cleared: true` dans `lib/data/archive.dart`).
- À confirmer : la date des églises de réveil et du pasteur Ayidini Abala, et celle de Kester Emeneya (1982).
- Les liens de don, de note et de contact de la page À propos sont à remplir dans `lib/ui/about_screen.dart`.

## Sources

- [Air Congo (2024)](https://en.wikipedia.org/wiki/Air_Congo) : premiers vols le 1er décembre 2024, flotte de 737-800, ATR 72-600 et 787.
- [Air Zaïre](https://en.wikipedia.org/wiki/Air_Za%C3%AFre) : Air Congo de 1961, DC-3, DC-4, DC-6, Boeing 707, DC-10 et 747.
- [Congo Airways](https://en.wikipedia.org/wiki/Congo_Airways) : premier vol le 20 octobre 2015 avec deux A320.
- [Lignes Aériennes Congolaises](https://en.wikipedia.org/wiki/Lignes_A%C3%A9riennes_Congolaises) : liquidées en 2013.
