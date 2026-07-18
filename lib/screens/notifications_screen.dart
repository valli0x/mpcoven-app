import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
import '../services/units.dart';
import '../services/tokens.dart';
import '../widgets/page_scaffold.dart';

const _kEth = Color(0xFF627EEA);
const _kBtc = Color(0xFFF7931A);

enum _MsgState { idle, accepting, done, failed }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Per-message UI state keyed by message id.
  final Map<String, _MsgState> _states = {};
  // Complete signature (hex) produced for an accepted sign-request.
  final Map<String, String> _sigResults = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final messages = provider.messages;
        return PageScaffold(
          title: 'Notifications',
          body: messages.isEmpty
              ? _buildEmpty(context)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    return _MessageCard(
                      message: m,
                      state: _states[m.id] ?? _MsgState.idle,
                      signature: _sigResults[m.id],
                      onAccept: () => _accept(m),
                      onDismiss: () => _dismiss(m),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No notifications',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Keygen requests from partners appear here',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<void> _accept(MailboxMessage message) async {
    if (message.type == 'sign-request') {
      await _acceptSign(message);
      return;
    }
    if (message.type == 'exchange-proposal') {
      await _acceptExchange(message);
      return;
    }
    setState(() => _states[message.id] = _MsgState.accepting);
    final provider = context.read<AppProvider>();
    final key = await provider.acceptKeygenInvite(message);
    if (!mounted) return;
    setState(() =>
        _states[message.id] = key != null ? _MsgState.done : _MsgState.failed);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(key != null
            ? 'Shared key created: ${key.address.substring(0, 10)}…'
            : 'Failed to complete keygen'),
        backgroundColor: key != null ? Colors.green : Colors.red,
      ),
    );

    // On success the message is acked by the provider; let the "done" badge
    // linger briefly, then it disappears from the list on the next refresh.
    if (key == null && mounted) {
      // allow retry after a failure
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _states[message.id] = _MsgState.idle);
    }
  }

  Future<void> _acceptExchange(MailboxMessage message) async {
    setState(() => _states[message.id] = _MsgState.accepting);
    final ok = await context.read<AppProvider>().acceptExchangeProposal(message);
    if (!mounted) return;
    setState(() =>
        _states[message.id] = ok ? _MsgState.done : _MsgState.failed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Exchange added' : 'Failed to accept exchange'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (!ok && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _states[message.id] = _MsgState.idle);
    }
  }

  Future<void> _acceptSign(MailboxMessage message) async {
    setState(() => _states[message.id] = _MsgState.accepting);
    final provider = context.read<AppProvider>();
    final sig = await provider.acceptSignRequest(message);
    if (!mounted) return;
    setState(() {
      if (sig != null && sig.isNotEmpty) {
        _sigResults[message.id] = sig;
        _states[message.id] = _MsgState.done;
      } else {
        _states[message.id] = _MsgState.failed;
      }
    });
    final ok = sig != null && sig.isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Signature completed'
            : (provider.errorMessage ?? 'Failed to co-sign')),
        backgroundColor: ok ? Colors.green : Colors.red,
        duration: Duration(seconds: ok ? 3 : 6),
      ),
    );
    if ((sig == null || sig.isEmpty) && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _states[message.id] = _MsgState.idle);
    }
  }

  Future<void> _dismiss(MailboxMessage message) async {
    final provider = context.read<AppProvider>();
    await provider.ackMessage(message.id);
  }
}

class _MessageCard extends StatelessWidget {
  final MailboxMessage message;
  final _MsgState state;
  final String? signature;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const _MessageCard({
    required this.message,
    required this.state,
    this.signature,
    required this.onAccept,
    required this.onDismiss,
  });

  Map<String, dynamic> get _body {
    final b = message.body;
    if (b is Map) return b.cast<String, dynamic>();
    return const {};
  }

  bool get _isKeygen => message.type == 'keygen-init';
  bool get _isSignRequest => message.type == 'sign-request';
  bool get _isExchange => message.type == 'exchange-proposal';
  bool get _isEth => (_body['network'] ?? 'eth').toString() == 'eth';

