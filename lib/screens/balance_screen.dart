import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../services/price_service.dart';
import '../services/units.dart';
import '../widgets/amount_field.dart';
import '../widgets/gradient_button.dart';
import '../widgets/page_scaffold.dart';

class BalanceScreen extends StatefulWidget {
  final String? prefillAddress;
  final String? prefillNetwork;

  const BalanceScreen({super.key, this.prefillAddress, this.prefillNetwork});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  BigInt? _expectedBase;
  late String _network;
  bool _isLoading = false;
  BalanceCheckResponse? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.prefillAddress ?? '');
    _network = widget.prefillNetwork ?? 'eth';
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEth = _network == 'eth';

    return PageScaffold(
      title: 'Check Balance',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _NetCard(
                      title: 'Ethereum',
                      icon: Icons.diamond_outlined,
                      color: const Color(0xFF627EEA),
                      isSelected: isEth,
                      onTap: () => setState(() => _network = 'eth'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NetCard(
                      title: 'Bitcoin',
                      icon: Icons.currency_bitcoin,
                      color: const Color(0xFFF7931A),
                      isSelected: !isEth,
                      onTap: () => setState(() => _network = 'btc'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  hintText: isEth ? '0x...' : 'bc1...',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AmountField(
                key: ValueKey(_network),
                network: _network,
                accent: isEth ? const Color(0xFF627EEA) : const Color(0xFFF7931A),
                label: 'Expected balance',
                onBaseChanged: (b) => _expectedBase = b,
              ),
              const SizedBox(height: 24),
              GradientButton(
                text: 'Check Balance',
                icon: Icons.search,
                isLoading: _isLoading,
                gradientColors: isEth
                    ? [const Color(0xFF627EEA), const Color(0xFF8B5CF6)]
                    : [const Color(0xFFF7931A), const Color(0xFFEA580C)],
                onPressed: _check,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 24),
                _BalanceResultCard(result: _result!, isEth: isEth),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _check() async {
    if (!_formKey.currentState!.validate()) return;
    final base = _expectedBase;
    if (base == null || base <= BigInt.zero) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });
    try {
      final api = context.read<AppProvider>().apiService;
      final result = await api.checkBalance(BalanceCheckRequest(
        network: _network,
        address: _addressController.text.trim(),
        expected: base.toInt(),
      ));
      setState(() => _result = result);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class _NetCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _NetCard({required this.title, required this.icon, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? color : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: isSelected ? color : null)),
          ],
        ),
      ),
    );
  }
}

class _BalanceResultCard extends StatefulWidget {
  final BalanceCheckResponse result;
  final bool isEth;

  const _BalanceResultCard({required this.result, required this.isEth});

  @override
  State<_BalanceResultCard> createState() => _BalanceResultCardState();
}

class _BalanceResultCardState extends State<_BalanceResultCard> {
  final _price = PriceService();
  double? _unitUsd;

  String get _net => widget.isEth ? 'eth' : 'btc';

  @override
  void initState() {
    super.initState();
    _price.usdPrice(_net).then((p) {
      if (mounted) setState(() => _unitUsd = p);
    });
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = widget.result.isSufficient;
    final accent = ok ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.cancel, color: accent, size: 28),
              const SizedBox(width: 12),
              Text(ok ? 'Sufficient' : 'Insufficient', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: accent)),
            ],
          ),
          const SizedBox(height: 16),
          _row(theme, 'Balance', widget.result.balance),
          const Divider(height: 16),
          _row(theme, 'Expected', widget.result.expected),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, int amount) {
    final human = Units.fromBase(amount, _net);
    final value = '$human ${Units.symbol(_net)}';
    String? usd;
    if (_unitUsd != null) {
      final crypto = double.tryParse(human) ?? 0;
      usd = '\$${(crypto * _unitUsd!).toStringAsFixed(2)}';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            if (usd != null)
              Text(usd, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
