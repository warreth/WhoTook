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
