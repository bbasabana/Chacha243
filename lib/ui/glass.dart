import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/chacha_colors.dart';

/// Une plaque de verre flouté qui laisse voir le ciel derrière elle.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.tint = ChachaColors.glassFill,
    this.blur = 18,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color tint;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: const [BoxShadow(color: ChachaColors.glassShadow, blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(tint, Colors.white, 0.25)!, tint, tint.withValues(alpha: tint.a * 0.6)],
              ),
              border: Border.all(color: ChachaColors.glassEdge, width: 1.2),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Un bouton en verre qui s'enfonce comme une goutte quand on appuie.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.onPressChanged,
    this.radius = 22,
    this.padding = const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
    this.tint = ChachaColors.glassFill,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Appelé à l'appui et au relâchement (bouton des gaz maintenu).
  final ValueChanged<bool>? onPressChanged;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color tint;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
    widget.onPressChanged?.call(down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onPressChanged != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.93 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: Glass(
            radius: widget.radius,
            padding: widget.padding,
            tint: _down ? Color.lerp(widget.tint, Colors.white, 0.3)! : widget.tint,
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
