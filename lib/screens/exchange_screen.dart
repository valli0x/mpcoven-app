import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../services/price_service.dart';
import '../services/units.dart';
import '../widgets/gradient_button.dart';
import '../widgets/page_scaffold.dart';

const _kEth = Color(0xFF627EEA);
const _kBtc = Color(0xFFF7931A);

/// Shared across the screen so all address rows reuse the 60s price cache.
final PriceService _priceService = PriceService();

/// Auto-refresh interval for exchange-address balances.
const Duration _kBalanceRefresh = Duration(hours: 1);

String _short(String s, {int head = 8, int tail = 6}) {
  if (s.length <= head + tail + 3) return s;
  return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
}

bool _looksEth(String a) => a.trim().toLowerCase().startsWith('0x');

String _netOf(String a) => _looksEth(a) ? 'eth' : 'btc';

/// Format a human-unit string into "0.0000…" with at least 4 decimals.
String _fmtAmount(String human) {
  final dot = human.indexOf('.');
  if (dot < 0) return '$human.0000';
  final frac = human.length - dot - 1;
  if (frac >= 4) return human;
  return human + '0' * (4 - frac);
}

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
        color: theme.colorScheme.surface,
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
    return Row(
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
    );
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
            Expanded(
              child: Text(_short(addr, head: 10, tail: 8),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace', fontWeight: FontWeight.w500)),
            ),
            IconButton(
              icon: Icon(Icons.copy_rounded,
                  size: 16, color: color.withValues(alpha: 0.8)),
              visualDensity: VisualDensity.compact,
              onPressed: () => Clipboard.setData(ClipboardData(text: addr)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 42, top: 2, bottom: 2),
          child: _AddressBalance(address: addr, accent: color),
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

/// Shows an address's on-chain balance + USD value, auto-refreshing hourly.
class _AddressBalance extends StatefulWidget {
  final String address;
  final Color accent;
  const _AddressBalance({required this.address, required this.accent});

  @override
  State<_AddressBalance> createState() => _AddressBalanceState();
}

class _AddressBalanceState extends State<_AddressBalance> {
  Timer? _timer;
  bool _loading = true;
  String? _human; // formatted balance in human units
  double? _usd; // balance value in USD
  bool _error = false;

  String get _net => _netOf(widget.address);

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(_kBalanceRefresh, (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant _AddressBalance old) {
    super.didUpdateWidget(old);
    if (old.address != widget.address) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final api = context.read<AppProvider>().apiService;
      final resp = await api.checkBalance(BalanceCheckRequest(
        network: _net,
        address: widget.address,
        expected: 0,
      ));
      final human = Units.fromBase(resp.balance, _net);
      double? usd;
      final price = await _priceService.usdPrice(_net);
      if (price != null) {
        usd = (double.tryParse(human) ?? 0) * price;
      }
      if (!mounted) return;
      setState(() {
        _human = human;
        _usd = usd;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (_loading && _human == null) {
      return Row(
        children: [
          SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
                strokeWidth: 1.6, color: muted.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 8),
          Text('checking balance…',
              style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        ],
      );
    }

    if (_error && _human == null) {
      return InkWell(
        onTap: _refresh,
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 12, color: muted),
            const SizedBox(width: 6),
            Text('balance unavailable · tap to retry',
                style: theme.textTheme.labelSmall?.copyWith(color: muted)),
          ],
        ),
      );
    }

    final sym = Units.symbol(_net);
    final amount = _fmtAmount(_human ?? '0');
    final usdStr = _usd != null
        ? '≈ \$${_usd!.toStringAsFixed(2)}'
        : '≈ \$—';

    return Row(
      children: [
        Text('$amount $sym',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: widget.accent,
            )),
        const SizedBox(width: 8),
        Text(usdStr,
            style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        const SizedBox(width: 6),
        InkWell(
          onTap: _loading ? null : _refresh,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: _loading
                ? SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.4, color: muted.withValues(alpha: 0.5)),
                  )
                : Icon(Icons.refresh, size: 13, color: muted.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }
}
