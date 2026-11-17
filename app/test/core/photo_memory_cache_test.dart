import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/media/photo_memory_cache.dart';

void main() {
  setUp(PhotoMemoryCache.instance.clear);
  tearDown(PhotoMemoryCache.instance.clear);

  test('locks the first verified bytes and reuses one provider', () {
    final cache = PhotoMemoryCache.instance;
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    expect(cache.hasPhoto('p1'), isFalse);
    expect(cache.providerFor('p1'), isNull);

    expect(cache.put('p1', bytes), isTrue);
    expect(cache.hasPhoto('p1'), isTrue);
    expect(cache.bytesFor('p1'), same(bytes));
    expect(cache.providerFor('p1'), same(cache.providerFor('p1')));
  });

  test('ignores duplicate and conflicting writes for a locked photo', () {
    final cache = PhotoMemoryCache.instance;
    final first = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final second = Uint8List.fromList(<int>[9, 9, 9, 9]);
    expect(cache.put('p1', first), isTrue);
    expect(cache.put('p1', Uint8List.fromList(first)), isFalse);
    expect(cache.put('p1', second), isFalse);
    expect(cache.bytesFor('p1'), same(first));
  });

  test('base64 writes reject bad payloads without locking the id', () {
    final cache = PhotoMemoryCache.instance;
    expect(cache.putBase64('p1', 'not base64'), isFalse);
    expect(cache.hasPhoto('p1'), isFalse);
    expect(cache.putBase64('p1', 'AQID'), isTrue);
    expect(cache.bytesFor('p1'), orderedEquals(<int>[1, 2, 3]));
  });

  test('clear drops bytes and providers for a new match', () {
    final cache = PhotoMemoryCache.instance;
    expect(cache.put('p1', Uint8List.fromList(<int>[1])), isTrue);
    final locked = cache.providerFor('p1');
    expect(locked, isNotNull);
    expect(cache.providerFor('p1'), same(locked));
    cache.clear();
    expect(cache.hasPhoto('p1'), isFalse);
    expect(cache.providerFor('p1'), isNull);
  });
}
