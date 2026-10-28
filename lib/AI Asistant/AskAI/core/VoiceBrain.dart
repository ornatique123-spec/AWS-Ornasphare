/// =======================================================================
///  🧠 VOICE BRAIN — mic e je sambhdyu te TAMARA data sathe meli ne sudhare
///
///  Phone nu speech engine tamara item / customer na naam janatu nathi,
///  etle "temple ring" ne "simple ring", "Divya" ne "Dibya",
///  "heritage necklace" ne "heritage neckless" lakhi nakhe.
///
///  Aa class tamara j shabdo (item master, stock na item, customer, label
///  code, AI na command shabdo) ni dictionary banave che ane mic na text na
///  ajanya shabdo ne "awaj" (phonetic) mujab sauthi najik na sacha shabd
///  sathe badli nakhe che. Sacha shabdo ne aDtu nathi.
///
///  File: Ask AI/core/voice_brain.dart
/// =======================================================================
class VoiceBrain {
  /// skeleton key → phrase (lowercase)
  static final List<_V> _vocab = [];
  static final Set<String> _known = {..._common, ..._commands.expand((c) => c.split(' '))};
  static final Set<String> _phraseSet = {};

  static int get size => _vocab.length;

  /// AI na shabdo (badha module) — aa hamesha dictionary ma
  static const List<String> _commands = [
    // stock
    'stock', 'gram', 'thi', 'vadhare', 'ochhu', 'upar', 'niche', 'juno', 'juna', 'junu', 'divas', 'mahina',
    'vechay', 'vechayu', 'vechaya', 'vechan', 'batav', 'batavo', 'ketlo', 'ketlu', 'ketla', 'kul', 'total',
    'category', 'reorder', 'photo', 'vagar', 'bhare', 'halka', 'sauthi', 'weight', 'gross', 'net', 'label',
    'barcode', 'piece', 'item', 'stone', 'moti', 'summary', 'umerayo', 'aavyo', 'navo', 'banya',
    'stock position', 'raw material', 'finished', 'customer received', 'repair',
    // date
    'aaje', 'kale', 'parmdivase', 'athvadiye', 'mahine', 'today', 'yesterday', 'week', 'month',
    'january', 'february', 'march', 'april', 'june', 'july', 'august', 'september', 'october', 'november',
    'december', 'financial year', 'varsh', 'varshe', 'mahina mujab', 'varsh mujab',
    // sales / approval / worker
    'sale', 'sales', 'estimate', 'sale estimate', 'approval', 'approval list', 'bill', 'customer', 'return',
    'vechayeli', 'vechayela', 'vechayelu', 'vechayo', 'sauthi vadhare', 'sauthi ochhu', 'sauthi vadhare vechayeli',
    'most sold', 'top selling', 'best selling', 'least sold', 'slow moving', 'fast moving',
    'worker', 'worker loss', 'loss', 'ledger', 'metal ledger', 'job work', 'karigar', 'voucher', 'print',
    // nav
    'kholo', 'open', 'banav', 'navu', 'gallery', 'stock gallery', 'label print', 'batch', 'image',
    'sales summary', 'refresh', 'help',
  ];

