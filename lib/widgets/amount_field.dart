import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/price_service.dart';
import '../services/units.dart';

/// Amount input in human units (ETH/BTC) with an optional USD toggle.
/// Exposes the value as BASE units (wei/satoshi) via [onBaseChanged].
class AmountField extends StatefulWidget {
  final String network; // 'eth' | 'btc'
  final Color accent;
  final String label;
  final void Function(BigInt? base) onBaseChanged;
  // ERC-20 override: when set, amounts use these decimals/symbol and the USD
  // toggle is hidden (no price feed for arbitrary tokens).
  final int? decimalsOverride;
  final String? symbolOverride;

  const AmountField({
    super.key,
    required this.network,
    required this.accent,
    required this.onBaseChanged,
    this.label = 'Amount',
    this.decimalsOverride,
    this.symbolOverride,
  });

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  final _controller = TextEditingController();
  final _price = PriceService();
  bool _usdMode = false;
  double? _unitUsd; // USD per 1 ETH/BTC
  String _hint = '';

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  @override
  void dispose() {
    _controller.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _loadPrice() async {
    final p = await _price.usdPrice(widget.network);
    if (mounted) setState(() => _unitUsd = p);
    _recompute();
  }

  bool get _isToken => widget.decimalsOverride != null;
  String get _sym => widget.symbolOverride ?? Units.symbol(widget.network);

  /// Convert the field text to BASE units and update hint + callback.
  void _recompute() {
    final raw = _controller.text.trim();
    BigInt? base;
    String hint = '';

    if (raw.isEmpty) {
      widget.onBaseChanged(null);
      setState(() => _hint = '');
      return;
    }

    if (_isToken) {
      // Token amounts are entered directly in token units (no USD toggle).
      base = Units.toBaseDec(raw, widget.decimalsOverride!);
    } else if (_usdMode) {
      // text is USD -> convert to crypto -> base
      final usd = double.tryParse(raw);
      if (usd != null && _unitUsd != null && _unitUsd! > 0) {
        final crypto = usd / _unitUsd!;
        base = Units.toBase(crypto.toStringAsFixed(Units.decimals(widget.network)),
            widget.network);
        hint = '≈ ${_trim(crypto)} $_sym';
      } else if (_unitUsd == null) {
        hint = 'price unavailable';
      }
    } else {
      // text is crypto -> base; hint shows USD
      base = Units.toBase(raw, widget.network);
      final crypto = double.tryParse(raw);
      if (crypto != null && _unitUsd != null) {
        hint = '≈ \$${(crypto * _unitUsd!).toStringAsFixed(2)}';
      }
    }

    widget.onBaseChanged(base);
    setState(() => _hint = hint);
  }

  String _trim(double v) {
    final s = v.toStringAsFixed(Units.decimals(widget.network));
    return s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = _usdMode ? 'USD' : _sym;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: (_) => _recompute(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: '${widget.label} ($unit)',
            hintText: _usdMode ? '0.00' : '0.0',
            prefixIcon: Icon(_usdMode
                ? Icons.attach_money
                : Icons.account_balance_wallet_outlined),
            suffixIcon: _isToken
                ? Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Text(_sym,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: widget.accent)),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ToggleButtons(
                      isSelected: [!_usdMode, _usdMode],
                      onPressed: (i) {
                        setState(() => _usdMode = i == 1);
                        _recompute();
                      },
                      borderRadius: BorderRadius.circular(8),
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 30),
                      selectedColor: Colors.white,
                      fillColor: widget.accent,
                      children: [Text(_sym), const Text('USD')],
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Text(
            _hint.isEmpty ? ' ' : _hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
