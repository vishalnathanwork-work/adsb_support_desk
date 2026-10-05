import 'package:intl/intl.dart';

class DateFormatter {
  static String relative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return DateFormat('dd MMM yyyy').format(dt);
  }

  static String full(DateTime dt) {
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }
}
