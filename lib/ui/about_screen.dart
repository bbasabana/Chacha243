import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../game/telemetry.dart';
import '../theme/chacha_colors.dart';
import 'glass.dart';
import 'soft_dialog.dart';

/// À propos de Chacha243, et comment soutenir le projet.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();

  /// La fiche du jeu sur Google Play ; la fiche App Store s'ajoutera à la sortie sur iPhone.
  static const playUrl = 'https://play.google.com/store/apps/details?id=cd.chacha243.chacha243';
  static const appStoreUrl = '';

  /// Le lien de don Stripe : le tableau de bord montre qui a donné, grâce à l'identifiant du pilote.
  static const donateUrl = 'https://donate.stripe.com/dRmeVebRTcK35ct0dlcbC00';
  static String get storeUrl => defaultTargetPlatform == TargetPlatform.iOS ? appStoreUrl : playUrl;

  /// L'adresse de contact, aussi donnée à l'App Store.
  static const contactEmail = 'bbasabana@gmail.com';

  /// Le code du jeu, ouvert à tous.
  static const sourceUrl = 'https://github.com/bbasabana/Chacha243';

  /// La toute première version du jeu, publiée en 2014.
  static const firstVersionUrl = 'https://apkpure.com/chacha-243/com.overlookdev.BalloonDefense';
}

