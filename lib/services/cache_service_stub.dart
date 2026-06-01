import 'cache_service.dart';

class _Stub implements CacheService {
  @override
  Future<void> hardRefresh() async {}
}

CacheService createCacheService() => _Stub();
