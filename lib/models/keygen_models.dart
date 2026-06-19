class IDGenerateResponse {
  final String myId;
  final String anotherId;

  IDGenerateResponse({required this.myId, required this.anotherId});

  factory IDGenerateResponse.fromJson(Map<String, dynamic> json) {
    return IDGenerateResponse(
      myId: json['my_id'] as String,
      anotherId: json['another_id'] as String,
    );
  }
}

class KeygenRequest {
  final String sessionId;
  final String myId;
  final String anotherId;
  final String? network;
  final int? index;

  KeygenRequest({
    required this.sessionId,
    required this.myId,
    required this.anotherId,
    this.network,
    this.index,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'session_id': sessionId,
      'my_id': myId,
      'another_id': anotherId,
    };
    if (network != null) map['network'] = network;
    if (index != null) map['index'] = index;
    return map;
  }
}

class KeygenResponse {
  final String publicKey;
  final String address;
  final String sessionId;
  final String? network;
  final int? index;

  KeygenResponse({
    required this.publicKey,
    required this.address,
    required this.sessionId,
    this.network,
    this.index,
  });

  factory KeygenResponse.fromJson(Map<String, dynamic> json) {
    return KeygenResponse(
      publicKey: json['public_key'] as String,
      address: json['address'] as String,
      sessionId: json['session_id'] as String,
      network: json['network'] as String?,
      index: json['index'] as int?,
    );
  }
}

class ApiError implements Exception {
  final String message;
  final int? statusCode;

  ApiError({required this.message, this.statusCode});

  @override
  String toString() => message;
}

class NonceResponse {
  final String nonce;
  final String message;

  NonceResponse({required this.nonce, required this.message});

  factory NonceResponse.fromJson(Map<String, dynamic> json) {
    return NonceResponse(
      nonce: json['nonce'] as String,
      message: json['message'] as String,
    );
  }
}

class LoginResponse {
  final String token;
  final String address;

  LoginResponse({required this.token, required this.address});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      address: json['address'] as String,
    );
  }
}

class Pair {
  final String id;
  final String initiator;
  final String partner;
  final String status;
  final int? createdAt;

  Pair({
    required this.id,
    required this.initiator,
    required this.partner,
    required this.status,
    this.createdAt,
  });

  factory Pair.fromJson(Map<String, dynamic> json) {
    return Pair(
      id: json['id'] as String,
      initiator: json['initiator'] as String,
      partner: json['partner'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as int?,
    );
  }
}

class PendingPairs {
  final List<Pair> incoming;
  final List<Pair> outgoing;

  PendingPairs({required this.incoming, required this.outgoing});

