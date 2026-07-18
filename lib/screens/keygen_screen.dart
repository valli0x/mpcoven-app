import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../widgets/gradient_button.dart';

enum KeyType { ecdsa, frost }

class KeygenScreen extends StatefulWidget {
  const KeygenScreen({super.key});

  @override
  State<KeygenScreen> createState() => _KeygenScreenState();
}

class _KeygenScreenState extends State<KeygenScreen> {
  final _partnerController = TextEditingController();
  KeyType _selectedKeyType = KeyType.ecdsa;
  String? _selectedPartner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.refreshPairs();
      provider.refreshAccounts();
    });
  }

  @override
  void dispose() {
    _partnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final acceptedPairs = provider.pendingPairs == null
            ? <Pair>[]
            : [
                ...provider.pendingPairs!.incoming.where((p) => p.status == 'accepted'),
                ...provider.pendingPairs!.outgoing.where((p) => p.status == 'accepted'),
              ];
        final myAddr = provider.authAddress ?? '';

        return CustomScrollView(
          slivers: [
            const SliverAppBar(
              title: Text('Generate Shared Key'),
              centerTitle: true,
              pinned: false,
              floating: true,
              snap: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // My address card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_circle_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('You',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  myAddr.isEmpty ? '(not authenticated)' : myAddr,
                                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Protocol selector
                    Text('Protocol',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _KeyTypeCard(
                            title: 'ECDSA',
                            subtitle: 'Ethereum',
                            icon: Icons.diamond_outlined,
                            color: const Color(0xFF627EEA),
                            isSelected: _selectedKeyType == KeyType.ecdsa,
                            onTap: () => setState(() => _selectedKeyType = KeyType.ecdsa),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KeyTypeCard(
                            title: 'FROST',
                            subtitle: 'Bitcoin',
                            icon: Icons.currency_bitcoin,
                            color: const Color(0xFFF7931A),
                            isSelected: _selectedKeyType == KeyType.frost,
                            onTap: () => setState(() => _selectedKeyType = KeyType.frost),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Partner picker
                    Text('Partner',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (acceptedPairs.isNotEmpty) ...[
                      ...acceptedPairs.map((p) {
                        final addr = p.initiator.toLowerCase() == myAddr.toLowerCase()
                            ? p.partner
                            : p.initiator;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _PartnerTile(
                            address: addr,
                            isSelected: _selectedPartner == addr,
                            onTap: () => setState(() {
                              _selectedPartner = addr;
                              _partnerController.text = addr;
                            }),
                          ),
                        );
                      }),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: theme.colorScheme.tertiary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No accepted pairs yet. Go to Pairing tab and create a pair first.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),
                    GradientButton(
                      text: 'Generate Shared Wallet',
                      icon: Icons.auto_awesome,
                      isLoading: false,
                      gradientColors: _selectedKeyType == KeyType.ecdsa
                          ? [const Color(0xFF627EEA), const Color(0xFF8B5CF6)]
                          : [const Color(0xFFF7931A), const Color(0xFFEA580C)],
                      onPressed: acceptedPairs.isEmpty ? null : () => _generate(provider),
                    ),

                    // Active / finished keygen jobs (parallel-capable).
                    if (provider.keygenJobs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...provider.keygenJobs.map((job) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _KeygenJobCard(
                              job: job,
                              onDismiss: () => provider.removeKeygenJob(job),
                            ),
                          )),
                    ],

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt_outlined,
                              size: 18, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your partner will get a notification — they need to approve to complete keygen.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (provider.errorMessage != null && provider.state == AppState.error) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(
                        message: provider.errorMessage!,
                        onDismiss: provider.clearError,
                      ),
                    ],

                    // Clearance for the floating bottom navigation bar.
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generate(AppProvider provider) async {
    final partner = _partnerController.text.trim();
    if (partner.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a partner first'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Non-blocking: spins up a tracked job. The button stays available so you
    // can start another keygen (with a different partner/protocol) right away.
    await provider.startKeygen(
      protocol: _selectedKeyType == KeyType.ecdsa ? 'ecdsa' : 'frost',
      partnerAddress: partner,
    );
  }

}

class _KeygenJobCard extends StatelessWidget {
  final KeygenJob job;
  final VoidCallback onDismiss;

  const _KeygenJobCard({required this.job, required this.onDismiss});

  String _short(String a, {int head = 8, int tail = 6}) =>
      a.length <= head + tail + 3
          ? a
          : '${a.substring(0, head)}…${a.substring(a.length - tail)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = job.isEth ? const Color(0xFF627EEA) : const Color(0xFFF7931A);
    final proto = job.protocol == 'ecdsa' ? 'ECDSA' : 'FROST';

    Color borderColor;
    switch (job.status) {
      case KeygenJobStatus.running:
        borderColor = accent.withValues(alpha: 0.45);
        break;
      case KeygenJobStatus.done:
        borderColor = Colors.green.withValues(alpha: 0.55);
        break;
      case KeygenJobStatus.failed:
        borderColor = theme.colorScheme.error.withValues(alpha: 0.55);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _leading(theme, accent),
              const SizedBox(width: 14),
              Expanded(child: _text(theme)),
              _Chip(
                label: '$proto · ${job.network.toUpperCase()} #${job.index}',
                color: accent,
              ),
            ],
          ),
          if (job.status != KeygenJobStatus.done) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDismiss,
                icon: Icon(
                    job.status == KeygenJobStatus.failed
                        ? Icons.close
                        : Icons.cancel_outlined,
                    size: 18),
                label: Text(
                    job.status == KeygenJobStatus.failed ? 'Dismiss' : 'Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                      color: theme.colorScheme.error.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    final addr = job.resultAddress ?? '';
                    Clipboard.setData(ClipboardData(text: addr));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Address copied'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _leading(ThemeData theme, Color accent) {
    switch (job.status) {
      case KeygenJobStatus.running:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        );
      case KeygenJobStatus.done:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case KeygenJobStatus.failed:
        return Icon(Icons.error_outline, color: theme.colorScheme.error, size: 24);
    }
  }

  Widget _text(ThemeData theme) {
    final proto = job.protocol == 'ecdsa' ? 'ECDSA' : 'FROST';
    switch (job.status) {
      case KeygenJobStatus.running:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generating $proto key…',
                style:
                    theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Waiting for ${_short(job.partner)} to approve',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        );
      case KeygenJobStatus.done:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shared key created',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600, color: Colors.green)),
            const SizedBox(height: 2),
            Text(_short(job.resultAddress ?? '', head: 10, tail: 8),
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
          ],
        );
      case KeygenJobStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Keygen failed',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600, color: theme.colorScheme.error)),
            const SizedBox(height: 2),
            Text(job.error ?? 'Unknown error',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        );
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _KeyTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _KeyTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.15)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isSelected ? color : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 32,
                  color: isSelected ? color : theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(title,
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold, color: isSelected ? color : null)),
              Text(subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? color.withOpacity(0.8)
                          : theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer))),
          IconButton(icon: const Icon(Icons.close), onPressed: onDismiss),
        ],
      ),
    );
  }
}

