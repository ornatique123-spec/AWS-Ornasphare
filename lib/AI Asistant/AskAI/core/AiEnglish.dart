import 'AiTranslator.dart';
import 'ai_core.dart';

/// =======================================================================
///  🇬🇧 AI ENGLISH — every answer is shown & spoken in English only
///
///  Some modules (Sales / Approval / Worker Loss …) still write their answers
///  in Gujlish ("Divya nu kul vechan ₹5,000 che"). This is a safety net that
///  turns those words into English before they are shown or spoken:
///    • Gujlish (Latin letters)  → English using a jewellery-ERP dictionary
///    • Gujarati / Hindi script  → English with the on-device translator
///  Text that is already English is not touched. Names, codes and numbers stay.
///
///  For perfect sentences, the module's own strings should be English — this
///  only fixes what is left.
///  File: Ask AI/core/ai_english.dart
/// =======================================================================
class AiEnglish {
  /// Words that only Gujlish uses — decide "is this Gujlish?"
  static const Set<String> _marks = {
    'che', 'chhe', 'nathi', 'nu', 'ni', 'kul', 'vechan', 'vechanu', 'vechayu', 'vechaya', 'vechayo', 'vechai',
    'mujab', 'karo', 'thi', 'ane', 'padela', 'baki', 'atyare', 'aaje', 'kale', 'koi', 'badha', 'badhi', 'badhu',
    'ketla', 'ketlo', 'ketlu', 'thayu', 'thaya', 'thayo', 'aavyu', 'aavyo', 'aavya', 'gayu', 'gaya', 'juo', 'batav',
    'batavo', 'jama', 'udhar', 'rakam', 'karigar', 'ghat', 'ghatado', 'divas', 'mahina', 'tarikh', 'sauthi',
    'vadhare', 'vadhu', 'ochhu', 'ochha', 'dabavo', 'kholo', 'khulse', 'hajar', 'maal', 'grahak', 'pachhu',
    'parat', 'bakaya', 'jamaa', 'chhello', 'chhella', 'pehla', 'pela', 'haju', 'hju', 'etle',
    'sudhi', 'upar', 'niche', 'vachhe', 'kai', 'shu', 'kon', 'kone', 'kona', 'malyo', 'malyu', 'mali',
    'apyo', 'aapyo', 'lidhu', 'lidho', 'didhu', 'didho', 'aavel', 'gayel', 'banyu', 'banya', 'sathe', 'vagar',
    'chalu', 'bandh', 'puru', 'adhu', 'samjayu', 'puchho', 'bolo', 'sambhdo', 'tamaru', 'tamara', 'mane',
    'vala', 'wala', 'vali', 'wali', 'vadi', 'vina', 'juna', 'juno', 'junu', 'navo', 'nava', 'umerayo',
    'umerayela', 'najik', 'halka', 'bhare', 'banela', 'vechati',
  };

