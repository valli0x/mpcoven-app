import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/keygen_models.dart';
import '../services/api_service.dart';

const _kTokenKey = 'auth_token';
const _kAddressKey = 'auth_address';

enum AppState { idle, loading, success, error }

enum KeygenJobStatus { running, done, failed }

/// A single in-flight (or finished) shared-key generation. Tracking these in
/// the provider lets several keygens run in parallel, each with its own card.
class KeygenJob {
  final String id; // == session_id
  final String partner;
  final String protocol; // 'ecdsa' | 'frost'
  final String network; // 'eth' | 'btc'
  final int index;
  KeygenJobStatus status;
  String? error;
  String? resultAddress;

  KeygenJob({
    required this.id,
    required this.partner,
    required this.protocol,
    required this.network,
    required this.index,
    this.status = KeygenJobStatus.running,
    this.error,
    this.resultAddress,
  });

  bool get isEth => network == 'eth';
}

class AppProvider extends ChangeNotifier {
  final ApiService _apiService;

  AppState _state = AppState.idle;
  String? _errorMessage;

  // Auth
  String? _authAddress;
  String? _authToken;
  bool _isRestoring = true;

  // Pairing
  PendingPairs? _pendingPairs;

  // Mailbox
  List<MailboxMessage> _messages = [];

  // Accounts
  List<AccountMeta> _accounts = [];

  // Keygen
  List<GeneratedKey> _generatedKeys = [];

  // Active / recent keygen jobs (parallel-capable).
  final List<KeygenJob> _keygenJobs = [];

  // User-defined exchanges (business state lives on the Go client).
  List<ExchangeEntry> _exchanges = [];

  AppProvider({required ApiService apiService}) : _apiService = apiService;

  ApiService get apiService => _apiService;
  AppState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == AppState.loading;
  bool get isAuthenticated => _apiService.isAuthenticated;
  bool get isRestoring => _isRestoring;
  String? get authAddress => _authAddress;
  PendingPairs? get pendingPairs => _pendingPairs;
  List<MailboxMessage> get messages => List.unmodifiable(_messages);
  List<AccountMeta> get accounts => List.unmodifiable(_accounts);

  // (removed dead _filteredPairs helper)
  List<GeneratedKey> get generatedKeys => List.unmodifiable(_generatedKeys);
  List<KeygenJob> get keygenJobs => List.unmodifiable(_keygenJobs);
  List<ExchangeEntry> get exchanges => List.unmodifiable(_exchanges);

  // ── Exchanges (Go client) ──

  Future<void> loadExchanges() async {
    try {
      _exchanges = await _apiService.listExchanges();
      notifyListeners();
    } catch (e) {
      _handleAuthError(e);
    }
  }

  /// Create an empty exchange draft on the client; refreshes the list.
  Future<bool> addExchange() async {
    try {
      await _apiService.createExchange();
      await loadExchanges();
      return true;
    } catch (e) {
      _handleAuthError(e);
      return false;
    }
  }

  /// Save addresses into an existing exchange.
  Future<bool> updateExchange(
      String id, String addressA, String addressB) async {
    try {
      await _apiService.updateExchange(id, addressA.trim(), addressB.trim());
      await loadExchanges();
      return true;
    } catch (e) {
      _handleAuthError(e);
      return false;
    }
  }

  Future<void> removeExchange(String id) async {
    try {
      await _apiService.deleteExchange(id);
      await loadExchanges();
    } catch (e) {
      _handleAuthError(e);
    }
  }

  // ── Co-sign history ──

  List<CosignEvent> _cosignHistory = [];
  List<CosignEvent> get cosignHistory => List.unmodifiable(_cosignHistory);

  Future<void> loadCosignHistory() async {
    try {
      _cosignHistory = await _apiService.getCosignHistory();
      notifyListeners();
    } catch (e) {
      _handleAuthError(e);
    }
  }

  Future<void> clearCosignHistory() async {
    try {
      await _apiService.clearCosignHistory();
      _cosignHistory = [];
      notifyListeners();
    } catch (e) {
      _handleAuthError(e);
    }
  }

  // ── Co-sign (MPC withdrawal) notification flow ──

  /// Partner ETH address derived from an account's stored party id
  /// (normalizePartyID = lowercased, 0x-stripped, so we re-add 0x).
  String _partnerAddressFor(AccountMeta account) {
    final other = (account.pairOther ?? '').trim();
    return other.startsWith('0x') ? other : '0x$other';
  }

