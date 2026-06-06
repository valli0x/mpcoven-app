import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../widgets/address_balance.dart';
import 'balance_screen.dart';
import 'notifications_screen.dart';
import 'tx_screen.dart';

const _kEth = Color(0xFF627EEA);
const _kBtc = Color(0xFFF7931A);

String _short(String s, {int head = 6, int tail = 6}) {
  if (s.length <= head + tail + 3) return s;
  return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
}

/// Ensure an ETH address is shown with the 0x prefix (party IDs are stored
/// normalized without it).
String _withHex(String addr) {
  final a = addr.trim();
  if (a.isEmpty) return a;
  return a.toLowerCase().startsWith('0x') ? a : '0x$a';
}

/// Compare two addresses ignoring 0x prefix and case.
bool _addrEq(String a, String b) =>
    a.toLowerCase().replaceFirst('0x', '') ==
    b.toLowerCase().replaceFirst('0x', '');

/// Deterministic gradient from an address (same idea as the keygen partner tile).
List<Color> _avatarGradient(String address) {
  final hex = address.toLowerCase().replaceFirst('0x', '');
  int byteAt(int o) {
    if (hex.length < o + 2) return 128;
    return int.tryParse(hex.substring(o, o + 2), radix: 16) ?? 128;
  }

  final h1 = (byteAt(0) / 255.0) * 360.0;
  final h2 = (byteAt(2) / 255.0) * 360.0;
  return [
    HSLColor.fromAHSL(1, h1, 0.6, 0.55).toColor(),
    HSLColor.fromAHSL(1, h2, 0.6, 0.40).toColor(),
  ];
}

class AccountsScreen extends StatefulWidget {
  final VoidCallback onSettingsPressed;

  const AccountsScreen({super.key, required this.onSettingsPressed});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  bool _loading = false;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await context.read<AppProvider>().refreshAccounts();
    if (mounted) setState(() => _loading = false);
  }

  /// Group accounts by partner address. Returns ordered list of (partner, items).
  List<MapEntry<String, List<AccountMeta>>> _grouped(List<AccountMeta> accounts) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? accounts
        : accounts.where((a) {
            return a.address.toLowerCase().contains(q) ||
                (a.pairOther ?? '').toLowerCase().contains(q) ||
                a.network.toLowerCase().contains(q) ||
                '${a.network}#${a.index}'.toLowerCase().contains(q);
          }).toList();

    final map = <String, List<AccountMeta>>{};
    for (final a in filtered) {
      final key = (a.pairOther ?? 'unknown').toLowerCase();
      map.putIfAbsent(key, () => []).add(a);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in entries) {
      e.value.sort((x, y) {
        if (x.network != y.network) return x.network.compareTo(y.network);
        return x.index.compareTo(y.index);
      });
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final accounts = provider.accounts;
        final groups = _grouped(accounts);

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Signature Escrow'),
              centerTitle: true,
              pinned: false,
              floating: true,
              snap: true,
              actions: [
                _NotificationsBell(messageCount: provider.messages.length),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: widget.onSettingsPressed,
                  tooltip: 'Settings',
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.secondaryContainer,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.security_rounded, size: 64, color: theme.colorScheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            '2-of-2 MPC Wallet',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Shared ETH & BTC accounts via ECDSA and FROST protocols',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'Accounts',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (accounts.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${accounts.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const Spacer(),
                        IconButton(
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          onPressed: _loading ? null : _refresh,
                        ),
                      ],
                    ),
                    if (accounts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search address or partner…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (accounts.isEmpty && !_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.wallet_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'No accounts yet',
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Go to Keygen tab to create shared keys',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              )
            else if (groups.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'Nothing matches "$_query"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final group = groups[index];
                    return _PartnerGroup(
                      partner: group.key,
                      accounts: group.value,
                      initiallyExpanded: groups.length == 1 || _query.isNotEmpty,
                    );
                  },
                  childCount: groups.length,
                ),
              ),
            // Bottom padding so the floating nav bar never covers the last card.
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }
}

/// A collapsible "folder" of accounts shared with one partner.
class _PartnerGroup extends StatefulWidget {
  final String partner;
  final List<AccountMeta> accounts;
  final bool initiallyExpanded;

