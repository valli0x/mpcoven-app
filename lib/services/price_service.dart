import 'dart:convert';
import 'package:http/http.dart' as http;

/// Free USD price quotes from CoinGecko (no API key, CORS-friendly).
class PriceService {
  static const _base =
      'https://api.coingecko.com/api/v3/simple/price?ids=ethereum,bitcoin&vs_currencies=usd';

  final http.Client _client;
  PriceService({http.Client? client}) : _client = client ?? http.Client();

  // Tiny in-memory cache (60s) so we don't hammer the endpoint.
  double? _eth;
  double? _btc;
  DateTime? _at;

  /// USD price of 1 unit of [network] ('eth'|'btc'). Returns null on failure.
  Future<double?> usdPrice(String network) async {
    final isEth = network == 'eth' || network == 'ethereum';
    if (_at != null && DateTime.now().difference(_at!).inSeconds < 60) {
      return isEth ? _eth : _btc;
    }
    try {
      final resp = await _client
          .get(Uri.parse(_base))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      _eth = (json['ethereum']?['usd'] as num?)?.toDouble();
      _btc = (json['bitcoin']?['usd'] as num?)?.toDouble();
      _at = DateTime.now();
      return isEth ? _eth : _btc;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
