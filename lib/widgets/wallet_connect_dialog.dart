import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/walletconnect_service.dart';

class WalletConnectDialog extends StatefulWidget {
  const WalletConnectDialog({super.key});

  @override
  State<WalletConnectDialog> createState() => _WalletConnectDialogState();
}

class _WalletConnectDialogState extends State<WalletConnectDialog> {
  String? _uri;
  String? _error;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final res = await WalletConnectService.instance.startSession();
      if (!mounted) return;
      setState(() {
        _uri = res.uri;
        _starting = false;
      });

      final result = await res.approval;
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _starting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_scanner,
                      color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Scan with mobile wallet',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Open MetaMask, Trust, Rainbow, or any WalletConnect-compatible wallet and scan this code.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              if (_starting) ...[
                const SizedBox(
                  width: 260,
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else if (_error != null) ...[
                Container(
                  width: 260,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.error),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: _uri!,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy link'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _uri!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('WC link copied')),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Waiting for approval…',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
