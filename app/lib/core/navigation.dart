import 'package:flutter/widgets.dart';

/// The app-level navigator, used by deep links so they can open the same
/// identity checkpoint as a scanned QR code.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
