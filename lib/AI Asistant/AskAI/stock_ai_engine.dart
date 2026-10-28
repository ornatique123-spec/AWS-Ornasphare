import 'dart:math';

import 'stock_ai_models.dart';

/// =======================================================================
///  STOCK AI ENGINE
///  Voice / text question (Gujarati, Hindi, English, Gujlish) samjhi ne
///  Stock Gallery data par analytics kare che. Fully offline — koi API key
///  ni jarur nathi.
///
///  Udaharan:
///   • "10 thi 15 gram temple ring batav"
///   • "50 gram thi vadhare watch"
///   • "juno stock" / "90 divas thi juno stock" / "kai item nathi vechati"
///   • "sauthi vadhare shu vechay che" / "kaya weight ma vadhare vechay"
///   • "TR18 batav" / "total stock ketlo" / "category wise stock"
///   • "photo vagar na item" / "sauthi bhare 5 item" / "shu reorder karvu"
/// =======================================================================

enum AiIntent {
  help,
  labelLookup,
  weightSearch,
  oldStock,
  bestSeller,
  weightBand,
  reorder,
  summary,
  categoryWise,
  heaviest,
  lightest,
  noImage,
  withImage,
  otherWeight,
  unknown,
}

enum StatusFilter { all, inStock, sold }

class AiQuery {
  AiIntent intent = AiIntent.unknown;
  String? exactItem; // "Temple Ring"
  String? keyword; // "ring" -> badha ring wala
  double? minW;
  double? maxW;
  bool approxWeight = false;
  int? days;
  int? limit;
  String? label;
  StatusFilter status = StatusFilter.all;
  bool statusExplicit = false;
  bool useGross = false;

  bool get hasWeight => minW != null || maxW != null;
  bool get hasItem => exactItem != null || keyword != null;

  @override
  String toString() =>
      'AiQuery($intent item=$exactItem kw=$keyword w=$minW-$maxW days=$days '
          'limit=$limit label=$label status=$status)';
}

class StockAiEngine {
  final List<StockItem> all;
  late final List<String> itemNames;
  late final Map<String, StockItem> _byLabel;

  StockAiEngine(this.all) {
    itemNames = all.map((e) => e.itemName).toSet().toList()..sort();
    _byLabel = {for (final i in all) _labelKey(i.labelCode): i};
  }

  bool get hasAddedDates => all.any((e) => e.addedOn != null);
  bool get hasSoldDates => all.any((e) => e.soldOn != null);

  // =====================================================================
  //  PUBLIC
  // =====================================================================

  AiAnswer ask(String raw) {
    if (all.isEmpty) {
      return const AiAnswer(text: 'Stock data could not be loaded. Please refresh and try again.');
    }
    final q = parse(raw);
    _applyContext(q, normalize(raw));
    _last = q;
    switch (q.intent) {
      case AiIntent.help:
        return helpAnswer();
      case AiIntent.labelLookup:
        return _labelLookup(q);
      case AiIntent.weightSearch:
        return _weightSearch(q);
      case AiIntent.oldStock:
        return _oldStock(q);
      case AiIntent.bestSeller:
        return _bestSeller(q);
      case AiIntent.weightBand:
        return _weightBand(q);
      case AiIntent.reorder:
        return _reorder(q);
      case AiIntent.summary:
        return _summary(q);
      case AiIntent.categoryWise:
        return _categoryWise(q);
      case AiIntent.heaviest:
        return _extreme(q, heaviest: true);
      case AiIntent.lightest:
        return _extreme(q, heaviest: false);
      case AiIntent.noImage:
        return _noImage(q);
      case AiIntent.withImage:
        return _withImage(q);
      case AiIntent.otherWeight:
        return _otherWeight(q);
      case AiIntent.unknown:
        return _unknown(raw);
    }
  }

  // ---------- conversation context ----------
  AiQuery? _last;

  /// "aa range ma juno stock" / "ema vadhare shu vechay" -> agla question
  /// nu item + weight filter yaad rakhe.
  void _applyContext(AiQuery q, String t) {
    final prev = _last;
    if (prev == null || q.hasItem || q.hasWeight || q.label != null) return;
    if (!_has(t, ['aa ', 'aama', 'ama ', 'ema', 'aa range', 'this', 'these', 'tema', 'isme', 'same'])) return;
    q.exactItem = prev.exactItem;
    q.keyword = prev.keyword;
    q.minW = prev.minW;
    q.maxW = prev.maxW;
    q.approxWeight = prev.approxWeight;
    q.useGross = prev.useGross;
  }

  void resetContext() => _last = null;

  static const List<String> suggestions = [
    '10 thi 15 gram temple ring',
    'Show old stock',
    'What sells the most?',
    'Which weight range sells most?',
    'What is the total stock?',
    'Category wise stock',
    'What should I reorder?',
    'Items without photo',
    'Items without photo PDF',
    'Items with photo PDF',
    'Top 5 heaviest items',
  ];

  AiAnswer helpAnswer() => AiAnswer(
    text: 'I can tell you all this about your stock:\n'
        '• Weight range: "10 to 15 gram temple ring", "above 50 gram"\n'
        '• Old stock: "old stock", "older than 90 days"\n'
        '• Selling: "what sells the most", "which weight range sells most"\n'
        '• Reorder: "what should I reorder"\n'
        '• Label: "show TR18"\n'
        '• Summary: "total stock", "category wise"\n'
        '• Others: "items without photo", "stone items", "top 5 heaviest"',
    speech: 'You can ask about weight range, old stock, best selling items, reorder, label code '
        'or total stock.',
    followUps: suggestions.take(5).toList(),
  );

  // =====================================================================
  //  PARSER
  // =====================================================================