class _PartnerTile extends StatelessWidget {
  final String address;
  final bool isSelected;
  final VoidCallback onTap;

  const _PartnerTile({
    required this.address,
    required this.isSelected,
    required this.onTap,
  });

  // Derive a deterministic colour pair from the address bytes.
  List<Color> _gradient() {
    final hex = address.toLowerCase().replaceFirst('0x', '');
    int parseByte(int offset) =>
        int.tryParse(hex.substring(offset, offset + 2), radix: 16) ?? 128;
    final h1 = parseByte(2);
    final h2 = parseByte(8);
    final h3 = parseByte(14);
    return [
      HSLColor.fromAHSL(1, (h1 * 360 / 255).clamp(0, 360), 0.55, 0.55).toColor(),
      HSLColor.fromAHSL(1, ((h2 + h3) * 360 / 510).clamp(0, 360), 0.6, 0.45)
          .toColor(),
    ];
  }

  String _short(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 8)}…${addr.substring(addr.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _gradient();
    final glow = colors.first;
    final alias = context.watch<AppProvider>().aliasFor(address);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? glow.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? glow.withValues(alpha: 0.7)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // gradient avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Partner',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      alias ?? _short(address),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: alias != null ? null : 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (alias != null)
                      Text(
                        _short(address),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedScale(
                scale: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: glow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
