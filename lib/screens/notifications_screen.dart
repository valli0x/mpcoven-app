import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/keygen_models.dart';
import '../providers/keygen_provider.dart';
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

  Future<void> _dismiss(MailboxMessage message) async {
    final provider = context.read<AppProvider>();
    await provider.ackMessage(message.id);
  }
}

class _MessageCard extends StatelessWidget {
  final MailboxMessage message;
  final _MsgState state;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const _MessageCard({
    required this.message,
    required this.state,
    required this.onAccept,
    required this.onDismiss,
  });

  Map<String, dynamic> get _body {
    final b = message.body;
    if (b is Map) return b.cast<String, dynamic>();
    return const {};
  }

  bool get _isKeygen => message.type == 'keygen-init';
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
                    _isKeygen ? Icons.vpn_key_rounded : Icons.mail_outline,
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
                        _isKeygen ? 'Keygen Request' : 'Message',
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
            if (_isKeygen) _buildFooter(context, accent),
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
            Text('Generating shared key…',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
          ],
        );
      case _MsgState.done:
        return Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Text('Shared key created',
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
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Accept & Generate'),
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

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.mono = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
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
