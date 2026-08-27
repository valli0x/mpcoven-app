import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../services/units.dart';
import '../widgets/page_scaffold.dart';

const _kEth = Color(0xFF627EEA);

String _short(String s, {int head = 8, int tail = 6}) =>
    s.length <= head + tail + 3
        ? s
        : '${s.substring(0, head)}…${s.substring(s.length - tail)}';

/// Co-sign / broadcast activity log (recorded on the Go client).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadCosignHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final events = provider.cosignHistory;
        return PageScaffold(
          title: 'Activity',
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => provider.loadCosignHistory(),
            ),
            if (events.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Clear history',
                onPressed: () => _confirmClear(context, provider),
              ),
          ],
          body: events.isEmpty
              ? _empty(context)
              : RefreshIndicator(
                  onRefresh: () => provider.loadCosignHistory(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: events.length,
                    itemBuilder: (_, i) => _EventCard(event: events[i]),
                  ),
                ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No activity yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Sent / completed signatures and broadcasts appear here',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, AppProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This removes the local activity log on this client.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await provider.clearCosignHistory();
  }
}

class _EventCard extends StatefulWidget {
  final CosignEvent event;
  const _EventCard({required this.event});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _broadcasting = false;

  CosignEvent get event => widget.event;

  // Either party can broadcast once they have both the completed signature and
  // the tx_data (acceptor gets both directly; initiator gets the signature back
  // via sign-result and already stored tx_data).
  bool _checkingEscrow = false;

  bool get _canBroadcast =>
      event.status == 'completed' &&
      event.signature.isNotEmpty &&
      event.txData.isNotEmpty;

  bool get _isEscrowAwait =>
      event.status == 'escrow-await' && event.escrowId.isNotEmpty;

  // A time-locked refund: claimable only once the server's timebox opens.
  bool get _isRefundAwait =>
      event.status == 'refund-await' && event.pub.isNotEmpty;
  bool _claimingRefund = false;

  Future<void> _claimRefund() async {
    setState(() => _claimingRefund = true);
    final provider = context.read<AppProvider>();
    final txHash = await provider.claimRefund(event);
    if (!mounted) return;
    setState(() => _claimingRefund = false);
    final ok = txHash != null && txHash.isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Refund broadcast: ${txHash.substring(0, 12)}…'
          : (provider.errorMessage ?? 'Refund not available yet')),
      backgroundColor: ok ? Colors.green : Colors.orange,
      duration: Duration(seconds: ok ? 4 : 6),
    ));
  }

  Future<void> _checkEscrow() async {
    setState(() => _checkingEscrow = true);
    final ok = await context.read<AppProvider>().checkEscrow(event);
    if (!mounted) return;
    setState(() => _checkingEscrow = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Released — ready to broadcast'
          : 'Still pending (waiting for the counterparty)'),
      backgroundColor: ok ? Colors.green : null,
    ));
  }

  Future<void> _broadcast() async {
    setState(() => _broadcasting = true);
    final txHash = await context.read<AppProvider>().broadcastCosign(event);
    if (!mounted) return;
    setState(() => _broadcasting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(txHash != null && txHash.isNotEmpty
            ? 'Broadcast: ${txHash.substring(0, 12)}…'
            : 'Broadcast failed'),
        backgroundColor:
            txHash != null && txHash.isNotEmpty ? Colors.green : Colors.red,
      ),
    );
  }

  ({String label, IconData icon, Color color}) get _role {
    switch (event.role) {
      case 'initiator':
        return (label: 'Sent incomplete', icon: Icons.upload_outlined, color: _kEth);
      case 'acceptor':
        return (label: 'Completed signature', icon: Icons.done_all, color: Colors.green);
      case 'broadcast':
        return (label: 'Broadcast', icon: Icons.send_rounded, color: const Color(0xFF8B5CF6));
      default:
        return (label: event.role, icon: Icons.history, color: _kEth);
    }
  }

  Color get _statusColor {
    switch (event.status) {
      case 'completed':
      case 'broadcast':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'sent':
      case 'escrow-await':
      case 'refund-await':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (event.status) {
      case 'sent':
        return 'awaiting partner';
      case 'escrow-await':
        return 'in escrow';
      case 'refund-await':
        return 'refund time-locked';
      case 'completed':
        return 'completed';
      case 'broadcast':
        return 'on-chain';
      case 'failed':
        return 'failed';
      default:
        return event.status;
    }
  }

  String _amountText() {
    if (event.amount.isEmpty) return '';
    try {
      return '${Units.fromBase(BigInt.parse(event.amount), event.network)} '
          '${Units.symbol(event.network)}';
    } catch (_) {
      return '';
    }
  }

  String _time() {
    if (event.createdAt == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(event.createdAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = _role;
    final amount = _amountText();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: r.color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: r.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(r.icon, color: r.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(r.label,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (event.index > 0)
              _row(context, Icons.account_balance_outlined, 'Account',
                  '${event.network.toUpperCase()} #${event.index}'),
            if (event.to.isNotEmpty)
              _row(context, Icons.send_outlined, 'To', _short(event.to)),
            if (amount.isNotEmpty)
              _row(context, Icons.payments_outlined, 'Amount', amount),
            if (event.hash.isNotEmpty)
              _row(context, Icons.tag, 'Hash', _short(event.hash),
                  copy: event.hash),
            if (event.signature.isNotEmpty)
              _row(context, Icons.draw_outlined, 'Signature',
                  _short(event.signature),
                  copy: event.signature),
            if (event.txHash.isNotEmpty)
              _row(context, Icons.receipt_long_outlined, 'Tx', _short(event.txHash),
                  copy: event.txHash),
            if (event.error.isNotEmpty)
              _row(context, Icons.error_outline, 'Error', event.error),
            if (_time().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(_time(),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (_isEscrowAwait) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _checkingEscrow ? null : _checkEscrow,
                  icon: _checkingEscrow
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.account_balance_outlined, size: 18),
                  label: const Text('Check escrow'),
                ),
              ),
            ],
            if (_isRefundAwait) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _claimingRefund ? null : _claimRefund,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange),
                  icon: _claimingRefund
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.lock_clock, size: 18),
                  label: const Text('Claim refund'),
                ),
              ),
            ],
            if (_canBroadcast) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _broadcasting ? null : _broadcast,
                  icon: _broadcasting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send Transaction'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value,
      {String? copy}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Fixed-width label column so all values line up vertically.
          SizedBox(
            width: 96,
            child: Row(
              children: [
                Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace', fontWeight: FontWeight.w500)),
          ),
          // Reserve the trailing slot on every row so values stay aligned
          // whether or not a copy button is present.
          SizedBox(
            width: 22,
            child: copy == null
                ? null
                : InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: copy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$label copied')),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Icon(Icons.copy_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7)),
                  ),
          ),
        ],
      ),
    );
  }
}
