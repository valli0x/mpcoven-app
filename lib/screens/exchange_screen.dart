import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/units.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../widgets/address_balance.dart';
import '../widgets/gradient_button.dart';
import '../widgets/page_scaffold.dart';
import 'tx_screen.dart';

const _kEth = Color(0xFF627EEA);
const _kBtc = Color(0xFFF7931A);

String _short(String s, {int head = 8, int tail = 6}) {
  if (s.length <= head + tail + 3) return s;
  return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
}

bool _looksEth(String a) => a.trim().toLowerCase().startsWith('0x');

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadExchanges();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final exchanges = provider.exchanges;
        return PageScaffold(
          title: 'Exchange',
          showBackButton: false,
          // HomeScreen already paints the gradient; avoid a doubled background.
          withBackground: false,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: GradientButton(
                  text: 'New Exchange',
                  icon: Icons.add,
                  isLoading: _creating,
                  gradientColors: const [Color(0xFF627EEA), Color(0xFFF7931A)],
                  onPressed: () => _create(provider),
                ),
              ),
              Expanded(
                child: exchanges.isEmpty
                    ? _empty(context)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        itemCount: exchanges.length,
                        itemBuilder: (_, i) => _ExchangeCard(
                          key: ValueKey(exchanges[i].id),
                          entry: exchanges[i],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _create(AppProvider provider) async {
    setState(() => _creating = true);
    await provider.addExchange();
    if (mounted) setState(() => _creating = false);
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF627EEA), Color(0xFFF7931A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  color: Colors.white, size: 38),
            ),
            const SizedBox(height: 20),
            Text('No exchanges yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Tap “New Exchange”, then paste two addresses and save.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}


class _ExchangeCard extends StatefulWidget {
  final ExchangeEntry entry;
  const _ExchangeCard({super.key, required this.entry});

  @override
  State<_ExchangeCard> createState() => _ExchangeCardState();
}

class _ExchangeCardState extends State<_ExchangeCard> {
  late bool _editing;
  bool _saving = false;
  bool _proposing = false;
  late final TextEditingController _aCtrl;
  late final TextEditingController _bCtrl;

  ExchangeEntry get entry => widget.entry;

  @override
  void initState() {
    super.initState();
    _aCtrl = TextEditingController(text: entry.addressA);
    _bCtrl = TextEditingController(text: entry.addressB);
    _editing = entry.addressA.isEmpty && entry.addressB.isEmpty;
  }

  @override
  void dispose() {
    _aCtrl.dispose();
    _bCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _editing ? _buildEdit(theme) : _buildView(theme),
      ),
    );
  }

  // ── View mode ──
  Widget _buildView(ThemeData theme) {
    final provider = context.watch<AppProvider>();
    final pA = provider.escrowPartnerAddress(entry.addressA);
    final pB = provider.escrowPartnerAddress(entry.addressB);
    final canInvite = (pA.isNotEmpty && entry.statusA != 'accepted') ||
        (pB.isNotEmpty && entry.statusB != 'accepted');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sideRow(theme, provider, entry.addressA, pA, entry.statusA),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(Icons.swap_vert_rounded,
                          size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text('exchange',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                  _sideRow(theme, provider, entry.addressB, pB, entry.statusB),
                ],
              ),
            ),
            Column(children: [
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 19, color: theme.colorScheme.primary),
                onPressed: () => setState(() => _editing = true),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 19, color: theme.colorScheme.error),
                onPressed: () => provider.removeExchange(entry.id),
                tooltip: 'Delete',
              ),
            ]),
          ],
        ),
        if (canInvite) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _proposing ? null : _propose,
              icon: _proposing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined, size: 18),
              label: const Text('Send invitations'),
            ),
          ),
        ],
        // Once a side is accepted, you can run the atomic-swap withdrawal via
        // escrow. Both parties do this; escrow releases each their own sig.
        if (entry.statusA == 'accepted' || entry.statusB == 'accepted') ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.account_balance_outlined, size: 18),
              label: const Text('Withdraw via escrow (swap)'),
              onPressed: () => _withdrawViaEscrow(provider),
            ),
          ),
        ],
      ],
    );
  }

  /// One escrow side: address + balance + its partner + per-side status.
  Widget _sideRow(ThemeData theme, AppProvider provider, String addr,
      String partner, String status) {
    if (addr.isEmpty) {
      return Text('(not set)',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    final isEth = _looksEth(addr);
    final color = isEth ? _kEth : _kBtc;
    final addrAlias = provider.aliasFor(addr);
    final isMine = provider.escrowAccountFor(addr) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(isEth ? Icons.diamond_outlined : Icons.currency_bitcoin,
                color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: SelectableText(addrAlias ?? _short(addr, head: 10, tail: 8),
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: addrAlias != null ? null : 'monospace',
                    fontWeight: FontWeight.w500)),
          ),
          _copyBtn(theme, color, addr, 'Address copied'),
          IconButton(
            icon: Icon(Icons.info_outline, size: 16, color: color),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Details',
            onPressed: () =>
                _showEscrowDetails(theme, provider, addr, partner, color),
          ),
          const Spacer(),
        ]),
        // Partner of this escrow + per-side status.
        Padding(
          padding: const EdgeInsets.only(left: 42, top: 2),
          child: Row(children: [
            if (!isMine)
              Flexible(
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 13, color: Colors.orange),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text('not in your accounts',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.orange)),
                  ),
                ]),
              )
            else if (partner.isNotEmpty) ...[
              Text('partner ',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              Flexible(
                child: SelectableText(
                    provider.aliasFor(partner) ??
                        _short(partner, head: 6, tail: 4),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontFamily: provider.aliasFor(partner) != null
                            ? null
                            : 'monospace')),
              ),
              _copyBtn(theme, color, partner, 'Partner copied', size: 13),
            ],
            const SizedBox(width: 8),
            _statusChip(theme, status),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 42, top: 2, bottom: 2),
          child:
              AddressBalance(address: addr, accent: color, autoRefresh: true),
        ),
      ],
    );
  }

  Widget _copyBtn(ThemeData theme, Color color, String text, String toast,
      {double size = 16}) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toast)),
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(Icons.copy_rounded,
            size: size, color: color.withValues(alpha: 0.8)),
      ),
    );
  }

  void _showEscrowDetails(ThemeData theme, AppProvider provider, String addr,
      String partner, Color color) {
    final acc = provider.escrowAccountFor(addr);
    // Requested transactions for this escrow: co-sign events whose escrow
    // address matches, or that belong to THIS exchange's swap (escrow_id).
    provider.loadCosignHistory();
    List<CosignEvent> eventsFor() => provider.cosignHistory
        .where((e) =>
            e.escrow.toLowerCase() == addr.toLowerCase() ||
            (e.escrowId.isNotEmpty && e.escrowId == entry.id))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final t = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.7),
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: t.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Icon(Icons.receipt_long_outlined, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      acc != null
                          ? 'Requests — ${acc.network.toUpperCase()} #${acc.index}'
                          : 'Requested transactions',
                      style: t.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(_short(addr, head: 10, tail: 8),
                    style: t.textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Flexible(
                  child: Consumer<AppProvider>(
                    builder: (_, p, __) {
                      final events = eventsFor()
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      if (events.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('No transaction requests for this account yet',
                              style: t.textTheme.bodySmall?.copyWith(
                                  color: t.colorScheme.onSurfaceVariant)),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _txRequestCard(t, color, events[i]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close')),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _txRequestCard(ThemeData t, Color color, CosignEvent e) {
    String amt = '';
    try {
      amt = '${Units.fromBase(BigInt.parse(e.amount), e.network)} '
          '${Units.symbol(e.network)}';
    } catch (_) {}
    Widget kv(IconData ic, String label, String value, {String? copy}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Icon(ic, size: 14, color: color.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
            Text(label,
                style: t.textTheme.labelSmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const Spacer(),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            if (copy != null && copy.isNotEmpty) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: copy));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Copied'),
                      duration: Duration(seconds: 2)));
                },
                child: Icon(Icons.copy_rounded,
                    size: 13, color: t.colorScheme.onSurfaceVariant),
              ),
            ],
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _roleChip(t, e.role),
          const SizedBox(width: 6),
          _cosignStatusChip(t, e.status),
        ]),
        const SizedBox(height: 6),
        if (e.to.isNotEmpty)
          kv(Icons.send_outlined, 'To', _short(e.to, head: 8, tail: 6),
              copy: e.to),
        if (amt.isNotEmpty) kv(Icons.payments_outlined, 'Amount', amt),
        if (e.hash.isNotEmpty)
          kv(Icons.tag, 'Hash', _short(e.hash, head: 8, tail: 6), copy: e.hash),
        if (e.txHash.isNotEmpty)
          kv(Icons.link, 'Tx', _short(e.txHash, head: 8, tail: 6),
              copy: e.txHash),
      ]),
    );
  }

  Widget _cosignStatusChip(ThemeData t, String status) {
    Color c;
    switch (status) {
      case 'completed':
      case 'broadcast':
        c = Colors.green;
        break;
      case 'sent':
      case 'escrow-await':
        c = Colors.orange;
        break;
      case 'failed':
        c = Colors.red;
        break;
      default:
        c = t.colorScheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.isEmpty ? '—' : status,
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _roleChip(ThemeData t, String role) {
    final c = role == 'initiator'
        ? _kEth
        : role == 'acceptor'
            ? Colors.green
            : t.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(role.isEmpty ? '—' : role,
          style: t.textTheme.labelSmall
              ?.copyWith(color: c, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusChip(ThemeData theme, String status) {
    late Color c;
    late String label;
    switch (status) {
      case 'invited':
        c = Colors.orange;
        label = 'invited';
        break;
      case 'accepted':
        c = Colors.green;
        label = 'accepted';
        break;
      default:
        c = theme.colorScheme.onSurfaceVariant;
        label = 'not invited';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  /// Pick which escrow account in this exchange to withdraw from (the one the
  /// Withdraw from MY assigned escrow only (creator → A, partner → B). No
  /// picker — both parties can't pick the same account.
  Future<void> _withdrawViaEscrow(AppProvider provider) async {
    final myAddr = provider.myExchangeWithdrawAddress(entry);
    if (myAddr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This exchange has no creator set — re-save it first')));
      return;
    }
    final account = provider.escrowAccountFor(myAddr);
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Your assigned escrow ${_short(myAddr)} is not one of your accounts')));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TxScreen(
        account: account,
        initialViaEscrow: true,
        escrowId: entry.id,
      ),
    ));
  }

  Future<void> _propose() async {
    final provider = context.read<AppProvider>();
    setState(() => _proposing = true);
    final ok = await provider.proposeExchange(entry);
    if (!mounted) return;
    setState(() => _proposing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Invitations sent'
          : (provider.errorMessage ?? 'Nothing to invite / no pair')),
      backgroundColor: ok ? Colors.green : Colors.red,
      duration: Duration(seconds: ok ? 3 : 7),
    ));
  }

  // ── Edit mode: paste/type the escrow address, with validation + search ──
  Widget _buildEdit(ThemeData theme) {
    final provider = context.watch<AppProvider>();

    Widget field(String label, TextEditingController ctrl) {
      final val = ctrl.text.trim();
      final acc = val.isEmpty ? null : provider.escrowAccountFor(val);
      Widget? hint;
      if (val.isNotEmpty) {
        hint = acc != null
            ? Row(children: [
                const Icon(Icons.check_circle, size: 13, color: Colors.green),
                const SizedBox(width: 4),
                Text('${acc.network.toUpperCase()} #${acc.index} · in your accounts',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.green)),
              ])
            : Row(children: [
                Icon(Icons.warning_amber_rounded,
                    size: 13, color: Colors.orange),
                const SizedBox(width: 4),
                Text('not one of your escrow accounts',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.orange)),
              ]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              labelText: label,
              hintText: '0x… / bc1…  (paste address)',
              isDense: true,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, size: 20),
                tooltip: 'Find my account',
                onPressed: () => _pickAccount(ctrl),
              ),
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: hint,
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field('Escrow A — YOU withdraw', _aCtrl),
        const SizedBox(height: 10),
        field('Escrow B — PARTNER withdraws', _bCtrl),
        const SizedBox(height: 6),
        Text('A is the account you withdraw from; B is your partner\'s. Paste '
            'each escrow address (or 🔍 to search). Each account is bound to one '
            'withdrawer — you can\'t both pull the same one.',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
                onPressed: _saving ? null : _cancel,
                child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  /// Searchable picker over MY accounts (handles hundreds without scrolling).
  Future<void> _pickAccount(TextEditingController target) async {
    final provider = context.read<AppProvider>();
    final accounts = provider.accounts;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final search = ValueNotifier<String>('');
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => search.value = v.toLowerCase(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by name / address / ETH #1…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Flexible(
                  child: ValueListenableBuilder<String>(
                    valueListenable: search,
                    builder: (_, q, __) {
                      final items = accounts.where((a) {
                        if (q.isEmpty) return true;
                        final label = '${a.network} #${a.index}'.toLowerCase();
                        final partner =
                            provider.escrowPartnerAddress(a.address);
                        final partnerName =
                            (provider.aliasFor(partner) ?? '').toLowerCase();
                        return a.address.toLowerCase().contains(q) ||
                            label.contains(q) ||
                            partner.toLowerCase().contains(q) ||
                            partnerName.contains(q);
                      }).toList();
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final a = items[i];
                          final isEth = a.network == 'eth';
                          final partner =
                              provider.escrowPartnerAddress(a.address);
                          final partnerName = provider.aliasFor(partner);
                          return ListTile(
                            leading: Icon(
                                isEth
                                    ? Icons.diamond_outlined
                                    : Icons.currency_bitcoin,
                                color: isEth ? _kEth : _kBtc),
                            title: Row(
                              children: [
                                Text('${a.network.toUpperCase()} #${a.index}'),
                                if (partner.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '· ${partnerName ?? _short(partner, head: 6, tail: 4)}',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: partnerName != null
                                            ? _kEth
                                            : Theme.of(ctx)
                                                .colorScheme
                                                .onSurfaceVariant,
                                        fontWeight: partnerName != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(_short(a.address, head: 10, tail: 8),
                                style:
                                    const TextStyle(fontFamily: 'monospace')),
                            onTap: () => Navigator.pop(ctx, a.address),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => target.text = picked);
    }
  }

  void _cancel() {
    final isEmptyDraft = entry.addressA.isEmpty && entry.addressB.isEmpty;
    if (isEmptyDraft) {
      context.read<AppProvider>().removeExchange(entry.id);
      return;
    }
    setState(() {
      _aCtrl.text = entry.addressA;
      _bCtrl.text = entry.addressB;
      _editing = false;
    });
  }

  Future<void> _save() async {
    final a = _aCtrl.text.trim();
    final b = _bCtrl.text.trim();
    if (a.isEmpty || b.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both escrow addresses')),
      );
      return;
    }
    if (a.toLowerCase() == b.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use two different accounts')),
      );
      return;
    }
    final provider = context.read<AppProvider>();
    final missing = <String>[
      if (provider.escrowAccountFor(a) == null) 'A',
      if (provider.escrowAccountFor(b) == null) 'B',
    ];
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Address ${missing.join(' & ')} is not one of your escrow accounts'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _saving = true);
    final ok = await provider.updateExchange(entry.id, a, b);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editing = false;
    });
  }
}
