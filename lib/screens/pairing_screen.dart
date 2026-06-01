import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../widgets/gradient_button.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _partnerController = TextEditingController();
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshPairs();
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
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Pairing'),
              centerTitle: true,
              pinned: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  onPressed: () => _confirmLogout(context, provider),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Authenticated user banner
                    if (provider.authAddress != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Signed in as',
                                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.green)),
                                  Text(
                                    provider.authAddress!,
                                    style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: provider.authAddress!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Address copied')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Icon(Icons.person_add_alt_1_outlined, color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text('Create New Pair',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _partnerController,
                      decoration: const InputDecoration(
                        hintText: '0x... (partner ETH address)',
                        prefixIcon: Icon(Icons.person_outline),
                        labelText: 'Partner Address',
                      ),
                    ),
                    const SizedBox(height: 12),
                    GradientButton(
                      text: 'Send Pair Request',
                      icon: Icons.group_add,
                      isLoading: provider.isLoading,
                      onPressed: () => _createPair(provider),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Icon(Icons.people_outline, color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text('Pending Pairs',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          icon: _refreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh, size: 20),
                          onPressed: _refreshing ? null : () => _refreshPairs(provider),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (provider.pendingPairs == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      if (provider.pendingPairs!.incoming.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Incoming',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.green, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        ...provider.pendingPairs!.incoming.map((p) => _PairTile(
                              pair: p,
                              isIncoming: true,
                              onAccept: () => _acceptPair(provider, p.id),
                            )),
                      ],
                      if (provider.pendingPairs!.outgoing.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Outgoing',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF627EEA), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        ...provider.pendingPairs!.outgoing
                            .map((p) => _PairTile(pair: p, isIncoming: false)),
                      ],
                      if (provider.pendingPairs!.incoming.isEmpty &&
                          provider.pendingPairs!.outgoing.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 48,
                                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                              const SizedBox(height: 8),
                              Text('No pending pairs',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                    ],

                    if (provider.errorMessage != null && provider.state == AppState.error) ...[
                      const SizedBox(height: 16),
                      Container(
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
                              child: Text(provider.errorMessage!,
                                  style:
                                      TextStyle(color: theme.colorScheme.onErrorContainer)),
                            ),
                            IconButton(
                                icon: const Icon(Icons.close), onPressed: provider.clearError),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createPair(AppProvider provider) async {
    final partner = _partnerController.text.trim();
    if (partner.isEmpty) return;
    final result = await provider.createPair(partner);
    if (result != null && mounted) {
      _partnerController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pair request sent'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _acceptPair(AppProvider provider, String pairId) async {
    await provider.acceptPair(pairId);
    if (mounted && provider.state == AppState.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pair accepted'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _refreshPairs(AppProvider provider) async {
    setState(() => _refreshing = true);
    await provider.refreshPairs();
    if (mounted) setState(() => _refreshing = false);
  }

  void _confirmLogout(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will need to sign in again to use the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _PairTile extends StatelessWidget {
  final Pair pair;
  final bool isIncoming;
  final VoidCallback? onAccept;

  const _PairTile({required this.pair, required this.isIncoming, this.onAccept});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncoming
              ? Colors.green.withOpacity(0.1)
              : const Color(0xFF627EEA).withOpacity(0.1),
          child: Icon(
            isIncoming ? Icons.call_received : Icons.call_made,
            color: isIncoming ? Colors.green : const Color(0xFF627EEA),
            size: 20,
          ),
        ),
        title: Text(
          isIncoming ? pair.initiator : pair.partner,
          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(pair.status),
        trailing: isIncoming && pair.status == 'pending'
            ? FilledButton(onPressed: onAccept, child: const Text('Accept'))
            : null,
      ),
    );
  }
}