  /// Phrases first (longest first), then single words. Lowercase keys.
  static const Map<String, String> _phrases = {
    // photo
    'photo vala item': 'items with photo', 'photo vala piece': 'pieces with photo', 'photo vala': 'with photo',
    'photo vagar na item': 'items without photo', 'photo vagar na piece': 'pieces without photo',
    'photo vagar': 'without photo', 'photo vina': 'without photo', 'photo baki': 'photo pending',
    'item mujab photo baki': 'item wise — photo pending', 'item mujab (photo vala)': 'item wise (with photo)',
    'other weight vala piece': 'pieces with other weight',
    // stock lists
    'najik na piece': 'nearest pieces', 'halka thi bhare': 'light to heavy', 'bhare thi halka': 'heavy to light',
    'sauthi juna piece': 'oldest pieces', 'juno pehla': 'oldest first', 'juni pehla': 'oldest first',
    'sauthi pehla banela hajar piece': 'earliest made pieces in stock', 'vechayela piece': 'sold pieces',
    'ochhu vechati item': 'slow selling items', 'item mujab vechan': 'item wise sales', 'kul piece': 'total pcs',
    'kul wt': 'total wt', 'item type': 'item types',
    'umerayela': 'added', 'badhi entry': 'all entries', 'badho stock': 'all stock',
    // status / actions
    'vechai gayo che': 'has been sold', 'vechai gaya che': 'have been sold', 'vechai gayu che': 'has been sold',
    'approval ma che': 'is on approval', 'approval ma': 'on approval', 'stock ma che': 'is in stock',
    'stock ma': 'in stock', 'return aavyo che': 'has been returned', 'return aavyu': 'returned',
    'parat aavyu': 'returned', 'parat aavyo': 'returned', 'pachhu aavyu': 'returned',
    'puri detail khulse': 'full details will open', 'detail khulse': 'details will open',
    'tap karo': 'tap', 'click karo': 'click', 'dabavo': 'press', 'niche': 'below', 'upar': 'above',
    'koi data nathi': 'no data', 'data nathi': 'no data', 'kai nathi': 'nothing', 'koi nathi': 'none',
    'malyo nathi': 'not found', 'malyu nathi': 'not found', 'mali nathi': 'not found', 'load na thayo': 'could not load',
    'load na thayu': 'could not load', 'load na thai': 'could not load', 'samjayu nahi': 'did not understand',
    'barabar samjayu nahi': 'did not understand properly', 'fari puchho': 'please ask again',
    'fari try karo': 'please try again', 'maaf karjo': 'sorry',
    // amounts / ledger
    'baki rakam': 'balance amount', 'bakaya rakam': 'balance amount', 'kul rakam': 'total amount',
    'kul vechan': 'total sales', 'kul ghat': 'total loss', 'kul jama': 'total credit', 'kul udhar': 'total debit',
    'fine ghat': 'fine loss', 'metal ghat': 'metal loss',
    // comparison
    'sauthi vadhare': 'the most', 'sauthi vadhu': 'the most', 'sauthi ochhu': 'the least', 'sauthi ochha': 'the least',
    'thi vadhare': 'more than', 'thi vadhu': 'more than', 'thi ochhu': 'less than', 'thi ochha': 'less than',
    // time
    'aa mahine': 'this month', 'gaya mahine': 'last month', 'aa athvadiye': 'this week', 'gaya athvadiye': 'last week',
    'aa varshe': 'this year', 'gaya varshe': 'last year', 'chhella': 'last', 'chhello': 'last', 'chhelli': 'last',
    // people
    'customer mujab': 'customer wise', 'item mujab': 'item wise', 'divas mujab': 'day wise', 'mahina mujab': 'month wise',
    'karigar mujab': 'worker wise', 'voucher mujab': 'voucher wise', 'type mujab': 'type wise',
  };

