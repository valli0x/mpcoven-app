import 'package:flutter/material.dart';
import 'app_background.dart';

/// Scaffold with the app gradient background and a centered max-width body.
/// Renders its own transparent header (no AppBar) so the gradient flows
/// from the very top of the screen.
class PageScaffold extends StatelessWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget body;
  final double maxWidth;
  final bool showBackButton;

  /// Draw the gradient AppBackground. Set false when the parent already
  /// provides one (e.g. a tab inside HomeScreen) to avoid a doubled background.
  final bool withBackground;

  const PageScaffold({
    super.key,
    this.title,
    this.actions,
    required this.body,
    this.maxWidth = 720,
    this.showBackButton = true,
    this.withBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          if (withBackground) const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Column(
              children: [
                if (title != null)
                  _Header(
                    title: title!,
                    actions: actions,
                    showBackButton: showBackButton,
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  const _Header({
    required this.title,
    this.actions,
    required this.showBackButton,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          if (showBackButton && canPop)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actions != null) ...actions! else const SizedBox(width: 48),
        ],
      ),
    );
  }
}
