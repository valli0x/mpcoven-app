import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/keygen_models.dart';

class ApiService {
  final String baseUrl;
  String? serverUrl;
  String? _token;
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
    );
    return KeygenResponse.fromJson(response);
  }

  Future<KeygenResponse> keygenFROST(KeygenRequest request) async {
    final response = await _makeRequest(
      'POST',
      '/v1/keygen/frost',
      body: request.toJson(),
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
    required String from,
    required String to,
    required String value,
    required String signature,
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
      },
    );
    return IncompleteSignatureResponse.fromJson(response);
  }

  Future<IncompleteSignatureResponse> acceptIncompleteSignature({
    required String alg,
    required String name,
    required String escrowAddress,
    required String myId,
    required String anotherId,
    String? hashTx,
  }) async {
    final body = <String, dynamic>{
      'alg': alg,
      'name': name,
      'escrow_address': escrowAddress,
      'my_id': myId,
      'another_id': anotherId,
    };
    if (hashTx != null) body['hash_tx'] = hashTx;
    final response = await _makeRequest(
      'POST',
      '/v1/incomplete-signature/accept',
      body: body,
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
  }) async {
    final base = useServer ? (serverUrl ?? baseUrl) : baseUrl;
    final uri = Uri.parse('$base$endpoint');

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (auth && _token != null) {
        headers['Authorization'] = 'Bearer $_token';
      }

      http.Response response;
      switch (method) {
        case 'POST':
          response = await _client.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'GET':
          response = await _client.get(uri, headers: headers);
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
