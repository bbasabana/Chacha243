import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../theme/chacha_colors.dart';
import 'glass.dart';

/// À propos de Chacha243, et comment soutenir le projet.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // À remplir avant la sortie : les liens réels du projet.
  static const contactEmail = '';
  static const supportUrl = '';
  static const storeUrl = '';

  /// Le code du jeu, ouvert à tous.
  static const sourceUrl = 'https://github.com/bbasabana/Chacha243';

  /// La toute première version du jeu, publiée en 2014.
  static const firstVersionUrl = 'https://apkpure.com/chacha-243/com.overlookdev.BalloonDefense';

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
                            final ok = await launchUrl(Uri.parse(sourceUrl), mode: LaunchMode.externalApplication);
                            if (!ok) copy(sourceUrl, 'Lien copié');
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
                        Text(sourceUrl, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5)),
                      ]),
                      section('Depuis 2014', [
                        const Text(
                          'La première version, « Chacha 243 », a été développée en 2014. Douze ans plus tard, le jeu renaît : '
                          'nouveaux avions, nouvelles époques, et toute l\'histoire du pays jusqu\'en 2027.',
                          style: body,
                        ),
                        const SizedBox(height: 10),
                        GlassButton(
                          onTap: () async {
                            final ok = await launchUrl(
                              Uri.parse(firstVersionUrl),
                              mode: LaunchMode.externalApplication,
                            );
                            if (!ok) copy(firstVersionUrl, 'Lien copié');
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
                          firstVersionUrl,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5),
                        ),
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
                              onTap: () => copy(
                                'Apprends l\'histoire du Congo en pilotant l\'avion de 1960 à 2027 : Chacha243 ! $storeUrl'
                                    .trim(),
                                'Message copié : colle-le où tu veux le partager',
                              ),
                              tint: const Color(0x55CE1021),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.share_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Partager le jeu', style: TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                            GlassButton(
                              onTap: storeUrl.isEmpty ? null : () => copy(storeUrl, 'Lien copié'),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Noter l\'application', style: TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                            GlassButton(
                              onTap: supportUrl.isEmpty ? null : () => copy(supportUrl, 'Lien copié'),
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
                              onTap: contactEmail.isEmpty ? null : () => copy(contactEmail, 'Adresse copiée'),
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
                          supportUrl.isEmpty ? 'Les liens de don et de contact arrivent bientôt.' : '',
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
                      ]),
                      section('Sources et droits', const [
                        Text(
                          'Les dates viennent de Wikipédia et de la presse congolaise ; elles sont relues par des historiens avant '
                          'chaque version. Les phrases en lingala sont relues par des locuteurs. Les photos d\'archives et les '
                          'chansons ne sont publiées qu\'avec l\'accord de leurs ayants droit.',
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