  static const Map<String, String> _scriptMap = {
    // Gujarati
    'ગ્રામ': 'gram', 'ગ્રા': 'gram', 'થી': 'thi', 'વધારે': 'vadhare', 'વધુ': 'vadhu',
    'ઓછું': 'ochhu', 'ઓછા': 'ochha', 'ઓછી': 'ochhi', 'નીચે': 'niche', 'ઉપર': 'upar',
    'જૂનો': 'juno', 'જુનો': 'juno', 'જૂનું': 'junu', 'જુનું': 'junu', 'જૂના': 'juna',
    'દિવસ': 'divas', 'મહિના': 'mahina', 'મહિનો': 'mahino', 'વર્ષ': 'varsh',
    'વેચાય': 'vechay', 'વેચાણ': 'vechan', 'વેચાયેલ': 'vechayel', 'વેચાયા': 'vechaya',
    'નથી': 'nathi', 'સ્ટોક': 'stock', 'રીંગ': 'ring', 'રિંગ': 'ring', 'વીંટી': 'ring',
    'ટેમ્પલ': 'temple', 'વોચ': 'watch', 'ઘડિયાળ': 'watch', 'કેટલા': 'ketla',
    'કેટલો': 'ketlo', 'કેટલું': 'ketlu', 'કુલ': 'kul', 'ફોટો': 'photo', 'વગર': 'vagar',
    'ભારે': 'bhare', 'હલકી': 'halki', 'હલકા': 'halka', 'સૌથી': 'sauthi', 'બતાવ': 'batav',
    'બતાવો': 'batavo', 'છે': 'che', 'ગોલ્ડ': 'gold', 'ગ્રોસ': 'gross', 'નેટ': 'net',
    'વેઇટ': 'weight', 'વજન': 'vajan', 'લેબલ': 'label', 'ટોટલ': 'total', 'પીસ': 'piece',
    'સ્ટોન': 'stone', 'મોતી': 'moti', 'રીઓર્ડર': 'reorder', 'ઈમેજ': 'image', 'ઇમેજ': 'image',
    'વિના': 'vina', 'ફોટા': 'photo', 'ફોટોગ્રાફ': 'photo', 'પીડીએફ': 'pdf', 'લિસ્ટ': 'list', 'યાદી': 'list',
    // 🔥 Gujarati number words (gu_IN engine ghani var shabd ma lakhe che)
    'દસ': '10', 'પંદર': '15', 'વીસ': '20', 'પચીસ': '25', 'ત્રીસ': '30',
    'ચાલીસ': '40', 'પચાસ': '50', 'સાઠ': '60', 'સિત્તેર': '70', 'એંસી': '80', 'નેવું': '90',
    // 🔥 Label code bolta (TR / OWG) — logs ma je aave te ahi umero
    'ટીઆર': 'tr', 'ટી આર': 'tr', 'ટી.આર.': 'tr', 'ઓડબલ્યુજી': 'owg', 'ઓ ડબલ્યુ જી': 'owg',
    // Hindi
    'ग्राम': 'gram', 'से': 'se', 'ज्यादा': 'jyada', 'कम': 'kam', 'पुराना': 'purana',
    'पुराने': 'purane', 'दिन': 'din', 'महीने': 'mahina', 'बिकता': 'bikta', 'बिकती': 'bikti',
    'बिका': 'bika', 'नहीं': 'nahi', 'स्टॉक': 'stock', 'अंगूठी': 'ring', 'घड़ी': 'watch',
    'सबसे': 'sabse', 'कितना': 'kitna', 'कितने': 'kitne', 'भारी': 'bhari',
    'दस': '10', 'पंद्रह': '15', 'बीस': '20', 'पच्चीस': '25', 'तीस': '30', 'चालीस': '40',
    'पचास': '50', 'टीआर': 'tr', 'टी आर': 'tr', 'बिना': 'bina', 'फोटो': 'photo', 'तस्वीर': 'photo',
    'इमेज': 'image', 'पीडीएफ': 'pdf', 'लिस्ट': 'list',
  };

  /// 🔥 en_IN engine Gujlish shabdo ne English jeva shabdo ma lakhi nakhe che.
  /// Aa list "🎤 ALT" debug log mathi bharo: khotu (dabi baju) → sachu (jamni baju).
  static const Map<String, String> _soundFixes = {
    'tea are': 'tr',
    'tee are': 'tr',
    'ti ar': 'tr',
    'double you': 'w',
    'double u': 'w',
    'bataw': 'batav',
    'batao': 'batav',
    'june o': 'juno',
    'temple rink': 'temple ring',
    'temple wing': 'temple ring',
  };

  static const Map<String, String> _numberWords = {
    'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6',
    'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10', 'eleven': '11',
    'twelve': '12', 'thirteen': '13', 'fourteen': '14', 'fifteen': '15', 'sixteen': '16',
    'seventeen': '17', 'eighteen': '18', 'nineteen': '19', 'twenty': '20', 'twenty five': '25',
    'thirty': '30', 'thirty five': '35', 'forty': '40', 'forty five': '45', 'fifty': '50',
    'sixty': '60', 'seventy': '70',
    'eighty': '80', 'ninety': '90', 'hundred': '100',
    'ek': '1', 'tran': '3', 'char': '4', 'panch': '5', 'paanch': '5',
    'das': '10', 'pandar': '15', 'pandara': '15', 'vis': '20', 'bees': '20',
    'pachis': '25', 'pachchis': '25', 'tris': '30', 'tees': '30', 'chalis': '40',
    'pachas': '50', 'pachaas': '50',
  };

  static const Set<String> _stopWords = {
    'stock', 'item', 'items', 'gram', 'grams', 'the', 'and', 'thi', 'ma', 'nu',
    'na', 'ni', 'ne', 'che', 'chhe', 'batav', 'batavo', 'show', 'mane', 'gold',
    'silver', 'sona', 'sonu', 'chandi', 'all', 'badha', 'badhu', 'jewellery',
    'jewelry', 'piece', 'pcs', 'label', 'weight', 'vajan', 'wala', 'vala', 'list',
    'total', 'kul', 'ketla', 'ketlo', 'ketlu', 'have', 'what', 'which', 'kai',
    'kaya', 'kya', 'shu', 'sauthi', 'top', 'old', 'juno', 'junu', 'new',
    'photo', 'image', 'pdf', 'vadi', 'vali', 'wali', 'sathe', 'vagar', 'vina', 'bina',
    'catalog', 'catalogue',
    'sell', 'sells', 'most', 'should', 'does', 'well', 'range', 'older', 'than', 'days', 'without', 'with', 'heaviest', 'lightest', 'pieces', 'reorder', 'category', 'wise', 'is', 'in',
  };

  String normalize(String raw) {
    var t = raw.toLowerCase();

    const gu = '૦૧૨૩૪૫૬૭૮૯';
    const hi = '०१२३४५६७८९';
    for (var i = 0; i < 10; i++) {
      t = t.replaceAll(gu[i], '$i').replaceAll(hi[i], '$i');
    }
    final scriptKeys = _scriptMap.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in scriptKeys) {
      t = t.replaceAll(k, ' ${_scriptMap[k]} ');
    }

    // "10-15" / "10–15" -> "10 to 15"
    t = t.replaceAllMapped(
        RegExp(r'(\d+(?:\.\d+)?)\s*[-–~]\s*(\d+(?:\.\d+)?)'), (m) => '${m[1]} to ${m[2]}');

    // 🔥 "t.r. 18" -> "t r 18" (letter vacche na dot hata vo, decimal 12.5 rehva do)
    t = t.replaceAllMapped(RegExp(r'([a-z])\.'), (m) => '${m[1]} ');

    t = t.replaceAll(RegExp(r'[^a-z0-9\.\+\s]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ');

    // 🔥 khota sambhdayela shabdo sudharo (longest first)
    final fixKeys = _soundFixes.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in fixKeys) {
      t = t.replaceAll(RegExp('\\b$k\\b'), _soundFixes[k]!);
    }

    // 🔥 "t r 18" / "o w g 15" -> "tr 18" / "owg 15" (chhuta bolela letters jodo)
    t = t.replaceAllMapped(
        RegExp(r'\b(?:[a-z] ){1,5}[a-z]\b'), (m) => m[0]!.replaceAll(' ', ''));