  String _short(String s, {int head = 6, int tail = 6}) =>
      s.length <= head + tail + 3
          ? s
          : '${s.substring(0, head)}…${s.substring(s.length - tail)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _isEth ? _kEth : _kBtc;
    final protocol = (_body['protocol'] ?? '').toString().toUpperCase();
    final network = (_body['network'] ?? '').toString().toUpperCase();
    final index = _body['index']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isKeygen
                        ? Icons.vpn_key_rounded
                        : _isSignRequest
                            ? Icons.draw_outlined
                            : _isExchange
                                ? Icons.swap_horiz_rounded
                                : Icons.mail_outline,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isKeygen
                            ? 'Keygen Request'
                            : _isSignRequest
                                ? 'Signature Request'
                                : _isExchange
                                    ? 'Exchange Proposal'
                                    : 'Message',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'From ${_short(message.from)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (_isKeygen && protocol.isNotEmpty)
                  _Chip(
                    label: protocol,
                    color: accent,
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Pretty details (instead of raw JSON)
            if (_isKeygen) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (network.isNotEmpty || index != null)
                      _DetailRow(
                        icon: _isEth
                            ? Icons.diamond_outlined
                            : Icons.currency_bitcoin,
                        label: 'Account',
                        value: [
                          if (network.isNotEmpty) network,
                          if (index != null) '#$index',
                        ].join(' '),
                        color: accent,
                      ),
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Initiator',
                      value: _short((_body['initiator'] ?? message.from).toString(),
                          head: 8, tail: 6),
                      color: accent,
                      mono: true,
                    ),
                    if (_body['session_id'] != null)
                      _DetailRow(
                        icon: Icons.tag,
                        label: 'Session',
                        value: _short(_body['session_id'].toString(),
                            head: 8, tail: 4),
                        color: accent,
                        mono: true,
                        last: true,
                      ),
                  ],
                ),
              ),
            ] else if (_isSignRequest) ...[
              _buildSignDetails(context, accent),
            ] else if (_isExchange) ...[
              _buildExchangeDetails(context, accent),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _body.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ),

            const SizedBox(height: 14),

            // Actions / status
            if (_isKeygen || _isSignRequest || _isExchange)
              _buildFooter(context, accent),

            // Completed signature output (sign-request only).
            if (_isSignRequest &&
                state == _MsgState.done &&
                (signature ?? '').isNotEmpty)
              _buildSignatureResult(context, accent),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeDetails(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    final a = (_body['address_a'] ?? '').toString();
    final b = (_body['address_b'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _DetailRow(
              icon: Icons.person_outline,
              label: 'From',
              value: _short(message.from, head: 8, tail: 6),
              color: accent,
              mono: true),
          if (a.isNotEmpty)
            _DetailRow(
                icon: Icons.tag,
                label: 'Address A',
                value: _short(a, head: 8, tail: 6),
                color: accent,
                mono: true),
          if (b.isNotEmpty)
            _DetailRow(
                icon: Icons.tag,
                label: 'Address B',
                value: _short(b, head: 8, tail: 6),
                color: accent,
                mono: true,
                last: true),
        ],
      ),
    );
  }

  Widget _buildSignDetails(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    final net = (_body['network'] ?? 'eth').toString();
    final index = _body['index']?.toString();
    final to = (_body['to'] ?? '').toString();
    final amountBase = (_body['amount'] ?? '').toString();
    final hash = (_body['hash_tx'] ?? '').toString();
    final escrow = (_body['escrow_address'] ?? '').toString();
    final txData = (_body['tx_data'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // FROM = which of YOUR accounts is being spent. This is what your
          // signature authorizes — verify it.
          _DetailRow(
            icon: _isEth ? Icons.diamond_outlined : Icons.currency_bitcoin,
            label: 'Spending from',
            value: [net.toUpperCase(), if (index != null) '#$index'].join(' '),
            color: accent,
          ),
          if (escrow.isNotEmpty)
            _DetailRow(
              icon: Icons.account_balance_outlined,
              label: 'Account',
              value: _short(escrow, head: 8, tail: 6),
              color: accent,
              mono: true,
              copyValue: escrow,
            ),
          // Verified To/amount decoded from tx_data (the bytes you actually
          // sign) — not the sender's claimed display values.
          _VerifiedTxDetails(
            txData: txData,
            network: net,
            claimedTo: to,
            claimedAmount: amountBase,
            accent: accent,
          ),
          if (hash.isNotEmpty)
            _DetailRow(
              icon: Icons.tag,
              label: 'Hash',
              value: _short(hash, head: 8, tail: 6),
              color: accent,
              mono: true,
              last: true,
              copyValue: hash,
            ),
        ],
      ),
    );
  }

  Widget _buildSignatureResult(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Complete signature',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: 18, color: accent),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: signature ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signature copied')),
                    );
                  },
                ),
              ],
            ),
            SelectableText(
              signature ?? '',
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    switch (state) {
      case _MsgState.accepting:
        return Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 12),
            Text(
                _isSignRequest
                    ? 'Co-signing…'
                    : _isExchange
                        ? 'Adding exchange…'
                        : 'Generating shared key…',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
          ],
        );
      case _MsgState.done:
        return Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Text(
                _isSignRequest
                    ? 'Signature ready'
                    : _isExchange
                        ? 'Exchange added'
                        : 'Shared key created',
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600, color: Colors.green)),
          ],
        );
      case _MsgState.failed:
        return Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 10),
            Text('Failed — retrying available',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error)),
          ],
        );
      case _MsgState.idle:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAccept,
              icon: Icon(
                  _isSignRequest
                      ? Icons.draw_outlined
                      : _isExchange
                          ? Icons.swap_horiz_rounded
                          : Icons.check,
                  size: 18),
              label: Text(_isSignRequest
                  ? 'Accept & Sign'
                  : _isExchange
                      ? 'Accept'
                      : 'Accept & Generate'),
            ),
          ],
        );
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool mono;
  final bool last;
  final String? copyValue; // full value to copy (row becomes tappable)

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.mono = false,
    this.last = false,
    this.copyValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Row(
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 10),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ),
        if (copyValue != null && copyValue!.isNotEmpty) ...[
          const SizedBox(width: 6),
          Icon(Icons.copy_rounded,
              size: 13, color: theme.colorScheme.onSurfaceVariant),
        ],
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: (copyValue != null && copyValue!.isNotEmpty)
          ? InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Clipboard.setData(ClipboardData(text: copyValue!));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$label copied'),
                  duration: const Duration(seconds: 2),
                ));
              },
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2), child: row),
            )
          : row,
    );
  }
}

