import 'dart:math';

/// =======================================================================
///  ASK AI — CORE (badha module mate common)
///  Stock, Sales, Approval, Approval Return... darek module aa j answer
///  format return kare, etle ek j screen badha mate chale.
/// =======================================================================

class AiStat {
  final String label;
  final String value;
  const AiStat(this.label, this.value);
}

class AiRow {
  final String title;
  final String value;
  final String? sub;

  /// 0..1 progress bar
  final double? bar;

  /// tap karvathi aa sawal puchay
  final String? askOnTap;

  const AiRow(this.title, this.value, {this.sub, this.bar, this.askOnTap});
}

class AiSection {
  final String title;
  final List<AiRow> rows;
  const AiSection(this.title, this.rows);
}

/// List ma batavva nu ek record (stock piece, sale bill, approval...)
class AiRecord {
  final String title;
  final String? subtitle;
  final String? value;
  final String? badge;
  final bool badgeGood;
  final String? imageUrl;
  final bool showThumb;
  final List<AiStat> details;

  final String? refId;            // 🔥 1) NAVU FIELD

  const AiRecord({
    required this.title,
    this.subtitle,
    this.value,
    this.badge,
    this.badgeGood = true,
    this.imageUrl,
    this.showThumb = false,
    this.details = const [],
    this.refId,                   // 🔥 2) CONSTRUCTOR MA
  });
}

class AiAnswer {
  final String text;
  final String speech;
  final List<AiStat> stats;
  final List<AiSection> sections;
  final List<AiRecord> items;
  final String? itemsTitle;
  final List<String> followUps;
  final String? filterLabel;

  /// Answer koi date range mate hoy to (report screen ma kholva mate)
  final AiPeriod? period;

  const AiAnswer({
    required this.text,
    String? speech,
    this.stats = const [],
    this.sections = const [],
    this.items = const [],
    this.itemsTitle,
    this.followUps = const [],
    this.filterLabel,
    this.period,
  }) : speech = speech ?? text;
}

// =======================================================================
//  PERIOD (aaje, kale, aa mahina, gaya mahina, chhela 7 divas, september...)
// =======================================================================

enum PeriodKind { day, week, month, year, fy, custom }

class AiPeriod {
  final DateTime from; // 00:00
  final DateTime to; // inclusive (date only)
  final String label;
  final PeriodKind kind;

  AiPeriod(DateTime from, DateTime to, this.label, this.kind)
      : from = DateTime(from.year, from.month, from.day),
        to = DateTime(to.year, to.month, to.day);

  bool contains(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(from) && !x.isAfter(to);
  }

  int get days => to.difference(from).inDays + 1;

  /// Sarkhamni mate aagal no same samay
  AiPeriod previous() {
    switch (kind) {
      case PeriodKind.month:
        final pf = DateTime(from.year, from.month - 1, 1);
        final lastDay = DateTime(pf.year, pf.month + 1, 0).day;
        final pt = DateTime(pf.year, pf.month, min(to.day, lastDay));
        return AiPeriod(pf, pt, 'Aagla mahina (${AiFmt.date(pf)} – ${AiFmt.date(pt)})', PeriodKind.month);
      case PeriodKind.year:
      case PeriodKind.fy:
        final pf = DateTime(from.year - 1, from.month, from.day);
        final pt = DateTime(to.year - 1, to.month, to.day);
        return AiPeriod(pf, pt, 'Aagla varsh (${AiFmt.date(pf)} – ${AiFmt.date(pt)})', kind);
      default:
        final pt = from.subtract(const Duration(days: 1));
        final pf = pt.subtract(Duration(days: days - 1));
        return AiPeriod(pf, pt, 'Aagla $days divas (${AiFmt.date(pf)} – ${AiFmt.date(pt)})', kind);
    }
  }

  @override
  String toString() => '$label [${AiFmt.date(from)} – ${AiFmt.date(to)}]';
}

class AiPeriodParser {
  static const _months = {
    'january': 1, 'jan': 1, 'janyuari': 1, 'february': 2, 'feb': 2, 'febuari': 2,
    'march': 3, 'mar': 3, 'april': 4, 'apr': 4, 'may': 5, 'mey': 5,
    'june': 6, 'jun': 6, 'july': 7, 'jul': 7, 'julai': 7, 'august': 8, 'aug': 8,
    'ogast': 8, 'september': 9, 'sep': 9, 'sept': 9, 'october': 10, 'oct': 10,
    'oktobar': 10, 'november': 11, 'nov': 11, 'navembar': 11, 'december': 12, 'dec': 12,
    'disembar': 12,
  };