    // number words -> digits (longest first)
    final keys = _numberWords.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in keys) {
      t = t.replaceAll(RegExp('\\b$k\\b'), _numberWords[k]!);
    }

    // units
    t = t.replaceAllMapped(
        RegExp(r'(\d)\s*(gms|gm|grams|gram|grm|gr|g)\b'), (m) => '${m[1]} gram');
    t = t.replaceAll(RegExp(r'\b(gms|gm|grams|grm)\b'), 'gram');

    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 🔥 item naam no fuzzy match: "tempal" -> "temple", "wach" -> "watch"
    return t.split(' ').map(_fuzzyFix).join(' ');
  }

  /// Item naam na badha shabdo (temple, ring, ornatique, watch, ...)
  late final Set<String> _vocab = {
    for (final n in itemNames)
      ...n.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 3),
  };

  String _fuzzyFix(String w) {
    if (w.length < 4 || RegExp(r'\d').hasMatch(w)) return w;
    if (_vocab.contains(w) || _stopWords.contains(w)) return w;

    final maxDist = w.length >= 6 ? 2 : 1; // "tempal"->"temple" = 2 badlav
    String? best;
    int bestDist = maxDist + 1;
    for (final v in _vocab) {
      if (v[0] != w[0]) continue; // pehlo akshar same hovo joie (khota match ochha)
      if ((v.length - w.length).abs() > maxDist) continue;
      final d = _editDistance(w, v);
      if (d < bestDist) {
        bestDist = d;
        best = v;
      }
    }
    return best ?? w;
  }

  static int _editDistance(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  AiQuery parse(String raw) {
    final q = AiQuery();
    var t = normalize(raw);
    final original = t;

    // ---------- label code (TR18 / "tr 18") ----------
    for (final m in RegExp(r'\b([a-z]{1,6})\s?(\d{1,6})\b').allMatches(t)) {
      final key = _labelKey('${m[1]}${m[2]}');
      if (_byLabel.containsKey(key)) {
        q.label = _byLabel[key]!.labelCode;
        t = t.replaceFirst(m[0]!, ' ');
        break;
      }
    }

    // ---------- days / months ----------
    final dm = RegExp(
        r'(\d+)\s*(days|day|divas|dvs|din|months|month|mahina|mahino|mahine|years|year|varsh|saal|sal)\b')
        .firstMatch(t);
    if (dm != null) {
      final n = int.parse(dm[1]!);
      final unit = dm[2]!;
      int mult = 1;
      if (unit.startsWith('mon') || unit.startsWith('mahi')) mult = 30;
      if (unit.startsWith('y') || unit.startsWith('var') || unit.startsWith('sa')) mult = 365;
      q.days = n * mult;
      t = t.replaceFirst(dm[0]!, ' ');
    }

    // ---------- top N ----------
    final lm = RegExp(r'\b(top|first|pehla|pela|pahela)\s*(\d+)').firstMatch(t) ??
        RegExp(r'\b(\d+)\s*(item|items|piece|pcs|nang)\b').firstMatch(t);
    if (lm != null) {
      final n = int.tryParse(lm[2]!) ?? int.tryParse(lm[1]!);
      if (n != null && n > 0 && n <= 200) {
        q.limit = n;
        t = t.replaceFirst(lm[0]!, ' ');
      }
    }

    // ---------- weight ----------
    const nr = r'(\d+(?:\.\d+)?)';
    final range = RegExp('$nr\\s*(?:gram\\s*)?(?:to|thi|se|and|ane|upto|sudhi|till)\\s*$nr(?!\\s*(?:days|divas))')
        .firstMatch(t);
    final above = RegExp(
        '$nr\\s*(?:gram)?\\s*(?:thi|se|na|ni|nu)?\\s*(?:upar|uper|vadhare|vadhu|above|more|over|jyada|zyada|plus|\\+)')
        .firstMatch(t);
    final above2 = RegExp('(?:above|over|more than|greater than|minimum|min)\\s*$nr').firstMatch(t);
    final below = RegExp(
        '$nr\\s*(?:gram)?\\s*(?:thi|se|na|ni|nu)?\\s*(?:niche|nichu|ochhu|ochu|ochha|ocha|below|under|less|kam|andar|sudhi)')
        .firstMatch(t);
    final below2 = RegExp('(?:below|under|less than|upto|maximum|max)\\s*$nr').firstMatch(t);
    final single = RegExp('$nr\\s*gram').firstMatch(t);

    if (range != null) {
      final a = double.parse(range[1]!), b = double.parse(range[2]!);
      q.minW = min(a, b);
      q.maxW = max(a, b);
    } else if (above != null || above2 != null) {
      q.minW = double.parse((above ?? above2)![1]!);
    } else if (below != null || below2 != null) {
      q.maxW = double.parse((below ?? below2)![1]!);
    } else if (single != null) {
      final w = double.parse(single[1]!);
      q.minW = max(0.0, w - 1);
      q.maxW = w + 1;
      q.approxWeight = true;
    }

    q.useGross = t.contains('gross');

    // ---------- item name ----------
    final tokens = <String>{};
    for (final w in t.split(' ')) {
      if (w.isEmpty) continue;
      tokens.add(w);
      if (w.length > 3 && w.endsWith('s')) tokens.add(w.substring(0, w.length - 1));
    }
    int bestLen = 0;
    for (final name in itemNames) {
      final words = name.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1);
      if (words.isNotEmpty && words.every(tokens.contains) && name.length > bestLen) {
        q.exactItem = name;
        bestLen = name.length;
      }
    }
    if (q.exactItem == null) {
      // partial: "ring" -> badha ring, "watch" -> badhi watch
      String? bestKw;
      int bestCount = 1 << 30;
      for (final tok in tokens) {
        if (tok.length < 3 || _stopWords.contains(tok) || RegExp(r'^\d').hasMatch(tok)) continue;
        final hits = itemNames
            .where((n) => n.toLowerCase().split(RegExp(r'\s+')).contains(tok))
            .toList();
        if (hits.isEmpty) continue;
        if (hits.length == 1) {
          q.exactItem = hits.first;
          break;
        }
        if (hits.length < bestCount) {
          bestCount = hits.length;
          bestKw = tok;
        }
      }
      if (q.exactItem == null) q.keyword = bestKw;
    }

    // ---------- status ----------
    if (_has(original, ['sold', 'vechayel', 'vechayela', 'vechai gay', 'vechaya', 'out stock', 'outstock', 'bik gay', 'bika'])) {
      q.status = StatusFilter.sold;
      q.statusExplicit = true;
    } else if (_has(original, ['in stock', 'instock', 'available', 'stock ma', 'padel', 'padela', 'hajar', 'hazar', 'baki'])) {
      q.status = StatusFilter.inStock;
      q.statusExplicit = true;
    }

    // ---------- intent ----------
    q.intent = _detectIntent(original, q);
    return q;
  }

  AiIntent _detectIntent(String t, AiQuery q) {
    bool has(List<String> w) => _has(t, w);

    if (has(['help', 'madad', 'shu puchi', 'su puchi', 'what can you', 'kya puch', 'kem vapar'])) {
      return AiIntent.help;
    }
    if (q.label != null) return AiIntent.labelLookup;

    final photoWord = has(['photo', 'image', 'pic', 'foto', 'fota', 'imej', 'emage']);
    if (photoWord &&
        has(['nathi', 'vagar', 'vagarna', 'vagar na', 'vina', 'vinaa', 'without', 'missing', 'baki', 'no ', 'nai', 'pending',
          'nahi', 'bina', 'na hoy', 'nathi evi', 'nathi eva', 'pending', 'pado', 'padvana', 'levana'])) {
      return AiIntent.noImage;
    }
    // "image vadi / photo vala / photo sathe na item" → photo che e item
    if (photoWord &&
        has(['vadi', 'vadu', 'vada', 'vali', 'valu', 'vala', 'wali', 'wala', 'walu', 'sathe', 'sathena', 'with',
          'che evi', 'che eva', 'hoy evi', 'hoy eva', 'vale', 'wale', 'pdf', 'catalog', 'catalogue', 'catlog'])) {
      return AiIntent.withImage;
    }
    if (has(['other weight', 'other wt', 'stone', 'nang', 'moti', 'kundan', 'diamond', 'meena', 'mina'])) {
      return AiIntent.otherWeight;
    }

    final notSelling = has([
      'na vechay', 'nathi vechay', 'vechatu nathi', 'vechati nathi', 'vechato nathi', 'vechay nathi',
      'vechayu nathi', 'nai vechay', 'nahi vechay', 'not sell', 'not selling', 'nahi bik', 'nai bik',
      'slow', 'dead', 'non moving', 'nonmoving', 'chalti nathi', 'chalto nathi', 'nathi chalti',
    ]);
    final oldWord = has([
      'old', 'junu', 'juno', 'juna', 'juni', 'purana', 'purane', 'purani', 'ghana divas', 'ghano samay',
      'lamba samay', 'lambo samay', 'aging', 'ageing', 'padyu', 'padi rahyu', 'padyo', 'pada che', 'older',
    ]);
    if (notSelling || oldWord) return AiIntent.oldStock;

    if (has(['reorder', 're order', 'restock', 'order karvu', 'order aapvu', 'order apvu', 'banavvu',
      'banavu', 'banavvi', 'khatam', 'short', 'shu banav', 'su banav', 'kya banav', 'manufacture', 'what to make'])) {
      return AiIntent.reorder;
    }

    final best = has([
      'vadhare vechay', 'vadhu vechay', 'jaldi vechay', 'vechay che', 'best sell', 'top sell', 'fast moving',
      'fast sell', 'popular', 'demand', 'most sold', 'zyada bik', 'jyada bik', 'sabse jyada bik',
      'vadhare vechan', 'vadhu vechan', 'best seller', 'bestseller', 'chalti', 'chale che', 'vadhare vechaya',
      'vadhu vechaya', 'selling', 'sale vadhare', 'sells', 'sell well', 'sells most', 'sells the most', 'best',
    ]);
    if (best) {
      if (has(['weight', 'vajan', 'gram', 'range', 'band', 'size']) && !q.hasWeight) {
        return AiIntent.weightBand;
      }
      return AiIntent.bestSeller;
    }

    if (!q.hasWeight) {
      if (has(['bhare', 'bhari', 'heavy', 'heaviest', 'vadhare vajan', 'vadhu vajan', 'max weight', 'moti item'])) {
        return AiIntent.heaviest;
      }
      if (has(['halk', 'light', 'lightest', 'ochhu vajan', 'ochha vajan', 'min weight', 'nani item'])) {
        return AiIntent.lightest;
      }
    }

    if (has(['category', 'item wise', 'itemwise', 'type wise', 'darek item', 'badhi item', 'item pramane',
      'breakdown', 'kaya kaya item', 'kai kai item'])) {
      return AiIntent.categoryWise;
    }

    if (q.hasWeight || q.hasItem) return AiIntent.weightSearch;

    if (has(['total', 'kul', 'summary', 'overview', 'ketlo', 'ketlu', 'ketla', 'kitna', 'kitne', 'how much',
      'how many', 'report', 'status', 'stock', 'dashboard'])) {
      return AiIntent.summary;
    }
    return AiIntent.unknown;
  }

  // =====================================================================
  //  HELPERS
  // =====================================================================

  static String _labelKey(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Word ni sharuat thi match ("old" -> "gold" ma match NA thay)
  static bool _has(String t, List<String> words) {
    final s = ' $t ';
    return words.any((w) => s.contains(' $w'));
  }

  double _w(StockItem i, AiQuery q) => q.useGross ? i.grossWeight : i.netWeight;

  static String g(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  static String pct(double v) => '${(v * 100).round()}%';

  /// Item + weight filter (status nahi)
  List<StockItem> _base(AiQuery q) {
    return all.where((i) {
      if (q.exactItem != null && i.itemName != q.exactItem) return false;
      if (q.keyword != null && !i.itemName.toLowerCase().contains(q.keyword!)) return false;
      final w = _w(i, q);
      if (q.minW != null && w < q.minW!) return false;
      if (q.maxW != null && w > q.maxW!) return false;
      return true;
    }).toList();
  }

  List<StockItem> _status(List<StockItem> list, StatusFilter s) {
    switch (s) {
      case StatusFilter.inStock:
        return list.where((e) => e.inStock).toList();
      case StatusFilter.sold:
        return list.where((e) => e.isSold).toList();
      case StatusFilter.all:
        return list;
    }
  }

  String _filterLabel(AiQuery q, {StatusFilter? status}) {
    final parts = <String>[];
    if (q.exactItem != null) parts.add(q.exactItem!);
    if (q.keyword != null) parts.add('"${q.keyword}" items');
    if (q.minW != null && q.maxW != null) {
      parts.add(q.approxWeight
          ? 'about ${g((q.minW! + q.maxW!) / 2)} g'
          : '${g(q.minW!)}–${g(q.maxW!)} g');
    } else if (q.minW != null) {
      parts.add('above ${g(q.minW!)} g');
    } else if (q.maxW != null) {
      parts.add('up to ${g(q.maxW!)} g');
    }
    if (q.useGross) parts.add('gross wt');
    final s = status ?? q.status;
    if (s == StatusFilter.inStock) parts.add('In stock');
    if (s == StatusFilter.sold) parts.add('Sold');
    return parts.isEmpty ? 'All stock' : parts.join(' · ');
  }

  double _sum(Iterable<StockItem> l, AiQuery q) => l.fold(0.0, (a, b) => a + _w(b, q));

  Map<String, List<StockItem>> _group(List<StockItem> l) {
    final m = <String, List<StockItem>>{};
    for (final i in l) {
      m.putIfAbsent(i.itemName, () => []).add(i);
    }
    return m;
  }

  List<AiRecord> _rec(List<StockItem> l) => l.map((e) => e.toRecord()).toList();

  List<StockItem> _limit(List<StockItem> l, AiQuery q, int def) => l.take(q.limit ?? def).toList();

  // =====================================================================
  //  ANSWERS
  // =====================================================================

  AiAnswer _labelLookup(AiQuery q) {
    final i = _byLabel[_labelKey(q.label!)]!;
    final status = i.isSold ? 'has been sold' : 'is in stock';
    final age = i.ageDays != null ? ', ${i.ageDays} days old' : '';
    return AiAnswer(
      text: '${i.labelCode} — ${i.itemName}. Net ${g(i.netWeight)} gram'
          '${i.hasOtherWeight ? ' (gross ${g(i.grossWeight)}, other ${g(i.otherWeight)})' : ''}. '
          'This piece $status$age.',
      stats: [
        AiStat('Gross', '${g(i.grossWeight)} g'),
        AiStat('Other', '${g(i.otherWeight)} g'),
        AiStat('Net', '${g(i.netWeight)} g'),
        AiStat('Status', i.isSold ? 'Sold' : 'In stock'),
        if (i.huid != '-') AiStat('HUID', i.huid),
        if (i.ageDays != null) AiStat('Age', '${i.ageDays} days'),
      ],
      items: _rec([i]),
      itemsTitle: 'Piece',
      followUps: ['${i.itemName} old stock', '${i.itemName} in stock'],
    );
  }

  AiAnswer _weightSearch(AiQuery q) {
    final base = _base(q);
    final status = q.statusExplicit ? q.status : StatusFilter.inStock;
    final list = _status(base, status)..sort((a, b) => _w(a, q).compareTo(_w(b, q)));
    final label = _filterLabel(q, status: status);

    if (list.isEmpty) {
      // nearest pieces suggest karo
      final pool = _status(
          all.where((i) =>
          (q.exactItem == null || i.itemName == q.exactItem) &&
              (q.keyword == null || i.itemName.toLowerCase().contains(q.keyword!))).toList(),
          status);
      final target = q.minW != null && q.maxW != null
          ? (q.minW! + q.maxW!) / 2
          : (q.minW ?? q.maxW ?? 0.0);
      pool.sort((a, b) => (_w(a, q) - target).abs().compareTo((_w(b, q) - target).abs()));
      final near = pool.take(6).toList();
      return AiAnswer(
        text: 'No piece found for $label.'
            '${near.isNotEmpty ? ' Here are ${near.length} pieces with the nearest weight.' : ''}',
        speech: 'No piece in this range.${near.isNotEmpty ? ' Showing the nearest pieces.' : ''}',
        items: _rec(near),
        itemsTitle: 'Nearest pieces',
        filterLabel: label,
      );
    }

    final total = _sum(list, q);
    final soldHere = status == StatusFilter.inStock ? base.where((e) => e.isSold).length : 0;
    final cats = _group(list);
    final weights = list.map((e) => _w(e, q)).toList();

    return AiAnswer(
      text: '$label: ${list.length} pieces found, total ${g(total)} gram. '
          'Weight from ${g(weights.first)} to ${g(weights.last)} gram.'
          '${soldHere > 0 ? ' $soldHere pieces in this range were already sold.' : ''}',
      speech: '${list.length} pieces found, total ${g(total)} gram.',
      stats: [
        AiStat('Pieces', '${list.length}'),
        AiStat('Total wt', '${g(total)} g'),
        AiStat('Avg', '${g(total / list.length)} g'),
        AiStat('Range', '${g(weights.first)}–${g(weights.last)} g'),
        if (soldHere > 0) AiStat('Sold', '$soldHere'),
      ],
      sections: cats.length > 1
          ? [
        AiSection(
            'Item wise',
            (cats.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length)))
                .map((e) => AiRow(e.key, '${e.value.length} pcs',
                sub: '${g(_sum(e.value, q))} g', bar: e.value.length / list.length))
                .toList())
      ]
          : const [],
      items: _rec(list),
      itemsTitle: 'Pieces (light to heavy)',
      filterLabel: label,
      followUps: [
        if (q.exactItem != null) 'Does ${q.exactItem} sell well?',
        'Old stock in this range',
        'Which weight range sells most?',
      ],
    );
  }

  AiAnswer _oldStock(AiQuery q) {
    final base = _base(q);
    final inStock = base.where((e) => e.inStock).toList();
    final label = _filterLabel(q, status: StatusFilter.all);

    // ---- category (item) wise sell-through: kai item nathi vechati ----
    final groups = _group(base);
    final catRows = groups.entries.map((e) {
      final total = e.value.length;
      final sold = e.value.where((x) => x.isSold).length;
      final pad = total - sold;
      final st = total == 0 ? 0.0 : sold / total;
      final ages = e.value.where((x) => x.inStock && x.ageDays != null).map((x) => x.ageDays!);
      final oldest = ages.isEmpty ? null : ages.reduce(max);
      return _Cat(e.key, total, sold, pad, st, oldest);
    }).where((c) => c.inStock > 0).toList()
      ..sort((a, b) {
        final c = a.sellThrough.compareTo(b.sellThrough);
        return c != 0 ? c : b.inStock.compareTo(a.inStock);
      });

    final sections = <AiSection>[
      AiSection(
        'Slow selling items (low sell-through = slow)',
        catRows
            .map((c) => AiRow(
          c.name,
          '${pct(c.sellThrough)} sold',
          sub: '${c.inStock} in stock · ${c.sold} sold'
              '${c.oldestDays != null ? ' · oldest ${c.oldestDays} days' : ''}',
          bar: c.sellThrough,
          askOnTap: '${c.name} old stock',
        ))
            .toList(),
      ),
    ];

    if (inStock.isEmpty) {
      return AiAnswer(text: 'No piece in stock for $label.', filterLabel: label);
    }

    String text;
    final stats = <AiStat>[];
    List<StockItem> items;

    if (hasAddedDates) {
      final dated = inStock.where((e) => e.ageDays != null).toList()
        ..sort((a, b) => b.ageDays!.compareTo(a.ageDays!));
      final minDays = q.days ?? 0;
      final filtered = dated.where((e) => e.ageDays! >= minDays).toList();
      final avg = dated.isEmpty ? 0 : dated.map((e) => e.ageDays!).reduce((a, b) => a + b) / dated.length;
      final o90 = dated.where((e) => e.ageDays! >= 90).length;
      final o180 = dated.where((e) => e.ageDays! >= 180).length;

      // aging buckets
      final buckets = <String, List<StockItem>>{
        '0–30 days': [], '31–90 days': [], '91–180 days': [], '181–365 days': [], '1 year+': [],
      };
      for (final i in dated) {
        final d = i.ageDays!;
        final k = d <= 30
            ? '0–30 days'
            : d <= 90
            ? '31–90 days'
            : d <= 180
            ? '91–180 days'
            : d <= 365
            ? '181–365 days'
            : '1 year+';
        buckets[k]!.add(i);
      }
      sections.insert(
          0,
          AiSection(
              'Aging (days in stock)',
              buckets.entries
                  .map((e) => AiRow(e.key, '${e.value.length} pcs',
                  sub: '${g(_sum(e.value, q))} g',
                  bar: dated.isEmpty ? 0 : e.value.length / dated.length))
                  .toList()));

      final oldest = dated.isNotEmpty ? dated.first : null;
      text = (q.days != null
          ? '$label: ${filtered.length} pieces are older than ${q.days} days, total ${g(_sum(filtered, q))} gram. '
          : '') +
          (oldest != null
              ? 'Oldest piece is ${oldest.labelCode} (${oldest.itemName}, ${g(oldest.netWeight)} g) — in stock for ${oldest.ageDays} days. '
              : '') +
          'Average stock age is ${avg.round()} days. $o90 pieces are 90+ days old.';
      if (catRows.isNotEmpty) {
        text += ' Slowest selling item: ${catRows.first.name} (only ${pct(catRows.first.sellThrough)} sold).';
      }
      stats.addAll([
        AiStat('In stock', '${inStock.length}'),
        AiStat('Avg age', '${avg.round()} days'),
        AiStat('90+ days', '$o90'),
        AiStat('180+ days', '$o180'),
        if (q.days != null) AiStat('${q.days}+ days', '${filtered.length}'),
      ]);
      items = _limit(filtered, q, 30);
    } else {
      // Date nathi -> ID order (nanu ID = pehla banyu)
      final sorted = [...inStock]..sort((a, b) => a.id.compareTo(b.id));
      items = _limit(sorted, q, 30);
      final first = sorted.first;
      text = '$label: ${inStock.length} pieces in stock (${g(_sum(inStock, q))} g). '
          'The earliest made piece still in stock is ${first.labelCode} (${first.itemName}, ${g(first.netWeight)} g). ';
      if (catRows.isNotEmpty) {
        final c = catRows.first;
        text += 'Slowest selling item is ${c.name} — only ${c.sold} of ${c.total} sold, ${c.inStock} still in stock. ';
      }
      text += '\n\nℹ️ For exact "days in stock", add created_at (label date) and sold_at fields to the Stock Gallery API.';
      stats.addAll([
        AiStat('In stock', '${inStock.length}'),
        AiStat('Stock wt', '${g(_sum(inStock, q))} g'),
        AiStat('Slow item', catRows.isNotEmpty ? catRows.first.name : '-'),
      ]);
    }

    return AiAnswer(
      text: text,
      speech: text.split('\n').first,
      stats: stats,
      sections: sections,
      items: _rec(items),
      itemsTitle: hasAddedDates ? 'Oldest pieces (oldest first)' : 'Earliest made pieces in stock',
      filterLabel: label,
      followUps: ['What sells the most?', 'What should I reorder?', 'Stock older than 90 days'],
    );
  }

  AiAnswer _bestSeller(AiQuery q) {
    var base = _base(q);
    String period = '';
    if (q.days != null && hasSoldDates) {
      final from = DateTime.now().subtract(Duration(days: q.days!));
      base = base.where((e) => e.inStock || (e.soldOn != null && e.soldOn!.isAfter(from))).toList();
      period = 'In the last ${q.days} days: ';
    }
    final groups = _group(base);
    final cats = groups.entries.map((e) {
      final sold = e.value.where((x) => x.isSold).length;
      final dts = e.value.where((x) => x.daysToSell != null).map((x) => x.daysToSell!).toList();
      return _Cat(e.key, e.value.length, sold, e.value.length - sold,
          e.value.isEmpty ? 0.0 : sold / e.value.length, null,
          avgDaysToSell: dts.isEmpty ? null : dts.reduce((a, b) => a + b) / dts.length,
          soldWeight: _sum(e.value.where((x) => x.isSold), q));
    }).toList()
      ..sort((a, b) {
        final c = b.sold.compareTo(a.sold);
        return c != 0 ? c : b.sellThrough.compareTo(a.sellThrough);
      });

    final totalSold = cats.fold<int>(0, (a, c) => a + c.sold);
    if (totalSold == 0) {
      return AiAnswer(
        text: '${period}No piece has been sold yet for ${_filterLabel(q, status: StatusFilter.all)}.',
        filterLabel: _filterLabel(q, status: StatusFilter.all),
      );
    }
    final maxSold = cats.first.sold;
    final top = cats.first;
    final fastest = cats.where((c) => c.sold > 0).toList()
      ..sort((a, b) => b.sellThrough.compareTo(a.sellThrough));

    final soldItems = base.where((e) => e.isSold).toList()
      ..sort((a, b) => (b.soldOn ?? DateTime(1900)).compareTo(a.soldOn ?? DateTime(1900)));

    final band = _bands(base, q);
    final bestBand = band.where((b) => b.sold > 0).toList()..sort((a, b) => b.sold.compareTo(a.sold));

    var text = '${period}The best selling item is ${top.name} — ${top.sold} pieces sold '
        '(of ${top.total}, ${pct(top.sellThrough)}).';
    if (fastest.isNotEmpty && fastest.first.name != top.name) {
      text += ' By sell-through, ${fastest.first.name} leads (${pct(fastest.first.sellThrough)}).';
    }
    if (top.avgDaysToSell != null) {
      text += ' ${top.name} sells in ${top.avgDaysToSell!.round()} days on average.';
    }
    if (bestBand.isNotEmpty) {
      text += ' By weight, ${bestBand.first.label} pieces sold the most.';
    }

    return AiAnswer(
      text: text,
      stats: [
        AiStat('Total sold', '$totalSold'),
        AiStat('Sold wt', '${g(cats.fold(0.0, (a, c) => a + c.soldWeight))} g'),
        AiStat('Top item', top.name),
        if (bestBand.isNotEmpty) AiStat('Top range', bestBand.first.label),
      ],
      sections: [
        AiSection(
          'Item wise sales',
          cats
              .map((c) => AiRow(
            c.name,
            '${c.sold} sold',
            sub: 'Sell-through ${pct(c.sellThrough)} · ${c.inStock} in stock'
                '${c.avgDaysToSell != null ? ' · avg ${c.avgDaysToSell!.round()} days' : ''}',
            bar: maxSold == 0 ? 0 : c.sold / maxSold,
            askOnTap: '${c.name} which weight range sells most',
          ))
              .toList(),
        ),
        if (bestBand.isNotEmpty)
          AiSection(
              'Weight range wise sales',
              band
                  .where((b) => b.total > 0)
                  .map((b) => AiRow(b.label, '${b.sold}/${b.total} sold',
                  sub: 'Sell-through ${pct(b.st)}', bar: b.st))
                  .toList()),
      ],
      items: _rec(_limit(soldItems, q, 20)),
      itemsTitle: 'Sold pieces',
      filterLabel: _filterLabel(q, status: StatusFilter.all),
      followUps: ['What should I reorder?', 'Show old stock', 'Which weight range sells most?'],
    );
  }

  AiAnswer _weightBand(AiQuery q) {
    final base = _base(q);
    final bands = _bands(base, q).where((b) => b.total > 0).toList();
    if (bands.isEmpty) return AiAnswer(text: 'No data for this filter.');
    final ranked = [...bands]..sort((a, b) {
      final c = b.sold.compareTo(a.sold);
      return c != 0 ? c : b.st.compareTo(a.st);
    });
    final top = ranked.first;
    final label = _filterLabel(q, status: StatusFilter.all);
    final rangeStock = base.where((e) {
      final w = _w(e, q);
      return e.inStock && w >= top.from && w < top.to;
    }).toList();

    return AiAnswer(
      text: '$label: ${top.label} pieces sell the most — ${top.sold} sold '
          '(of ${top.total}, ${pct(top.st)}). ${rangeStock.length} pieces in this range are still in stock.'
          '${ranked.length > 1 && ranked[1].sold > 0 ? ' Second is ${ranked[1].label} (${ranked[1].sold} sold).' : ''}',
      stats: [
        AiStat('Best range', top.label),
        AiStat('Sold', '${top.sold}'),
        AiStat('Sell-through', pct(top.st)),
        AiStat('In stock', '${rangeStock.length}'),
      ],
      sections: [
        AiSection(
            'Weight range (10 g buckets)',
            bands
                .map((b) => AiRow(b.label, '${b.sold}/${b.total} sold',
                sub: '${b.total - b.sold} in stock · sell-through ${pct(b.st)}',
                bar: b.st,
                askOnTap: '${q.exactItem ?? ''} ${g(b.from)} to ${g(b.to)} gram'.trim()))
                .toList()),
      ],
      items: _rec(rangeStock),
      itemsTitle: '${top.label} — in stock',
      filterLabel: label,
      followUps: ['What should I reorder?', 'What sells the most?'],
    );
  }

  AiAnswer _reorder(AiQuery q) {
    final base = _base(q);
    final groups = _group(base);
    final rows = <AiRow>[];
    final suggestions = <String>[];

    final scored = groups.entries.map((e) {
      final total = e.value.length;
      final sold = e.value.where((x) => x.isSold).length;
      final pad = total - sold;
      final st = total == 0 ? 0.0 : sold / total;
      final bands = _bands(e.value, q).where((b) => b.sold > 0).toList()
        ..sort((a, b) {
          // je range vechay che pan stock ma ochha che
          final ra = a.sold / (a.total - a.sold + 1), rb = b.sold / (b.total - b.sold + 1);
          return rb.compareTo(ra);
        });
      return (name: e.key, total: total, sold: sold, pad: pad, st: st, band: bands.isEmpty ? null : bands.first);
    }).where((x) => x.sold > 0).toList()
      ..sort((a, b) => b.st.compareTo(a.st));

    for (final s in scored) {
      final urgent = s.st >= 0.4 || s.pad <= 2;
      final bandTxt = s.band != null ? ' · make ${s.band!.label}' : '';
      rows.add(AiRow(
        '${urgent ? '🔴 ' : '🟢 '}${s.name}',
        urgent ? 'Reorder' : 'Stock ok',
        sub: 'Sell-through ${pct(s.st)} · ${s.pad} in stock · ${s.sold} sold$bandTxt',
        bar: s.st,
      ));
      if (urgent) suggestions.add('${s.name}${s.band != null ? ' (${s.band!.label})' : ''}');
    }

    if (rows.isEmpty) {
      return AiAnswer(text: 'Not enough sales data yet to suggest a reorder.');
    }

    return AiAnswer(
      text: suggestions.isEmpty
          ? 'No item needs an urgent reorder right now — stock levels are fine.'
          : 'Worth reordering / making new: ${suggestions.join(', ')}. '
          'These items have high sell-through or fewer than 2 pieces left in stock.',
      sections: [AiSection('Reorder suggestion', rows)],
      filterLabel: _filterLabel(q, status: StatusFilter.all),
      followUps: ['Which weight range sells most?', 'Show old stock'],
    );
  }

  AiAnswer _summary(AiQuery q) {
    final base = _base(q);
    final inS = base.where((e) => e.inStock).toList();
    final sold = base.where((e) => e.isSold).toList();
    final noImg = inS.where((e) => !e.hasImage).length;
    final groups = _group(base);
    final label = _filterLabel(q, status: StatusFilter.all);

    return AiAnswer(
      text: '$label: total ${base.length} pieces — ${inS.length} in stock (${g(_sum(inS, q))} g) '
          'and ${sold.length} sold (${g(_sum(sold, q))} g). ${groups.length} item types.'
          '${noImg > 0 ? ' $noImg pieces in stock have no photo yet.' : ''}',
      stats: [
        AiStat('Total pcs', '${base.length}'),
        AiStat('In stock', '${inS.length}'),
        AiStat('Sold', '${sold.length}'),
        AiStat('Stock wt', '${g(_sum(inS, q))} g'),
        AiStat('Sold wt', '${g(_sum(sold, q))} g'),
        AiStat('Item type', '${groups.length}'),
        AiStat('No photo', '$noImg'),
      ],
      sections: [_categorySection(groups, q)],
      filterLabel: label,
      followUps: ['Show old stock', 'What sells the most?', 'Items without photo'],
    );
  }

  AiAnswer _categoryWise(AiQuery q) {
    final base = _base(q);
    final groups = _group(base);
    final inS = base.where((e) => e.inStock).toList();
    return AiAnswer(
      text: '${inS.length} pieces in stock across ${groups.length} item types (${g(_sum(inS, q))} g).',
      sections: [_categorySection(groups, q)],
      filterLabel: _filterLabel(q, status: StatusFilter.all),
      followUps: ['What sells the most?', 'Show old stock'],
    );
  }

  AiSection _categorySection(Map<String, List<StockItem>> groups, AiQuery q) {
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.where((x) => x.inStock).length.compareTo(a.value.where((x) => x.inStock).length));
    final maxIn = entries.isEmpty ? 1 : max(1, entries.first.value.where((x) => x.inStock).length);
    return AiSection(
      'Item wise stock',
      entries.map((e) {
        final inS = e.value.where((x) => x.inStock).toList();
        final ws = inS.map((x) => _w(x, q)).toList()..sort();
        return AiRow(
          e.key,
          '${inS.length} pcs · ${g(_sum(inS, q))} g',
          sub: 'Sold ${e.value.length - inS.length}'
              '${ws.isNotEmpty ? ' · range ${g(ws.first)}–${g(ws.last)} g · avg ${g(_sum(inS, q) / inS.length)} g' : ''}',
          bar: inS.length / maxIn,
          askOnTap: '${e.key} in stock',
        );
      }).toList(),
    );
  }

  AiAnswer _extreme(AiQuery q, {required bool heaviest}) {
    final status = q.statusExplicit ? q.status : StatusFilter.inStock;
    final list = _status(_base(q), status)
      ..sort((a, b) => heaviest ? _w(b, q).compareTo(_w(a, q)) : _w(a, q).compareTo(_w(b, q)));
    if (list.isEmpty) return const AiAnswer(text: 'No piece found.');
    final items = _limit(list, q, 10);
    final f = items.first;
    return AiAnswer(
      text: 'The ${heaviest ? 'heaviest' : 'lightest'} piece is ${f.labelCode} (${f.itemName}) — ${g(_w(f, q))} gram. '
          'Top ${items.length} are below.',
      items: _rec(items),
      itemsTitle: heaviest ? 'Heavy to light' : 'Light to heavy',
      filterLabel: _filterLabel(q, status: status),
    );
  }

  AiAnswer _noImage(AiQuery q) {
    final list = _base(q).where((e) => e.inStock && !e.hasImage).toList()
      ..sort((a, b) {
        final c = a.itemName.compareTo(b.itemName);
        return c != 0 ? c : a.labelCode.compareTo(b.labelCode);
      });
    final label = _filterLabel(q, status: StatusFilter.inStock);
    if (list.isEmpty) {
      return AiAnswer(
        text: '$label: every piece in stock has a photo. 👍',
        speech: 'Every piece has a photo.',
        filterLabel: label,
      );
    }
    final allIn = _base(q).where((e) => e.inStock).length;
    final groups = _group(list).entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    final maxN = groups.first.value.length;
    final wt = _sum(list, q);
    return AiAnswer(
      text: '$label: ${list.length} pieces in stock have no photo (${allIn == 0 ? 0 : (list.length * 100 / allIn).round()}% of stock), '
          'total ${g(wt)} gram. Most pending: ${groups.first.key} (${groups.first.value.length} pieces).\n'
          'Tap 📄 PDF below to print or share the list on WhatsApp.',
      speech: '${list.length} pieces have no photo. Most pending is ${groups.first.key}.',
      stats: [
        AiStat('No photo', '${list.length} pcs'),
        AiStat('Total wt', '${g(wt)} g'),
        AiStat('Item types', '${groups.length}'),
        AiStat('In stock', '$allIn pcs'),
      ],
      sections: [
        AiSection(
          'Item wise — photo pending',
          groups
              .map((e) => AiRow(
            e.key,
            '${e.value.length} pcs',
            sub: '${g(_sum(e.value, q))} g · ${e.value.take(6).map((x) => x.labelCode).join(', ')}'
                '${e.value.length > 6 ? ' …' : ''}',
            bar: e.value.length / maxN,
            askOnTap: '${e.key} without photo',
          ))
              .toList(),
        ),
      ],
      items: _rec(list),
      itemsTitle: 'Items without photo',
      filterLabel: label,
      followUps: [
        'Items without photo PDF',
        if (groups.length > 1) '${groups.first.key} without photo',
        'What is the total stock?',
      ],
    );
  }

  /// 📷 Photo che e hajar item (catalogue / photo vali PDF mate)
  AiAnswer _withImage(AiQuery q) {
    final status = q.statusExplicit ? q.status : StatusFilter.inStock;
    final list = _status(_base(q), status).where((e) => e.hasImage).toList()
      ..sort((a, b) {
        final c = a.itemName.compareTo(b.itemName);
        return c != 0 ? c : _w(a, q).compareTo(_w(b, q));
      });
    final label = _filterLabel(q, status: status);
    if (list.isEmpty) {
      return AiAnswer(
        text: '$label: no piece has a photo.',
        speech: 'No piece has a photo.',
        filterLabel: label,
        followUps: const ['Items without photo'],
      );
    }
    final all0 = _status(_base(q), status).length;
    final groups = _group(list).entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    final maxN = groups.first.value.length;
    final wt = _sum(list, q);
    return AiAnswer(
      text: '$label: ${list.length} pieces have a photo (${all0 == 0 ? 0 : (list.length * 100 / all0).round()}%), '
          'total ${g(wt)} gram, ${groups.length} items.\n'
          'Tap 📄 PDF below → "With photos" to get a catalogue PDF with a photo in every row.',
      speech: '${list.length} pieces have a photo.',
      stats: [
        AiStat('With photo', '${list.length} pcs'),
        AiStat('Total wt', '${g(wt)} g'),
        AiStat('Item types', '${groups.length}'),
        AiStat('No photo', '${all0 - list.length} pcs'),
      ],
      sections: [
        AiSection(
          'Item wise (with photo)',
          groups
              .map((e) => AiRow(
            e.key,
            '${e.value.length} pcs',
            sub: '${g(_sum(e.value, q))} g',
            bar: e.value.length / maxN,
            askOnTap: '${e.key} with photo',
          ))
              .toList(),
        ),
      ],
      items: _rec(list),
      itemsTitle: 'Items with photo',
      filterLabel: label,
      followUps: [
        'Items with photo PDF',
        if (groups.length > 1) '${groups.first.key} with photo PDF',
        'Items without photo',
      ],
    );
  }

  AiAnswer _otherWeight(AiQuery q) {
    final status = q.statusExplicit ? q.status : StatusFilter.inStock;
    final list = _status(_base(q), status).where((e) => e.hasOtherWeight).toList()
      ..sort((a, b) => b.otherWeight.compareTo(a.otherWeight));
    final ow = list.fold(0.0, (a, b) => a + b.otherWeight);
    return AiAnswer(
      text: list.isEmpty
          ? 'No piece has other weight (stone / pearl).'
          : '${list.length} pieces have other weight, total ${g(ow)} gram.',
      stats: [AiStat('Pieces', '${list.length}'), AiStat('Other wt', '${g(ow)} g')],
      items: _rec(list),
      itemsTitle: 'Pieces with other weight',
      filterLabel: _filterLabel(q, status: status),
    );
  }

  AiAnswer _unknown(String raw) => AiAnswer(
    text: 'Sorry, I did not understand "$raw". Try asking something like:',
    speech: 'Sorry, I did not understand. Please ask again.',
    followUps: suggestions.take(6).toList(),
  );

  // =====================================================================
  //  WEIGHT BANDS
  // =====================================================================

  List<_Band> _bands(List<StockItem> list, AiQuery q, {double size = 10}) {
    if (list.isEmpty) return [];
    final maxW = list.map((e) => _w(e, q)).reduce(max);
    final n = (maxW / size).floor() + 1;
    final bands = List.generate(n, (i) => _Band(i * size, (i + 1) * size));
    for (final i in list) {
      final idx = min(n - 1, (_w(i, q) / size).floor());
      bands[idx].total++;
      if (i.isSold) bands[idx].sold++;
    }
    return bands;
  }
}

class _Band {
  final double from;
  final double to;
  int total = 0;
  int sold = 0;
  _Band(this.from, this.to);
  double get st => total == 0 ? 0.0 : sold / total;
  String get label => '${StockAiEngine.g(from)}–${StockAiEngine.g(to)} g';
}

class _Cat {
  final String name;
  final int total;
  final int sold;
  final int inStock;
  final double sellThrough;
  final int? oldestDays;
  final double? avgDaysToSell;
  final double soldWeight;
  _Cat(this.name, this.total, this.sold, this.inStock, this.sellThrough, this.oldestDays,
      {this.avgDaysToSell, this.soldWeight = 0});
}