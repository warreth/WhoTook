import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Takes or picks one photo for the optional avatar. The system picker is
/// used on purpose: the player chooses exactly the frame they want to share.
abstract class AvatarPhotoService {
  Future<Uint8List?> pick({required bool camera});
}

class DeviceAvatarPhotoService implements AvatarPhotoService {
  DeviceAvatarPhotoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pick({required bool camera}) async {
    try {
      final file = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } on Object {
      return null;
    }
  }
}

final avatarPhotoServiceProvider = Provider<AvatarPhotoService>(
  (ref) => DeviceAvatarPhotoService(),
);
