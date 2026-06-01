import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/keygen_provider.dart';
import '../services/cache_service.dart';
import '../widgets/page_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  final String clientUrl;
  final String serverUrl;
  final void Function(String clientUrl, String serverUrl) onUrlsChanged;

  const SettingsScreen({
    super.key,
    required this.clientUrl,
    required this.serverUrl,
    required this.onUrlsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _clientUrlController;
  late final TextEditingController _serverUrlController;

  @override
  void initState() {
    super.initState();
    _clientUrlController = TextEditingController(text: widget.clientUrl);
    _serverUrlController = TextEditingController(text: widget.serverUrl);
  }

  @override
  void dispose() {
    _clientUrlController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PageScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dns_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('Server Configuration', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _clientUrlController,
                    decoration: InputDecoration(
                      labelText: 'Client URL (local)',
                      hintText: 'http://localhost:8080',
                      prefixIcon: const Icon(Icons.computer),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serverUrlController,
                    decoration: InputDecoration(
                      labelText: 'Host Server URL',
                      hintText: 'http://localhost:8282',
                      prefixIcon: const Icon(Icons.cloud_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        widget.onUrlsChanged(
                          _clientUrlController.text.trim(),
                          _serverUrlController.text.trim(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URLs updated'), behavior: SnackBarBehavior.floating),
                        );
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Maintenance card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('Maintenance',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'If something looks stale or broken after an update, use these to refresh.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Force update (clear cache & reload)'),
                    onPressed: () => _forceUpdate(context),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Reset all data (logout + clear)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => _resetAllData(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('About', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoTile(title: 'App', value: 'Signature Escrow'),
                  const Divider(),
                  _InfoTile(title: 'Protocols', value: 'ECDSA (ETH), FROST (BTC)'),
                  const Divider(),
                  _InfoTile(title: 'Threshold', value: '2-of-2 Multi-signature'),
                  const Divider(),
                  _InfoTile(title: 'Auth', value: 'MetaMask EIP-191 + JWT'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('How to Use', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _StepTile(number: '1', title: 'Authenticate', description: 'Sign a nonce with MetaMask to get a JWT'),
                  _StepTile(number: '2', title: 'Create Pair', description: 'Pair with another ETH address'),
                  _StepTile(number: '3', title: 'Generate Keys', description: 'Both parties run keygen (ECDSA or FROST)'),
                  _StepTile(number: '4', title: 'Transact', description: 'Build TX hash, sign cooperatively, send'),
                  _StepTile(number: '5', title: 'Withdraw', description: 'Use incomplete-signature flow for escrow'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _forceUpdate(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force update'),
        content: const Text(
          'This will unregister the service worker, clear all caches, and reload the app. Your sign-in session is kept.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Force update')),
        ],
      ),
    );
    if (confirm != true) return;
    await CacheService.instance.hardRefresh();
  }

  Future<void> _resetAllData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This will log you out, clear all stored settings and cache, then reload. You will need to sign in again.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    // Logout (clears in-memory + persisted JWT)
    context.read<AppProvider>().logout();
    // Clear ALL SharedPreferences (any future settings too)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Clear browser caches + SW, then reload
    await CacheService.instance.hardRefresh();
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _StepTile({required this.number, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
            child: Center(
              child: Text(number, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