  /// [t] normalize karelo text hovo joie (AiText.normalize)
  static AiPeriod? parse(String t, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    bool has(List<String> w) => AiText.has(t, w);

    // chhela N divas / last N days / chhela N mahina
    final m = RegExp(r'(chhela|chela|chhella|last|past|pachhla|pichhle|pichle)\s*(\d+)\s*(divas|din|days|day|mahina|mahino|months|month|athvadiya|weeks|week|varsh|years|year)')
        .firstMatch(t);
    if (m != null) {
      final k = int.parse(m[2]!);
      final u = m[3]!;
      if (u.startsWith('mah') || u.startsWith('mon')) {
        final f = DateTime(today.year, today.month - k, today.day + 1);
        return AiPeriod(f, today, 'Chhela $k mahina', PeriodKind.custom);
      }
      if (u.startsWith('ath') || u.startsWith('week')) {
        return AiPeriod(today.subtract(Duration(days: k * 7 - 1)), today, 'Chhela $k athvadiya', PeriodKind.custom);
      }
      if (u.startsWith('var') || u.startsWith('year')) {
        return AiPeriod(DateTime(today.year - k, today.month, today.day + 1), today, 'Chhela $k varsh', PeriodKind.custom);
      }
      return AiPeriod(today.subtract(Duration(days: k - 1)), today, 'Chhela $k divas', PeriodKind.custom);
    }

    final last = has(['gaya', 'gayo', 'gai', 'gayu', 'last', 'pichhla', 'pichle', 'pichla', 'previous', 'aaglo', 'agla']);

    if (has(['parmdivas', 'parmdi', 'day before yesterday', 'parso'])) {
      final d = today.subtract(const Duration(days: 2));
      return AiPeriod(d, d, 'Parmdivas', PeriodKind.day);
    }
    if (has(['aaje', 'aaj ', 'aje ', 'today', 'aajnu'])) {
      return AiPeriod(today, today, 'Aaje', PeriodKind.day);
    }
    if (has(['kale ', 'gai kale', 'yesterday', 'kal '])) {
      final d = today.subtract(const Duration(days: 1));
      return AiPeriod(d, d, 'Kale', PeriodKind.day);
    }

    if (has(['athvadiy', 'athvadiu', 'week', 'saptah', 'hafte', 'hafta'])) {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      if (last) {
        final f = monday.subtract(const Duration(days: 7));
        return AiPeriod(f, f.add(const Duration(days: 6)), 'Gaya athvadiye', PeriodKind.week);
      }
      return AiPeriod(monday, today, 'Aa athvadiye', PeriodKind.week);
    }

    // month name: "september", "september 2026"
    for (final e in _months.entries) {
      final mm = RegExp('(^|\\s)${e.key}(\\s+(\\d{4}))?(\\s|\$)').firstMatch(t);
      if (mm == null) continue;
      var y = mm[3] != null ? int.parse(mm[3]!) : today.year;
      if (mm[3] == null && e.value > today.month) y -= 1; // aavta mahina nahi, gaya varsh no
      final f = DateTime(y, e.value, 1);
      var to = DateTime(y, e.value + 1, 0);
      if (to.isAfter(today)) to = today;
      return AiPeriod(f, to, '${_monthName(e.value)} $y', PeriodKind.month);
    }

    // "mahina wise" / "monthly" = trend, period nahi
    final grouping = has(['wise', 'pramane', 'mujab', 'monthly', 'yearly', 'daily', 'trend']);

    if (!grouping && has(['mahina', 'mahino', 'mahine', 'month', 'mahinanu'])) {
      if (last) {
        final f = DateTime(today.year, today.month - 1, 1);
        return AiPeriod(f, DateTime(today.year, today.month, 0), 'Gaya mahine (${_monthName(f.month)})', PeriodKind.month);
      }
      return AiPeriod(DateTime(today.year, today.month, 1), today, 'Aa mahine (${_monthName(today.month)})', PeriodKind.month);
    }

    if (has(['financial year', 'fy ', 'nanakiy'])) {
      final startY = today.month >= 4 ? today.year : today.year - 1;
      if (last) {
        return AiPeriod(DateTime(startY - 1, 4, 1), DateTime(startY, 3, 31), 'Gayu FY ${startY - 1}-${(startY) % 100}', PeriodKind.fy);
      }
      return AiPeriod(DateTime(startY, 4, 1), today, 'Aa FY $startY-${(startY + 1) % 100}', PeriodKind.fy);
    }

    if (!grouping && has(['varsh', 'year', 'saal', 'sal '])) {
      if (last) {
        return AiPeriod(DateTime(today.year - 1, 1, 1), DateTime(today.year - 1, 12, 31), 'Gaya varsh ${today.year - 1}', PeriodKind.year);
      }
      return AiPeriod(DateTime(today.year, 1, 1), today, 'Aa varsh ${today.year}', PeriodKind.year);
    }
    return null;
  }