  factory PendingPairs.fromJson(Map<String, dynamic> json) {
    return PendingPairs(
      incoming: (json['incoming'] as List<dynamic>?)
              ?.map((e) => Pair.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      outgoing: (json['outgoing'] as List<dynamic>?)
              ?.map((e) => Pair.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MailboxMessage {
  final String id;
  final String from;
  final String to;
  final String pairId;
  final String type;
  final dynamic body;
  final int? createdAt;

  MailboxMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.pairId,
    required this.type,
    this.body,
    this.createdAt,
  });

  factory MailboxMessage.fromJson(Map<String, dynamic> json) {
    return MailboxMessage(
      id: json['id'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      pairId: json['pair_id'] as String,
      type: json['type'] as String,
      body: json['body'],
      createdAt: json['created_at'] as int?,
    );
  }
}

class AccountMeta {
  final String network;
  final int index;
  final String address;
  final String publicKey;
  final String? pairMyId;
  final String? pairOther;
  final String? sessionId;

  AccountMeta({
    required this.network,
    required this.index,
    required this.address,
    required this.publicKey,
    this.pairMyId,
    this.pairOther,
    this.sessionId,
  });

  factory AccountMeta.fromJson(Map<String, dynamic> json) {
    return AccountMeta(
      network: json['network'] as String? ?? '',
      index: json['index'] as int? ?? 0,
      address: json['address'] as String? ?? '',
      publicKey: json['public_key'] as String? ?? '',
      pairMyId: json['pair_my_id'] as String?,
      pairOther: json['pair_other'] as String?,
      sessionId: json['session_id'] as String?,
    );
  }
}

class BalanceCheckRequest {
  final String network;
  final String address;
  final int expected;

  BalanceCheckRequest({
    required this.network,
    required this.address,
    required this.expected,
  });

  Map<String, dynamic> toJson() => {
        'network': network,
        'address': address,
        'expected': expected,
      };
}

class BalanceCheckResponse {
  final String network;
  final String address;
  final int balance;
  final int expected;
  final bool isSufficient;

  BalanceCheckResponse({
    required this.network,
    required this.address,
    required this.balance,
    required this.expected,
    required this.isSufficient,
  });

  factory BalanceCheckResponse.fromJson(Map<String, dynamic> json) {
    return BalanceCheckResponse(
      network: json['network'] as String,
      address: json['address'] as String,
      balance: json['balance'] as int,
      expected: json['expected'] as int,
      isSufficient: json['is_sufficient'] as bool,
    );
  }
}

class TxHashResponse {
  final String network;
  final String hash;
  final String? txData;

  TxHashResponse({
    required this.network,
    required this.hash,
    this.txData,
  });

  factory TxHashResponse.fromJson(Map<String, dynamic> json) {
    return TxHashResponse(
      network: json['network'] as String,
      hash: json['hash'] as String,
      txData: json['tx_data'] as String?,
    );
  }
}

class TxSendResponse {
  final String status;
  final String txHash;
  final String message;

  TxSendResponse({
    required this.status,
    required this.txHash,
    required this.message,
  });

  factory TxSendResponse.fromJson(Map<String, dynamic> json) {
    return TxSendResponse(
      status: json['status'] as String,
      txHash: json['tx_hash'] as String,
      message: json['message'] as String,
    );
  }
}

class IncompleteSignatureResponse {
  final String status;
  final String? completeSignature;
  final String message;

  IncompleteSignatureResponse({
    required this.status,
    this.completeSignature,
    required this.message,
  });

  factory IncompleteSignatureResponse.fromJson(Map<String, dynamic> json) {
    return IncompleteSignatureResponse(
      status: json['status'] as String,
      completeSignature: json['complete_signature'] as String?,
      message: json['message'] as String,
    );
  }
}

class GeneratedKey {
  final String type;
  final String name;
  final String publicKey;
  final String address;
  final DateTime createdAt;

  GeneratedKey({
    required this.type,
    required this.name,
    required this.publicKey,
    required this.address,
    required this.createdAt,
  });
}

/// One local co-sign / broadcast history entry (recorded on the Go client).
class CosignEvent {
  final String id;
  final String role; // initiator | acceptor | broadcast
  final String status; // sent | completed | failed | broadcast
  final String network;
  final int index;
  final String escrow;
  final String to;
  final String amount; // base units
  final String hash;
  final String signature;
  final String txData;
  final String txHash;
  final String error;
  final String escrowId; // pollination id (atomic swap)
  final String pub; // escrow account public key
  final int createdAt; // unix ms

  CosignEvent({
    required this.id,
    required this.role,
    required this.status,
    required this.network,
    required this.index,
    required this.escrow,
    required this.to,
    required this.amount,
    required this.hash,
    required this.signature,
    required this.txData,
    required this.txHash,
    required this.error,
    this.escrowId = '',
    this.pub = '',
    required this.createdAt,
  });

  factory CosignEvent.fromJson(Map<String, dynamic> json) => CosignEvent(
        id: json['id'] as String? ?? '',
        role: json['role'] as String? ?? '',
        status: json['status'] as String? ?? '',
        network: json['network'] as String? ?? 'eth',
        index: json['index'] as int? ?? 0,
        escrow: json['escrow'] as String? ?? '',
        to: json['to'] as String? ?? '',
        amount: json['amount'] as String? ?? '',
        hash: json['hash'] as String? ?? '',
        signature: json['signature'] as String? ?? '',
        txData: json['tx_data'] as String? ?? '',
        txHash: json['tx_hash'] as String? ?? '',
        error: json['error'] as String? ?? '',
        escrowId: json['escrow_id'] as String? ?? '',
        pub: json['pub'] as String? ?? '',
        createdAt: json['created_at'] as int? ?? 0,
      );
}

/// A user-defined exchange linking two escrow accounts (any ETH/BTC addresses).
/// Local for now; swap logic will be added later.
class ExchangeEntry {
  final String id;
  // Each side is an escrow account with its OWN partner + invite status.
  final String addressA;
  final String partnerA; // counterpart of escrow A
  final String statusA; // '' | invited | accepted
  final String addressB;
  final String partnerB;
  final String statusB;
  final int createdAt; // epoch ms

  ExchangeEntry({
    required this.id,
    required this.addressA,
    this.partnerA = '',
    this.statusA = '',
    required this.addressB,
    this.partnerB = '',
    this.statusB = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'address_a': addressA,
        'partner_a': partnerA,
        'status_a': statusA,
        'address_b': addressB,
        'partner_b': partnerB,
        'status_b': statusB,
        'created_at': createdAt,
      };

  factory ExchangeEntry.fromJson(Map<String, dynamic> json) => ExchangeEntry(
        id: json['id'] as String,
        addressA: json['address_a'] as String? ?? '',
        partnerA: json['partner_a'] as String? ?? '',
        statusA: json['status_a'] as String? ?? '',
        addressB: json['address_b'] as String? ?? '',
        partnerB: json['partner_b'] as String? ?? '',
        statusB: json['status_b'] as String? ?? '',
        createdAt: json['created_at'] as int? ?? 0,
      );
}
