/// =======================================================================
///  📅 AI DATE WORDS — aaje / kale / parmdivase … badhi bhasha ma
///
///  Gujarati : આજે, કાલે, ગઈકાલે, પરમદિવસે, આ અઠવાડિયે, આ મહિને, ગયા મહિને
///  Hindi    : आज, कल, परसों, इस हफ्ते, पिछले हफ्ते, इस महीने, पिछले महीने
///  English  : today, yesterday, day before yesterday, this week, last week,
///             this month, last month, last 7 days, 12-10-2026, 12 october
///  Gujlish  : aaje / aje, kale / gaikale, parmdivase / parso,
///             aa athvadiye, aa mahine, chhella 7 divas, 12 tarikh
///
///  AiDateWords.parse("aje ketlo stock umerayo") → AiDateRange(aaje)
///  File: Ask AI/core/ai_date_words.dart
/// =======================================================================
class AiDateRange {
  final DateTime from; // 00:00
  final DateTime to; // 23:59:59
  final String label; // "Aaje"
  final String key; // today / yesterday / dby / week / ...

  AiDateRange(this.from, this.to, this.label, this.key);

  bool contains(DateTime? d) => d != null && !d.isBefore(from) && !d.isAfter(to);

  bool get singleDay => from.year == to.year && from.month == to.month && from.day == to.day;

  /// "Aaje (15-10-2026)" / "Aa mahine (01-10-2026 thi 15-10-2026)"
  String get title => singleDay ? '$label (${fmt(from)})' : '$label (${fmt(from)} thi ${fmt(to)})';

  /// Sarkhamni mate aagal no etlo j samay (aaje → kale, aa mahine → gaya mahine)
  int get spanDays =>
      DateTime(to.year, to.month, to.day).difference(DateTime(from.year, from.month, from.day)).inDays + 1;

  /// 2 mahina thi lambo samay (varsh / january thi september)?
  bool get isLong => spanDays > 62;

  AiDateRange get previous {
    // lambo samay → gaya varshe aa j samay (business ma aavi j sarkhamni thay)
    if (isLong) {
      DateTime back(DateTime d) => DateTime(d.year - 1, d.month, d.day, d.hour, d.minute, d.second);
      return AiDateRange(back(from), back(to), 'Gaya varshe aa j samay', 'prev');
    }
    if (key == 'this_month' || key == 'last_month' || key.startsWith('month_')) {
      final f = DateTime(from.year, from.month - 1, 1);
      return AiDateRange(f, DateTime(f.year, f.month + 1, 0, 23, 59, 59), 'Aagla mahine', 'prev');
    }
    final days = DateTime(to.year, to.month, to.day).difference(DateTime(from.year, from.month, from.day)).inDays + 1;
    final f = from.subtract(Duration(days: days));
    final t = to.subtract(Duration(days: days));
    final lbl = key == 'today'
        ? 'Kale'
        : key == 'yesterday'
        ? 'Parmdivase'
        : key == 'this_week' || key == 'last_week'
        ? 'Aagla athvadiye'
        : days == 1
        ? fmt(f)
        : 'Aagla $days divas';
    return AiDateRange(f, t, lbl, 'prev');
  }

  /// API mate "2026-10-15"
  String get apiFrom => api(from);
  String get apiTo => api(to);