  /// Initiator: tell the partner a transaction is waiting to be co-signed.
  /// Mirrors the keygen-init notification, but type `sign-request`.
  Future<void> notifySignRequest({
    required AccountMeta account,
    required String toAddress,
    required String amountBase,
    required String hashTx,
    String txData = '',
  }) async {
    final partner = _partnerAddressFor(account);
    final pairId = findPairIdWith(partner);
    if (pairId == null) return; // no accepted pair -> nothing to notify
    try {
      await _apiService.sendMailboxMessage(
        to: partner,
        pairId: pairId,
        type: 'sign-request',
        body: {
          'alg': account.network == 'eth' ? 'ecdsa' : 'frost',
          'name': '${account.network}/${account.index}',
          'network': account.network,
          'index': account.index,
          'escrow_address': account.address,
          'to': toAddress,
          'amount': amountBase,
          'hash_tx': hashTx,
          'tx_data': txData,
          'initiator': _authAddress,
        },
      );
    } catch (_) {/* best-effort: the relay still carries the incsig */}
  }

  /// Initiator one-shot: create the tx hash, notify the partner, and send our
  /// incomplete signature — all under the hood. Broadcast happens later from
  /// the partner's Activity (they receive tx_data in the notification).
  /// Returns null on success, or an error message.
  Future<String?> startCoSign({
    required AccountMeta account,
    required String toAddress,
    required BigInt amountBase,
  }) async {
    try {
      final hashResp = await _apiService.createTxHash(
        network: account.network,
        from: account.address,
        to: toAddress,
        amount: amountBase.toInt(),
      );
      await notifySignRequest(
        account: account,
        toAddress: toAddress,
        amountBase: amountBase.toString(),
        hashTx: hashResp.hash,
        txData: hashResp.txData ?? '',
      );
      await _apiService.sendIncompleteSignature(
        alg: account.network == 'eth' ? 'ecdsa' : 'frost',
        name: '${account.network}/${account.index}',
        escrowAddress: account.address,
        hashTx: hashResp.hash,
        myId: account.pairMyId ?? '',
        anotherId: account.pairOther ?? '',
        to: toAddress,
        amount: amountBase.toString(),
      );
      await loadCosignHistory();
      return null;
    } catch (e) {
      _handleAuthError(e);
      return e is ApiError ? e.message : '$e';
    }
  }

  /// Broadcast a completed co-sign (acceptor side) from Activity.
  /// Returns the on-chain tx hash, or null on failure.
  Future<String?> broadcastCosign(CosignEvent ev) async {
    try {
      final resp = await _apiService.sendTransaction(
        network: ev.network,
        signature: ev.signature,
        txData: ev.txData,
        to: ev.to,
        value: ev.amount,
      );
      await loadCosignHistory();
      return resp.txHash;
    } catch (e) {
      _handleAuthError(e);
      _errorMessage = e is ApiError ? e.message : '$e';
      notifyListeners();
      return null;
    }
  }

