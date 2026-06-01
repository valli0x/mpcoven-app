import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'metamask_service.dart';

class _WebMetaMask implements MetaMaskService {
  @override
  bool get isAvailable {
    try {
      return globalContext.has('ethereum');
    } catch (_) {
      return false;
    }
  }

  JSObject get _ethereum => globalContext.getProperty<JSObject>('ethereum'.toJS);

  @override
  Future<String> connect() async {
    if (!isAvailable) {
      throw Exception('MetaMask not detected. Please install the MetaMask browser extension.');
    }
    final args = {'method': 'eth_requestAccounts'}.jsify() as JSObject;
    final result = await _ethereum.callMethod<JSPromise>('request'.toJS, args).toDart;
    final accounts = (result as JSArray).toDart;
    if (accounts.isEmpty) {
      throw Exception('No accounts returned from MetaMask');
    }
    return (accounts.first as JSString).toDart;
  }

  @override
  Future<String> personalSign(String message, String address) async {
    if (!isAvailable) {
      throw Exception('MetaMask not detected');
    }
    final params = [message.toJS, address.toJS].toJS;
    final args = ({'method': 'personal_sign', 'params': params}).jsify() as JSObject;
    final result = await _ethereum.callMethod<JSPromise>('request'.toJS, args).toDart;
    return (result as JSString).toDart;
  }
}

MetaMaskService createMetaMaskService() => _WebMetaMask();
