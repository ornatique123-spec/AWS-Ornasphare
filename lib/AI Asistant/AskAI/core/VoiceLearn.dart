import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// =======================================================================
///  🎤 VOICE LEARN — mic khotu lakhe to ek var sudharo, pachhi yaad rahe
///
///  Bolya: "aje ketlo stock umerayo"   mic lakhe: "ajay ketlo stock umbrella"
///  → bubble par ✏️ dabavo → "aje ketlo stock umerayo" sudhari ne moklo
///  → have pachhi "ajay"→"aje", "umbrella"→"umerayo" pote sudharai jase.
///
///  SharedPreferences key: ai_voice_fixes
///  File: Ask AI/core/voice_learn.dart
/// =======================================================================
class VoiceLearn {
  static const _key = 'ai_voice_fixes';
  static Map<String, String> _fixes = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_key);
      if (s != null) _fixes = Map<String, String>.from(jsonDecode(s) as Map);
    } catch (_) {}
    _loaded = true;
  }

  static Map<String, String> get all => Map.unmodifiable(_fixes);

  /// Mic na text par sikhela sudhara lagavo (lambu pehla, aakha shabd j)
  static String apply(String text) {
    var t = ' ${builtIn(text)} ';
    if (_fixes.isEmpty) return t.trim();
    final keys = _fixes.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in keys) {
      t = t.replaceAll(RegExp('(?<=\\s)${RegExp.escape(k)}(?=\\s)', caseSensitive: false), _fixes[k]!);
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // =====================================================================
  //  🔧 BUILT-IN — mic weight / item bolva ma je khotu lakhe te
  //  "10 the 15 gram" / "1015 gram" / "10th 15" / "ten tea fifteen"
  //  "grammy temple rink" / "simple ring" → "10 thi 15 gram ni temple ring"
  // =====================================================================
  static const String _num =
      r'(\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|'
      r'sixteen|seventeen|eighteen|nineteen|twenty|twenty five|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred)';

  /// Be number vachche "thi" ne badle aavta shabdo
  static const String _sep =
      r'(?:the|thee|tea|tee|ti|te|t|d|dee|di|thy|thai|they|than|then|thik|teen|ki|kit|key|three)';

  static const Map<String, String> _fixWords = {
    // gram
    'grammy': 'gram ni', 'gramin': 'gram ni', 'gram knee': 'gram ni', 'gram nee': 'gram ni', 'grand': 'gram',
    'grams': 'gram', 'graam': 'gram', 'gramm': 'gram', 'cram': 'gram', 'kram': 'gram', 'gram e': 'gram',
    'grahm': 'gram', 'gramme': 'gram', 'gramnee': 'gram ni', 'gramni': 'gram ni',
    // temple ring
    'temple rink': 'temple ring', 'temple wring': 'temple ring', 'temple rang': 'temple ring',
    'temple ding': 'temple ring', 'temple bring': 'temple ring', 'temple king': 'temple ring',
    'temple rings': 'temple ring', 'temper ring': 'temple ring', 'tempel ring': 'temple ring',
    'tample ring': 'temple ring', 'simple ring': 'temple ring', 'temple bring ring': 'temple ring',
    'tempal': 'temple', 'tempel': 'temple', 'tample': 'temple', 'tempul': 'temple', 'templ': 'temple',
    'temp le': 'temple', 'tem pal': 'temple',
    // ni / thi / batav
    'knee': 'ni', 'nee': 'ni', 'thee': 'thi', 'bataw': 'batav', 'batao': 'batav', 'bata': 'batav',
    // 🛒 sale / vechan / sauthi vadhare / common words (mic mistakes)
    'cell': 'sale', 'sell': 'sale', 'sail': 'sale', 'cells': 'sale', 'sells': 'sale', 'sails': 'sale',
    'sel': 'sale', 'seal': 'sale', 'cell ma': 'sale ma', 'sell ma': 'sale ma', 'cell nu': 'sale nu', 'sell nu': 'sale nu',
    'cell report': 'sale report', 'sales man': 'sales', 'sail estimate': 'sale estimate', 'cell estimate': 'sale estimate',
    'sell estimate': 'sale estimate', 'vechayali': 'vechayeli', 'vechayli': 'vechayeli', 'vecha yeli': 'vechayeli',
    'vachayeli': 'vechayeli', 'vichayeli': 'vechayeli', 'vech ayeli': 'vechayeli', 'we chayeli': 'vechayeli',
    'be chayeli': 'vechayeli', 'bechayeli': 'vechayeli', 'vechaieli': 'vechayeli', 'vechaeli': 'vechayeli',
    'vechheli': 'vechayeli', 'vecheli': 'vechayeli', 'vechali': 'vechayeli', 'vacheli': 'vechayeli', 'wechayeli': 'vechayeli',
    'vachayela': 'vechayela', 'vecha yu': 'vechayu', 'vachayu': 'vechayu', 'vichayu': 'vechayu', 'we chayu': 'vechayu',
    'be chayu': 'vechayu', 'bechayu': 'vechayu', 'vechaio': 'vechayu', 'vecheyu': 'vechayu', 'vechhayu': 'vechayu',
    'wechayu': 'vechayu', 'vachayo': 'vechayo', 'vachan': 'vechan', 'vechhan': 'vechan', 'we chan': 'vechan',
    'sau thi': 'sauthi', 'southy': 'sauthi', 'sauti': 'sauthi', 'sothi': 'sauthi', 'sotthi': 'sauthi',
    'south': 'sauthi', 'sauthee': 'sauthi', 'sautee': 'sauthi', 'sowthi': 'sauthi', 'so thi': 'sauthi',
    'sau tea': 'sauthi', 'wadhare': 'vadhare', 'vadhaare': 'vadhare', 'vadare': 'vadhare', 'wadhaare': 'vadhare',
    'vadhre': 'vadhare', 'vadhar': 'vadhare', 'vadhari': 'vadhare', 'ochu': 'ochhu',
    'ochoo': 'ochhu', 'occhu': 'ochhu', 'aitem': 'item', 'itam': 'item', 'idem': 'item', 'i tem': 'item',
    'atom': 'item', 'itom': 'item', 'aage': 'aaje', 'aaj e': 'aaje', 'aje': 'aaje', 'kaale': 'kale', 'kalay': 'kale',
    'param divase': 'parmdivase', 'kitlu': 'ketlu', 'ketalu': 'ketlu', 'katlu': 'ketlu', 'kitlo': 'ketlo',
    'ketalo': 'ketlo', 'stuck': 'stock', 'stok': 'stock', 'stalk': 'stock', 'stocks': 'stock', 'approve': 'approval',
    'a proval': 'approval', 'approvel': 'approval', 'aproval': 'approval', 'approwal': 'approval', 'a pro val': 'approval',
    'costumer': 'customer', 'customar': 'customer', 'kastamar': 'customer', 'customers': 'customer', 'retun': 'return',
    'ritan': 'return', 're turn': 'return', 'returned': 'return', 'walker': 'worker', 'worke': 'worker',
    'workar': 'worker', 'vorker': 'worker', 'bar code': 'barcode', 'bar cod': 'barcode', 'label code': 'barcode',
    'asti mate': 'estimate', 'estimated': 'estimate',
  };

  static String builtIn(String text) {
    var t = ' ${text.toLowerCase().trim()} ';
    t = t.replaceAll(RegExp(r'[,?!]'), ' ').replaceAll(RegExp(r'\s+'), ' ');

    // 1) shabd sudharo (lambu pehla)
    final keys = _fixWords.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in keys) {
      t = t.replaceAll(' $k ', ' ${_fixWords[k]} ');
      t = t.replaceAll(' $k ', ' ${_fixWords[k]} ');
    }

    // 2) "10th 15" / "10 th 15" → "10 thi 15"
    t = t.replaceAllMapped(RegExp(r' (\d+)\s?(?:th|st|nd|rd) (\d+) '), (m) => ' ${m[1]} thi ${m[2]} ');

    // 3) "10 the 15" / "ten tea fifteen" → "10 thi 15"
    t = t.replaceAllMapped(RegExp(' $_num $_sep $_num (?=gram|g |gm|ni|na|nu|no|ma|ring|item|ni )'),
            (m) => ' ${m[1]} thi ${m[2]} ');

    // 4) "1015 gram" / "10 15 gram" (vachche nu "thi" gumayu) → "10 thi 15 gram"
    t = t.replaceAllMapped(RegExp(r' (\d{1,2})(\d{2}) (?=gram|g |gm)'), (m) {
      final a = int.parse(m[1]!), b = int.parse(m[2]!);
      return (a > 0 && b > a && b <= 99) ? ' ${m[1]} thi ${m[2]} ' : m[0]!;
    });
    t = t.replaceAllMapped(RegExp(r' (\d{1,3}) (\d{1,3}) (?=gram|g |gm)'), (m) {
      final a = int.parse(m[1]!), b = int.parse(m[2]!);
      return b > a ? ' ${m[1]} thi ${m[2]} ' : m[0]!;
    });

    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// heard = mic e lakhelu, fixed = tame sudharelu
  /// return = sikhela sudhara (UI ma batavva)
  static Future<Map<String, String>> learn(String heard, String fixed) async {
    final a = _words(heard), b = _words(fixed);
    final learned = <String, String>{};
    if (a.isEmpty || b.isEmpty || a.join(' ') == b.join(' ')) return learned;

    // aagal-pachhal na same shabdo kadhi ne vachche no badlav
    var s = 0;
    while (s < a.length && s < b.length && a[s] == b[s]) {
      s++;
    }
    var ea = a.length, eb = b.length;
    while (ea > s && eb > s && a[ea - 1] == b[eb - 1]) {
      ea--;
      eb--;
    }
    final from = a.sublist(s, ea), to = b.sublist(s, eb);
    if (from.isEmpty || to.isEmpty) return learned;

    if (from.length == to.length) {
      for (var i = 0; i < from.length; i++) {
        if (from[i] != to[i] && from[i].length >= 2) learned[from[i]] = to[i];
      }
    } else if (from.length <= 4) {
      learned[from.join(' ')] = to.join(' ');
    }
    // number badlva (10 → 15) jeva sudhara sikhva nahi — e sawal j judo che
    learned.removeWhere((k, v) => RegExp(r'^\d+$').hasMatch(k) || RegExp(r'^\d+$').hasMatch(v));
    if (learned.isEmpty) return learned;

    _fixes.addAll(learned);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(_fixes));
    } catch (_) {}
    return learned;
  }

  static Future<void> forget(String heard) async {
    _fixes.remove(heard);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(_fixes));
    } catch (_) {}
  }

  static Future<void> clear() async {
    _fixes.clear();
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key);
    } catch (_) {}
  }

  static List<String> _words(String s) =>
      s.toLowerCase().trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
}