class _AboutScreenState extends State<AboutScreen> with WidgetsBindingObserver {
  /// Le pilote vient d'ouvrir le lien de don : au retour, on regarde si le paiement est arrivé.
  bool _donating = false;
  final _code = Telemetry.pilotCode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _donating) _waitForGift();
  }

  /// Le paiement met quelques secondes à arriver : on regarde six fois, puis on remercie.
  Future<void> _waitForGift() async {
    for (var i = 0; i < 6; i++) {
      if (!mounted) return;
      if (await Telemetry.newGift()) {
        _donating = false;
        if (mounted) await showGiftThanks(context);
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 4));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Glass(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: ChachaColors.yellow,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
    const body = TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4);

    void copy(String text, String done) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ChachaColors.skyDeep, ChachaColors.night],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GlassButton(
                      onTap: () => Navigator.of(context).pop(),
                      padding: const EdgeInsets.all(10),
                      radius: 16,
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'À propos · Soutenir',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      section('Chacha243', const [
                        Text(
                          'Chacha243 t\'apprend l\'histoire du Congo en jouant : tu pilotes l\'avion du pays du 30 juin 1960, '
                          'jour de l\'Indépendance, au 30 juin 2027. Chaque moment marquant est un médaillon, chaque épreuve '
                          'une zone à traverser, et l\'avion change avec les compagnies de chaque époque.',
                          style: body,
                        ),
                      ]),
                      section('Open source', [
                        const Text(
                          'Chacha243 est open source : son code est ouvert à tous sur GitHub. Tu peux le lire, '
                          'proposer une correction ou une date d\'histoire, et aider à l\'améliorer.',
                          style: body,
                        ),
                        const SizedBox(height: 10),
                        GlassButton(
                          onTap: () async {
                            final ok = await launchUrl(
                              Uri.parse(AboutScreen.sourceUrl),
                              mode: LaunchMode.externalApplication,
                            );
                            if (!ok) copy(AboutScreen.sourceUrl, 'Lien copié');
                          },
                          tint: const Color(0x557CF0A6),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.code_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Voir le code sur GitHub', style: TextStyle(fontSize: 15)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AboutScreen.sourceUrl,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5),
                        ),
                      ]),
                      section('Depuis 2014', [
                        const Text(
                          'La première version, « Chacha 243 », a été développée en 2014. Douze ans plus tard, le jeu renaît : '
                          'nouveaux avions, nouvelles époques, et toute l\'histoire du pays jusqu\'en 2027.',
                          style: body,
                        ),
                        if (!appStoreRules) ...[
                          const SizedBox(height: 10),
                          GlassButton(
                            onTap: () async {
                              final ok = await launchUrl(
                                Uri.parse(AboutScreen.firstVersionUrl),
                                mode: LaunchMode.externalApplication,
                              );
                              if (!ok) copy(AboutScreen.firstVersionUrl, 'Lien copié');
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Voir la version de 2014', style: TextStyle(fontSize: 15)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AboutScreen.firstVersionUrl,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5),
                          ),
                        ],
                      ]),
                      section('Soutenir le projet', [
                        const Text(
                          'Le jeu est fait pour les élèves, les familles et la diaspora. Tu peux nous aider :',
                          style: body,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            GlassButton(
                              // Étoiles et message, gardés dans le tableau de bord.
                              onTap: () => showDialog<void>(context: context, builder: (_) => const _RatingDialog()),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Noter l\'application', style: TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                            if (!appStoreRules)
                              GlassButton(
                                onTap: () async {
                                  var url = AboutScreen.donateUrl;
                                  try {
                                    url = '${AboutScreen.donateUrl}?client_reference_id=${await Telemetry.playerId()}';
                                  } catch (_) {}
                                  _donating = true;
                                  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                  if (!ok) copy(AboutScreen.donateUrl, 'Lien copié');
                                },
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('Faire un don', style: TextStyle(fontSize: 15)),
                                  ],
                                ),
                              ),
                            GlassButton(
                              // Une date, une photo ou une chanson : elle arrive dans le tableau de bord.
                              onTap: () => showDialog<void>(context: context, builder: (_) => const _ProposalDialog()),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.photo_library_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Proposer une photo, une date', style: TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tu peux aussi proposer depuis le site : waddiel.pro/chacha243/proposer',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                        ),
                      ]),
                      section('Ton pilote', [
                        ValueListenableBuilder(
                          valueListenable: missionsDone,
                          builder: (_, m, _) => Text(
                            '${pilotName.value ?? 'Pilote'} · ${pilotRank(m)} · $m mission${m > 1 ? 's' : ''} réussie${m > 1 ? 's' : ''}',
                            style: body,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder(
                          future: _code,
                          builder: (_, s) => s.data == null
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ton code pilote. Note-le : il te rend ta partie sur un autre téléphone. Ne le donne à personne.',
                                      style: body,
                                    ),
                                    const SizedBox(height: 8),
                                    GlassButton(
                                      onTap: () => copy(s.data!, 'Code copié'),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Text(s.data!, style: const TextStyle(fontSize: 16, letterSpacing: 2)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ]),
                      section('Confidentialité', [
                        const Text(
                          'Le jeu n\'a ni compte ni publicité. Notre serveur reçoit ton nom de pilote, ta photo si tu en choisis une, '
                          'ta progression (années atteintes, échecs, missions), un identifiant technique, le modèle du téléphone et '
                          'son système, ainsi que ce que tu nous envoies toi-même (note, proposition). Rien n\'est vendu ni partagé. '
                          'Ces données servent à retrouver ta partie, au classement et à corriger les bugs.',
                          style: body,
                        ),
                        const SizedBox(height: 10),
                        GlassButton(
                          onTap: () async {
                            final id = await Telemetry.playerId();
                            final ok = await launchUrl(
                              Uri.parse(
                                'mailto:${AboutScreen.contactEmail}?subject=${Uri.encodeComponent('Supprimer mes données Chacha 243 ($id)')}',
                              ),
                            );
                            if (!ok) copy(AboutScreen.contactEmail, 'Adresse copiée');
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Demander la suppression de mes données', style: TextStyle(fontSize: 15)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AboutScreen.contactEmail,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5),
                        ),
                      ]),
                      if (appStoreRules)
                        section('Sources', const [
                          Text(
                            'Le jeu est gratuit. Les dates viennent de Wikipédia et de la presse congolaise. '
                            'Une erreur ? Signale-la depuis « Proposer une photo, une date ».',
                            style: body,
                          ),
                        ])
                      else
                        section('Sources et droits', const [
                          Text(
                            'Le jeu est gratuit. Les photos, les sons et les chansons ont été téléchargés librement sur Internet, '
                            'pour un usage gratuit : ils accompagnent le jeu, sans aucun usage commercial. '
                            'Les dates viennent de Wikipédia et de la presse congolaise. '
                            'Une erreur, une photo à retirer ? Propose ou signale-la depuis « Proposer une photo, une date ».',
                            style: body,
                          ),
                        ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le remerciement après un don : en lingala, avec un emoji de merci.
Future<void> showGiftThanks(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => SoftDialog(
    title: 'Matondo mingi ! 🙏',
    actions: [SoftButton('Ee, matondi', onTap: () => Navigator.of(context).pop())],
    children: [
      Text(
        'Matondo mingi mpo na lisungi na yo. Tosepeli 🙏',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 16, height: 1.4),
      ),
    ],
  ),
);

/// Les notes en lingala : de une à cinq étoiles, chacune avec son mot.
const _ratingWords = <String>['Na leli', 'Eza bien, kasi…', 'Eza malamu', 'Kitoko', 'Kitoko makasi'];

/// Noter l'application : de petites étoiles avec leur mot en lingala, un message, et un merci à la fin.
class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  final _comment = TextEditingController();
  int _stars = 0;
  bool _sending = false, _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Telemetry.myStars().then((n) {
      if (mounted && _stars == 0) setState(() => _stars = n);
    });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final ok = await Telemetry.sendRating(_stars, _comment.text.trim());
    if (!mounted) return;
    setState(() {
      _sending = false;
      _done = ok;
      if (!ok) _error = 'Internet ezali te : meka lisusu sima.';
    });
  }

  Widget _row(int n) {
    final on = n == _stars;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: on ? const Color(0x55CE1021) : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _stars = n),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= n ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 17,
                    color: i <= n ? ChachaColors.yellow : Colors.white30,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _ratingWords[n - 1],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: on ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ),
                if (on) const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return SoftDialog(
        title: 'Matondo mingi ! 🙏',
        actions: [
          if (_stars >= 4 && AboutScreen.storeUrl.isNotEmpty)
            SoftButton(
              'Google Play',
              quiet: true,
              onTap: () => launchUrl(Uri.parse(AboutScreen.storeUrl), mode: LaunchMode.externalApplication),
            ),
          SoftButton('Ee, matondi', onTap: () => Navigator.of(context).pop()),
        ],
        children: [
          Text(
            'Tosepeli na avis na yo. Matondo mingi 🙏',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 16, height: 1.4),
          ),
        ],
      );
    }
    return SoftDialog(
      title: 'Pesa note na yo',
      actions: [
        SoftButton('Tika', quiet: true, onTap: () => Navigator.of(context).pop()),
        SoftButton(_sending ? 'Ezali kokende…' : 'Tinda', onTap: _stars == 0 || _sending ? null : _send),
      ],
      children: [
        // Clavier ouvert : seule la note choisie reste, pour laisser la place d'écrire.
        for (var n = 1; n <= 5; n++)
          if (MediaQuery.viewInsetsOf(context).bottom == 0 ||
              (n == _stars && MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom >= 380))
            _row(n),
        const SizedBox(height: 6),
        TextField(
          controller: _comment,
          maxLength: 300,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white),
          decoration: softField('Koma message na yo (soki olingi)').copyWith(counterText: ''),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFFF9A9A), fontSize: 13)),
          ),
      ],
    );
  }
}

