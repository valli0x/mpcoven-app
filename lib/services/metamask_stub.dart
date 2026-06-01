import 'metamask_service.dart';

class _StubMetaMask implements MetaMaskService {
  @override
  bool get isAvailable => false;

  @override
  Future<String> connect() async {
    throw UnsupportedError('MetaMask is only available on web');
  }

  @override
  Future<String> personalSign(String message, String address) async {
    throw UnsupportedError('MetaMask is only available on web');
  }
}

MetaMaskService createMetaMaskService() => _StubMetaMask();
