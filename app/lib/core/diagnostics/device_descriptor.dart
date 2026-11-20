import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// A compact, privacy-safe hardware description for bug reports. No device
/// name, advertising id or account data is read.
class DeviceDescriptor {
  const DeviceDescriptor({required this.osLabel, required this.deviceLabel});

  final String osLabel;
  final String deviceLabel;
}

/// Returns null on the web and on platforms without a useful descriptor.
Future<DeviceDescriptor?> readDeviceDescriptor() async {
  if (kIsWeb) return null;
  try {
    final info = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = await info.androidInfo;
        final release = android.version.release;
        final osLabel = RegExp(r'^\d+(\.\d+)*$').hasMatch(release)
            ? 'Android $release'
            : 'Android SDK ${android.version.sdkInt}';
        return DeviceDescriptor(
          osLabel: osLabel,
          deviceLabel:
              '${android.manufacturer} ${android.model} '
              '(SDK ${android.version.sdkInt})',
        );
      case TargetPlatform.iOS:
        final ios = await info.iosInfo;
        return DeviceDescriptor(
          osLabel: '${ios.systemName} ${ios.systemVersion}',
          deviceLabel: '${ios.model} (${ios.utsname.machine})',
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  } on Object {
    return null;
  }
}