  /// Nana / samanya shabdo — aene kadi na badlo
  static const Set<String> _common = {
    'che', 'chhe', 'nu', 'ni', 'na', 'no', 'ne', 'ma', 'thi', 'ane', 'ke', 'to', 'pan', 'aa', 'e', 'hu', 'tame', 'mane', 'shu', 'su', 'kai', 'kya', 'kyan', 'kon', 'kone', 'kona', 'mate', 'have', 'hoy', 'nathi', 'nahi', 'nai', 'badha', 'badhu', 'badhi', 'wala', 'vala', 'jo', 'joie', 'karo', 'kar', 'kari', 'aapo', 'apo', 'list', 'the', 'a', 'an', 'of', 'in', 'is', 'and', 'or', 'show', 'me', 'all', 'how', 'many', 'much', 'what', 'which', 'are', 'with', 'without', 'from', 'more', 'less', 'than', 'above', 'below', 'top', 'last', 'hai', 'he', 'ka', 'ki', 'se', 'kitna', 'kitne', 'kab', 'aaj', 'kal', 'dikhao', 'batao', 'wise', 'itemwise', 'type', 'heavy', 'light', 'sold', 'out', 'available', 'image', 'images', 'pic', 'old', 'new', 'best', 'seller', 'fast', 'slow', 'ok', 'yes', 'haa', 'jovu', 'juo', 'chalu', 'bandh', 'kem', 'cho', 'gold', 'silver', 'sonu', 'chandi', 'sab', 'sabse', 'please', 'plz', 'report', 'details', 'detail', 'close', 'kaya', 'kayu', 'kayo', 'kevi', 'rite', 'ketli', 'vise', 'wali', 'hua', 'tha', 'gaya', 'gayu', 'gai', 'aapjo', 'jaldi', 'pehla', 'pachhi', 'badhe', 'etle', 'kyare', 'koi', 'pase',
  };

  /// Dictionary navi banavo (screen khule tyare + data aave tyare)
  static void build({
    Iterable<String> items = const [],
    Iterable<String> customers = const [],
    Iterable<String> codes = const [],
  }) {
    _vocab.clear();
    _phraseSet.clear();
    void add(String raw, int weight) {
      final p = _clean(raw);
      if (p.replaceAll(' ', '').length < 3 || !_phraseSet.add(p)) return;
      _vocab.add(_V(p, weight));
      for (final w in p.split(' ')) {
        if (w.length >= 3) _known.add(w);
      }
    }

    for (final c in _commands) {
      add(c, 1);
    }
    for (final i in items) {
      add(i, 3);
      // "Temple Ring" → "temple", "ring" pan
      for (final w in _clean(i).split(' ')) {
        if (w.length >= 4) add(w, 2);
      }
    }
    for (final c in customers) {
      add(c, 2);
      final first = _clean(c).split(' ').first;
      if (first.length >= 4) add(first, 2);
    }
    for (final c in codes) {
      _known.add(_clean(c).replaceAll(' ', ''));
    }
  }

  /// Aa shabd dictionary ma che? (alternates ma sacho andaj pasand karva)
  static double coverage(String text) {
    final w = _clean(text).split(' ').where((x) => x.length >= 3 && !RegExp(r'\d').hasMatch(x)).toList();
    if (w.isEmpty) return 0;
    return w.where(_known.contains).length / w.length;
  }