/// Proposer une date, une photo ou une chanson : tout part vers le tableau de bord, où elle est lue avant d'entrer dans le jeu.
class _ProposalDialog extends StatefulWidget {
  const _ProposalDialog();

  @override
  State<_ProposalDialog> createState() => _ProposalDialogState();
}

class _ProposalDialogState extends State<_ProposalDialog> {
  static const _kinds = {'date': 'Une date', 'photo': 'Une photo', 'song': 'Une chanson'};
  final _title = TextEditingController(), _happened = TextEditingController();
  final _link = TextEditingController(), _message = TextEditingController();
  String _kind = 'date';
  Uint8List? _image;
  bool _sending = false, _done = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _happened, _link, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (mounted) setState(() => _image = bytes);
    } catch (_) {}
  }

  bool get _ready =>
      _title.text.trim().length >= 3 &&
      (_message.text.trim().isNotEmpty || _link.text.trim().isNotEmpty || _image != null);

  Future<void> _send() async {
    final link = _link.text.trim();
    if (link.isNotEmpty && !RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(link)) {
      setState(() => _error = 'Le lien doit commencer par https://');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final code = await Telemetry.sendProposal(
      kind: _kind,
      title: _title.text.trim(),
      happened: _happened.text.trim(),
      link: link,
      message: _message.text.trim(),
      image: _kind == 'photo' ? _image : null,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _done = code == 204;
      if (code != 204) {
        _error = switch (code) {
          0 => 'Pas de connexion : réessaie plus tard.',
          429 => 'Tu as déjà envoyé plusieurs propositions : réessaie dans une heure.',
          _ => 'La proposition n\'est pas partie : vérifie le titre, le lien et la photo.',
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return SoftDialog(
        title: 'Matondo mingi ! 🙏',
        actions: [SoftButton('Fermer', onTap: () => Navigator.of(context).pop())],
        children: [
          Text(
            'Ta proposition est bien arrivée. On la lit, et si elle est juste, elle entre dans le jeu.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 16, height: 1.4),
          ),
        ],
      );
    }
    Widget field(TextEditingController c, String hint, {int lines = 1, int max = 120, TextInputType? type}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        maxLength: max,
        minLines: 1,
        maxLines: lines,
        keyboardType: type,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: Colors.white),
        decoration: softField(hint),
      ),
    );
    return SoftDialog(
      title: 'Proposer au jeu',
      actions: [
        SoftButton('Annuler', quiet: true, onTap: () => Navigator.of(context).pop()),
        SoftButton(_sending ? 'Envoi…' : 'Envoyer', onTap: _ready && !_sending ? _send : null),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final e in _kinds.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _kind == e.key,
                onSelected: (_) => setState(() => _kind = e.key),
                showCheckmark: false,
                selectedColor: const Color(0xFFCE1021),
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                side: BorderSide.none,
                labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
          ],
        ),
        const SizedBox(height: 10),
        field(_title, _kind == 'song' ? 'Titre et artiste' : 'Ce qui s\'est passé'),
        field(_happened, 'Date (ex. 30 juin 1960)', max: 60),
        field(_link, 'Lien : chanson, photo, article (https://…)', max: 300, type: TextInputType.url),
        if (_kind == 'photo')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SoftButton(_image == null ? 'Choisir une photo' : 'Changer la photo', onTap: _pick),
                const SizedBox(width: 12),
                if (_image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_image!, height: 56, width: 56, fit: BoxFit.cover),
                  ),
              ],
            ),
          ),
        field(_message, 'Ton message : pourquoi c\'est important', lines: 3, max: 800),
        if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFFF9A9A), fontSize: 13)),
      ],
    );
  }
}
