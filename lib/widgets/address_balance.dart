import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../services/price_service.dart';
import '../services/units.dart';

/// Shared price service so all rows reuse the 60s quote cache.
final PriceService kPriceService = PriceService();

bool _looksEth(String a) => a.trim().toLowerCase().startsWith('0x');

/// Format a human-unit string into "0.0000…" with at least 4 decimals.
String _fmtAmount(String human) {
  final dot = human.indexOf('.');
  if (dot < 0) return '$human.0000';
  final frac = human.length - dot - 1;
  if (frac >= 4) return human;
  return human + '0' * (4 - frac);
}

/// Shows an address's on-chain balance + USD value.
///
/// - [autoRefresh] true: fetches on mount and every [refreshEvery].
/// - [autoRefresh] false: fetches only when the refresh button is tapped.
class AddressBalance extends StatefulWidget {
  final String address;
  final Color accent;

  /// Network override ('eth'|'btc'). If null, derived from the address.
  final String? network;
  final bool autoRefresh;
  final Duration refreshEvery;

  const AddressBalance({
    super.key,
    required this.address,
    required this.accent,
    this.network,
    this.autoRefresh = false,
    this.refreshEvery = const Duration(hours: 1),
  });

  @override
  State<AddressBalance> createState() => _AddressBalanceState();
}

class _AddressBalanceState extends State<AddressBalance> {
  Timer? _timer;
  bool _loading = false;
  String? _human;
  double? _usd;
  bool _error = false;

  String get _net =>
      widget.network ?? (_looksEth(widget.address) ? 'eth' : 'btc');

  @override
  void initState() {
    super.initState();
    if (widget.autoRefresh) {
      _refresh();
      _timer = Timer.periodic(widget.refreshEvery, (_) => _refresh());
    }
  }

  @override
  void didUpdateWidget(covariant AddressBalance old) {
    super.didUpdateWidget(old);
    if (old.address != widget.address && widget.autoRefresh) _refresh();
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
      final price = await kPriceService.usdPrice(_net);
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

    // Manual mode, never fetched yet: just a "check balance" button.
    if (_human == null && !_loading && !_error) {
      return InkWell(
        onTap: _refresh,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Icon(Icons.refresh, size: 13, color: muted.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text('check balance',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted)),
            ],
          ),
        ),
      );
    }

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
    final usdStr = _usd != null ? '≈ \$${_usd!.toStringAsFixed(2)}' : '≈ \$—';

    return Row(
      children: [
        Flexible(
          child: Text('$amount $sym',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: widget.accent,
              )),
        ),
        const SizedBox(width: 8),
        Text(usdStr, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        const SizedBox(width: 4),
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
                : Icon(Icons.refresh,
                    size: 13, color: muted.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }
}
