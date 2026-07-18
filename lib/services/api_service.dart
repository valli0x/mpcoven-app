import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/keygen_models.dart';

class ApiService {
  final String baseUrl;
  String? serverUrl;
  String? _token;
  String? _clientToken;
  final http.Client _client;

  ApiService({
    required this.baseUrl,
    this.serverUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? get token => _token;
  bool get isAuthenticated => _token != null;

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;

  // ── Client auth (local/remote Go client on baseUrl) ──
  String? get clientToken => _clientToken;
  void setClientToken(String token) => _clientToken = token;
  void clearClientToken() => _clientToken = null;

  Future<NonceResponse> clientRequestNonce(String address) async {
    final response = await _makeRequest('POST', '/v1/auth/nonce',
        body: {'address': address});
    return NonceResponse.fromJson(response);
  }

  Future<LoginResponse> clientLogin(
      String address, String signature, String nonce) async {
    final response = await _makeRequest('POST', '/v1/auth/login',
        body: {'address': address, 'signature': signature, 'nonce': nonce});
    final resp = LoginResponse.fromJson(response);
    _clientToken = resp.token;
    return resp;
  }

  /// The identity this client is bound to: {address, has_keys, bound}.
  Future<Map<String, dynamic>> clientIdentity() async {
    return _makeRequest('GET', '/v1/identity');
  }

  // ── Auth (server) ──

  Future<NonceResponse> requestNonce(String address) async {
    final response = await _makeRequest(
      'POST',
      '/v1/auth/nonce',
      body: {'address': address},
      useServer: true,
    );
    return NonceResponse.fromJson(response);
  }

  Future<LoginResponse> login(String address, String signature, String nonce) async {
    final response = await _makeRequest(
      'POST',
      '/v1/auth/login',
      body: {'address': address, 'signature': signature, 'nonce': nonce},
      useServer: true,
    );
    final loginResp = LoginResponse.fromJson(response);
    _token = loginResp.token;
    return loginResp;
  }

  // ── Pairing (server) ──

  Future<Pair> createPair(String partnerAddress) async {
    final response = await _makeRequest(
      'POST',
      '/v1/pair/create',
      body: {'partner': partnerAddress},
      useServer: true,
      auth: true,
    );
    return Pair.fromJson(response);
  }

  Future<Pair> acceptPair(String pairId) async {
    final response = await _makeRequest(
      'POST',
      '/v1/pair/accept',
      body: {'id': pairId},
      useServer: true,
      auth: true,
    );
    return Pair.fromJson(response);
  }

  /// Delete a pair on the server entirely (both participants lose it).
  Future<void> deletePair(String pairId) async {
    await _makeRequest(
      'POST',
      '/v1/pair/delete',
      body: {'id': pairId},
      useServer: true,
      auth: true,
    );
  }

  Future<PendingPairs> getPendingPairs() async {
    final response = await _makeRequest(
      'GET',
      '/v1/pair/pending',
      useServer: true,
      auth: true,
    );
    return PendingPairs.fromJson(response);
  }

  // ── Mailbox (server) ──

  Future<String> sendMailboxMessage({
    required String to,
    required String pairId,
    required String type,
    required Map<String, dynamic> body,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/v1/mailbox/send',
      body: {'to': to, 'pair_id': pairId, 'type': type, 'body': body},
      useServer: true,
      auth: true,
    );
    return response['id'] as String;
  }

  /// Atomically claim a keygen session (partner side, before running keygen).
  /// Returns false if the initiator already cancelled it.
  Future<bool> claimSession(String sessionId) async {
    final response = await _makeRequest(
      'POST',
      '/v1/session/claim',
      body: {'session_id': sessionId},
      useServer: true,
      auth: true,
    );
    return response['ok'] == true;
  }

  /// Atomically cancel a keygen session (initiator side).
  /// Returns false if the partner already claimed it (too late).
  Future<bool> cancelSession(String sessionId) async {
    final response = await _makeRequest(
      'POST',
      '/v1/session/cancel',
      body: {'session_id': sessionId},
      useServer: true,
      auth: true,
    );
    return response['ok'] == true;
  }

  Future<List<MailboxMessage>> getPendingMessages() async {
    final response = await _makeRequest(
      'GET',
      '/v1/mailbox/pending',
      useServer: true,
      auth: true,
    );
    final messages = response['messages'] as List<dynamic>?;
    return messages
            ?.map((e) => MailboxMessage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<void> ackMessage(String messageId) async {
    await _makeRequest(
      'POST',
      '/v1/mailbox/ack',
      body: {'id': messageId},
      useServer: true,
      auth: true,
    );
  }

  // ── Keygen (client) ──

  Future<KeygenResponse> keygenECDSA(KeygenRequest request) async {
    final response = await _makeRequest(
      'POST',
      '/v1/keygen/ecdsa',
      body: request.toJson(),
      timeout: const Duration(minutes: 5),
    );
    return KeygenResponse.fromJson(response);
  }

  Future<KeygenResponse> keygenFROST(KeygenRequest request) async {
    final response = await _makeRequest(
      'POST',
      '/v1/keygen/frost',
      body: request.toJson(),
      timeout: const Duration(minutes: 5),
    );
    return KeygenResponse.fromJson(response);
  }

  // ── Accounts (client) ──

  Future<List<AccountMeta>> listAccounts({String? network}) async {
    final query = network != null ? '?network=$network' : '';
    final response = await _makeRequest('GET', '/v1/accounts/list$query');
    final accounts = response['accounts'] as List<dynamic>?;
    return accounts
            ?.map((e) => AccountMeta.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<AccountMeta> getAccount(String network, int index) async {
    final response = await _makeRequest(
      'POST',
      '/v1/accounts/get',
      body: {'network': network, 'index': index},
    );
    return AccountMeta.fromJson(response);
  }

  // ── Exchanges (client) ──

  Future<List<ExchangeEntry>> listExchanges() async {
    final response = await _makeRequest('GET', '/v1/exchanges/list');
    final list = response['exchanges'] as List<dynamic>?;
    return list
            ?.map((e) => ExchangeEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  /// Create an exchange (draft). Addresses optional — fill via [updateExchange].
  Future<ExchangeEntry> createExchange({
    String addressA = '',
    String addressB = '',
  }) async {
    final response = await _makeRequest(
      'POST',
      '/v1/exchanges/create',
      body: {'address_a': addressA, 'address_b': addressB},
    );
    return ExchangeEntry.fromJson(response);
  }

  Future<ExchangeEntry> updateExchange(
    String id,
    String addressA,
    String addressB, {
    String? partnerA,
    String? statusA,
    String? partnerB,
    String? statusB,
    String? creator,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/v1/exchanges/update',
      body: {
        'id': id,
        'address_a': addressA,
        'address_b': addressB,
        if (partnerA != null && partnerA.isNotEmpty) 'partner_a': partnerA,
        if (statusA != null && statusA.isNotEmpty) 'status_a': statusA,
        if (partnerB != null && partnerB.isNotEmpty) 'partner_b': partnerB,
        if (statusB != null && statusB.isNotEmpty) 'status_b': statusB,
        if (creator != null && creator.isNotEmpty) 'creator': creator,
      },
    );
    return ExchangeEntry.fromJson(response);
  }

  /// Create-or-replace an exchange by id (acceptor imports a proposal).
  Future<ExchangeEntry> upsertExchange({
    required String id,
    required String addressA,
    required String partnerA,
    required String statusA,
    required String addressB,
    required String partnerB,
    required String statusB,
    required String creator,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/v1/exchanges/upsert',
      body: {
        'id': id,
        'address_a': addressA,
        'partner_a': partnerA,
        'status_a': statusA,
        'address_b': addressB,
        'partner_b': partnerB,
        'status_b': statusB,
        'creator': creator,
      },
    );
    return ExchangeEntry.fromJson(response);
  }

  Future<void> deleteExchange(String id) async {
    await _makeRequest('POST', '/v1/exchanges/delete', body: {'id': id});
  }

  /// Permanently delete one account's key material on the local client.
  /// [address] is echoed as a confirmation guard (backend verifies it).
  Future<void> deleteAccount({
    required String network,
    required int index,
    required String address,
  }) async {
    await _makeRequest(
      'POST',
      '/v1/accounts/delete',
      body: {'network': network, 'index': index, 'address': address},
    );
  }

  // ── Balance (client) ──

  Future<BalanceCheckResponse> checkBalance(BalanceCheckRequest request) async {
    final response = await _makeRequest(
      'POST',
      '/v1/balance/check',
      body: request.toJson(),
    );
    return BalanceCheckResponse.fromJson(response);
  }

  // ── Transaction (client) ──

  Future<TxHashResponse> createTxHash({
    required String network,
    required String from,
    required String to,
    required int amount,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/v1/tx/hash',
      body: {'network': network, 'from': from, 'to': to, 'amount': amount},
    );
    return TxHashResponse.fromJson(response);
  }

  Future<TxSendResponse> sendTransaction({
    required String network,
    String from = '',
    String to = '',
    String value = '',
    required String signature,
    String? txData,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/v1/tx/send',
      body: {
        'network': network,
        'from': from,
        'to': to,
        'value': value,
        'signature': signature,
        if (txData != null && txData.isNotEmpty) 'tx_data': txData,
      },
    );
    return TxSendResponse.fromJson(response);
  }

  // ── Incomplete Signature (client) ──

  Future<IncompleteSignatureResponse> sendIncompleteSignature({
    required String alg,
    required String name,
    required String escrowAddress,
    required String hashTx,
    required String myId,
    required String anotherId,
    String? to,
    String? amount,
    String? txData,
    String? escrowId,
    String? pub,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/v1/incomplete-signature/send',
      body: {
        'alg': alg,
        'name': name,
        'escrow_address': escrowAddress,
        'hash_tx': hashTx,
        'my_id': myId,
        'another_id': anotherId,
        if (to != null && to.isNotEmpty) 'to': to,
        if (amount != null && amount.isNotEmpty) 'amount': amount,
        if (txData != null && txData.isNotEmpty) 'tx_data': txData,
        if (escrowId != null && escrowId.isNotEmpty) 'escrow_id': escrowId,
        if (pub != null && pub.isNotEmpty) 'pub': pub,
      },
      timeout: const Duration(minutes: 5),
    );
    return IncompleteSignatureResponse.fromJson(response);
  }

  /// Decode an unsigned tx_data so the acceptor can verify what they sign.
  Future<Map<String, dynamic>> decodeTx(String network, String txData) async {
    return _makeRequest('POST', '/v1/tx/decode',
        body: {'network': network, 'tx_data': txData});
  }

  // ── Escrow (server pollination, atomic swap) ──

  /// Deposit a flower (the completed signature) into the server escrow.
  /// Returns the response status ('pending' | 'complete') + optional signature.
  Future<Map<String, dynamic>> escrowDeposit({
    required String alg,
    required String id,
    required String pub,
    required String hash,
    required String sig,
  }) async {
    return _makeRequest('POST', '/v1/escrow',
        useServer: true,
        auth: true,
        body: {'alg': alg, 'id': id, 'pub': pub, 'hash': hash, 'sig': sig});
  }

  /// Poll the escrow pollination for {id, pub}. When both flowers are valid,
  /// returns {status:'complete', signature: base64}.
  Future<Map<String, dynamic>> escrowCheck({
    required String id,
    required String pub,
  }) async {
    return _makeRequest('POST', '/v1/escrow/check',
        useServer: true, auth: true, body: {'id': id, 'pub': pub});
  }

  /// Convert a CMP-native ECDSA signature (as released by the escrow) into the
  /// 65-byte Ethereum r‖s‖v form required by /v1/tx/send. Client-side op.
  Future<String> sigToEthereum(String cmpSigHex) async {
    final resp = await _makeRequest('POST', '/v1/sig/ethereum',
        body: {'signature': cmpSigHex});
    return (resp['signature'] ?? '').toString();
  }

  /// Initiator: attach the partner-returned signature to our 'sent' history
  /// entry so we can broadcast it too.
  Future<void> completeCosign(String hash, String signature) async {
    await _makeRequest('POST', '/v1/cosign/complete',
        body: {'hash': hash, 'signature': signature});
  }

  // ── Aliases / contacts (client) ──

  Future<Map<String, String>> getAliases() async {
    final response = await _makeRequest('GET', '/v1/aliases/list');
    final m = response['aliases'];
    if (m is Map) {
      return m.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  Future<void> setAlias(String address, String name) async {
    await _makeRequest('POST', '/v1/aliases/set',
        body: {'address': address, 'name': name});
  }

  Future<void> deleteAlias(String address) async {
    await _makeRequest('POST', '/v1/aliases/delete', body: {'address': address});
  }

  // ── Co-sign history (client) ──

  Future<List<CosignEvent>> getCosignHistory() async {
    final response = await _makeRequest('GET', '/v1/cosign/history');
    final list = response['events'] as List<dynamic>?;
    return list
            ?.map((e) => CosignEvent.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<void> clearCosignHistory() async {
    await _makeRequest('POST', '/v1/cosign/history/clear');
  }

  Future<IncompleteSignatureResponse> acceptIncompleteSignature({
    required String alg,
    required String name,
    required String escrowAddress,
    required String myId,
    required String anotherId,
    String? hashTx,
    String? to,
    String? amount,
    String? txData,
    String? escrowId,
  }) async {
    final body = <String, dynamic>{
      'alg': alg,
      'name': name,
      'escrow_address': escrowAddress,
      'my_id': myId,
      'another_id': anotherId,
    };
    if (hashTx != null) body['hash_tx'] = hashTx;
    if (to != null && to.isNotEmpty) body['to'] = to;
    if (amount != null && amount.isNotEmpty) body['amount'] = amount;
    if (txData != null && txData.isNotEmpty) body['tx_data'] = txData;
    if (escrowId != null && escrowId.isNotEmpty) body['escrow_id'] = escrowId;
    final response = await _makeRequest(
      'POST',
      '/v1/incomplete-signature/accept',
      body: body,
      timeout: const Duration(minutes: 5),
    );
    return IncompleteSignatureResponse.fromJson(response);
  }

  // ── Internal ──

  Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool useServer = false,
    bool auth = false,
    // Default guards against a stuck/stale connection hanging the UI forever.
    // MPC-heavy endpoints (keygen, co-sign) pass a longer timeout below.
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final base = useServer ? (serverUrl ?? baseUrl) : baseUrl;
    final uri = Uri.parse('$base$endpoint');

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (useServer) {
        if (auth && _token != null) {
          headers['Authorization'] = 'Bearer $_token';
        }
      } else if (_clientToken != null) {
        // Client (Go :8080/:8081) now requires its own JWT on all /v1
        // operational routes (auth/nonce, auth/login, identity stay public).
        headers['Authorization'] = 'Bearer $_clientToken';
      }

      http.Response response;
      switch (method) {
        case 'POST':
          response = await _client
              .post(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(timeout);
          break;
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(timeout);
          break;
        default:
          throw ApiError(message: 'Unsupported HTTP method: $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return {};
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        String errorMessage;
        try {
          final errorBody = jsonDecode(response.body);
          // Backend uses either {"errors":[...]} or {"error":"..."}.
          if (errorBody is Map) {
            final errs = errorBody['errors'];
            if (errs is List && errs.isNotEmpty) {
              errorMessage = errs.first.toString();
            } else if (errorBody['error'] is String) {
              errorMessage = errorBody['error'] as String;
            } else if (errorBody['message'] is String) {
              errorMessage = errorBody['message'] as String;
            } else {
              errorMessage = 'HTTP ${response.statusCode}';
            }
          } else {
            errorMessage = response.body;
          }
        } catch (_) {
          errorMessage =
              response.body.isNotEmpty ? response.body : 'HTTP ${response.statusCode}';
        }
        throw ApiError(message: errorMessage, statusCode: response.statusCode);
      }
    } on TimeoutException {
      throw ApiError(message: 'Request timed out — check your connection and try again.');
    } on SocketException catch (e) {
      throw ApiError(message: 'Network error: ${e.message}');
    } on FormatException catch (e) {
      throw ApiError(message: 'Invalid response format: ${e.message}');
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(message: 'Unexpected error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
