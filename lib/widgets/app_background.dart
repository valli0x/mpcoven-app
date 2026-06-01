import 'package:flutter/material.dart';

/// Full-screen decorative background. Use inside a Stack with Positioned.fill.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0B0E1A),
                    const Color(0xFF131729),
                    const Color(0xFF0E1322),
                  ]
                : [
                    scheme.surface,
                    scheme.primaryContainer.withValues(alpha: 0.25),
                    scheme.surface,
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -80,
              child: _GlowOrb(
                color:
                    const Color(0xFF627EEA).withValues(alpha: isDark ? 0.18 : 0.20),
                size: 320,
              ),
            ),
            Positioned(
              bottom: -100,
              right: -100,
              child: _GlowOrb(
                color:
                    const Color(0xFFF7931A).withValues(alpha: isDark ? 0.10 : 0.14),
                size: 280,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
