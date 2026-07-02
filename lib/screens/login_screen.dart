import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/keygen_provider.dart';
import '../services/metamask_service.dart';
import '../services/walletconnect_service.dart';
import '../widgets/app_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/wallet_connect_dialog.dart';

String _short(String a) {
  final s = a.trim();
  if (s.length <= 12) return s;
  return '${s.substring(0, 6)}…${s.substring(s.length - 4)}';
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onSettingsPressed;
  final String clientUrl;
  final String serverUrl;
  final void Function(String clientUrl, String serverUrl) onUrlsChanged;

  const LoginScreen({
    super.key,
    required this.onSettingsPressed,
    required this.clientUrl,
    required this.serverUrl,
    required this.onUrlsChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _addressController = TextEditingController();
  final _signatureController = TextEditingController();

  String? _nonce;
  String? _nonceMessage;
  bool _manualMode = false;
  bool _busy = false;

  // "Connecting to" — the client we point at + its bound identity.
  bool _editClientUrl = false;
  late final TextEditingController _clientUrlController =
      TextEditingController(text: widget.clientUrl);
  Map<String, dynamic>? _clientInfo; // /v1/identity
  bool _clientProbing = false;
  bool _clientUnreachable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _probeClient());
  }

  @override
  void didUpdateWidget(covariant LoginScreen old) {
    super.didUpdateWidget(old);
    if (old.clientUrl != widget.clientUrl) {
      _clientUrlController.text = widget.clientUrl;
      _probeClient();
    }
  }

  Future<void> _probeClient() async {
    setState(() {
      _clientProbing = true;
      _clientUnreachable = false;
    });
    final info = await context.read<AppProvider>().clientIdentityInfo();
    if (!mounted) return;
    setState(() {
      _clientProbing = false;
      _clientInfo = info;
      _clientUnreachable = info == null;
    });
  }

  void _saveClientUrl() {
    final url = _clientUrlController.text.trim();
    if (url.isEmpty) return;
    widget.onUrlsChanged(url, widget.serverUrl);
    setState(() => _editClientUrl = false);
    // The parent rebuilds ApiService; didUpdateWidget re-probes.
  }

  // Manual two-step: after the server sign-in, a second signature authorizes
  // the Go client itself (which binds to / enforces its owner address).
  bool _clientSignStep = false;
  String? _clientNonce;
  String? _clientMessage;

  void _showClientLoginError(AppProvider provider) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(provider.errorMessage ?? 'Client sign-in failed'),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 6),
    ));
    // Without a client token nothing works — return to a clean login.
    provider.logout();
  }

  bool get _hasMetaMask => MetaMaskService.instance.isAvailable;

  @override
  void dispose() {
    _addressController.dispose();
    _signatureController.dispose();
    _clientUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('mpcoven'),
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: AppBackground()),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.secondaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.security_rounded, size: 72, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        'MPC Wallet',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with your Ethereum wallet to manage shared accounts',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildConnectingCard(theme),
                const SizedBox(height: 20),

                if (_hasMetaMask && !_manualMode) ...[
                  _MetaMaskButton(
                    onPressed: _busy || provider.isLoading ? null : () => _loginWithMetaMask(provider),
                    isLoading: _busy || provider.isLoading,
                  ),
                  const SizedBox(height: 12),
                  _WalletConnectButton(
                    onPressed: _busy || provider.isLoading
                        ? null
                        : () => _loginWithWalletConnect(provider),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _manualMode = true),
                    child: const Text('Use manual sign-in'),
                  ),
                ] else if (!_hasMetaMask && !_manualMode) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.extension_outlined, color: theme.colorScheme.tertiary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('MetaMask not detected',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                              Text(
                                'Install the MetaMask browser extension for one-click sign-in.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _WalletConnectButton(
                    onPressed: _busy || provider.isLoading
                        ? null
                        : () => _loginWithWalletConnect(provider),
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    text: 'Manual Sign-in',
                    icon: Icons.edit_outlined,
                    onPressed: () => setState(() => _manualMode = true),
                  ),
                ] else ...[
                  _ManualFlow(
                    addressController: _addressController,
                    signatureController: _signatureController,
                    nonce: _nonce,
                    nonceMessage: _nonceMessage,
                    clientSignStep: _clientSignStep,
                    clientMessage: _clientMessage,
                    isLoading: provider.isLoading,
                    onRequestNonce: () => _requestNonce(provider),
                    onLogin: () => _manualLogin(provider),
                    onReset: _resetManual,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() {
                      _manualMode = false;
                      _nonce = null;
                      _nonceMessage = null;
                      _clientSignStep = false;
                      _clientNonce = null;
                      _clientMessage = null;
                      _signatureController.clear();
                    }),
                    label: Text(_hasMetaMask
                        ? 'Back to wallet sign-in'
                        : 'Back to QR sign-in'),
                  ),
                ],

                if (provider.errorMessage != null && provider.state == AppState.error) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(provider.errorMessage!,
                              style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: provider.clearError),
                      ],
                    ),
                  ),
                ],

                    const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectingCard(ThemeData theme) {
    final info = _clientInfo;
    final bound = info?['bound'] == true;
    final hasKeys = info?['has_keys'] == true;
    final authReq = info?['auth_required'] != false;
    final owner = (info?['address'] ?? '').toString();

    Widget status;
    if (_clientProbing) {
      status = Row(children: [
        const SizedBox(
            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text('Checking client…',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]);
    } else if (_clientUnreachable) {
      status = Row(children: [
        Icon(Icons.cloud_off_rounded, size: 15, color: theme.colorScheme.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text('Client not reachable — check the address',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error)),
        ),
      ]);
    } else if (bound && owner.isNotEmpty) {
      status = Row(children: [
        Icon(Icons.verified_user_rounded,
            size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Owned by ${_short(owner)} — sign in with this account'
            '${authReq ? '' : ' · auth off'}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ]);
    } else {
      status = Row(children: [
        Icon(Icons.fiber_new_rounded,
            size: 16, color: theme.colorScheme.tertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hasKeys
                ? 'Client has keys but is unbound'
                : 'Fresh client — first sign-in becomes its owner'
                    '${authReq ? '' : ' · auth off'}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Connecting to',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (!_editClientUrl)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: 'Change client address',
                  onPressed: () => setState(() => _editClientUrl = true),
                ),
              if (!_editClientUrl)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 8),
                  constraints: const BoxConstraints(),
                  icon: _clientProbing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 16),
                  tooltip: 'Re-check',
                  onPressed: _clientProbing ? null : _probeClient,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_editClientUrl) ...[
            TextField(
              controller: _clientUrlController,
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'http://localhost:8080',
                prefixIcon: Icon(Icons.link, size: 18),
              ),
              onSubmitted: (_) => _saveClientUrl(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _editClientUrl = false;
                    _clientUrlController.text = widget.clientUrl;
                  }),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                    onPressed: _saveClientUrl, child: const Text('Save')),
              ],
            ),
          ] else ...[
            Text(widget.clientUrl,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontFamily: 'monospace')),
            const SizedBox(height: 8),
            status,
          ],
        ],
      ),
    );
  }

  Future<void> _loginWithWalletConnect(AppProvider provider) async {
    if (!WalletConnectService.instance.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'WalletConnect not configured yet — admin needs to set a Project ID.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await showDialog<WalletConnectResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const WalletConnectDialog(),
      );

      if (result == null) return; // user closed dialog

      final address = result.address;
      final nonceResp = await provider.requestNonce(address);
      if (nonceResp == null) return;

      final signature = await WalletConnectService.instance.personalSign(
        session: result.session,
        message: nonceResp.message,
        address: address,
      );

      final loginResult = await provider.login(address, signature, nonceResp.nonce);
      if (loginResult != null && await provider.clientAuthRequired()) {
        // Second signature: authenticate to the Go client itself.
        final ok = await provider.clientLogin(
          address,
          (msg) => WalletConnectService.instance.personalSign(
            session: result.session,
            message: msg,
            address: address,
          ),
        );
        if (!ok && mounted) _showClientLoginError(provider);
      }

      // Close out the WC session — we got what we needed.
      WalletConnectService.instance.disconnect(result.session);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WalletConnect error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginWithMetaMask(AppProvider provider) async {
    setState(() => _busy = true);
    try {
      final mm = MetaMaskService.instance;
      final address = await mm.connect();

      final nonceResp = await provider.requestNonce(address);
      if (nonceResp == null) return;

      final signature = await mm.personalSign(nonceResp.message, address);

      final loginResult = await provider.login(address, signature, nonceResp.nonce);
      if (loginResult != null && await provider.clientAuthRequired()) {
        // Second signature: authenticate to the Go client itself.
        final ok = await provider.clientLogin(
          address,
          (msg) => mm.personalSign(msg, address),
        );
        if (!ok && mounted) _showClientLoginError(provider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('MetaMask error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestNonce(AppProvider provider) async {
    final addr = _addressController.text.trim();
    if (addr.isEmpty) return;
    final result = await provider.requestNonce(addr);
    if (result != null) {
      setState(() {
        _nonce = result.nonce;
        _nonceMessage = result.message;
      });
    }
  }

  Future<void> _manualLogin(AppProvider provider) async {
    final addr = _addressController.text.trim();
    final sig = _signatureController.text.trim();
    if (addr.isEmpty || sig.isEmpty) return;

    if (!_clientSignStep) {
      // Phase 1: server sign-in.
      if (_nonce == null) return;
      final result = await provider.login(addr, sig, _nonce!);
      if (result == null) return;
      // Local client with CLIENT_AUTH=none: no second signature needed.
      if (!await provider.clientAuthRequired()) {
        provider.refreshPairs();
        provider.refreshAccounts();
        return;
      }
      // Phase 2: fetch a client nonce and ask for a second signature.
      final cn = await provider.clientRequestNonce(addr);
      if (cn == null) {
        if (mounted) _showClientLoginError(provider);
        return;
      }
      setState(() {
        _clientSignStep = true;
        _clientNonce = cn.nonce;
        _clientMessage = cn.message;
        _signatureController.clear();
      });
      return;
    }

    // Phase 2 submit: authorize the Go client with the second signature.
    if (_clientNonce == null) return;
    final ok = await provider.clientLoginRaw(addr, sig, _clientNonce!);
    if (!ok) {
      if (mounted) _showClientLoginError(provider);
      _resetManual();
      return;
    }
    provider.refreshPairs();
    provider.refreshAccounts();
  }

  void _resetManual() {
    setState(() {
      _nonce = null;
      _nonceMessage = null;
      _clientSignStep = false;
      _clientNonce = null;
      _clientMessage = null;
      _signatureController.clear();
    });
  }
}

class _MetaMaskButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _MetaMaskButton({required this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF6851B), Color(0xFFE2761B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: const Color(0xFFF6851B).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.white, size: 26),
                      const SizedBox(width: 12),
                      Text(
                        'Sign in with MetaMask',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _WalletConnectButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _WalletConnectButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B99FC), Color(0xFF6259CE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: const Color(0xFF3B99FC).withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Scan QR with mobile wallet',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualFlow extends StatelessWidget {
  final TextEditingController addressController;
  final TextEditingController signatureController;
  final String? nonce;
  final String? nonceMessage;
  final bool clientSignStep;
  final String? clientMessage;
  final bool isLoading;
  final VoidCallback onRequestNonce;
  final VoidCallback onLogin;
  final VoidCallback onReset;

  const _ManualFlow({
    required this.addressController,
    required this.signatureController,
    required this.nonce,
    required this.nonceMessage,
    required this.clientSignStep,
    required this.clientMessage,
    required this.isLoading,
    required this.onRequestNonce,
    required this.onLogin,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (clientSignStep) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.verified_user_outlined,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Step 2 — authorize this client',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Sign this second message so the Go client accepts you as its owner:',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              clientMessage ?? '',
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: signatureController,
            decoration: const InputDecoration(
              hintText: '0x... (signature)',
              prefixIcon: Icon(Icons.draw_outlined),
              labelText: 'Client signature',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          GradientButton(
            text: 'Authorize client',
            icon: Icons.login,
            isLoading: isLoading,
            onPressed: onLogin,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onReset, child: const Text('Start over')),
        ],
      );
    }

    if (nonce == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Manual sign-in',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextFormField(
            controller: addressController,
            decoration: const InputDecoration(
              hintText: '0x...',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              labelText: 'ETH Address',
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(
            text: 'Continue',
            icon: Icons.arrow_forward,
            isLoading: isLoading,
            onPressed: onRequestNonce,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sign this message with your wallet:',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            nonceMessage ?? nonce!,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: signatureController,
          decoration: const InputDecoration(
            hintText: '0x... (signature)',
            prefixIcon: Icon(Icons.draw_outlined),
            labelText: 'Signature',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        GradientButton(
          text: 'Sign In',
          icon: Icons.login,
          isLoading: isLoading,
          onPressed: onLogin,
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onReset, child: const Text('Use a different address')),
      ],
    );
  }
}
