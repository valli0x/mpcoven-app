import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'cache_service.dart';

class _Web implements CacheService {
  @override
  Future<void> hardRefresh() async {
    // 1. Unregister all service workers
    try {
      final nav = globalContext.getProperty<JSObject?>('navigator'.toJS);
      final sw = nav?.getProperty<JSObject?>('serviceWorker'.toJS);
      if (sw != null) {
        final regs =
            await sw.callMethod<JSPromise>('getRegistrations'.toJS).toDart;
        final regsList = (regs as JSArray).toDart;
        for (final reg in regsList) {
          await (reg as JSObject)
              .callMethod<JSPromise>('unregister'.toJS)
              .toDart;
        }
      }
    } catch (_) {}

    // 2. Delete all entries from caches API
    try {
      final caches = globalContext.getProperty<JSObject?>('caches'.toJS);
      if (caches != null) {
        final keys = await caches.callMethod<JSPromise>('keys'.toJS).toDart;
        final keysList = (keys as JSArray).toDart;
        for (final key in keysList) {
          await caches
              .callMethod<JSPromise>('delete'.toJS, key)
              .toDart;
        }
      }
    } catch (_) {}

    // 3. Reload, bypassing browser cache where possible
    final location = globalContext.getProperty<JSObject>('location'.toJS);
    location.callMethod<JSAny?>('reload'.toJS);
  }
}

CacheService createCacheService() => _Web();
