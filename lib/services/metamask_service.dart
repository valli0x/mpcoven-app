import 'metamask_stub.dart' if (dart.library.js_interop) 'metamask_web.dart';

abstract class MetaMaskService {
  bool get isAvailable;
  Future<String> connect();
  Future<String> personalSign(String message, String address);

  static MetaMaskService? _instance;
  static MetaMaskService get instance => _instance ??= createMetaMaskService();
}
