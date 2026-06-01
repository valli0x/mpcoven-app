import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../widgets/amount_field.dart';
import '../widgets/gradient_button.dart';
import '../widgets/page_scaffold.dart';

class TxScreen extends StatefulWidget {
  final AccountMeta account;

  const TxScreen({super.key, required this.account});

  @override
  State<TxScreen> createState() => _TxScreenState();
}

class _TxScreenState extends State<TxScreen> {
  final _formKey = GlobalKey<FormState>();
  final _toController = TextEditingController();
  final _signatureController = TextEditingController();
  BigInt? _amountBase;

  bool _loadingHash = false;
  bool _loadingSend = false;
  TxHashResponse? _txHash;
  TxSendResponse? _txSend;
  String? _error;

  @override
  void dispose() {
    _toController.dispose();
    _signatureController.dispose();
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
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(isEth ? Icons.diamond_outlined : Icons.currency_bitcoin, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('From', style: theme.textTheme.labelSmall?.copyWith(color: color)),
                          Text(
                            widget.account.address,
                            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
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
              ),
              const SizedBox(height: 16),
              AmountField(
                network: widget.account.network,
                accent: color,
                label: 'Amount',
                onBaseChanged: (b) => _amountBase = b,
              ),
              const SizedBox(height: 24),

              GradientButton(
                text: 'Create TX Hash',
                icon: Icons.tag,
                isLoading: _loadingHash,
                gradientColors: [color, color.withOpacity(0.7)],
                onPressed: _createHash,
              ),

              if (_txHash != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('TX Hash', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.copy_rounded, size: 18, color: color),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _txHash!.hash));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hash copied')));
                            },
                          ),
                        ],
                      ),
                      SelectableText(
                        _txHash!.hash,
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _signatureController,
                  decoration: const InputDecoration(
                    labelText: 'Signature (hex)',
                    hintText: '0x...',
                    prefixIcon: Icon(Icons.draw_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                GradientButton(
                  text: 'Send Transaction',
                  icon: Icons.send,
                  isLoading: _loadingSend,
                  gradientColors: [Colors.green, Colors.green.shade700],
                  onPressed: _send,
                ),
              ],

              if (_txSend != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Text('Sent!', style: theme.textTheme.titleSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('TX: ${_txSend!.txHash}', style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                      Text(_txSend!.message, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createHash() async {
    if (!_formKey.currentState!.validate()) return;
    final base = _amountBase;
    if (base == null || base <= BigInt.zero) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _loadingHash = true;
      _error = null;
      _txHash = null;
    });
    try {
      final api = context.read<AppProvider>().apiService;
      final result = await api.createTxHash(
        network: widget.account.network,
        from: widget.account.address,
        to: _toController.text.trim(),
        amount: base.toInt(),
      );
      setState(() => _txHash = result);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loadingHash = false);
    }
  }

  Future<void> _send() async {
    final sig = _signatureController.text.trim();
    if (sig.isEmpty) return;
    setState(() {
      _loadingSend = true;
      _error = null;
    });
    try {
      final api = context.read<AppProvider>().apiService;
      final result = await api.sendTransaction(
        network: widget.account.network,
        from: widget.account.address,
        to: _toController.text.trim(),
        value: (_amountBase ?? BigInt.zero).toString(),
        signature: sig,
      );
      setState(() => _txSend = result);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loadingSend = false);
    }
  }
}