  static const Map<String, String> _words = {
    'che': '', 'chhe': '', 'nathi': 'not', 'ane': 'and', 'pan': 'also', 'ke': 'or', 'kul': 'total',
    'vechan': 'sales', 'vechanu': 'sales', 'vechayu': 'sold', 'vechaya': 'sold', 'vechayo': 'sold', 'vechayela': 'sold',
    'mujab': 'wise', 'padela': 'in stock', 'baki': 'pending', 'bakaya': 'balance', 'atyare': 'now',
    'aaje': 'today', 'kale': 'yesterday', 'parmdivase': 'day before yesterday', 'koi': 'any', 'badha': 'all',
    'badhi': 'all', 'badhu': 'all', 'ketla': 'how many', 'ketlo': 'how much', 'ketlu': 'how much',
    'thayu': '', 'thaya': '', 'thayo': '', 'aavyu': 'received', 'aavyo': 'received', 'aavya': 'received',
    'aavel': 'received', 'gayu': 'gone', 'gaya': 'gone', 'gayel': 'gone', 'juo': 'see', 'batav': 'show',
    'batavo': 'show', 'jama': 'credit', 'jamaa': 'credit', 'udhar': 'debit', 'rakam': 'amount', 'karigar': 'worker',
    'ghat': 'loss', 'ghatado': 'loss', 'divas': 'days', 'mahina': 'months', 'mahino': 'month', 'varsh': 'year',
    'tarikh': 'date', 'vadhare': 'more', 'vadhu': 'more', 'ochhu': 'less', 'ochha': 'less', 'kholo': 'open',
    'khulse': 'will open', 'hajar': 'available', 'maal': 'goods', 'grahak': 'customer', 'parat': 'returned',
    'pehla': 'first', 'pela': 'first', 'haju': 'still', 'hju': 'still', 'etle': 'so', 'mate': 'for',
    'sudhi': 'until', 'kai': 'which', 'shu': 'what', 'kon': 'who', 'kone': 'to whom', 'kona': 'whose',
    'malyo': 'found', 'malyu': 'found', 'mali': 'found', 'apyo': 'given', 'aapyo': 'given', 'lidhu': 'taken',
    'lidho': 'taken', 'didhu': 'given', 'didho': 'given', 'banyu': 'made', 'banya': 'made', 'sathe': 'with',
    'vagar': 'without', 'chalu': 'active', 'bandh': 'closed', 'puru': 'complete', 'adhu': 'partial',
    'ma': 'in', 'thi': 'from', 'nang': 'pcs', 'piece': 'pcs', 'entry': 'entries', 'tamaru': 'your', 'tamara': 'your',
    'mane': 'me', 'puchho': 'ask', 'bolo': 'say', 'vachhe': 'between', 'em': 'so', 'male': 'found',
    'vala': 'with', 'wala': 'with', 'vali': 'with', 'wali': 'with', 'vadi': 'with', 'vina': 'without',
    'juna': 'old', 'juno': 'old', 'junu': 'old', 'navo': 'new', 'nava': 'new', 'umerayo': 'added',
    'najik': 'nearest', 'halka': 'light', 'bhare': 'heavy', 'banela': 'made', 'vechati': 'selling',
  };

  /// translated chip → original question (module engines understand the original)
  static final Map<String, String> _orig = {};
  static String originalOf(String shown) => _orig[shown] ?? shown;

  static bool _isGujlish(String s) {
    final w = s.toLowerCase().split(RegExp(r'[^a-z]+')).where((x) => x.isNotEmpty).toList();
    if (w.isEmpty) return false;
    final hits = w.where(_marks.contains).length;
    if (hits >= 2 || (hits == 1 && w.length <= 3)) return true;
    // jani-ti Gujlish phrase ("photo vagar na item") hoy to pan
    if (hits == 1) {
      final low = ' ${w.join(' ')} ';
      return _phraseKeys.any((k) => k.contains(' ') && low.contains(' $k '));
    }
    return false;
  }

  static final List<String> _phraseKeys = _phrases.keys.toList()..sort((a, b) => b.length - a.length);

  /// Gujlish → English (sync). English text comes back unchanged.
  static String fix(String s) {
    if (s.isEmpty || !_isGujlish(s)) return s;
    return s.split('\n').map(_fixLine).join('\n');
  }

