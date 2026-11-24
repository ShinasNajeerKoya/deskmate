/// Small formatting helpers (no intl: the phone app is English-only for now).
library;

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
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

String two(int n) => n.toString().padLeft(2, '0');

/// "3:40 PM" (12-hour) or "15:40" (24-hour).
String clockWithSuffix(DateTime d, bool use24h) =>
    use24h ? clockText(d, true) : '${displayHour(d, false)}:${two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';

/// "Monday, 23 November"
String longDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// "MON · 23 NOV"
String shortDateCaps(DateTime d) =>
    '${_weekdays[d.weekday - 1].substring(0, 3)} · ${d.day} ${_months[d.month - 1].substring(0, 3)}'.toUpperCase();

/// "Mon 23 Nov"
String dayMonthShort(DateTime d) =>
    '${_weekdays[d.weekday - 1].substring(0, 3)} ${d.day} ${_months[d.month - 1].substring(0, 3)}';

/// Single-letter weekday, "M".."S".
String weekdayLetter(DateTime d) => _weekdays[d.weekday - 1][0];

int displayHour(DateTime d, bool use24h) => use24h ? d.hour : (d.hour % 12 == 0 ? 12 : d.hour % 12);

/// "10:42" in the chosen format.
String clockText(DateTime d, bool use24h) => '${two(displayHour(d, use24h))}:${two(d.minute)}';

/// "1:24" from seconds.
String stopwatch(Duration d) =>
    d.inHours > 0 ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}' : mmss(d.inSeconds);

String mmss(int seconds) => '${seconds ~/ 60}:${two(seconds % 60)}';

/// "1h 48m" / "12m"
String hm(Duration d) => d.inHours > 0 ? '${d.inHours}h ${d.inMinutes % 60}m' : '${d.inMinutes}m';

String pct(double? v) => v == null ? '—' : '${v.round()}%';

/// "1.2M", "820K"
String compact(int? n) {
  if (n == null) return '—';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).round()}K';
  return '$n';
}

/// KB/s → "1.2 MB/s" / "80 KB/s"
String rate(double? kbs) {
  if (kbs == null) return '—';
  return kbs >= 1000 ? '${(kbs / 1000).toStringAsFixed(1)} MB/s' : '${kbs.round()} KB/s';
}

/// MB → "3.3 GB" / "512 MB"
String megabytes(int mb) => mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '$mb MB';

/// "Thu"
String weekdayShort(DateTime d) => _weekdays[d.weekday - 1].substring(0, 3);
