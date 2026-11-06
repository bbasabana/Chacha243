import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../theme/chacha_colors.dart';
import 'glass.dart';

/// Une nouvelle version sur Google Play : on la propose sans quitter le jeu.
///
/// Ne fait rien hors d'Android, ni quand l'application n'a pas été installée depuis Google Play.
Future<void> checkPlayUpdate(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable || !info.flexibleUpdateAllowed) return;
    if (!context.mounted) return;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const _UpdateDialog());
  } catch (_) {
    // Pas de Google Play sur ce téléphone, ou pas de réseau : on joue avec la version actuelle.
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog();

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  StreamSubscription<InstallStatus>? _listen;
  bool _working = false;
  String _step = '';

  @override
  void dispose() {
    _listen?.cancel();
    super.dispose();
  }

  Future<void> _update() async {
    setState(() {
      _working = true;
      _step = 'Téléchargement de la nouvelle version…';
    });
    _listen = InAppUpdate.installUpdateListener.listen((s) {
      if (!mounted) return;
      setState(
        () => _step = switch (s) {
          InstallStatus.downloading || InstallStatus.pending => 'Téléchargement de la nouvelle version…',
          InstallStatus.downloaded || InstallStatus.installing => 'Installation… le jeu va redémarrer.',
          InstallStatus.failed || InstallStatus.canceled => 'La mise à jour n\'a pas pu se faire.',
          _ => _step,
        },
      );
      if (s == InstallStatus.downloaded) InAppUpdate.completeFlexibleUpdate().catchError((_) {});
      if (s == InstallStatus.failed || s == InstallStatus.canceled) setState(() => _working = false);
    });
    try {
      final r = await InAppUpdate.startFlexibleUpdate();
      if (r != AppUpdateResult.success && mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Glass(
        tint: const Color(0x88001A40),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update_rounded, color: ChachaColors.yellow, size: 32),
            const SizedBox(height: 6),
            const Text(
              'Nouvelle version de Chacha243',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              _working
                  ? _step
                  : 'De nouveaux moments et des corrections t\'attendent. La mise à jour se fait ici, sans quitter le jeu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_working)
              const SizedBox(
                width: 220,
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: Color(0x33FFFFFF),
                  color: ChachaColors.yellow,
                ),
              )
            else
              Wrap(
                spacing: 10,
                children: [
                  GlassButton(
                    onTap: _update,
                    tint: const Color(0x66CE1021),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: const Text('Mettre à jour', style: TextStyle(fontSize: 15)),
                  ),
                  GlassButton(
                    onTap: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: const Text('Plus tard', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
