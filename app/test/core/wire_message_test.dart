import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/protocol/wire_message.dart';

Uint8List bytesOf(int length, {int seed = 0}) {
  final data = Uint8List(length);
  for (var i = 0; i < length; i++) {
    data[i] = (i * 31 + seed) & 0xFF;
  }
  return data;
}

void main() {
  group('WireMessage', () {
    test('encodes the documented envelope', () {
      final message = WireMessage(
        type: WireType.submitGuess,
        seq: 12,
        payload: <String, dynamic>{'roundNumber': 3, 'guessedPlayerId': 'p2'},
      );
      final json = jsonDecode(message.encode()) as Map<String, dynamic>;
      expect(json['type'], 'submit_guess');
      expect(json['seq'], 12);
      expect((json['payload'] as Map)['guessedPlayerId'], 'p2');
    });

    test('roundtrips through decode', () {
      final message = WireMessage(
        type: WireType.lobbyState,
        seq: 4,
        payload: <String, dynamic>{
          'roundsK': 10,
          'players': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'p1', 'ready': true},
          ],
        },
      );
      final decoded = WireMessage.decode(message.encode());
      expect(decoded.type, WireType.lobbyState);
      expect(decoded.seq, 4);
      expect((decoded.payload['players'] as List).length, 1);
    });

    test('defaults to an empty payload', () {
      final decoded = WireMessage.decode('{"type":"ping","seq":1}');
      expect(decoded.payload, isEmpty);
    });

    test('rejects non JSON', () {
      expect(
        () => WireMessage.decode('nope'),
        throwsA(isA<WireFormatException>()),
      );
    });

    test('rejects a missing type or seq', () {
      expect(
        () => WireMessage.decode('{"seq":1}'),
        throwsA(isA<WireFormatException>()),
      );
      expect(
        () => WireMessage.decode('{"type":"ping"}'),
        throwsA(isA<WireFormatException>()),
      );
    });

    test('rejects a non object payload', () {
      expect(
        () => WireMessage.decode('{"type":"ping","seq":1,"payload":[1]}'),
        throwsA(isA<WireFormatException>()),
      );
    });

    test('every protocol constant is unique and non empty', () {
      expect(WireType.all.length, 40);
      for (final type in WireType.all) {
        expect(type, isNotEmpty);
      }
      expect(WireType.all.toSet().length, WireType.all.length);
    });

    test('covers every documented event', () {
      expect(WireType.all, <String>{
        'join_req',
        'join_ack',
        'kick',
        'lobby_state',
        'start_prepare',
        'submit_photos',
        'photo_chunk',
        'photo_complete',
        'player_ready',
        'plant_photo',
        'plant_assignment',
        'version_warning',
        'round_countdown',
        'round_show',
        'submit_guess',
        'screenshot_taken',
        'screenshot_alert',
        'sound_effect',
        'room_theme',
        'round_reveal',
        'caption_submit',
        'caption_options',
        'caption_vote',
        'caption_reveal',
        'meme_assignment',
        'meme_submit',
        'meme_options',
        'meme_vote',
        'meme_reveal',
        'meme_swap',
        'timeline_submit',
        'timeline_reveal',
        'extend_prepare',
        'extend_submit',
        'game_podium',
        'state_sync',
        'room_closed',
        'error_notice',
        'ping',
        'pong',
      });
    });
  });

  group('PhotoChunker', () {
    test('splits into 16 KB base64 chunks', () {
      final data = bytesOf(16 * 1024 + 100);
      final chunks = PhotoChunker.split('photo-1', data);
      expect(chunks.length, 2);
      expect(chunks[0].index, 0);
      expect(chunks[1].index, 1);
      expect(chunks[0].total, 2);
      expect(base64Decode(chunks[0].data).length, 16 * 1024);
      expect(base64Decode(chunks[1].data).length, 100);
      expect(chunks[0].photoId, 'photo-1');
    });

    test('an exact multiple of the chunk size has no empty tail chunk', () {
      final chunks = PhotoChunker.split('p', bytesOf(32 * 1024));
      expect(chunks.length, 2);
      expect(base64Decode(chunks[1].data).length, 16 * 1024);
    });

    test('stamps every chunk with the SHA-256 of the whole photo', () {
      final data = bytesOf(5000);
      final digest = sha256.convert(data).toString();
      final chunks = PhotoChunker.split('p', data);
      expect(chunks.every((c) => c.sha256 == digest), isTrue);
    });

    test('rejects an empty photo', () {
      expect(
        () => PhotoChunker.split('p', Uint8List(0)),
        throwsA(isA<WireFormatException>()),
      );
    });

    test('rejects a photo above 2 MB', () {
      expect(
        () =>
            PhotoChunker.split('p', Uint8List(PhotoChunker.maxPhotoBytes + 1)),
        throwsA(isA<WireFormatException>()),
      );
    });

    test('chunk survives a JSON roundtrip', () {
      final chunk = PhotoChunker.split('p', bytesOf(1000)).single;
      final restored = PhotoChunk.fromJson(
        jsonDecode(jsonEncode(chunk.toJson())) as Map<String, dynamic>,
      );
      expect(restored.data, chunk.data);
      expect(restored.sha256, chunk.sha256);
    });
  });

  group('PhotoChunkAssembler', () {
    test('reassembles the original bytes from out of order chunks', () {
      final data = bytesOf(40 * 1024 + 7, seed: 3);
      final chunks = PhotoChunker.split('p', data);
      final assembler = PhotoChunkAssembler();
      Uint8List? result;
      for (final chunk in chunks.reversed) {
        final out = assembler.add(chunk);
        if (out != null) {
          result = out;
        }
      }
      expect(result, isNotNull);
      expect(result, orderedEquals(data));
      expect(assembler.isPending('p'), isFalse);
    });

    test('returns null until the last chunk arrives', () {
      final chunks = PhotoChunker.split('p', bytesOf(20 * 1024));
      final assembler = PhotoChunkAssembler();
      expect(assembler.add(chunks[0]), isNull);
      expect(assembler.isPending('p'), isTrue);
      expect(assembler.add(chunks[1]), isNotNull);
    });

    test('rejects a tampered chunk via SHA-256', () {
      final data = bytesOf(30 * 1024);
      final chunks = PhotoChunker.split('p', data);
      final tampered = PhotoChunk(
        photoId: chunks[1].photoId,
        index: chunks[1].index,
        total: chunks[1].total,
        data: base64Encode(bytesOf(1000, seed: 99)),
        sha256: chunks[1].sha256,
      );
      final assembler = PhotoChunkAssembler();
      assembler.add(chunks[0]);
      expect(
        () => assembler.add(tampered),
        throwsA(isA<PhotoAssemblyException>()),
      );
    });

    test('rejects a forged hash', () {
      final data = bytesOf(1000);
      final chunk = PhotoChunker.split('p', data).single;
      final forged = PhotoChunk(
        photoId: chunk.photoId,
        index: chunk.index,
        total: chunk.total,
        data: chunk.data,
        sha256: sha256.convert(bytesOf(1000, seed: 5)).toString(),
      );
      expect(
        () => PhotoChunkAssembler().add(forged),
        throwsA(isA<PhotoAssemblyException>()),
      );
    });

    test('rejects a chunk larger than 16 KB', () {
      final oversized = PhotoChunk(
        photoId: 'p',
        index: 0,
        total: 1,
        data: base64Encode(bytesOf(16 * 1024 + 1)),
        sha256: 'x',
      );
      expect(
        () => PhotoChunkAssembler().add(oversized),
        throwsA(isA<PhotoAssemblyException>()),
      );
    });

    test('rejects a photo that grows past 2 MB', () {
      final assembler = PhotoChunkAssembler();
      const total = 129; // 129 * 16 KB > 2 MB
      final hash = 'f' * 64;
      expect(() {
        for (var i = 0; i < total; i++) {
          assembler.add(
            PhotoChunk(
              photoId: 'big',
              index: i,
              total: total,
              data: base64Encode(Uint8List(16 * 1024)),
              sha256: hash,
            ),
          );
        }
      }, throwsA(isA<PhotoAssemblyException>()));
    });

    test('rejects an out of range index', () {
      expect(
        () => PhotoChunkAssembler().add(
          const PhotoChunk(
            photoId: 'p',
            index: 2,
            total: 2,
            data: 'AA==',
            sha256: 'x',
          ),
        ),
        throwsA(isA<PhotoAssemblyException>()),
      );
    });

    test('rejects duplicate chunks', () {
      final chunks = PhotoChunker.split('p', bytesOf(20 * 1024));
      final assembler = PhotoChunkAssembler()..add(chunks[0]);
      expect(
        () => assembler.add(chunks[0]),
        throwsA(isA<PhotoAssemblyException>()),
      );
    });

    test('rejects mismatched metadata for the same photo', () {
      final chunks = PhotoChunker.split('p', bytesOf(20 * 1024));
      final assembler = PhotoChunkAssembler()..add(chunks[0]);
      final other = PhotoChunk(
        photoId: 'p',
        index: 1,
        total: chunks[1].total,
        data: chunks[1].data,
        sha256: 'different',
      );
      expect(
        () => assembler.add(other),
        throwsA(isA<PhotoAssemblyException>()),
      );
    });

    test('rejects invalid base64', () {
      expect(
        () => PhotoChunkAssembler().add(
          const PhotoChunk(
            photoId: 'p',
            index: 0,
            total: 1,
            data: '!!!',
            sha256: 'x',
          ),
        ),
        throwsA(isA<PhotoAssemblyException>()),
      );
    });

    test('interleaves two photos without mixing bytes', () {
      final a = bytesOf(20 * 1024, seed: 1);
      final b = bytesOf(20 * 1024, seed: 2);
      final chunksA = PhotoChunker.split('a', a);
      final chunksB = PhotoChunker.split('b', b);
      final assembler = PhotoChunkAssembler();
      Uint8List? doneA;
      Uint8List? doneB;
      for (var i = 0; i < 2; i++) {
        doneA = assembler.add(chunksA[i]) ?? doneA;
        doneB = assembler.add(chunksB[i]) ?? doneB;
      }
      expect(doneA, orderedEquals(a));
      expect(doneB, orderedEquals(b));
    });

    test('discard drops a partial transfer', () {
      final chunks = PhotoChunker.split('p', bytesOf(20 * 1024));
      final assembler = PhotoChunkAssembler()..add(chunks[0]);
      expect(assembler.isPending('p'), isTrue);
      assembler.discard('p');
      expect(assembler.isPending('p'), isFalse);
    });
  });
}