  static const _mNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];
  static String _monthName(int m) => _mNames[(m - 1) % 12];
  static String monthName(int m) => _monthName(m);
}

// =======================================================================
//  TEXT — Gujarati / Hindi / English / Gujlish normalize
// =======================================================================

class AiText {
  static const Map<String, String> _script = {
    // Gujarati
    'ગ્રામ': 'gram', 'થી': 'thi', 'વધારે': 'vadhare', 'વધુ': 'vadhu', 'ઓછું': 'ochhu',
    'ઓછા': 'ochha', 'નીચે': 'niche', 'ઉપર': 'upar', 'જૂનો': 'juno', 'જુનો': 'juno',
    'જૂનું': 'junu', 'દિવસ': 'divas', 'મહિના': 'mahina', 'મહિનો': 'mahino', 'મહિને': 'mahine',
    'વર્ષ': 'varsh', 'વેચાય': 'vechay', 'વેચાણ': 'vechan', 'વેચાયેલ': 'vechayel',
    'નથી': 'nathi', 'સ્ટોક': 'stock', 'કેટલા': 'ketla', 'કેટલો': 'ketlo', 'કેટલું': 'ketlu',
    'કુલ': 'kul', 'સૌથી': 'sauthi', 'બતાવ': 'batav', 'આજે': 'aaje', 'આજ': 'aaj',
    'કાલે': 'kale', 'ગઈકાલે': 'gai kale', 'ગયા': 'gaya', 'ગયો': 'gayo', 'ગયું': 'gayu',
    'આ': 'aa', 'અઠવાડિયે': 'athvadiye', 'અઠવાડિયું': 'athvadiyu', 'અઠવાડિયા': 'athvadiya',
    'છેલ્લા': 'chhela', 'બિલ': 'bill', 'ગ્રાહક': 'grahak', 'પાર્ટી': 'party',
    'રૂપિયા': 'rupiya', 'મજૂરી': 'majuri', 'ફાઈન': 'fine', 'સરેરાશ': 'sarasari',
    'સરખામણી': 'sarkhamni', 'વધ્યું': 'vadhyu', 'ઘટ્યું': 'ghatyu', 'કોણે': 'kone',
    'બનાવ્યા': 'banavya', 'મોટું': 'motu', 'મોટો': 'moto', 'રોજ': 'roj', 'વાર': 'var',
    'આવ્યા': 'aavya', 'ગ્રાહકો': 'grahako',
    // Hindi
    'ग्राम': 'gram', 'से': 'se', 'ज्यादा': 'jyada', 'कम': 'kam', 'दिन': 'din',
    'महीने': 'mahine', 'महीना': 'mahina', 'आज': 'aaj', 'कल': 'kal', 'पिछले': 'pichhle',
    'इस': 'is', 'हफ्ते': 'hafte', 'साल': 'saal', 'बिक्री': 'vechan', 'ग्राहक': 'grahak',
    'कितना': 'kitna', 'कितने': 'kitne', 'सबसे': 'sabse', 'बिल': 'bill', 'रुपये': 'rupiya',
    'मजदूरी': 'majuri', 'नहीं': 'nahi', 'किसने': 'kone',
  };

  static const Map<String, String> _numWords = {
    'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6',
    'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10', 'fifteen': '15', 'twenty': '20',
    'thirty': '30', 'forty': '40', 'fifty': '50', 'sixty': '60', 'ninety': '90', 'hundred': '100',
    'ek': '1', 'tran': '3', 'char': '4', 'panch': '5', 'paanch': '5', 'saat': '7', 'das': '10',
    'pandar': '15', 'vis': '20', 'bees': '20', 'tris': '30', 'tees': '30', 'chalis': '40',
    'pachas': '50', 'saath': '60', 'nevu': '90', 'nabbe': '90',
  };

