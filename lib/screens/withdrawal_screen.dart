import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../widgets/gradient_button.dart';
import '../widgets/page_scaffold.dart';

class WithdrawalScreen extends StatefulWidget {
  final AccountMeta account;

  /// Optional TX hash to pre-fill (e.g. coming from the Create TX Hash screen).
  final String? prefillHash;

  /// Optional tx details (To / amount in base units) so the partner's
  /// sign-request notification can show what is being signed.
  final String? prefillTo;
  final String? prefillAmountBase;

  const WithdrawalScreen({
    super.key,
    required this.account,
    this.prefillHash,
    this.prefillTo,
    this.prefillAmountBase,
  });

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _hashTxController = TextEditingController();
  final _escrowAddrController = TextEditingController();

  bool _isSending = false;
  bool _isAccepting = false;
  IncompleteSignatureResponse? _result;
  String? _error;

  String get _alg => widget.account.network == 'eth' ? 'ecdsa' : 'frost';

  @override
  void initState() {
    super.initState();
    _escrowAddrController.text = widget.account.address;
    if (widget.prefillHash != null && widget.prefillHash!.isNotEmpty) {
      _hashTxController.text = widget.prefillHash!;
    }
  }

  @override
  void dispose() {
    _hashTxController.dispose();
    _escrowAddrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEth = widget.account.network == 'eth';
    final color = isEth ? const Color(0xFF627EEA) : const Color(0xFFF7931A);

    return PageScaffold(
      title: 'MPC Withdrawal',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Account: ${widget.account.network.toUpperCase()} #${widget.account.index}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(widget.account.address,
                      style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis),
                  if (widget.account.pairMyId != null) ...[
                    const SizedBox(height: 8),
                    Text('My ID: ${widget.account.pairMyId}',
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: theme.colorScheme.onSurfaceVariant)),
                    Text('Other ID: ${widget.account.pairOther}',
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _escrowAddrController,
              decoration: const InputDecoration(
                labelText: 'Escrow Address',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hashTxController,
              decoration: const InputDecoration(
                labelText: 'TX Hash (hex)',
                hintText: '0x...',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Send Incomplete Signature',
              icon: Icons.draw_outlined,
              isLoading: _isSending,
              gradientColors: [color, color.withOpacity(0.7)],
              onPressed: _send,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: _isAccepting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isAccepting ? 'Accepting...' : 'Accept & Complete Signature'),
              onPressed: _isAccepting ? null : _accept,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            if (_result != null) ...[
              const SizedBox(height: 24),
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
                        Expanded(child: Text(_result!.status, style: theme.textTheme.titleSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_result!.message, style: theme.textTheme.bodySmall),
                    if (_result!.completeSignature != null) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _result!.completeSignature!));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signature copied')));
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Complete Signature', style: theme.textTheme.labelSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(_result!.completeSignature!, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                            ],
                          ),
                        ),
                      ),
                    ],
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
    );
  }

  Future<void> _send() async {
    final hash = _hashTxController.text.trim();
    if (hash.isEmpty) return;
    setState(() {
      _isSending = true;
      _error = null;
      _result = null;
    });
    try {
      final provider = context.read<AppProvider>();
      // Notify the partner first so their Notifications shows a "Signature
      // request" with what's being signed; the incsig itself is buffered by
      // the relay, so order doesn't matter.
      await provider.notifySignRequest(
        account: widget.account,
        toAddress: widget.prefillTo ?? '',
        amountBase: widget.prefillAmountBase ?? '',
        hashTx: hash,
      );
      final result = await provider.apiService.sendIncompleteSignature(
        alg: _alg,
        name: '${widget.account.network}/${widget.account.index}',
        escrowAddress: _escrowAddrController.text.trim(),
        hashTx: hash,
        myId: widget.account.pairMyId ?? '',
        anotherId: widget.account.pairOther ?? '',
      );
      setState(() => _result = result);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _accept() async {
    setState(() {
      _isAccepting = true;
      _error = null;
      _result = null;
    });
    try {
      final api = context.read<AppProvider>().apiService;
      final hash = _hashTxController.text.trim();
      final result = await api.acceptIncompleteSignature(
        alg: _alg,
        name: '${widget.account.network}/${widget.account.index}',
        escrowAddress: _escrowAddrController.text.trim(),
        myId: widget.account.pairMyId ?? '',
        anotherId: widget.account.pairOther ?? '',
        hashTx: hash.isNotEmpty ? hash : null,
      );
      setState(() => _result = result);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _isAccepting = false);
    }
  }
}
