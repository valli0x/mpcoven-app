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
  late final TextEditingController _aCtrl;
  late final TextEditingController _bCtrl;
  late bool _editing;
  bool _saving = false;
  bool _proposing = false;

  @override
  void initState() {
    super.initState();
    _aCtrl = TextEditingController(text: widget.entry.addressA);
    _bCtrl = TextEditingController(text: widget.entry.addressB);
    // New drafts (both empty) open straight in edit mode.
    _editing = widget.entry.addressA.isEmpty && widget.entry.addressB.isEmpty;
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
        // Translucent surface so the app gradient tints the card, matching the
        // keygen/balance cards (instead of an opaque near-black panel).
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
    final entry = widget.entry;
    final hasAddrs = entry.addressA.isNotEmpty && entry.addressB.isNotEmpty;
    final canPropose = entry.status == 'draft' && hasAddrs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Partner + status header
        Row(
          children: [
            if (entry.partner.isNotEmpty) ...[
              Icon(Icons.person_outline,
                  size: 15, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('with ${_short(entry.partner, head: 8, tail: 6)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace')),
            ] else
              Text('Not shared yet',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            const Spacer(),
            _statusChip(theme, entry.status),
          ],
        ),
        const SizedBox(height: 8),
        Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _addrRow(theme, widget.entry.addressA),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.swap_vert_rounded,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('exchange',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              _addrRow(theme, widget.entry.addressB),
            ],
          ),
        ),
        Column(
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 19, color: theme.colorScheme.primary),
              onPressed: () => setState(() => _editing = true),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 19, color: theme.colorScheme.error),
              onPressed: () =>
                  context.read<AppProvider>().removeExchange(widget.entry.id),
              tooltip: 'Delete',
            ),
          ],
        ),
      ],
        ),
        if (canPropose) ...[
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
              label: const Text('Send to partner'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _statusChip(ThemeData theme, String status) {
    late Color c;
    late String label;
    switch (status) {
      case 'proposed':
        c = Colors.orange;
        label = 'proposed';
        break;
      case 'accepted':
        c = Colors.green;
        label = 'accepted';
        break;
      default:
        c = theme.colorScheme.onSurfaceVariant;
        label = 'draft';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: c, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _propose() async {
    final provider = context.read<AppProvider>();
    final partners = provider.acceptedPartners;
    if (partners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Create a pair first to share an exchange')));
      return;
    }
    String? partner = partners.first;
    if (partners.length > 1) {
      partner = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Send exchange to…',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final p in partners)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(_short(p, head: 10, tail: 8),
                      style: const TextStyle(fontFamily: 'monospace')),
                  onTap: () => Navigator.pop(ctx, p),
                ),
            ],
          ),
        ),
      );
    }
    if (partner == null || !mounted) return;
    setState(() => _proposing = true);
    final ok = await provider.proposeExchange(widget.entry, partner);
    if (!mounted) return;
    setState(() => _proposing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Proposal sent' : 'Failed to send proposal'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
  }

  Widget _addrRow(ThemeData theme, String addr) {
    if (addr.isEmpty) {
      return Text('(not set)',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    final isEth = _looksEth(addr);
    final color = isEth ? _kEth : _kBtc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  isEth ? Icons.diamond_outlined : Icons.currency_bitcoin,
                  color: color,
                  size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(_short(addr, head: 10, tail: 8),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace', fontWeight: FontWeight.w500)),
            ),
            // Copy sits right next to the address (not pushed to the far edge).
            IconButton(
              icon: Icon(Icons.copy_rounded,
                  size: 16, color: color.withValues(alpha: 0.8)),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8, right: 4),
              tooltip: 'Copy address',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: addr));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address copied')),
                );
              },
            ),
            const Spacer(),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 42, top: 2, bottom: 2),
          child: AddressBalance(
              address: addr, accent: color, autoRefresh: true),
        ),
      ],
    );
  }

  // ── Edit mode ──
  Widget _buildEdit(ThemeData theme) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          hintText: '0x… / bc1…',
          isDense: true,
          filled: true,
          fillColor:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _aCtrl,
          autofocus: true,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: deco('Address A'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bCtrl,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: deco('Address B'),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _saving ? null : _cancel,
              child: const Text('Cancel'),
            ),
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
    final entry = widget.entry;
    final isEmptyDraft = entry.addressA.isEmpty && entry.addressB.isEmpty;
    if (isEmptyDraft) {
      // Discard an untouched draft entirely.
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
        const SnackBar(content: Text('Enter both addresses')),
      );
      return;
    }
    setState(() => _saving = true);
    final ok =
        await context.read<AppProvider>().updateExchange(widget.entry.id, a, b);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editing = false;
    });
  }
}
