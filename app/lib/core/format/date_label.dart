import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';

String monthName(AppLocalizations l10n, int month) =>
    DateFormat.MMMM(l10n.localeName).format(DateTime(2000, month));

String monthShort(AppLocalizations l10n, int month) =>
    DateFormat.MMM(l10n.localeName).format(DateTime(2000, month));

String monthYear(AppLocalizations l10n, int year, int month) =>
    '${monthName(l10n, month)} $year';

/// "3 years" / "7 months" / "1 year 2 months" for a month distance.
String monthDistance(AppLocalizations l10n, int months) {
  if (months <= 0) return l10n.exact;
  final years = months ~/ 12;
  final rest = months % 12;
  if (years == 0) return l10n.monthCount(rest);
  final yearLabel = l10n.yearCount(years);
  if (rest == 0) return yearLabel;
  return '$yearLabel ${l10n.monthCount(rest)}';
}
