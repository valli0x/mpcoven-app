import 'cache_service_stub.dart'
    if (dart.library.js_interop) 'cache_service_web.dart';

abstract class CacheService {
  /// Unregister all service workers + clear all caches API entries, then reload.
  Future<void> hardRefresh();

  static CacheService? _instance;
  static CacheService get instance => _instance ??= createCacheService();
}
