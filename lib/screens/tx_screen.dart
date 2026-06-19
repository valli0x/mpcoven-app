import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../widgets/amount_field.dart';
import '../widgets/gradient_button.dart';
import '../widgets/page_scaffold.dart';

/// Initiator screen: enter recipient + amount and send the transaction for
/// 2-of-2 co-signing in one tap. The hash, partner notification and our
/// incomplete signature are all handled under the hood. The partner approves
/// from their Notifications and broadcasts from Activity.
class TxScreen extends StatefulWidget {
  final AccountMeta account;

  /// Pre-check the escrow swap toggle (e.g. when launched from an Exchange).
  final bool initialViaEscrow;

  /// Shared pollination id for the swap (e.g. the Exchange id). Both sides must
  /// use the same id. Falls back to the pair id inside the provider when empty.
  final String? escrowId;

  const TxScreen({
    super.key,
    required this.account,
    this.initialViaEscrow = false,
    this.escrowId,
  });

  @override
  State<TxScreen> createState() => _TxScreenState();
}

class _TxScreenState extends State<TxScreen> {
  final _formKey = GlobalKey<FormState>();
  final _toController = TextEditingController();
  BigInt? _amountBase;

  bool _loading = false;
  bool _sent = false;
  bool _viaEscrow = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _viaEscrow = widget.initialViaEscrow;
  }

  @override
  void dispose() {
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEth = widget.account.network == 'eth';
    final color = isEth ? const Color(0xFF627EEA) : const Color(0xFFF7931A);

    return PageScaffold(
      title: 'Send ${widget.account.network.toUpperCase()}',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                        isEth
                            ? Icons.diamond_outlined
                            : Icons.currency_bitcoin,
                        color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('From',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: color)),
                          Text(
                            widget.account.address,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _toController,
                decoration: InputDecoration(
                  labelText: 'To Address',
                  hintText: isEth ? '0x...' : 'bc1...',
                  prefixIcon: const Icon(Icons.send_outlined),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                onChanged: (_) => _resetSent(),
              ),
              const SizedBox(height: 16),
              AmountField(
                network: widget.account.network,
                accent: color,
                label: 'Amount',
                onBaseChanged: (b) {
                  _amountBase = b;
                  _resetSent();
                },
              ),
              const SizedBox(height: 12),
              // Atomic-swap escrow toggle: the partner delivers the completed
              // signature into the server escrow, released only against ours.
              CheckboxListTile(
                value: _viaEscrow,
                onChanged: (v) => setState(() {
                  _viaEscrow = v ?? false;
                  _resetSent();
                }),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Withdraw via escrow (atomic swap)'),
                subtitle: Text(
                    'Partner\'s signature goes to the escrow, not to you; '
                    'released only when both sides have co-signed.',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 12),
              GradientButton(
                text: _viaEscrow ? 'Send to escrow (swap)' : 'Send for co-signing',
                icon: _viaEscrow
                    ? Icons.account_balance_outlined
                    : Icons.handshake_outlined,
                isLoading: _loading,
                gradientColors: [color, color.withValues(alpha: 0.7)],
                onPressed: _start,
              ),
              const SizedBox(height: 10),
              Text(
                _viaEscrow
                    ? 'Atomic swap: both parties must run this on the escrow the '
                        'other funded. Track release in Activity → Check escrow.'
                    : 'The partner approves the signature in their Notifications '
                        'and broadcasts it from Activity. Track status in Activity.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (_sent) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sent for co-signing. The partner will approve & '
                          'broadcast. See Activity for status.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!,
                      style:
                          TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _resetSent() {
    if (_sent || _error != null) {
      setState(() {
        _sent = false;
        _error = null;
      });
    }
  }

  Future<void> _start() async {
    if (!_formKey.currentState!.validate()) return;
    final base = _amountBase;
    if (base == null || base <= BigInt.zero) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _sent = false;
    });
    final err = await context.read<AppProvider>().startCoSign(
          account: widget.account,
          toAddress: _toController.text.trim(),
          amountBase: base,
          viaEscrow: _viaEscrow,
          escrowIdOverride: widget.escrowId,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = err == null;
      _error = err;
    });
  }
}
