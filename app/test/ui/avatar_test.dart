import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/core/avatars.dart';
import 'package:whotook/core/media/avatar_photo_service.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/ui/screens/avatar_crop_screen.dart';
import 'package:whotook/ui/widgets/avatar_editor.dart';
import 'package:whotook/ui/widgets/common.dart';

class _FakeCropper implements AvatarCropper {
  _FakeCropper(this.bytes);
  final Uint8List bytes;

  @override
  Future<Uint8List?> crop(RenderRepaintBoundary boundary) async => bytes;
}

class _FakePhotoService implements AvatarPhotoService {
  _FakePhotoService(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List?> pick({required bool camera}) async => bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final photo = File('test/ui/fixtures/party-dog.jpg').readAsBytesSync();

  testWidgets('the crop screen returns a small avatar image', (tester) async {
    Uint8List? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avatarCropperProvider.overrideWithValue(_FakeCropper(photo)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildWhoTookTheme(Brightness.light),
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Uint8List>(
                    MaterialPageRoute<Uint8List>(
                      builder: (_) => AvatarCropScreen(imageBytes: photo),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Your photo'), findsOneWidget);
    await tester.tap(find.text('Use this photo'));
    await tester.pump();
    for (var i = 0; i < 30 && result == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(result, isNotNull);
    expect(result, isNotEmpty);
  });

  testWidgets('the avatar editor saves a picked photo', (tester) async {
    String? avatar;
    String? stored;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avatarPhotoServiceProvider.overrideWithValue(
            _FakePhotoService(photo),
          ),
          avatarCropperProvider.overrideWithValue(_FakeCropper(photo)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildWhoTookTheme(Brightness.light),
          home: Scaffold(
            body: AvatarEditor(
              avatar: kAvatarIds.first,
              photoBase64: null,
              onChanged: (nextAvatar, nextPhoto) {
                avatar = nextAvatar;
                stored = nextPhoto;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Take a selfie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AvatarCropScreen), findsOneWidget);
    await tester.tap(find.text('Use this photo'));
    await tester.pump();
    for (var i = 0; i < 30 && avatar == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(avatar, kPhotoAvatar);
    expect(stored, isNotNull);
    expect(stored, isNotEmpty);
  });

  testWidgets('the avatar widget renders the stored photo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildWhoTookTheme(Brightness.light),
        home: Center(
          child: PlayerAvatar(
            initial: 'Bram',
            avatar: kPhotoAvatar,
            photoBase64: base64Encode(photo),
            size: 48,
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });
}