  static String _fixLine(String line) {
    if (!_isGujlish(line)) return line;
    var t = line;
    // "10 thi 15" → "10 to 15"
    t = t.replaceAllMapped(RegExp(r'(\d)\s+thi\s+(\d)', caseSensitive: false), (m) => '${m[1]} to ${m[2]}');
    // "koi X nathi" → "no X"
    t = t.replaceAllMapped(RegExp(r'\bkoi\s+([\w ]{1,30}?)\s+nathi\b', caseSensitive: false), (m) => '§NO§ ${m[1]}');
    // phrases
    for (final k in _phraseKeys) {
      t = t.replaceAll(RegExp('\\b${RegExp.escape(k)}\\b', caseSensitive: false), _phrases[k]!);
    }
    // "Divya nu vechan" → "Divya's sales"
    t = t.replaceAllMapped(RegExp(r"(\b[A-Za-z0-9][\w.&-]*)\s+(nu|ni|no|na|ne)\b(?=\s+\w)", caseSensitive: false),
            (m) => "${m[1]}'s");
    t = t.replaceAll(RegExp(r'\b(nu|ni|no|na|ne)\b', caseSensitive: false), '');
    // words
    t = t.replaceAllMapped(RegExp(r'\b[A-Za-z]+\b'), (m) {
      final w = m[0]!;
      final e = _words[w.toLowerCase()];
      if (e == null) return w;
      if (e.isEmpty) return '';
      return (w[0] == w[0].toUpperCase() && w[0] != w[0].toLowerCase()) ? '${e[0].toUpperCase()}${e.substring(1)}' : e;
    });
    // "is" ane khali jagya saaf
    t = t.replaceAllMapped(RegExp(r'\s+is\s*([.!,]|$)'), (m) => m[1]!);
    t = t.replaceAll('§NO§', 'no').replaceAll(RegExp(r' {2,}'), ' ').trim();
    t = t.replaceAllMapped(RegExp(r'\s+([.,!?])'), (m) => m[1]!);
    // pehlo akshar capital (emoji / number pachhi pan)
    t = t.replaceFirstMapped(RegExp(r'^([^A-Za-z]*)([a-z])'), (m) => '${m[1]}${m[2]!.toUpperCase()}');
    return t;
  }

  static final _script = RegExp(r'[ऀ-ॿ઀-૿]');

  /// Gujlish + Gujarati/Hindi script → English (async, for full answers)
  static Future<String> fixAsync(String s) async {
    var t = fix(s);
    if (_script.hasMatch(t)) {
      final lines = <String>[];
      for (final l in t.split('\n')) {
        if (_script.hasMatch(l)) {
          final en = await AiTranslator.toEnglish(l);
          lines.add(en ?? l);
        } else {
          lines.add(l);
        }
      }
      t = lines.join('\n');
    }
    return t;
  }

  static bool needsWork(AiAnswer a) {
    bool n(String? s) => s != null && (_script.hasMatch(s) || _isGujlish(s));
    return n(a.text) ||
        n(a.speech) ||
        a.stats.any((s) => n(s.label) || n(s.value)) ||
        a.sections.any((s) => n(s.title) || s.rows.any((r) => n(r.title) || n(r.value) || n(r.sub))) ||
        n(a.itemsTitle?.toString()) ||
        n(a.filterLabel?.toString()) ||
        a.followUps.any(n);
  }

  /// Full answer → English. Records are not rebuilt (voucher taps keep working);
  /// their text is fixed on screen with [fix].
  static Future<AiAnswer> answer(AiAnswer a) async {
    if (!needsWork(a)) return a;
    final follow = <String>[];
    for (final f in a.followUps) {
      final e = await fixAsync(f);
      _orig[e] = f;
      follow.add(e);
    }
    return AiAnswer(
      text: await fixAsync(a.text),
      speech: await fixAsync(a.speech),
      stats: [for (final s in a.stats) AiStat(await fixAsync(s.label), fix(s.value))],
      sections: [
        for (final s in a.sections)
          AiSection(await fixAsync(s.title), [
            for (final r in s.rows)
              AiRow(fix(r.title), fix(r.value), sub: r.sub == null ? null : fix(r.sub!), bar: r.bar, askOnTap: r.askOnTap),
          ]),
      ],
      items: a.items,
      // dynamic: works whether AiAnswer field is String or String?
      itemsTitle: (a.itemsTitle == null ? null : await fixAsync(a.itemsTitle.toString())) as dynamic,
      filterLabel: (a.filterLabel == null ? null : await fixAsync(a.filterLabel.toString())) as dynamic,
      followUps: follow,
      period: a.period,
    );
  }
}