  static String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  static String api(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  String toString() => 'AiDateRange($key $title)';
}

class AiDateWords {
  // ---------------------------------------------------------------------
  //  Script shabdo → latin (lambu pehla)
  // ---------------------------------------------------------------------
  static const Map<String, String> _script = {
    // ---- Gujarati ----
    'પરમદિવસે': ' parmdivase ', 'પરમ દિવસે': ' parmdivase ', 'પરમદિવસ': ' parmdivase ', 'પરમ દિવસ': ' parmdivase ',
    'પરમદિવસના': ' parmdivase ', 'પરમ દી': ' parmdivase ', 'પરમદી': ' parmdivase ',
    'ગઈકાલે': ' gaikale ', 'ગઈ કાલે': ' gaikale ', 'ગઇકાલે': ' gaikale ', 'ગઇ કાલે': ' gaikale ', 'ગઈકાલ': ' gaikale ',
    'આજે': ' aaje ', 'આજ': ' aaje ', 'આજનું': ' aaje ', 'આજનો': ' aaje ', 'આજના': ' aaje ', 'આજની': ' aaje ',
    'કાલે': ' kale ', 'કાલ': ' kale ', 'કાલનું': ' kale ', 'કાલનો': ' kale ',
    'અઠવાડિયે': ' athvadiye ', 'અઠવાડિયા': ' athvadiye ', 'અઠવાડિયું': ' athvadiye ', 'વીક': ' week ',
    'મહિને': ' mahine ', 'મહિનામાં': ' mahine ', 'મહિના': ' mahine ', 'મહિનો': ' mahine ',
    'વર્ષે': ' varshe ', 'વર્ષ': ' varshe ',
    'ગયા': ' gaya ', 'ગયે': ' gaya ', 'ગયો': ' gaya ', 'છેલ્લા': ' chhella ', 'છેલ્લે': ' chhella ', 'છેલ્લો': ' chhella ',
    'આ ': ' aa ', 'દિવસ': ' divas ', 'દિવસમાં': ' divas ', 'તારીખે': ' tarikh ', 'તારીખ': ' tarikh ',
    'ઉમેરાયો': ' umerayo ', 'ઉમેરાયું': ' umerayo ', 'ઉમેરાયા': ' umerayo ', 'ઉમેર્યો': ' umerayo ', 'ઉમેર્યા': ' umerayo ',
    'આવ્યો': ' aavyo ', 'આવ્યું': ' aavyo ', 'આવ્યા': ' aavyo ', 'નવો': ' navo ', 'નવા': ' navo ', 'નવું': ' navo ',
    'બન્યો': ' banyo ', 'બન્યા': ' banyo ', 'બન્યું': ' banyo ', 'જમા': ' jama ', 'એડ': ' add ',
    'વેચાયું': ' vechayu ', 'વેચાયો': ' vechayu ', 'વેચાયા': ' vechayu ', 'વેચાણ': ' vechan ', 'વેચ્યું': ' vechayu ',
    'વેચ્યા': ' vechayu ', 'વેચાઈ': ' vechayu ', 'સેલ': ' sale ', 'બીલ': ' bill ', 'બિલ': ' bill ',
    'સ્ટોક': ' stock ', 'સ્ટૉક': ' stock ', 'માલ': ' maal ', 'કેટલો': ' ketlo ', 'કેટલું': ' ketlu ', 'કેટલા': ' ketla ',
    'કુલ': ' kul ', 'અપ્રુવલ': ' approval ', 'એપ્રુવલ': ' approval ', 'અપ્રૂવલ': ' approval ',
    'જાન્યુઆરી': ' january ', 'ફેબ્રુઆરી': ' february ', 'માર્ચ': ' march ', 'એપ્રિલ': ' april ',
    'જૂન': ' june ', 'જુલાઈ': ' july ', 'ઓગસ્ટ': ' august ', 'સપ્ટેમ્બર': ' september ', 'ઓક્ટોબર': ' october ',
    'નવેમ્બર': ' november ', 'ડિસેમ્બર': ' december ', 'ઑક્ટોબર': ' october ', 'ઓકટોબર': ' october ',
    'જાન્યુઆરિ': ' january ', 'ઓગષ્ટ': ' august ', 'સપ્ટેંબર': ' september ',
    'થી': ' thi ', 'સુધી': ' sudhi ', 'સુધીનું': ' sudhi ', 'નાણાકીય વર્ષ': ' fy ', 'નાણાકીય': ' fy ',
    'વર્ષમાં': ' varshe ', 'સાલ': ' varshe ',
    // ---- Hindi ----
    'जनवरी': ' january ', 'फरवरी': ' february ', 'मार्च': ' march ', 'अप्रैल': ' april ', 'मई': ' may ',
    'जून': ' june ', 'जुलाई': ' july ', 'अगस्त': ' august ', 'सितंबर': ' september ', 'सितम्बर': ' september ',
    'अक्टूबर': ' october ', 'अक्तूबर': ' october ', 'नवंबर': ' november ', 'नवम्बर': ' november ',
    'दिसंबर': ' december ', 'दिसम्बर': ' december ', 'से': ' se ', 'तक': ' sudhi ', 'वित्तीय वर्ष': ' fy ',
    'परसों': ' parso ', 'परसो': ' parso ', 'आज': ' aaje ', 'कल': ' kale ', 'बीते कल': ' kale ',
    'हफ्ते': ' hafte ', 'हफ़्ते': ' hafte ', 'सप्ताह': ' hafte ', 'हफ्ता': ' hafte ',
    'महीने': ' mahine ', 'महीना': ' mahine ', 'साल': ' varshe ', 'इस': ' is ', 'पिछले': ' pichhle ', 'पिछला': ' pichhle ',
    'पिछली': ' pichhle ', 'पिछले हफ्ते': ' pichhle hafte ', 'दिन': ' divas ', 'तारीख': ' tarikh ', 'तारीख़': ' tarikh ',
    'जुड़ा': ' umerayo ', 'जुड़े': ' umerayo ', 'जोड़ा': ' umerayo ', 'जोड़े': ' umerayo ', 'आया': ' aavyo ',
    'आए': ' aavyo ', 'आये': ' aavyo ', 'नया': ' navo ', 'नए': ' navo ', 'बना': ' banyo ', 'बने': ' banyo ',
    'बिका': ' vechayu ', 'बिके': ' vechayu ', 'बिकी': ' vechayu ', 'बेचा': ' vechayu ', 'बेचे': ' vechayu ',
    'बिक्री': ' vechan ', 'सेल': ' sale ', 'स्टॉक': ' stock ', 'माल': ' maal ', 'कितना': ' ketlo ', 'कितने': ' ketla ',
    'कितनी': ' ketla ',
  };