/// Decodes tx_data on the client and shows the AUTHORITATIVE To/amount that the
/// signature will actually authorize — flagging any mismatch with the sender's
/// claimed display values (anti-tampering: see what you really sign).
class _VerifiedTxDetails extends StatelessWidget {
  final String txData;
  final String network;
  final String claimedTo;
  final String claimedAmount;
  final Color accent;

  const _VerifiedTxDetails({
    required this.txData,
    required this.network,
    required this.claimedTo,
    required this.claimedAmount,
    required this.accent,
  });

  String _short(String s, {int head = 8, int tail = 6}) =>
      s.length <= head + tail + 3
          ? s
          : '${s.substring(0, head)}…${s.substring(s.length - tail)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (txData.isEmpty) {
      // No tx_data to verify against — show claimed values with a caution.
      return Column(children: [
        if (claimedTo.isNotEmpty)
          _DetailRow(
              icon: Icons.send_outlined,
              label: 'To',
              value: _short(claimedTo),
              color: accent,
              mono: true),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(Icons.info_outline, size: 12, color: Colors.orange),
            const SizedBox(width: 4),
            Text('unverified (no tx data)',
                style:
                    theme.textTheme.labelSmall?.copyWith(color: Colors.orange)),
          ]),
        ),
      ]);
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: context.read<AppProvider>().apiService.decodeTx(network, txData),
      builder: (context, snap) {
        if (!snap.hasData) {
          return _DetailRow(
              icon: Icons.hourglass_empty,
              label: 'To',
              value: 'verifying…',
              color: accent);
        }
        final d = snap.data!;
        final to = (d['to'] ?? '').toString();
        final valueBase = (d['value'] ?? '0').toString();
        final isErc20 = d['is_erc20'] == true;
        final tokenContract = (d['token'] ?? '').toString();
        final tok = isErc20 ? tokenForContract(tokenContract) : null;
        String amountText = '';
        try {
          if (tok != null) {
            amountText =
                '${Units.fromBaseDec(BigInt.parse(valueBase), tok.decimals)} ${tok.symbol}';
          } else {
            amountText = '${Units.fromBase(BigInt.parse(valueBase), network)} '
                '${Units.symbol(network)}';
          }
        } catch (_) {}
        final toMismatch =
            claimedTo.isNotEmpty && to.toLowerCase() != claimedTo.toLowerCase();
        final amtMismatch =
            claimedAmount.isNotEmpty && valueBase != claimedAmount;
        return Column(children: [
          if (tok != null)
            _DetailRow(
                icon: Icons.token_outlined,
                label: 'Token (verified)',
                value: '${tok.symbol}  ${_short(tokenContract)}',
                color: accent,
                mono: true,
                copyValue: tokenContract),
          _DetailRow(
              icon: Icons.send_outlined,
              label: 'To (verified)',
              value: _short(to),
              color: toMismatch ? Colors.red : Colors.green,
              mono: true,
              copyValue: to),
          if (amountText.isNotEmpty)
            _DetailRow(
                icon: Icons.payments_outlined,
                label: 'Amount (verified)',
                value: amountText,
                color: amtMismatch ? Colors.red : Colors.green),
          if (toMismatch || amtMismatch)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      'WARNING: signed transaction differs from what was shown — do NOT accept',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
        ]);
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