  const _PartnerGroup({
    required this.partner,
    required this.accounts,
    required this.initiallyExpanded,
  });

  @override
  State<_PartnerGroup> createState() => _PartnerGroupState();
}

class _PartnerGroupState extends State<_PartnerGroup> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grad = _avatarGradient(widget.partner);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          // Folder header (partner)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: grad),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.folder_shared_outlined,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Partner · Ethereum',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _short(_withHex(widget.partner), head: 10, tail: 8),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.accounts.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz,
                          color: theme.colorScheme.onSurfaceVariant, size: 20),
                      tooltip: 'Partner actions',
                      color: theme.colorScheme.surfaceContainerHigh,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                        ),
                      ),
                      onSelected: (v) {
                        if (v == 'delete') _confirmDelete(context);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  color: theme.colorScheme.error, size: 19),
                              const SizedBox(width: 12),
                              Text('Delete pair & accounts',
                                  style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Accounts
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: [
                Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                ...widget.accounts.map((a) => _AccountRow(account: a)),
                const SizedBox(height: 6),
              ],
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        bool matches = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void check(String v) =>
                setLocal(() => matches = _addrEq(v, widget.partner));
            return AlertDialog(
              title: const Text('Delete shared accounts?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This permanently deletes your key share for '
                    '${widget.accounts.length} shared account(s) with this partner. '
                    'It cannot be undone — make sure any balances are withdrawn first.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text('Type the partner address to confirm:',
                      style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  SelectableText(
                    _withHex(widget.partner),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: check,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '0x… address',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: matches ? () => Navigator.pop(ctx, true) : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !context.mounted) return;
    final ok = await provider.deleteAccountsWithPartner(widget.partner);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Accounts deleted'
            : 'Some accounts could not be deleted (client offline?)'),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ),
    );
  }

}

class _AccountRow extends StatelessWidget {
  final AccountMeta account;

  const _AccountRow({required this.account});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEth = account.network == 'eth';
    final color = isEth ? _kEth : _kBtc;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showActions(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEth ? Icons.diamond_outlined : Icons.currency_bitcoin,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${account.network.toUpperCase()} #${account.index}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _short(account.address, head: 8, tail: 8),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AddressBalance(
                      address: account.address,
                      network: account.network,
                      accent: color,
                      // Accounts: refresh only on the button.
                      autoRefresh: false,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 18, color: color.withOpacity(0.7)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: account.address));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final isEth = account.network == 'eth';
    final color = isEth ? _kEth : _kBtc;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            // Float the sheet off the edges so all corners are rounded.
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEth ? Icons.diamond_outlined : Icons.currency_bitcoin,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${account.network.toUpperCase()} #${account.index}',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _short(account.address, head: 8, tail: 8),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                          if (account.pairOther != null)
                            Text(
                              'with ${_short(_withHex(account.pairOther!), head: 8, tail: 6)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _ActionTile(
                  icon: Icons.account_balance_wallet_outlined,
                  color: color,
                  label: 'Check Balance',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BalanceScreen(
                          prefillAddress: account.address,
                          prefillNetwork: account.network),
                    ));
                  },
                ),
                _ActionTile(
                  icon: Icons.send_rounded,
                  color: color,
                  label: 'Send Transaction',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TxScreen(account: account),
                    ));
                  },
                ),
                const SizedBox(height: 4),
                _ActionTile(
                  icon: Icons.delete_outline,
                  color: theme.colorScheme.error,
                  label: 'Delete this account',
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteSingle(context);
                  },
                ),
              ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteSingle(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text('Delete ${account.network.toUpperCase()} #${account.index}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes your key share for this single '
                'account. It cannot be undone — make sure the balance is '
                'withdrawn first.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SelectableText(
                account.address,
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await provider.deleteSingleAccount(account);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Account deleted' : 'Could not delete account'),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsBell extends StatelessWidget {
  final int messageCount;

  const _NotificationsBell({required this.messageCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(messageCount > 0
              ? Icons.notifications_active
              : Icons.notifications_outlined),
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        ),
        if (messageCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                messageCount > 9 ? '9+' : '$messageCount',
                style: const TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