  /// en_IN engine Gujlish shabdo ne aavu lakhi nakhe che → sachu
  static const Map<String, String> _sound = {
    // aaje
    'aaj': 'aaje', 'aj': 'aaje', 'aje': 'aaje', 'aaje': 'aaje', 'ajje': 'aaje', 'aage': 'aaje', 'aaje ke': 'aaje',
    'aajay': 'aaje', 'aaji': 'aaje', 'today': 'aaje', 'todays': 'aaje', 'today s': 'aaje', 'aajnu': 'aaje',
    'aaj nu': 'aaje', 'aaj no': 'aaje', 'aaj na': 'aaje', 'ajnu': 'aaje',
    // kale / gaikale
    'kaale': 'kale', 'kal': 'kale', 'kalle': 'kale', 'kaley': 'kale', 'call a': 'kale',
    'gai kale': 'kale', 'gaikale': 'kale', 'gay kale': 'kale', 'guy kale': 'kale', 'gai kal': 'kale', 'gaikal': 'kale',
    'yesterday': 'kale', 'yesterdays': 'kale', 'kal nu': 'kale', 'kalnu': 'kale', 'beete kal': 'kale',
    // parmdivase
    'day before yesterday': 'parmdivase', 'parmdivase': 'parmdivase', 'param divase': 'parmdivase',
    'param diwase': 'parmdivase', 'param divas': 'parmdivase', 'param diwas': 'parmdivase', 'parm divase': 'parmdivase',
    'parm diwase': 'parmdivase', 'paramdivase': 'parmdivase', 'parmdivas': 'parmdivase', 'paramdivas': 'parmdivase',
    'farm divase': 'parmdivase', 'param the base': 'parmdivase', 'param devese': 'parmdivase', 'param dive': 'parmdivase',
    'parmdi': 'parmdivase', 'param di': 'parmdivase', 'parso': 'parmdivase', 'parson': 'parmdivase',
    'parsu': 'parmdivase', 'parsun': 'parmdivase', 'parsho': 'parmdivase', 'parsoo': 'parmdivase',
    // athvadiyu / hafto
    'athvadiye': 'week', 'athvadiya': 'week', 'athvadiyu': 'week', 'athwadiye': 'week', 'athwadiya': 'week',
    'athvadia': 'week', 'at wadiye': 'week', 'hafte': 'week', 'hafta': 'week', 'hafto': 'week', 'saptah': 'week',
    // mahino
    'mahine': 'month', 'mahina': 'month', 'mahino': 'month', 'mahinama': 'month', 'mahiney': 'month',
    'mahinay': 'month', 'mahene': 'month', 'mahne': 'month', 'mahinee': 'month',
    'varshe': 'year', 'varas': 'year', 'saal': 'year', 'varsh': 'year', 'varsha': 'year', 'years': 'year',
    'months': 'month', 'financial year': 'fy', 'finance year': 'fy', 'f y': 'fy', 'nanakiya': 'fy',
    'nanakiy': 'fy', 'fiscal year': 'fy', 'till': 'sudhi', 'until': 'sudhi', 'upto': 'sudhi', 'tak': 'sudhi',
    'janvari': 'january', 'january': 'january', 'febserved': 'february', 'februari': 'february',
    'feburary': 'february', 'aprail': 'april', 'epril': 'april', 'julai': 'july', 'agast': 'august',
    'ogast': 'august', 'septembar': 'september', 'sapetmbar': 'september', 'sitambar': 'september',
    'octobar': 'october', 'oktobar': 'october', 'aktubar': 'october', 'navembar': 'november',
    'novembar': 'november', 'disembar': 'december', 'decembar': 'december',
    // gaya / chhella / pichhle
    'gaya': 'last', 'gaye': 'last', 'gya': 'last', 'pichhle': 'last', 'pichle': 'last', 'pichhla': 'last',
    'chhella': 'last', 'chella': 'last', 'chela': 'last', 'chhelle': 'last', 'previous': 'last',
    'is': 'this', 'aa': 'this', 'current': 'this', 'chalu': 'this',
    'divas': 'days', 'diwas': 'days', 'din': 'days', 'day': 'days',
    'tarikh': 'date', 'tarik': 'date', 'tareekh': 'date', 'tarikhe': 'date',
  };

