/// Conversions between human units (ETH/BTC) and base units (wei/satoshi).
/// Uses BigInt to avoid floating-point precision loss on large wei values.
class Units {
  /// Decimals per network: ETH = 18 (wei), BTC = 8 (satoshi).
  static int decimals(String network) =>
      (network == 'eth' || network == 'ethereum') ? 18 : 8;

  static String symbol(String network) =>
      (network == 'eth' || network == 'ethereum') ? 'ETH' : 'BTC';

  /// Parse a human decimal string ("0.011") into base units (BigInt).
  /// Returns null if the input isn't a valid non-negative decimal.
  static BigInt? toBase(String human, String network) =>
      toBaseDec(human, decimals(network));

  /// Like [toBase] but with an explicit decimal count (for ERC-20 tokens).
  static BigInt? toBaseDec(String human, int dec) {
    final s = human.trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(s) || s == '.') return null;
    final parts = s.split('.');
    final intPart = parts[0].isEmpty ? '0' : parts[0];
    var fracPart = parts.length > 1 ? parts[1] : '';
    if (fracPart.length > dec) {
      fracPart = fracPart.substring(0, dec); // truncate excess precision
    }
    fracPart = fracPart.padRight(dec, '0');
    try {
      return BigInt.parse(intPart) * BigInt.from(10).pow(dec) +
          BigInt.parse(fracPart.isEmpty ? '0' : fracPart);
    } catch (_) {
      return null;
    }
  }

  /// Format base units (as int or BigInt) into a trimmed human string.
  static String fromBase(Object base, String network) =>
      fromBaseDec(base, decimals(network));

  /// Like [fromBase] but with an explicit decimal count (for ERC-20 tokens).
  static String fromBaseDec(Object base, int dec) {
    final b = base is BigInt ? base : BigInt.from(base as int);
    final divisor = BigInt.from(10).pow(dec);
    final whole = b ~/ divisor;
    final frac = (b % divisor).toString().padLeft(dec, '0');
    final trimmed = frac.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
  }
}