  /// Acceptor: complete the co-signature for an incoming `sign-request`.
  /// Returns the complete signature hex, or null on failure.
  Future<String?> acceptSignRequest(MailboxMessage message) async {
    final body = message.body;
    if (body is! Map) return null;

    final escrow = (body['escrow_address'] ?? '').toString();
    final hash = (body['hash_tx'] ?? '').toString();
    final to = (body['to'] ?? '').toString();
    final amount = (body['amount'] ?? '').toString();
    final txData = (body['tx_data'] ?? '').toString();

    // Use OUR local account for this escrow (our own party ids / index).
    AccountMeta? acct;
    for (final a in _accounts) {
      if (a.address.toLowerCase() == escrow.toLowerCase()) {
        acct = a;
        break;
      }
    }
    if (acct == null) {
      _errorMessage = 'No local account for this escrow address';
      _state = AppState.error;
      notifyListeners();
      return null;
    }

    try {
      final resp = await _apiService.acceptIncompleteSignature(
        alg: acct.network == 'eth' ? 'ecdsa' : 'frost',
        name: '${acct.network}/${acct.index}',
        escrowAddress: acct.address,
        myId: acct.pairMyId ?? '',
        anotherId: acct.pairOther ?? '',
        hashTx: hash.isNotEmpty ? hash : null,
        to: to,
        amount: amount,
        txData: txData,
      );
      await ackMessage(message.id);
      await refreshMessages();
      return resp.completeSignature;
    } catch (e) {
      _handleAuthError(e);
      _errorMessage = e is ApiError ? e.message : '$e';
      _state = AppState.error;
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    _state = AppState.idle;
    notifyListeners();
  }

  // ── Auth ──

  Future<NonceResponse?> requestNonce(String address) async {
    return _run(() => _apiService.requestNonce(address));
  }

  Future<LoginResponse?> login(String address, String signature, String nonce) async {
    final result = await _run(() => _apiService.login(address, signature, nonce));
    if (result != null) {
      _authAddress = result.address;
      _authToken = result.token;
      await _persistSession(result.token, result.address);
      _startPolling();
    }
    return result;
  }

  void logout() {
    _stopPolling();
    _apiService.clearToken();
    _authAddress = null;
    _authToken = null;
    _pendingPairs = null;
    _messages = [];
    _accounts = const [];
    _keygenJobs.clear();
    _clearPersistedSession();
    notifyListeners();
  }

  /// True if an error means the session is no longer valid (token expired).
  bool _isAuthError(Object e) =>
      e is ApiError &&
      (e.statusCode == 401 ||
          e.message.toLowerCase().contains('expired') ||
          e.message.toLowerCase().contains('invalid or expired'));

  /// Session expired → log out silently so the UI returns to the login screen
  /// (user re-signs a nonce to get a fresh 24h token). Returns true if handled.
  bool _handleAuthError(Object e) {
    if (!_isAuthError(e)) return false;
    _sessionExpired = true;
    logout();
    return true;
  }

  bool _sessionExpired = false;
  bool get sessionExpired => _sessionExpired;
  void clearSessionExpired() => _sessionExpired = false;

  /// Restore a previously persisted session (called once at app start).
  /// Returns true if a valid session was restored.
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kTokenKey);
      final address = prefs.getString(_kAddressKey);
      if (token == null || address == null) {
        _isRestoring = false;
        notifyListeners();
        return false;
      }

      _apiService.setToken(token);
      _authToken = token;
      _authAddress = address;

      // Verify the token is still valid by hitting an authenticated endpoint.
      try {
        await _apiService.getPendingPairs();
      } catch (_) {
        // Token expired or invalid — clear it.
        _apiService.clearToken();
        _authToken = null;
        _authAddress = null;
        await _clearPersistedSession();
        _isRestoring = false;
        notifyListeners();
        return false;
      }

