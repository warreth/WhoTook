const List<String> monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> monthShortNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String monthName(int month) => monthNames[(month - 1).clamp(0, 11)];

String monthShort(int month) => monthShortNames[(month - 1).clamp(0, 11)];

String monthYear(int year, int month) => '${monthName(month)} $year';

/// "3 years" / "7 months" / "1 year 2 months" for a month distance.
String monthDistance(int months) {
  if (months <= 0) return 'exact';
  final years = months ~/ 12;
  final rest = months % 12;
  if (years == 0) return rest == 1 ? '1 month' : '$rest months';
  final yearLabel = years == 1 ? '1 year' : '$years years';
  if (rest == 0) return yearLabel;
  final restLabel = rest == 1 ? '1 month' : '$rest months';
  return '$yearLabel $restLabel';
}
