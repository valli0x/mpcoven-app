import 'dart:async';
import 'dart:convert';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

/// WalletConnect v2 Project ID — register a free one at https://cloud.reown.com
/// and replace this placeholder. The QR sign-in button will stay disabled
/// (with a helpful tooltip) until a real ID is set.
const String kWalletConnectProjectId = '7a217a0a4ff507d0fdfde5749fa97160';

class WalletConnectResult {
  final String address;
  final SessionData session;
  WalletConnectResult({required this.address, required this.session});
}

class WalletConnectService {
  static final WalletConnectService instance = WalletConnectService._();
  WalletConnectService._();

  Web3App? _client;
  Completer<SessionData>? _approvalCompleter;

  bool get isConfigured =>
      kWalletConnectProjectId.isNotEmpty &&
      kWalletConnectProjectId != 'YOUR_PROJECT_ID';

  Future<void> _ensureInit() async {
    if (_client != null) return;
    if (!isConfigured) {
      throw Exception(
          'WalletConnect not configured — admin needs to set a Project ID.');
    }
    _client = await Web3App.createInstance(
      projectId: kWalletConnectProjectId,
      metadata: const PairingMetadata(
        name: 'mpcoven',
        description: '2-of-2 MPC shared wallet for Ethereum and Bitcoin',
        url: 'https://mpcoven.net/app/',
        icons: ['https://mpcoven.net/app/icons/Icon-512.png'],
      ),
    );
  }

  /// Start a new session. Returns the WC URI immediately for QR rendering.
  /// The returned `approval` future completes once the user approves the
  /// connection in their mobile wallet.
  Future<({String uri, Future<WalletConnectResult> approval})>
      startSession() async {
    await _ensureInit();

    final connectRes = await _client!.connect(
      requiredNamespaces: {
        'eip155': const RequiredNamespace(
          chains: ['eip155:1'],
          methods: ['personal_sign'],
          events: ['accountsChanged', 'chainChanged'],
        ),
      },
    );

    final approval = connectRes.session.future.then((session) {
      final acct =
          session.namespaces['eip155']?.accounts.first ?? '';
      // accounts are formatted as "eip155:1:0xAddress"
      final addr = acct.split(':').last;
      return WalletConnectResult(address: addr, session: session);
    });

    return (uri: connectRes.uri.toString(), approval: approval);
  }

  /// Request a personal_sign (EIP-191) from the connected wallet.
  Future<String> personalSign({
    required SessionData session,
    required String message,
    required String address,
  }) async {
    if (_client == null) throw Exception('Not initialized');

    final hexMessage = '0x' +
        utf8
            .encode(message)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();

    final result = await _client!.request(
      topic: session.topic,
      chainId: 'eip155:1',
      request: SessionRequestParams(
        method: 'personal_sign',
        params: [hexMessage, address],
      ),
    );
    return result as String;
  }

  Future<void> disconnect(SessionData session) async {
    try {
      await _client?.disconnectSession(
        topic: session.topic,
        reason: const WalletConnectError(
            code: 6000, message: 'User disconnected'),
      );
    } catch (_) {}
  }
}