  static const Map<String, int> _months = {
    'january': 1, 'jan': 1, 'janyuari': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3, 'april': 4, 'apr': 4,
    'may': 5, 'june': 6, 'jun': 6, 'july': 7, 'jul': 7, 'julai': 7, 'august': 8, 'aug': 8, 'ogast': 8,
    'september': 9, 'sep': 9, 'sept': 9, 'october': 10, 'oct': 10, 'oktobar': 10, 'november': 11, 'nov': 11,
    'december': 12, 'dec': 12, 'disembar': 12,
  };

  static const Map<String, String> _wordNum = {
    'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6', 'seven': '7', 'eight': '8',
    'nine': '9', 'ten': '10', 'fifteen': '15', 'twenty': '20', 'thirty': '30',
    'be': '2', 'tran': '3', 'char': '4', 'panch': '5', 'chha': '6', 'saat': '7', 'sat': '7', 'aath': '8',
    'das': '10', 'pandar': '15', 'vis': '20', 'tris': '30',
  };

  /// Script + sound fix pachhi no latin text (fakt date samajva mate)
  static String normalize(String raw) {
    var t = ' ${raw.toLowerCase()} ';
    const gu = '૦૧૨૩૪૫૬૭૮૯';
    const hi = '०१२३४५६७८९';
    for (var i = 0; i < 10; i++) {
      t = t.replaceAll(gu[i], '$i').replaceAll(hi[i], '$i');
    }
    final sk = _script.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in sk) {
      t = t.replaceAll(k, _script[k]!);
    }
    // "12/10/2026", "12.10.2026" → "12-10-2026"
    t = t.replaceAllMapped(RegExp(r'(\d{1,2})[/.](\d{1,2})[/.](\d{2,4})'), (m) => '${m[1]}-${m[2]}-${m[3]}');
    t = t.replaceAll(RegExp(r"[^a-z0-9\-\s]"), ' ').replaceAll(RegExp(r'\s+'), ' ');
    t = ' ${t.trim()} ';
    final fk = _sound.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in fk) {
      t = t.replaceAll(' $k ', ' ${_sound[k]} ');
      t = t.replaceAll(' $k ', ' ${_sound[k]} '); // bevdu (lagolag shabd)
    }
    final nk = _wordNum.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in nk) {
      t = t.replaceAll(RegExp('(?<= )$k(?= (days|week|month|year|this|last))'), _wordNum[k]!);
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Sawal ma date no shabd che? (alternates sorting mate pan)
  static bool hasDate(String raw) => parse(raw) != null;

  /// null = koi date/samay nathi bolyo
  static AiDateRange? parse(String raw, {DateTime? now}) {
    final t = ' ${normalize(raw)} ';
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    DateTime end(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);
    AiDateRange day(int back, String label, String key) {
      final d = today.subtract(Duration(days: back));
      return AiDateRange(d, end(d), label, key);
    }

    bool has(String w) => t.contains(' $w ');

    // ---- 1) puri tarikh: 12-10-2026 / 12-10 ----
    final full = RegExp(r' (\d{1,2})-(\d{1,2})(?:-(\d{2,4}))? ').firstMatch(t);
    if (full != null) {
      final d = int.parse(full[1]!), m = int.parse(full[2]!);
      var y = full[3] == null ? n.year : int.parse(full[3]!);
      if (y < 100) y += 2000;
      if (d >= 1 && d <= 31 && m >= 1 && m <= 12) {
        final x = DateTime(y, m, d);
        // "10-15 gram" jevu range nathi ne? → year/separator hoy to j date gano
        if (full[3] != null || has('date')) {
          return AiDateRange(x, end(x), AiDateRange.fmt(x), 'date');
        }
      }
    }

    // ---- 1b) 📆 MAHINA THI MAHINO: "january thi september", "jan 2025 to march 2025",
    //          "october thi march" (varsh badlay), "april se june" ----
    final mk = _months.keys.toList()..sort((a, b) => b.length - a.length);
    final mAlt = mk.join('|');
    final mr = RegExp(' ($mAlt)(?: (20\\d{2}))? (?:thi|to|se|till|sudhi|and|ane|-) ($mAlt)(?: (20\\d{2}))? ')
        .firstMatch(t);
    if (mr != null) {
      final m1 = _months[mr[1]]!, m2 = _months[mr[3]]!;
      int? y1 = mr[2] == null ? null : int.parse(mr[2]!);
      int? y2 = mr[4] == null ? null : int.parse(mr[4]!);
      if (y1 == null && y2 == null) {
        // "october thi march" → gaya varsh na october thi aa varsh na march
        y2 = (m2 > n.month) ? n.year - 1 : n.year;
        y1 = m1 > m2 ? y2 - 1 : y2;
      } else if (y1 == null) {
        y1 = m1 > m2 ? y2! - 1 : y2!;
      } else {
        y2 ??= m2 < m1 ? y1 + 1 : y1;
      }
      final f = DateTime(y1, m1, 1);
      var l = end(DateTime(y2!, m2 + 1, 0));
      if (l.isAfter(end(today))) l = end(today);
      if (!l.isBefore(f)) {
        return AiDateRange(f, l, '${_cap(_fullMonth(m1))}${y1 != y2 ? ' $y1' : ''} thi ${_cap(_fullMonth(m2))} $y2',
            'mrange');
      }
    }

    // ---- 1c) 📅 VARSH THI VARSH: "2024 thi 2026" ----
    final yr = RegExp(r' (20\d{2}) (?:thi|to|se|till|sudhi|and|ane|-) (20\d{2}) ').firstMatch(t);
    if (yr != null) {
      final a = int.parse(yr[1]!), b = int.parse(yr[2]!);
      final ya = a < b ? a : b, yb = a < b ? b : a;
      var l = end(DateTime(yb, 12, 31));
      if (l.isAfter(end(today))) l = end(today);
      return AiDateRange(DateTime(ya, 1, 1), l, '$ya thi $yb', 'yrange');
    }

    // ---- 1d) 💼 NANAKIYA VARSH: "fy 2025-26" / "2025-26" / "aa financial year" ----
    final fyM = RegExp(r' (?:fy )?(20\d{2})-(\d{2}|20\d{2}) ').firstMatch(t);
    if (fyM != null || has('fy')) {
      int startY;
      if (fyM != null) {
        startY = int.parse(fyM[1]!);
      } else {
        final cur = n.month >= 4 ? n.year : n.year - 1;
        final y = RegExp(r' (20\d{2}) ').firstMatch(t);
        startY = y != null ? int.parse(y[1]!) : (has('last') ? cur - 1 : cur);
      }
      var l = end(DateTime(startY + 1, 3, 31));
      if (l.isAfter(end(today))) l = end(today);
      final lbl = 'FY $startY-${((startY + 1) % 100).toString().padLeft(2, '0')}';
      return AiDateRange(DateTime(startY, 4, 1), l, lbl, 'fy');
    }

    // ---- 1e) "march 2025" / "2025 na march ma" (ek mahino, varsh sathe) ----
    for (final k in mk) {
      final a = RegExp(' $k (20\\d{2}) ').firstMatch(t) ??
          RegExp(' (20\\d{2}) (?:na |ni |no |nu |ma |mein |ke |ka )?$k ').firstMatch(t);
      if (a != null) {
        final y = int.parse(a[1]!), m = _months[k]!;
        var l = end(DateTime(y, m + 1, 0));
        if (l.isAfter(end(today))) l = end(today);
        return AiDateRange(DateTime(y, m, 1), l, '${_cap(_fullMonth(m))} $y', 'mmonth_$m');
      }
    }

    // ---- 1f) ek varsh: "2025 nu sale" / "2025 ma" / "year 2025" ----
    final oneY = RegExp(r' (20\d{2}) (?!gram|g |gm)').firstMatch(t);
    if (oneY != null) {
      final y = int.parse(oneY[1]!);
      if (y <= n.year && y >= 2000) {
        var l = end(DateTime(y, 12, 31));
        if (l.isAfter(end(today))) l = end(today);
        return AiDateRange(DateTime(y, 1, 1), l, 'Varsh $y', 'year_$y');
      }
    }

    // ---- 2) "12 october" / "october 12" / "12 tarikh" ----
    for (final e in _months.entries) {
      final a = RegExp(' (\\d{1,2}) ${e.key} ').firstMatch(t) ?? RegExp(' ${e.key} (\\d{1,2}) ').firstMatch(t);
      if (a != null) {
        final dd = int.parse(a[1]!);
        if (dd >= 1 && dd <= 31) {
          var x = DateTime(n.year, e.value, dd);
          if (x.isAfter(today)) x = DateTime(n.year - 1, e.value, dd);
          return AiDateRange(x, end(x), AiDateRange.fmt(x), 'date');
        }
      }
    }
    final tar = RegExp(r' (\d{1,2}) date ').firstMatch(t) ?? RegExp(r' date (\d{1,2}) ').firstMatch(t);
    if (tar != null) {
      final dd = int.parse(tar[1]!);
      if (dd >= 1 && dd <= 31) {
        var x = DateTime(n.year, n.month, dd);
        if (x.isAfter(today)) x = DateTime(n.year, n.month - 1, dd);
        return AiDateRange(x, end(x), AiDateRange.fmt(x), 'date');
      }
    }

    // ---- 3) aaje / kale / parmdivase ----
    if (has('parmdivase')) return day(2, 'Parmdivase', 'dby');
    if (has('aaje')) return day(0, 'Aaje', 'today');
    if (has('kale')) return day(1, 'Kale', 'yesterday');

    // ---- 4) "chhella 7 divas" / "last 3 days" / "7 divas ma" ----
    final nd = RegExp(r' (?:last )?(\d{1,3}) days ').firstMatch(t);
    // "90 divas thi juno" (juno stock) date nathi → 'last' ke 'divas ma' hoy to j
    if (nd != null && (has('last') || t.contains(' days ma ') || t.contains(' days mein '))) {
      final k = int.parse(nd[1]!).clamp(1, 366);
      final f = today.subtract(Duration(days: k - 1));
      return AiDateRange(f, end(today), 'Chhella $k divas', 'days_$k');
    }

    // ---- 4b) "chhella 3 mahina" / "last 2 year" ----
    final nm = RegExp(r' (\d{1,2}) (month|year) ').firstMatch(t);
    if (nm != null && (has('last') || t.contains(' ${nm[1]} ${nm[2]} ma '))) {
      final k = int.parse(nm[1]!).clamp(1, 36);
      final isY = nm[2] == 'year';
      final f = isY ? DateTime(today.year - k, today.month, today.day + 1) : DateTime(today.year, today.month - k, today.day + 1);
      return AiDateRange(f, end(today), isY ? 'Chhella $k varsh' : 'Chhella $k mahina', isY ? 'nyears' : 'nmonths');
    }

    // ---- 5) athvadiyu ----
    if (has('week')) {
      final start = today.subtract(Duration(days: today.weekday - 1)); // Somvar
      if (has('last')) {
        final f = start.subtract(const Duration(days: 7));
        return AiDateRange(f, end(f.add(const Duration(days: 6))), 'Gaya athvadiye', 'last_week');
      }
      return AiDateRange(start, end(today), 'Aa athvadiye', 'this_week');
    }

    // ---- 6) mahino ----
    for (final e in _months.entries) {
      final k = e.key;
      // "june" = "juno" pan sambhdai sake → "october ma" / "october mahine" hoy to j
      final said = [' $k ma ', ' $k month ', ' in $k ', ' $k ni ', ' $k nu ', ' $k no ', ' $k na ', ' $k mein ', ' $k me ']
          .any(t.contains);
      if (k.length >= 4 && said) {
        var y = n.year;
        if (e.value > n.month) y -= 1;
        final f = DateTime(y, e.value, 1);
        final l = DateTime(y, e.value + 1, 0);
        return AiDateRange(f, end(l.isAfter(today) ? today : l), _cap(e.key), 'month_${e.value}');
      }
    }
    if (has('month')) {
      if (has('last')) {
        final f = DateTime(n.year, n.month - 1, 1);
        return AiDateRange(f, end(DateTime(n.year, n.month, 0)), 'Gaya mahine', 'last_month');
      }
      return AiDateRange(DateTime(n.year, n.month, 1), end(today), 'Aa mahine', 'this_month');
    }
    if (has('year') && (has('this') || has('last'))) {
      if (has('last')) {
        return AiDateRange(DateTime(n.year - 1, 1, 1), end(DateTime(n.year - 1, 12, 31)), 'Gaya varshe', 'last_year');
      }
      return AiDateRange(DateTime(n.year, 1, 1), end(today), 'Aa varshe', 'this_year');
    }
    return null;
  }

  static const List<String> _monthNames = [
    'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november',
    'december',
  ];

  static String _fullMonth(int m) => _monthNames[(m - 1) % 12];

  /// "Oct 2026" — mahina mujab section mate
  static String monthLabel(DateTime d) => '${_cap(_fullMonth(d.month)).substring(0, 3)} ${d.year}';

  /// "october 2026" — tap kari ne puchhva mate
  static String monthAsk(DateTime d) => '${_fullMonth(d.month)} ${d.year}';

  static String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}