      _startPolling();
      _isRestoring = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isRestoring = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _persistSession(String token, String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      await prefs.setString(_kAddressKey, address);
    } catch (_) {}
  }

  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kTokenKey);
      await prefs.remove(_kAddressKey);
    } catch (_) {}
  }

  // ── Background polling for inbox ──

  Timer? _pollTimer;

  void _startPolling() {
    _pollTimer?.cancel();
    // Use silent refresh so the initial fetch right after login doesn't
    // flash an error banner if the server is slow / unreachable.
    _silentRefresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _silentRefresh();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _silentRefresh() async {
    try {
      final result = await _apiService.getPendingMessages();
      _messages = await _processCancellations(result);
      notifyListeners();
    } catch (e) {
      // A 401 during the background poll means the token expired — log out so
      // the UI returns to login instead of silently failing forever.
      _handleAuthError(e);
    }
  }

  /// Drop any keygen-init whose initiator later sent a keygen-cancel (and the
  /// cancel notices themselves), ack them server-side, return the cleaned list.
  /// `pair-removed` is a service message — never shown, just acked. (We no
  /// longer "hide" partners: a pair either exists on the server or is deleted.)
  Future<List<MailboxMessage>> _processCancellations(
      List<MailboxMessage> msgs) async {
    final cancelledSessions = <String>{};
    final toAck = <String>[];

    for (final m in msgs) {
      if (m.type == 'keygen-cancel') {
        final b = m.body;
        final sid = (b is Map ? b['session_id'] : null)?.toString();
        if (sid != null) cancelledSessions.add(sid);
        toAck.add(m.id);
      } else if (m.type == 'pair-removed') {
        // Partner deleted the pair — refresh so it disappears from our list.
        toAck.add(m.id);
      }
    }

    final kept = <MailboxMessage>[];
    for (final m in msgs) {
      if (m.type == 'keygen-cancel' || m.type == 'pair-removed') continue;
      if (m.type == 'keygen-init') {
        final b = m.body;
        final sid = (b is Map ? b['session_id'] : null)?.toString();
        if (sid != null && cancelledSessions.contains(sid)) {
          toAck.add(m.id); // cancelled invite — remove it
          continue;
        }
      }
      kept.add(m);
    }

    for (final id in toAck) {
      try {
        await _apiService.ackMessage(id);
      } catch (_) {}
    }
    return kept;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  // ── Pairing ──

  Future<Pair?> createPair(String partnerAddress) async {
    final result = await _run(() => _apiService.createPair(partnerAddress));
    if (result != null) await refreshPairs();
    return result;
  }

  Future<Pair?> acceptPair(String pairId) async {
    final result = await _run(() => _apiService.acceptPair(pairId));
    if (result != null) {
      await refreshPairs();
      await refreshAccounts();
    }
    return result;
  }

  Future<void> refreshPairs() async {
    // Silent — background fetch.
    try {
      _pendingPairs = await _apiService.getPendingPairs();
      notifyListeners();
    } catch (_) {}
  }

  // ── Mailbox ──

  Future<void> refreshMessages() async {
    // Silent — background fetch should not surface as a global error state.
    try {
      _messages = await _processCancellations(
          await _apiService.getPendingMessages());
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> sendMessage({
    required String to,
    required String pairId,
    required String type,
    required Map<String, dynamic> body,
  }) async {
    final result = await _run(
      () => _apiService.sendMailboxMessage(to: to, pairId: pairId, type: type, body: body),
    );
    if (result != null) await refreshMessages();
    return result;
  }

  Future<void> ackMessage(String messageId) async {
    await _run(() => _apiService.ackMessage(messageId));
    await refreshMessages();
  }

  // ── Accounts ──

  Future<void> refreshAccounts() async {
    // Silent — local client may be unreachable (mixed content / not running)
    // and we don't want a red error banner flashing on the deployed web app.
    try {
      _accounts = await _apiService.listAccounts();
      notifyListeners();
    } catch (_) {
      _accounts = const [];
      notifyListeners();
    }
  }

  // ── Delete ──

  /// Permanently delete ALL shared accounts with [partnerAddress] from this
  /// client (cascade), then delete the pair on the server (gone for both —
  /// re-pair needed to use again). Irreversible for the deleted key shares.
  Future<bool> deleteAccountsWithPartner(String partnerAddress) async {
    final lower = partnerAddress.toLowerCase();
    final toDelete = _accounts
        .where((a) => (a.pairOther ?? '').toLowerCase() == lower)
        .toList();

    bool allOk = true;
    for (final a in toDelete) {
      try {
        await _apiService.deleteAccount(
          network: a.network,
          index: a.index,
          address: a.address,
        );
      } catch (_) {
        allOk = false;
      }
    }

    // Notify the partner so their side refreshes, THEN delete the pair on the
    // server. Send the notice before delete — deleting invalidates the
    // pair-scoped mailbox send.
    final pairId = findPairIdWith(partnerAddress);
    if (pairId != null && _authAddress != null) {
      try {
        await _apiService.sendMailboxMessage(
          to: partnerAddress,
          pairId: pairId,
          type: 'pair-removed',
          body: {'by': _authAddress},
        );
      } catch (_) {}
      try {
        await _apiService.deletePair(pairId);
      } catch (_) {}
    }

    await refreshPairs();
    await refreshAccounts();
    notifyListeners();
    return allOk;
  }

  /// Permanently delete ONE shared account (single escrow) from this client.
  /// Irreversible — the 2-of-2 key share is destroyed.
  Future<bool> deleteSingleAccount(AccountMeta account) async {
    try {
      await _apiService.deleteAccount(
        network: account.network,
        index: account.index,
        address: account.address,
      );
      await refreshAccounts();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Find the accepted pair_id with a given partner address.
  String? findPairIdWith(String partnerAddress) {
    final pairs = _pendingPairs;
    if (pairs == null) return null;
    final lower = partnerAddress.toLowerCase();
    for (final p in [...pairs.incoming, ...pairs.outgoing]) {
      if (p.status != 'accepted') continue;
      if (p.initiator.toLowerCase() == lower || p.partner.toLowerCase() == lower) {
        return p.id;
      }
    }
    return null;
  }

  /// Pick the next available account index (1-100) for a network. Also reserves
  /// indices used by running jobs so parallel keygens don't collide.
  int nextFreeIndex(String network) {
    final used = <int>{
      ..._accounts.where((a) => a.network == network).map((a) => a.index),
      ..._keygenJobs
          .where((j) => j.network == network && j.status == KeygenJobStatus.running)
          .map((j) => j.index),
    };
    for (var i = 1; i <= 100; i++) {
      if (!used.contains(i)) return i;
    }
    return 1;
  }

  String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  // ── Keygen orchestration ──

  /// Start a shared key generation as a tracked, non-blocking job. Returns the
  /// job (already added to [keygenJobs]) or null if it couldn't be started.
  /// Several jobs can run at once — each gets its own card in the UI.
  Future<KeygenJob?> startKeygen({
    required String protocol, // 'ecdsa' or 'frost'
    required String partnerAddress,
  }) async {
    if (_authAddress == null) {
      _errorMessage = 'Not authenticated';
      _state = AppState.error;
      notifyListeners();
      return null;
    }

    // Refresh first — the local cache may be stale.
    await refreshPairs();

    final pairId = findPairIdWith(partnerAddress);
    if (pairId == null) {
      _errorMessage = 'No accepted pair with this partner. Create a pair first.';
      _state = AppState.error;
      notifyListeners();
      return null;
    }

    final network = protocol == 'ecdsa' ? 'eth' : 'btc';
    final job = KeygenJob(
      id: _generateUuid(),
      partner: partnerAddress,
      protocol: protocol,
      network: network,
      index: nextFreeIndex(network),
    );
    _keygenJobs.insert(0, job);
    notifyListeners();

    // Fire and forget — the job updates itself.
    _runKeygenJob(job, pairId);
    return job;
  }

  Future<void> _runKeygenJob(KeygenJob job, String pairId) async {
    // 1) Notify the partner.
    try {
      await _apiService.sendMailboxMessage(
        to: job.partner,
        pairId: pairId,
        type: 'keygen-init',
        body: {
          'session_id': job.id,
          'protocol': job.protocol,
          'network': job.network,
          'index': job.index,
          'initiator': _authAddress,
        },
      );
    } catch (e) {
      if (!_keygenJobs.contains(job)) return;
      job.status = KeygenJobStatus.failed;
      job.error = 'Failed to notify partner';
      notifyListeners();
      return;
    }

    // 2) Run our half. Direct API call (no global _state) so parallel jobs
    //    don't clobber each other.
    try {
      final req = KeygenRequest(
        sessionId: job.id,
        myId: _authAddress!,
        anotherId: job.partner,
        network: job.network,
        index: job.index,
      );
      final resp = job.protocol == 'ecdsa'
          ? await _apiService.keygenECDSA(req)
          : await _apiService.keygenFROST(req);

      // Dropped (cancelled) while running?
      if (!_keygenJobs.contains(job)) return;

      _generatedKeys.insert(
        0,
        GeneratedKey(
          type: job.protocol == 'ecdsa' ? 'ECDSA' : 'FROST',
          name: '${job.network.toUpperCase()} #${job.index}',
          publicKey: resp.publicKey,
          address: resp.address,
          createdAt: DateTime.now(),
        ),
      );
      job.status = KeygenJobStatus.done;
      job.resultAddress = resp.address;
      notifyListeners();
      // New account appears in the Accounts tab automatically.
      refreshAccounts();
    } catch (e) {
      if (!_keygenJobs.contains(job)) return;
      job.status = KeygenJobStatus.failed;
      job.error = e is ApiError ? e.message : '$e';
      notifyListeners();
    }
  }

  /// Cancel / dismiss a job card. If it was still running, tell the partner so
  /// their pending invite disappears and they don't complete a dead session.
  void removeKeygenJob(KeygenJob job) {
    final wasRunning = job.status == KeygenJobStatus.running;
    _keygenJobs.remove(job);
    notifyListeners();

    if (wasRunning) {
      // Authoritative, atomic cancel on the server. If the partner already
      // claimed the session this returns false (too late) — but we still drop
      // the card locally; the partner will complete their half.
      _apiService.cancelSession(job.id).catchError((_) => false);

      final pairId = findPairIdWith(job.partner);
      if (pairId != null) {
        // Also notify via mailbox so the partner's invite disappears.
        _apiService
            .sendMailboxMessage(
              to: job.partner,
              pairId: pairId,
              type: 'keygen-cancel',
              body: {'session_id': job.id},
            )
            .catchError((_) => '');
      }
    }
  }

  /// Fetch the mailbox fresh and report whether a keygen-cancel exists for the
  /// given session id (initiator changed their mind).
  Future<bool> _isSessionCancelled(String sessionId) async {
    try {
      final fresh = await _apiService.getPendingMessages();
      for (final m in fresh) {
        if (m.type != 'keygen-cancel') continue;
        final b = m.body;
        final sid = (b is Map ? b['session_id'] : null)?.toString();
        if (sid == sessionId) return true;
      }
    } catch (_) {
      // If we can't verify, fall through (treat as not cancelled).
    }
    return false;
  }

  /// Accept a keygen-init message: parse the body and run our side of keygen
  /// with the parameters chosen by the initiator.
  Future<GeneratedKey?> acceptKeygenInvite(MailboxMessage message) async {
    if (_authAddress == null) return null;

    final body = message.body;
    if (body is! Map) {
      _errorMessage = 'Invalid keygen invite payload';
      _state = AppState.error;
      notifyListeners();
      return null;
    }

    final sessionId = body['session_id'] as String?;
    final protocol = body['protocol'] as String?;
    final index = body['index'] as int?;
    if (sessionId == null || protocol == null || index == null) {
      _errorMessage = 'Keygen invite missing required fields';
      _state = AppState.error;
      notifyListeners();
      return null;
    }

    // Authoritative race guard: atomically claim the session on the server.
    // If the initiator cancelled (even a millisecond ago), claim returns false
    // and we abort instead of running a dead keygen.
    bool claimed;
    try {
      claimed = await _apiService.claimSession(sessionId);
    } catch (_) {
      // Fall back to the mailbox check if the claim call failed outright.
      claimed = !await _isSessionCancelled(sessionId);
    }
    if (!claimed) {
      await ackMessage(message.id); // remove the stale invite
      await refreshMessages();
      _errorMessage = 'The initiator cancelled this keygen.';
      _state = AppState.error;
      notifyListeners();
      return null;
    }

    final result = protocol == 'ecdsa'
        ? await generateECDSAKey(
            sessionId: sessionId,
            myId: _authAddress!,
            anotherId: message.from,
            index: index,
          )
        : await generateFROSTKey(
            sessionId: sessionId,
            myId: _authAddress!,
            anotherId: message.from,
            index: index,
          );

    if (result != null) {
      await ackMessage(message.id);
      await refreshAccounts();
    }
    return result;
  }

  // ── Keygen ──

  Future<GeneratedKey?> generateECDSAKey({
    required String sessionId,
    required String myId,
    required String anotherId,
    String network = 'eth',
    int index = 1,
  }) async {
    final request = KeygenRequest(
      sessionId: sessionId,
      myId: myId,
      anotherId: anotherId,
      network: network,
      index: index,
    );
    final response = await _run(() => _apiService.keygenECDSA(request));
    if (response == null) return null;
    final key = GeneratedKey(
      type: 'ECDSA',
      name: 'ETH #$index',
      publicKey: response.publicKey,
      address: response.address,
      createdAt: DateTime.now(),
    );
    _generatedKeys.insert(0, key);
    notifyListeners();
    // Auto-refresh the Accounts list so the new shared account shows up
    // immediately on both sides — no manual refresh needed.
    refreshAccounts();
    return key;
  }

  Future<GeneratedKey?> generateFROSTKey({
    required String sessionId,
    required String myId,
    required String anotherId,
    int index = 1,
  }) async {
    final request = KeygenRequest(
      sessionId: sessionId,
      myId: myId,
      anotherId: anotherId,
      index: index,
    );
    final response = await _run(() => _apiService.keygenFROST(request));
    if (response == null) return null;
    final key = GeneratedKey(
      type: 'FROST',
      name: 'BTC #$index',
      publicKey: response.publicKey,
      address: response.address,
      createdAt: DateTime.now(),
    );
    _generatedKeys.insert(0, key);
    notifyListeners();
    // Auto-refresh the Accounts list so the new shared account shows up
    // immediately on both sides — no manual refresh needed.
    refreshAccounts();
    return key;
  }

  void removeKey(GeneratedKey key) {
    _generatedKeys.remove(key);
    notifyListeners();
  }

  void clearAllKeys() {
    _generatedKeys.clear();
    notifyListeners();
  }

  // ── Generic runner ──

  Future<T?> _run<T>(Future<T> Function() fn) async {
    _state = AppState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await fn();
      _state = AppState.success;
      notifyListeners();
      return result;
    } on ApiError catch (e) {
      if (_handleAuthError(e)) return null; // expired session → logged out
      _errorMessage = e.message;
      _state = AppState.error;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = '$e';
      _state = AppState.error;
      notifyListeners();
      return null;
    }
  }
}
