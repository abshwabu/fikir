class EthiopianDate {
  const EthiopianDate({
    required this.year,
    required this.month,
    required this.day,
  }) : assert(month >= 1 && month <= 13, 'Month must be between 1 and 13'),
       assert(day >= 1 && day <= 30, 'Day must be between 1 and 30');

  final int year;
  final int month;
  final int day;

  static const List<String> monthNamesEnglish = [
    'Meskerem',
    'Tikimt',
    'Hidar',
    'Tahsas',
    'Tir',
    'Yekatit',
    'Megabit',
    'Miazia',
    'Ginbot',
    'Sene',
    'Hamle',
    'Nehase',
    'Pagume',
  ];

  static const List<String> monthNamesAmharic = [
    'መስከረም',
    'ጥቅምት',
    'ኅዳር',
    'ታኅሣሥ',
    'ጥር',
    'የካቲት',
    'መጋቢት',
    'ሚያዝያ',
    'ግንቦት',
    'ሰኔ',
    'ሐምሌ',
    'ነሐሴ',
    'ጳጉሜ',
  ];

  bool get isLeapYear => (year % 4) == 3;

  int get maxDaysInMonth {
    if (month < 13) return 30;
    return isLeapYear ? 6 : 5;
  }

  String get monthNameEnglish => monthNamesEnglish[month - 1];
  String get monthNameAmharic => monthNamesAmharic[month - 1];

  /// Converts Gregorian [DateTime] to [EthiopianDate].
  static EthiopianDate fromGregorian(DateTime gregorian) {
    final jdn = _gregorianToJdn(gregorian.year, gregorian.month, gregorian.day);
    return _jdnToEthiopian(jdn);
  }

  /// Converts this [EthiopianDate] to Gregorian [DateTime].
  DateTime toGregorian() {
    final jdn = _ethiopianToJdn(year, month, day);
    return _jdnToGregorian(jdn);
  }

  static int _gregorianToJdn(int year, int month, int day) {
    var y = year;
    var m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = y ~/ 100;
    final b = 2 - a + (a ~/ 4);
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        day +
        b -
        1524;
  }

  static DateTime _jdnToGregorian(int jdn) {
    final l = jdn + 68569;
    final n = (4 * l) ~/ 146097;
    final l1 = l - ((146097 * n + 3) ~/ 4);
    final i = (4000 * (l1 + 1)) ~/ 1461001;
    final l2 = l1 - ((1461 * i) ~/ 4) + 31;
    final j = (80 * l2) ~/ 2447;
    final day = l2 - ((2447 * j) ~/ 80);
    final l3 = j ~/ 11;
    final month = j + 2 - 12 * l3;
    final year = 100 * (n - 49) + i + l3;
    return DateTime.utc(year, month, day);
  }

  static int _ethiopianToJdn(int year, int month, int day) {
    const jdnOffset = 1723856;
    return (jdnOffset + 365) +
        365 * (year - 1) +
        (year ~/ 4) +
        30 * (month - 1) +
        day -
        1;
  }

  static EthiopianDate _jdnToEthiopian(int jdn) {
    const jdnOffset = 1723856;
    final r = (jdn - jdnOffset) % 1461;
    final n = (r % 365) + 365 * (r ~/ 1460);
    final year = 4 * ((jdn - jdnOffset) ~/ 1461) +
        (r ~/ 365) -
        (r ~/ 1460);
    final month = (n ~/ 30) + 1;
    final day = (n % 30) + 1;
    return EthiopianDate(year: year, month: month, day: day);
  }

  String format({bool useAmharicMonth = false}) {
    final mName = useAmharicMonth ? monthNameAmharic : monthNameEnglish;
    return '$mName $day, $year';
  }

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EthiopianDate &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => year.hashCode ^ month.hashCode ^ day.hashCode;
}
