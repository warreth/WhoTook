import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';

/// Opens a public WhoTook page or mail client outside the app.
Future<void> openExternal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.parse(url);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}

Future<void> openSupport(BuildContext context) =>
    openExternal(context, 'mailto:$kSupportEmail?subject=WhoTook%20support');

/// The right store for this phone. iOS is not in the App Store yet, so the
/// website explains the SideStore route until the listing is live.
String appStoreUrl() {
  if (kIsWeb) return kSiteUrl;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => kAndroidStoreUrl,
    TargetPlatform.iOS => kIosStoreUrl,
    _ => kSiteUrl,
  };
}
