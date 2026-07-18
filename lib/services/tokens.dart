import 'package:flutter/material.dart';

/// Known ERC-20 tokens (Ethereum mainnet). The native ETH "token" has an empty
/// contract — that path builds a normal ETH send.
class TokenInfo {
  final String symbol;
  final String contract; // '' = native ETH
  final int decimals;
  final int colorValue; // brand accent for the chip
  const TokenInfo(this.symbol, this.contract, this.decimals, this.colorValue);

  bool get isNative => contract.isEmpty;
  Color get color => Color(colorValue);
}

const kNativeEth = TokenInfo('ETH', '', 18, 0xFF627EEA);

/// Mainnet ERC-20s offered in the UI. Add more as needed.
const kEthTokens = <TokenInfo>[
  kNativeEth,
  TokenInfo('USDT', '0xdAC17F958D2ee523a2206206994597C13D831ec7', 6, 0xFF26A17B),
  TokenInfo('USDC', '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', 6, 0xFF2775CA),
  TokenInfo('DAI', '0x6B175474E89094C44Da98b954EedeAC495271d0F', 18, 0xFFF5AC37),
];

TokenInfo tokenForContract(String contract) {
  final c = contract.toLowerCase();
  for (final t in kEthTokens) {
    if (t.contract.toLowerCase() == c) return t;
  }
  return TokenInfo('TOKEN', contract, 18, 0xFF8B5CF6);
}
