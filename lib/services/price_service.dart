import 'dart:convert';
import 'package:http/http.dart' as http;

/// Free USD price quotes. Primary source: Coinbase spot (no API key, generous
/// limits, CORS-friendly). Fallback: CoinGecko. Keeps the last known price so a
/// transient rate-limit (HTTP 429) doesn't blank the UI.
class PriceService {
  static const _coinbaseEth = 'https://api.coinbase.com/v2/prices/ETH-USD/spot';
  static const _coinbaseBtc = 'https://api.coinbase.com/v2/prices/BTC-USD/spot';
  static const _coingecko =
      'https://api.coingecko.com/api/v3/simple/price?ids=ethereum,bitcoin&vs_currencies=usd';

  final http.Client _client;
  PriceService({http.Client? client}) : _client = client ?? http.Client();

  // Last known prices (kept across failures) + cache timestamp.
  double? _eth;
  double? _btc;
  DateTime? _at;

  static const _ttl = Duration(minutes: 5);

  /// USD price of 1 unit of [network] ('eth'|'btc').
  /// Returns the last known value if a refresh fails; null only if never loaded.
  Future<double?> usdPrice(String network) async {
    final isEth = network == 'eth' || network == 'ethereum';

    final fresh =
        _at != null && DateTime.now().difference(_at!) < _ttl;
    if (fresh && _eth != null && _btc != null) {
      return isEth ? _eth : _btc;
    }

    final ok = await _fetchCoinbase() || await _fetchCoinGecko();
    if (ok) _at = DateTime.now();

    // Even on failure, return whatever we last had (may be null first time).
    return isEth ? _eth : _btc;
  }

  Future<bool> _fetchCoinbase() async {
    try {
      final results = await Future.wait([
        _client.get(Uri.parse(_coinbaseEth)).timeout(const Duration(seconds: 8)),
        _client.get(Uri.parse(_coinbaseBtc)).timeout(const Duration(seconds: 8)),
      ]);
      final ethResp = results[0];
      final btcResp = results[1];
      if (ethResp.statusCode != 200 || btcResp.statusCode != 200) return false;
      final eth = double.tryParse(
          (jsonDecode(ethResp.body)['data']?['amount'] as String?) ?? '');
      final btc = double.tryParse(
          (jsonDecode(btcResp.body)['data']?['amount'] as String?) ?? '');
      if (eth == null || btc == null) return false;
      _eth = eth;
      _btc = btc;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _fetchCoinGecko() async {
    try {
      final resp = await _client
          .get(Uri.parse(_coingecko))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return false;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final eth = (json['ethereum']?['usd'] as num?)?.toDouble();
      final btc = (json['bitcoin']?['usd'] as num?)?.toDouble();
      if (eth == null || btc == null) return false;
      _eth = eth;
      _btc = btc;
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _client.close();
}
