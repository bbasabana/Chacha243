import 'package:flutter/material.dart';

import '../theme/chacha_colors.dart';

/// La fenêtre douce du jeu : un fond bleu nuit, des bords tout ronds, un titre, et un contenu qui défile
/// quand l'écran est petit (téléphone couché, clavier ouvert). Elle s'adapte du petit téléphone à la tablette.
class SoftDialog extends StatelessWidget {
  const SoftDialog({super.key, required this.title, required this.children, this.actions = const []});

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Clavier ouvert sur un écran bas (téléphone couché) : on cache le titre pour laisser la place d'écrire.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final tight = keyboard > 0 && size.height - keyboard < 380;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: size.width < 420 ? 12 : 24, vertical: tight ? 4 : 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size.width >= 700 ? 520 : 460, maxHeight: size.height * 0.94),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF16336F), ChachaColors.night],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: const [BoxShadow(color: Color(0x66000814), blurRadius: 30, offset: Offset(0, 12))],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, tight ? 10 : 18, 20, tight ? 8 : 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!tight) ...[
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                ],
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 8), actions[i]],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le bouton principal d'une fenêtre douce : rouge, tout rond.
class SoftButton extends StatelessWidget {
  const SoftButton(this.label, {super.key, this.onTap, this.quiet = false});

  final String label;
  final VoidCallback? onTap;

  /// Un bouton discret (« Tika ») : sans fond.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: Material(
        color: quiet ? Colors.transparent : const Color(0xFFCE1021),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            child: Text(
              label,
              style: TextStyle(color: quiet ? Colors.white70 : Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le champ de texte des fenêtres douces : un voile clair, sans trait dur.
InputDecoration softField(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Colors.white54),
  filled: true,
  fillColor: Colors.white.withValues(alpha: 0.09),
  isDense: true,
  counterStyle: const TextStyle(color: Colors.white38),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
  ),
);
