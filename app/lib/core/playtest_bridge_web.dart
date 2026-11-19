// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

void publish(String json) {
  html.window.localStorage['whotook.playtest.state'] = json;
}

String? takePlaytestCommand() {
  final raw = html.window.localStorage['whotook.playtest.command'];
  if (raw == null || raw.isEmpty) return null;
  html.window.localStorage.remove('whotook.playtest.command');
  return raw;
}