  static String normalize(String raw) {
    var t = raw.toLowerCase();
    const gu = '૦૧૨૩૪૫૬૭૮૯', hi = '०१२३४५६७८९';
    for (var i = 0; i < 10; i++) {
      t = t.replaceAll(gu[i], '$i').replaceAll(hi[i], '$i');
    }
    final keys = _script.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in keys) {
      t = t.replaceAll(k, ' ${_script[k]} ');
    }
    t = t.replaceAllMapped(
        RegExp(r'(\d+(?:\.\d+)?)\s*[–~]\s*(\d+(?:\.\d+)?)'), (m) => '${m[1]} to ${m[2]}');
    t = t.replaceAll('₹', ' rupiya ');
    t = t.replaceAll(RegExp(r'[^a-z0-9\.\+\-\s]'), ' ');
    final nk = _numWords.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in nk) {
      t = t.replaceAll(RegExp('\\b$k\\b'), _numWords[k]!);
    }
    t = t.replaceAllMapped(RegExp(r'(\d)\s*(gms|gm|grams|gram|grm|gr|g)\b'), (m) => '${m[1]} gram');
    t = t.replaceAllMapped(RegExp(r'(\d)\s*(k|hajar|hazar|thousand)\b'), (m) => '${m[1]}000');
    t = t.replaceAllMapped(RegExp(r'(\d)\s*(lakh|lac|lakhs)\b'), (m) => '${m[1]}00000');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Word ni sharuat thi match ("old" -> "gold" ma match NA thay)
  static bool has(String t, List<String> words) {
    final s = ' $t ';
    return words.any((w) => s.contains(' $w'));
  }

  static int score(String t, List<String> words) {
    final s = ' $t ';
    return words.where((w) => s.contains(' $w')).length;
  }

  /// "10 thi 15 gram", "50 gram thi vadhare", "20 gram niche"
  static ({double? min, double? max}) weightRange(String t) {
    const nr = r'(\d+(?:\.\d+)?)';
    final range = RegExp('$nr\\s*(?:gram\\s*)?(?:to|thi|se|and|ane|upto|sudhi|till|-)\\s*$nr\\s*gram').firstMatch(t) ??
        RegExp('$nr\\s*gram\\s*(?:to|thi|se|and|ane|-)\\s*$nr').firstMatch(t);
    if (range != null) {
      final a = double.parse(range[1]!), b = double.parse(range[2]!);
      return (min: min(a, b), max: max(a, b));
    }
    final above = RegExp('$nr\\s*gram\\s*(?:thi|se|na|ni|nu)?\\s*(?:upar|uper|vadhare|vadhu|above|more|over|jyada|plus|\\+)')
        .firstMatch(t);
    if (above != null) return (min: double.parse(above[1]!), max: null);
    final below = RegExp('$nr\\s*gram\\s*(?:thi|se|na|ni|nu)?\\s*(?:niche|ochhu|ochu|ochha|below|under|less|kam|andar|sudhi)')
        .firstMatch(t);
    if (below != null) return (min: null, max: double.parse(below[1]!));
    return (min: null, max: null);
  }
}

// =======================================================================
//  FORMAT — Indian number style
// =======================================================================

class AiFmt {
  /// 156509.62 -> 1,56,509.62
  static String inr(double v, {int decimals = 0}) {
    final neg = v < 0;
    final s = v.abs().toStringAsFixed(decimals);
    final parts = s.split('.');
    var ip = parts[0];
    String out;
    if (ip.length <= 3) {
      out = ip;
    } else {
      final last3 = ip.substring(ip.length - 3);
      var rest = ip.substring(0, ip.length - 3);
      final groups = <String>[];
      while (rest.length > 2) {
        groups.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) groups.insert(0, rest);
      out = '${groups.join(',')},$last3';
    }
    if (parts.length > 1 && decimals > 0) out = '$out.${parts[1]}';
    return '${neg ? '-' : ''}₹$out';
  }

  /// Bolva mate: 156509 -> "1.57 lakh rupiya"
  static String spokenInr(double v) {
    final a = v.abs();
    if (a >= 10000000) return '${_trim(a / 10000000)} crore rupiya';
    if (a >= 100000) return '${_trim(a / 100000)} lakh rupiya';
    if (a >= 1000) return '${_trim(a / 1000)} hajar rupiya';
    return '${a.round()} rupiya';
  }

  static String _trim(double v) => v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

  /// grams: 5714.794 -> "5,714.79"
  static String g(double v) {
    if (v == v.roundToDouble()) return _group(v.toStringAsFixed(0));
    final s = v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    final p = s.split('.');
    return p.length > 1 ? '${_group(p[0])}.${p[1]}' : _group(p[0]);
  }

  static String _group(String ip) {
    final neg = ip.startsWith('-');
    if (neg) ip = ip.substring(1);
    if (ip.length <= 3) return '${neg ? '-' : ''}$ip';
    return '${neg ? '-' : ''}${inr(double.parse(ip)).substring(1)}';
  }

  static String pct(double v) => '${(v * 100).round()}%';

  static String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  static String shortDate(DateTime d) =>
      '${d.day} ${AiPeriodParser.monthName(d.month).substring(0, 3)}';

  static const weekdays = ['Somvar', 'Mangalvar', 'Budhvar', 'Guruvar', 'Shukravar', 'Shanivar', 'Ravivar'];

  /// Farak: +12% / -8%
  static String change(double now, double before) {
    if (before == 0) return now == 0 ? '0%' : 'navu';
    final c = (now - before) / before;
    return '${c >= 0 ? '+' : ''}${(c * 100).round()}%';
  }
}