  /// 🎯 Mukhya: "10 thi 15 gram simple rink" → "10 thi 15 gram temple ring"
  static String correct(String text) {
    if (_vocab.isEmpty) return text;
    // lowercase j — "12.5", "br-8", Gujarati lipi jeva shabdo jem na tem rahe
    final words = text.toLowerCase().trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      _Hit? best;
      for (var n = 3; n >= 1; n--) {
        if (i + n > words.length) continue;
        final part = words.sublist(i, i + n);
        // number / code vala shabd ne na advu
        if (part.any((w) => RegExp(r'[^a-z]').hasMatch(w))) continue;
        // badha shabdo sacha j che → kai badlvu nathi
        if (part.every((w) => _known.contains(w) || w.length <= 2)) continue;
        final gram = part.join(' ');
        final letters = gram.replaceAll(' ', '').length;
        if (letters < 4) continue;
        final h = _bestMatch(gram, n);
        if (h != null && (best == null || h.score < best.score - 0.01)) {
          best = h;
        }
      }
      if (best != null) {
        out.add(best.phrase);
        i += best.n;
      } else {
        out.add(words[i]);
        i++;
      }
    }
    return out.join(' ');
  }

  static _Hit? _bestMatch(String gram, int n) {
    final fa = _full(gram), sa = _skel(gram);
    _Hit? best;
    for (final v in _vocab) {
      final wc = v.words;
      if ((wc - n).abs() > 1) continue;
      // pehlo avaj same hovo joie (khota match ochha)
      if (v.full.isEmpty || fa.isEmpty || v.full[0] != fa[0]) {
        // "c/k/s" ane "v/b" jeva sarkha avaj chalavo
        if (!_sameStart(v.full, fa)) continue;
      }
      final lenF = fa.length > v.full.length ? fa.length : v.full.length;
      if ((fa.length - v.full.length).abs() > (lenF * 0.35).ceil()) continue;
      final dF = _lev(fa, v.full);
      final dS = _lev(sa, v.skel);
      final ok = dF <= (lenF >= 9 ? 2 : 1) ||
          (dS == 0 && dF <= (lenF * 0.4).floor()) ||
          (dS <= 1 && v.skel.length >= 5 && dF <= (lenF * 0.3).floor());
      if (!ok) continue;
      // nanu score = vadhu sacho; vajan vala (item) ne thodu aagal
      final score = (dF + dS * 0.5) / lenF - v.weight * 0.01 - (wc == n ? 0.02 : 0);
      if (best == null || score < best.score) best = _Hit(v.phrase, n, score);
    }
    return best;
  }

  static bool _sameStart(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    const groups = ['ck', 'sjz', 'vbw', 'td', 'pf', 'gj', 'ie', 'ou', 'ae'];
    return groups.any((g) => g.contains(a[0]) && g.contains(b[0]));
  }

  // ---------------------------------------------------------------------
  //  Phonetic keys (Indian English / Gujlish mate)
  // ---------------------------------------------------------------------
  static String _clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// "Heritage Necklace" → "heritajneklas"
  static String _full(String s) {
    var t = _clean(s).replaceAll(' ', '');
    const rep = [
      ['tch', 'c'], ['chh', 'c'], ['ch', 'c'], ['sh', 's'], ['ph', 'f'], ['bh', 'b'], ['kh', 'k'], ['gh', 'g'],
      ['th', 't'], ['dh', 'd'], ['jh', 'j'], ['ck', 'k'], ['q', 'k'], ['x', 'ks'], ['w', 'v'], ['z', 'j'],
      ['ee', 'i'], ['ea', 'i'], ['oo', 'u'], ['ou', 'u'], ['aa', 'a'], ['ai', 'e'], ['ay', 'e'], ['ei', 'e'],
      ['ey', 'e'], ['y', 'i'], ['ge', 'je'], ['gi', 'ji'], ['ce', 'se'], ['ci', 'si'],
    ];
    for (final r in rep) {
      t = t.replaceAll(r[0], r[1]);
    }
    // "c" ekla (ch nathi) → k  — "c" have "ch" no avaj che, etle j rakho
    t = t.replaceAll(RegExp(r'h(?![aeiou])'), ''); // "rahm" → "ram"
    t = t.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!); // double akshar
    return t;
  }

  /// Vowel vagar no dhaancho: "temple" → "tmpl", "tempal" → "tmpl"
  static String _skel(String s) {
    final f = _full(s);
    if (f.isEmpty) return f;
    return f[0] + f.substring(1).replaceAll(RegExp(r'[aeiou]'), '').replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
  }

  static int _lev(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var m = cur[j - 1] + 1;
        if (prev[j] + 1 < m) m = prev[j] + 1;
        if (prev[j - 1] + cost < m) m = prev[j - 1] + cost;
        cur[j] = m;
      }
      prev = cur;
    }
    return prev[b.length];
  }
}

class _V {
  final String phrase;
  final int weight;
  late final String full = VoiceBrain._full(phrase);
  late final String skel = VoiceBrain._skel(phrase);
  late final int words = phrase.split(' ').length;
  _V(this.phrase, this.weight);
}

class _Hit {
  final String phrase;
  final int n;
  final double score;
  _Hit(this.phrase, this.n, this.score);
}
