import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../widgets/address_balance.dart';
import '../widgets/gradient_button.dart';
import '../widgets/page_scaffold.dart';

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
  String? _selA; // selected escrow address for side A
  String? _selB;

  ExchangeEntry get entry => widget.entry;

  @override
  void initState() {
    super.initState();
    _selA = entry.addressA.isEmpty ? null : entry.addressA;
    _selB = entry.addressB.isEmpty ? null : entry.addressB;
    _editing = entry.addressA.isEmpty && entry.addressB.isEmpty;
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

  Future<void> _propose() async {
    setState(() => _proposing = true);
    final ok = await context.read<AppProvider>().proposeExchange(entry);
    if (!mounted) return;
    setState(() => _proposing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Invitations sent' : 'Nothing to invite / no pair'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
  }

  // ── Edit mode (pick from MY escrow accounts only) ──
  Widget _buildEdit(ThemeData theme) {
    final accounts = context.watch<AppProvider>().accounts;

    DropdownButtonFormField<String> picker(
        String label, String? value, ValueChanged<String?> onChanged) {
      // Include a legacy value not in accounts so it isn't silently dropped.
      final items = <DropdownMenuItem<String>>[
        for (final a in accounts)
          DropdownMenuItem(
            value: a.address,
            child: Text('${a.network.toUpperCase()} #${a.index} · '
                '${_short(a.address, head: 6, tail: 4)}'),
          ),
        if (value != null && !accounts.any((a) => a.address == value))
          DropdownMenuItem(value: value, child: Text(_short(value))),
      ];
      return DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: items,
        onChanged: onChanged,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
                'No escrow accounts yet — generate keys first, then link them here.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ),
        picker('Escrow A', _selA, (v) => setState(() => _selA = v)),
        const SizedBox(height: 10),
        picker('Escrow B', _selB, (v) => setState(() => _selB = v)),
        const SizedBox(height: 6),
        Text('Pick two of your escrow accounts. Each side\'s partner is taken '
            'from that account.',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _saving ? null : _cancel, child: const Text('Cancel')),
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

  void _cancel() {
    final isEmptyDraft = entry.addressA.isEmpty && entry.addressB.isEmpty;
    if (isEmptyDraft) {
      context.read<AppProvider>().removeExchange(entry.id);
      return;
    }
    setState(() {
      _selA = entry.addressA.isEmpty ? null : entry.addressA;
      _selB = entry.addressB.isEmpty ? null : entry.addressB;
      _editing = false;
    });
  }

  Future<void> _save() async {
    final a = _selA ?? '';
    final b = _selB ?? '';
    if (a.isEmpty || b.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick both escrow accounts')),
      );
      return;
    }
    if (a == b) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick two different accounts')),
      );
      return;
    }
    setState(() => _saving = true);
    final ok = await context.read<AppProvider>().updateExchange(entry.id, a, b);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editing = false;
    });
  }
}
