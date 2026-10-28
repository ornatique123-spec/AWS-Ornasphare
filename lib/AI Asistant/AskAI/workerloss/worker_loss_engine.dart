import 'dart:math';

import '../../../Api_Constant/ApiConstants.dart';
import '../../VoucherDetails.dart';
import '../core/ai_core.dart';
import 'worker_loss_models.dart';

/// =======================================================================
///  WORKER LOSS AI ENGINE
///  loss = receive + bhuko − source   (− = ghat, + = vadharo)
///
///  Udaharan:
///   • "worker wise loss" / "kono sauthi vadhare loss" / "loss taka ma"
///   • "Devang no loss" / "Dishank Patel nu casting ma loss"
///   • "sauthi saro karigar" (ochhu ghat)
///   • "stage wise loss" / "casting ma ketlo loss"
///   • "bhuko ketlo" / "worker wise bhuko"
///   • "sauthi motu loss" (entry) / "vadharo vali entry"
///   • "galat entry check karo" (hisab match na thay evi)
///   • "aa mahina nu loss" / "mahina wise loss" / "aa mahina vs gaya mahina loss"
///   • "VV26-9" / "buch 104"
///   • "voucher wise loss" / "Devang nu voucher wise loss"
///   • "day wise loss" / "aa mahina nu divas wise loss"
///   • 📒 METAL LEDGER (format = daily | detailed):
///       "metal ledger" / "worker wise ledger" / "kona paase metal baki"
///       "sakir nu daily ledger" / "Devang nu detailed ledger"
///       "aa mahina nu ledger" / "VV26-9 ledger"
/// =======================================================================

enum LossIntent {
  help,
  voucher,
  workerDetail,
  workerRanking,
  bestWorkers,
  stageWise,
  bhuko,
  worstEntries,
  gain,
  check,
  trend,
  compare,
  summary,
  voucherWise,
  dayWise,
  ledger,
  unknown,
}

class LossQuery {
  LossIntent intent = LossIntent.unknown;
  AiPeriod? period;
  String? worker;
  List<String> workerOptions = [];
  String? stage;
  String? voucherKey;
  String? buch;
  int? limit;
  bool byPercent = false;

  /// 📒 Metal ledger
  bool ledger = false;
  String format = 'daily'; // ledgerFormats ni key: daily | detailed

  @override
  String toString() =>
      'LossQuery($intent period=$period worker=$worker stage=$stage v=$voucherKey buch=$buch '
          'pct=$byPercent ledger=$ledger format=$format)';
}

class _Tot {
  int rows = 0;
  double source = 0, receive = 0, bhuko = 0, loss = 0, ghat = 0, vadharo = 0;
  int issues = 0;
  final Set<String> workers = {};
  final Set<String> vouchers = {};

  void add(LossEntry e) {
    rows++;
    source += e.source;
    receive += e.receive;
    bhuko += e.bhuko;
    loss += e.loss;
    if (e.loss < 0) ghat += -e.loss;
    if (e.loss > 0) vadharo += e.loss;
    if (e.issue != null) issues++;
    workers.add(e.worker);
    vouchers.add(e.voucherNo);
  }

  /// Net ghat % (positive = nuksan)
  double get lossPct => source == 0 ? 0 : -loss / source * 100;
  double get bhukoPct => source == 0 ? 0 : bhuko / source * 100;

  static _Tot of(Iterable<LossEntry> l) {
    final t = _Tot();
    for (final e in l) {
      t.add(e);
    }
    return t;
  }
}

class WorkerLossEngine {
  final List<LossEntry> all;
  late final List<String> workers;
  late final List<String> stages;
  LossQuery? _last;

  WorkerLossEngine(this.all) {
    all.sort((a, b) => b.date.compareTo(a.date));
    workers = {
      ...all.map((e) => e.worker),
      for (final f in ledgerFormats.keys) ...?LedgerStore.of(f)?.map((g) => g.worker),
    }.toList()
      ..sort();
    stages = all.map((e) => e.stage).where((e) => e != '-').toSet().toList()..sort();
  }

  static const List<String> suggestions = [
    'Worker wise loss',
    'Voucher wise loss',
    'Day wise loss',
    'Metal ledger worker wise',
    'Detailed ledger',
    'Who has the most loss?',
    'Best worker',
    'Stage wise loss',
    'Worker wise bhuko',
    'Check wrong entries',
    'Loss this month',
    'Month wise loss',
  ];

  // =====================================================================
  //  PUBLIC
  // =====================================================================

  AiAnswer ask(String raw) {
    if (all.isEmpty) {
      return const AiAnswer(text: 'No worker loss entries found.', speech: 'No worker loss entries found.');
    }
    final q = parse(raw);
    _last = q;
    switch (q.intent) {
      case LossIntent.help:
        return helpAnswer();
      case LossIntent.voucher:
        return _voucher(q);
      case LossIntent.workerDetail:
        return _worker(q);
      case LossIntent.workerRanking:
        return _ranking(q, worstFirst: true);
      case LossIntent.bestWorkers:
        return _ranking(q, worstFirst: false);
      case LossIntent.stageWise:
        return _stages(q);
      case LossIntent.bhuko:
        return _bhuko(q);
      case LossIntent.worstEntries:
        return _entries(q, ghat: true);
      case LossIntent.gain:
        return _entries(q, ghat: false);
      case LossIntent.check:
        return _check(q);
      case LossIntent.trend:
        return _trend(q);
      case LossIntent.compare:
        return _compare(q);
      case LossIntent.summary:
        return _summary(q);
      case LossIntent.voucherWise:
        return _voucherWise(q);
      case LossIntent.dayWise:
        return _trend(q, byDay: true);
      case LossIntent.ledger:
        return _ledger(q);
      case LossIntent.unknown:
        return _unknown(raw);
    }
  }

  AiAnswer helpAnswer() => const AiAnswer(
    text: 'You can ask about worker loss like this:\n'
        '• "worker wise loss", "who has the most loss", "loss in percent"\n'
        '• "Devang loss", "Dishank Patel casting loss"\n'
        '• "best worker", "stage wise loss", "worker wise bhuko"\n'
        '• "biggest loss", "gain entries", "check wrong entries"\n'
        '• "loss this month", "month wise loss", "this month vs last month loss"\n'
        '• "VV26-9", "buch 104", "voucher wise loss", "day wise loss"\n'
        '• 📒 Metal ledger: "metal ledger", "who has metal pending", '
        '"Sakir daily ledger", "Devang detailed ledger"\n'
        'Note: − = loss (shortage), + = gain. In the ledger, Dr = metal pending with the worker, Cr = worker got extra.',
    speech: 'You can ask about worker wise loss, one worker\'s loss, stage wise loss, bhuko, '
        'or wrong entries.',
    followUps: ['Worker wise loss', 'Voucher wise loss', 'Metal ledger worker wise', 'Check wrong entries'],
  );

  // =====================================================================
  //  PARSER
  // =====================================================================

  static const Set<String> _stop = {
    'the', 'and', 'nu', 'na', 'ni', 'no', 'ne', 'ma', 'thi', 'che', 'chhe', 'loss', 'ghat', 'bhuko', 'worker',
    'karigar', 'kaarigar', 'wise', 'ketlo', 'ketla', 'ketlu', 'batav', 'mane', 'aa', 'gaya', 'mahina',
    'mahine', 'divas', 'top', 'shu', 'kon', 'kono', 'kone', 'sauthi', 'vadhare', 'ochhu', 'saro', 'casting',
    'tree', 'cutting', 'jobwork', 'receive', 'stage', 'entry', 'check', 'galat', 'vadharo', 'motu', 'taka',
    'percent', 'buch', 'voucher', 'mkt', 'ledger', 'khatu', 'khata', 'metal', 'baki', 'pending', 'daily',
    'detailed', 'detail', 'day', 'vouchar', 'format', 'roj', 'date', 'tarikh', 'paase', 'pase', 'kona',
    'list', 'who', 'has', 'have', 'most', 'highest', 'best', 'biggest', 'worst', 'gain', 'gains', 'entries',
    'wrong', 'month', 'this', 'last', 'show', 'grams', 'gram', 'dust', 'with', 'for', 'all', 'by', 'in', 'of',
    'vs', 'compare', 'workers',
  };

  LossQuery parse(String raw) {
    final q = LossQuery();
    final t = AiText.normalize(raw);
    bool has(List<String> w) => AiText.has(t, w);

    // ---------- voucher / buch ----------
    final keys = {for (final e in all) e.voucherKey};
    final toks = t.split(' ');
    outer:
    for (var size = 1; size <= 3; size++) {
      for (var i = 0; i + size <= toks.length; i++) {
        final k = toks.sublist(i, i + size).join().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (k.length >= 4 && keys.contains(k)) {
          q.voucherKey = k;
          break outer;
        }
      }
    }
    final bm = RegExp(r'\bbuch\s*(no|number|nambar)?\s*([a-z]?\d+[a-z]?)\b').firstMatch(t);
    if (bm != null) q.buch = bm[2]!.toUpperCase();

    q.period = AiPeriodParser.parse(t);

    final lm = RegExp(r'\b(top|first|pehla|pela)\s*(\d+)').firstMatch(t);
    if (lm != null) q.limit = int.parse(lm[2]!);

    q.byPercent = has(['taka', 'percent', '%', 'ratio', 'pramane taka']);

    // ---------- 📒 metal ledger + format ----------
    q.ledger = has([
      'ledger', 'legder', 'lejar', 'khatu', 'khata', 'khatavahi', 'metal baki', 'baki metal', 'pending metal',
      'metal pending', 'paase baki', 'pase baki', 'paase ketlu metal', 'pase ketlu metal', 'dr cr', 'jama udhar',
      'udhar jama', 'metal hisab', 'opening', 'closing',
    ]);
    if (has(['detail', 'vigat', 'vigatvar', 'puru ledger', 'full ledger', 'entry wise', 'voucher wise ledger',
      'item wise', 'issue receive'])) {
      q.format = 'detailed';
    } else if (has(['daily', 'day wise', 'divas wise', 'roj', 'date wise', 'tarikh wise', 'dainik'])) {
      q.format = 'daily';
    }

    // ---------- stage ----------
    if (has(['casting'])) {
      q.stage = _stageLike('casting');
    } else if (has(['tree', 'cutting', 'zaad', 'jhad'])) {
      q.stage = _stageLike('tree');
    } else if (has(['jobwork', 'job work', 'jobvork'])) {
      q.stage = _stageLike('job');
    }

    // ---------- worker ----------
    final w = _matchNames(t, workers);
    if (w.length == 1) {
      q.worker = w.first;
    } else if (w.length > 1) {
      q.workerOptions = w;
    }

    final prev = _last;
    if (prev != null && q.worker == null && q.workerOptions.isEmpty && prev.worker != null &&
        has(['eno', 'eni', 'enu', 'ena', 'teno', 'aa worker', 'aa karigar', 'same'])) {
      q.worker = prev.worker;
    }

    q.intent = _intent(t, q);

    // "aa mahina vs gaya mahina" -> chalu mahina sathe
    if (q.intent == LossIntent.compare && has(['aa mahin', 'this month', 'is mahine'])) {
      final n = DateTime.now();
      q.period = AiPeriod(DateTime(n.year, n.month, 1), DateTime(n.year, n.month, n.day),
          'This month (${AiPeriodParser.monthName(n.month)})', PeriodKind.month);
    }
    return q;
  }

  String? _stageLike(String key) {
    for (final s in stages) {
      if (s.toLowerCase().contains(key)) return s;
    }
    return null;
  }

  LossIntent _intent(String t, LossQuery q) {
    bool has(List<String> w) => AiText.has(t, w);

    if (has(['help', 'madad', 'shu puchi', 'su puchi', 'what can'])) return LossIntent.help;
    if (q.ledger) return LossIntent.ledger;
    if (q.voucherKey != null || q.buch != null) return LossIntent.voucher;
    if (has(['voucher wise', 'vouchar wise', 'voucher mujab', 'voucher pramane', 'bill wise', 'badha voucher',
      'kaya voucher ma', 'voucher list'])) {
      return LossIntent.voucherWise;
    }
    if (has(['divas wise', 'day wise', 'daily', 'date wise', 'tarikh wise', 'roj nu', 'roj no', 'dainik',
      'divas mujab'])) {
      return LossIntent.dayWise;
    }
    if (has(['galat', 'check', 'mismatch', 'shanka', 'bhul', 'wrong', 'error', 'khotu', 'khoti', 'match nathi',
      'gadbad', 'vichitra'])) {
      return LossIntent.check;
    }
    if (has(['compare', 'sarkhamni', 'vs ', 'versus', 'vadhyu', 'ghatyu', 'karta ', 'farak', 'sudharo', 'sudharyu'])) {
      return LossIntent.compare;
    }
    if (has(['mahina wise', 'month wise', 'monthly', 'trend', 'mahine mahine'])) {
      return LossIntent.trend;
    }
    if (has(['bhuko', 'bhukko', 'dust', 'powder', 'dhul'])) return LossIntent.bhuko;
    if (has(['vadharo', 'vadharu', 'extra', 'gain', 'plus', 'vadhu aavyu', 'jyada aaya'])) return LossIntent.gain;
    if (has(['motu loss', 'moto loss', 'sauthi motu', 'sauthi moto', 'motu ghat', 'biggest', 'worst entry',
      'kai entry', 'kaya voucher', 'kayu buch', 'kaya buch'])) {
      return LossIntent.worstEntries;
    }
    if (has(['saro', 'saru', 'sari', 'best', 'ochhu loss', 'ochho loss', 'ochhi ghat', 'ochhu ghat', 'imandar',
      'good worker', 'sabse kam', 'least loss', 'lowest loss'])) {
      return LossIntent.bestWorkers;
    }
    if (q.worker != null) return LossIntent.workerDetail;
    if (has(['stage wise', 'stage', 'process wise', 'vibhag']) || (q.stage != null && !has(['worker', 'karigar']))) {
      return q.stage != null && !has(['stage wise']) ? LossIntent.summary : LossIntent.stageWise;
    }
    if (has(['worker', 'karigar', 'kaarigar', 'kono', 'kone', 'kon ', 'kiska', 'vadhare loss', 'vadhu loss',
      'vadhare ghat', 'vadhu ghat', 'ranking', 'most loss', 'highest loss', 'who has', 'workers'])) {
      return LossIntent.workerRanking;
    }
    if (q.workerOptions.isNotEmpty) return LossIntent.workerDetail;
    if (q.byPercent) return LossIntent.workerRanking; // "loss taka ma"
    if (q.period != null || has(['loss', 'ghat', 'nuksan', 'total', 'kul', 'summary', 'hisab', 'source', 'receive'])) {
      return LossIntent.summary;
    }
    return LossIntent.unknown;
  }

  /// Worker naam: pura naam pehla ("Dishank Patel"), nahi to shabd thi.
  List<String> _matchNames(String t, List<String> names) {
    final s = ' $t ';
    final full = names.where((n) {
      final ln = AiText.normalize(n);
      return ln.length >= 3 && s.contains(' $ln ');
    }).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (full.isNotEmpty) {
      final best = full.first;
      final same = full.where((n) => n.length == best.length).toList();
      return same.length == 1 ? [best] : same;
    }
    final tokens = t.split(' ').where((w) => w.length >= 3 && !_stop.contains(w)).toSet();
    if (tokens.isEmpty) return [];
    final scored = <String, int>{};
    for (final n in names) {
      final nt = AiText.normalize(n).split(' ').where((w) => w.length >= 3 && !_stop.contains(w));
      final hit = nt.where(tokens.contains).length;
      if (hit > 0) scored[n] = hit;
    }
    if (scored.isEmpty) return [];
    final top = scored.values.reduce(max);
    final best = scored.entries.where((e) => e.value == top).map((e) => e.key).toList()..sort();
    final exact = best.where((n) => AiText.normalize(n).split(' ').length == top).toList();
    if (exact.length == 1) return exact;
    return best;
  }

  // =====================================================================
  //  HELPERS
  // =====================================================================

  List<LossEntry> _base(LossQuery q, {AiPeriod? period}) {
    final p = period ?? q.period;
    return all.where((e) {
      if (p != null && !p.contains(e.date)) return false;
      if (q.worker != null && e.worker != q.worker) return false;
      if (q.stage != null && e.stage != q.stage) return false;
      return true;
    }).toList();
  }

  String _filterLabel(LossQuery q, {AiPeriod? period}) {
    final parts = <String>[(period ?? q.period)?.label ?? 'All entries'];
    if (q.worker != null) parts.add(q.worker!);
    if (q.stage != null) parts.add(q.stage!);
    return parts.join(' · ');
  }

  String _lt(double l) => LossEntry.lossText(l);
  String _pct(double v) => '${v >= 0 ? '' : '−'}${AiFmt.g(v.abs())}%';

  String _speakLoss(double l) {
    final g = AiFmt.g(l.abs()).replaceAll(',', '');
    if (l.abs() < 0.0005) return 'no loss';
    return l < 0 ? '$g grams loss' : '$g grams gain';
  }

  Map<String, List<LossEntry>> _groupBy(List<LossEntry> l, String Function(LossEntry) key) {
    final m = <String, List<LossEntry>>{};
    for (final e in l) {
      m.putIfAbsent(key(e), () => []).add(e);
    }
    return m;
  }

  /// Loss entry record — tap → te voucher nu ledger popup
  List<AiRecord> _rec(Iterable<LossEntry> l, [int n = 100]) =>
      l.take(n).map((e) => VoucherDetails.attachLedger(e.toRecord(), _voucherPopup(e.voucherNo))).toList();

  List<AiStat> _totStats(_Tot t) => [
    AiStat('Entries', '${t.rows}'),
    AiStat('Source', '${AiFmt.g(t.source)} g'),
    AiStat('Receive', '${AiFmt.g(t.receive)} g'),
    AiStat('Bhuko', '${AiFmt.g(t.bhuko)} g'),
    AiStat('Net', _lt(t.loss)),
    AiStat('Loss %', _pct(t.lossPct)),
    if (t.ghat > 0) AiStat('Total loss', '${AiFmt.g(t.ghat)} g'),
    if (t.vadharo > 0) AiStat('Total gain', '${AiFmt.g(t.vadharo)} g'),
    if (t.issues > 0) AiStat('⚠️ Check', '${t.issues} entries'),
  ];

  AiSection _workerSection(List<LossEntry> l, {bool worstFirst = true, bool byPercent = false, int n = 20, String? title}) {
    final g = _groupBy(l, (e) => e.worker).map((k, v) => MapEntry(k, _Tot.of(v))).entries.toList();
    // worstFirst: sauthi vadhu ghat (sauthi negative) pehla
    g.sort((a, b) {
      final x = byPercent ? -a.value.lossPct : a.value.loss;
      final y = byPercent ? -b.value.lossPct : b.value.loss;
      return worstFirst ? x.compareTo(y) : y.compareTo(x);
    });
    final maxAbs = g.isEmpty ? 1.0 : g.map((e) => byPercent ? e.value.lossPct.abs() : e.value.loss.abs()).reduce(max);
    return AiSection(
      title ?? 'By worker (${byPercent ? 'loss %' : 'net loss'})',
      g.take(n).map((e) {
        final t = e.value;
        return AiRow(
          '${t.loss < -0.0005 ? '🔴' : t.loss > 0.0005 ? '🟡' : '🟢'} ${e.key}',
          byPercent ? _pct(t.lossPct) : _lt(t.loss),
          sub: '${t.rows} entries · ${AiFmt.g(t.source)} → ${AiFmt.g(t.receive)} g · bhuko ${AiFmt.g(t.bhuko)} g'
              '${byPercent ? ' · ${_lt(t.loss)}' : ' · ${_pct(t.lossPct)}'}',
          bar: maxAbs == 0 ? 0 : (byPercent ? t.lossPct.abs() : t.loss.abs()) / maxAbs,
          askOnTap: '${e.key} loss',
        );
      }).toList(),
    );
  }

  AiSection _stageSection(List<LossEntry> l) {
    final g = _groupBy(l, (e) => e.stage).map((k, v) => MapEntry(k, _Tot.of(v))).entries.toList()
      ..sort((a, b) => a.value.loss.compareTo(b.value.loss));
    final maxAbs = g.isEmpty ? 1.0 : max(0.001, g.map((e) => e.value.loss.abs()).reduce(max));
    return AiSection(
      'By stage',
      g
          .map((e) => AiRow(e.key, _lt(e.value.loss),
          sub: '${e.value.rows} entries · ${AiFmt.g(e.value.source)} → ${AiFmt.g(e.value.receive)} g · '
              'bhuko ${AiFmt.g(e.value.bhuko)} g · ${_pct(e.value.lossPct)}',
          bar: e.value.loss.abs() / maxAbs,
          askOnTap: '${e.key} worker wise loss'))
          .toList(),
    );
  }

  AiAnswer _none(LossQuery q) => AiAnswer(
    text: '${_filterLabel(q)} — no entries found.',
    speech: 'No entries found.',
    filterLabel: _filterLabel(q),
    followUps: ['Worker wise loss', 'Month wise loss'],
  );

  // =====================================================================
  //  ANSWERS
  // =====================================================================

  AiAnswer _summary(LossQuery q) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final t = _Tot.of(l);
    final byW = _groupBy(l, (e) => e.worker).map((k, v) => MapEntry(k, _Tot.of(v))).entries.toList()
      ..sort((a, b) => a.value.loss.compareTo(b.value.loss));
    final worst = byW.first;

    var text = '${_filterLabel(q)}: ${t.rows} entries, ${t.workers.length} workers.\n'
        'Source ${AiFmt.g(t.source)} g → receive ${AiFmt.g(t.receive)} g, bhuko ${AiFmt.g(t.bhuko)} g. '
        'Net: ${_lt(t.loss)} (${_pct(t.lossPct)}).';
    if (worst.value.loss < 0) {
      text += ' Highest loss: ${worst.key} — ${AiFmt.g(-worst.value.loss)} g.';
    }
    if (t.issues > 0) text += '\n⚠️ ${t.issues} entries do not add up — ask "check wrong entries".';

    return AiAnswer(
      text: text,
      speech: '${_filterLabel(q)}: ${_speakLoss(t.loss)}. '
          '${worst.value.loss < 0 ? 'The highest loss is with ${worst.key}.' : ''}',
      stats: _totStats(t),
      sections: [
        _workerSection(l, n: 6, title: 'By worker (highest loss first)'),
        if (q.stage == null) _stageSection(l),
      ],
      items: _rec(l),
      itemsTitle: 'Entries (newest first)',
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: ['Worker wise loss in percent', 'Check wrong entries', 'Month wise loss'],
    );
  }

  AiAnswer _voucher(LossQuery q) {
    final l = all.where((e) {
      if (q.voucherKey != null && e.voucherKey != q.voucherKey) return false;
      if (q.buch != null && e.buchNo.toUpperCase() != q.buch) return false;
      return true;
    }).toList();
    if (l.isEmpty) {
      return AiAnswer(text: 'No entries found for ${q.buch != null ? 'buch ${q.buch}' : 'this voucher'}.');
    }
    final t = _Tot.of(l);
    final label = q.voucherKey != null ? l.first.voucherNo : 'Buch ${q.buch}';
    return AiAnswer(
      text: '$label: ${t.rows} entries, ${t.workers.join(', ')}.\n'
          'Source ${AiFmt.g(t.source)} → receive ${AiFmt.g(t.receive)} g, bhuko ${AiFmt.g(t.bhuko)} g. '
          'Net ${_lt(t.loss)}.${t.issues > 0 ? ' ⚠️ Please check ${t.issues} entries.' : ''}',
      speech: '$label: ${_speakLoss(t.loss)}.',
      stats: _totStats(t),
      sections: [_stageSection(l)],
      items: _rec(l),
      itemsTitle: 'Entries of $label',
    );
  }

  AiAnswer _worker(LossQuery q) {
    if (q.worker == null) {
      return AiAnswer(
        text: 'There are ${q.workerOptions.length} workers with this name. Which one?',
        speech: 'There are ${q.workerOptions.length} workers with this name. Which one?',
        followUps: q.workerOptions.take(6).map((w) => '$w loss').toList(),
      );
    }
    final name = q.worker!;
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final t = _Tot.of(l);

    // badha worker ni sarkhamni ma kyan che (ghat % pramane)
    final ranks = _groupBy(_base(LossQuery()..period = q.period..stage = q.stage), (e) => e.worker)
        .map((k, v) => MapEntry(k, _Tot.of(v)))
        .entries
        .where((e) => e.value.source > 0)
        .toList()
      ..sort((a, b) => b.value.lossPct.compareTo(a.value.lossPct));
    final rank = ranks.indexWhere((e) => e.key == name) + 1;
    final avgPct = _Tot.of(_base(LossQuery()..period = q.period..stage = q.stage)).lossPct;

    final worstE = [...l]..sort((a, b) => a.loss.compareTo(b.loss));
    final worst = worstE.first;

    // mahina mujab
    final mg = _groupBy(l, (e) => '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}');
    final mk = mg.keys.toList()..sort((a, b) => b.compareTo(a));
    final mt = {for (final k in mk) k: _Tot.of(mg[k]!)};
    final mMax = mt.values.isEmpty ? 1.0 : max(0.001, mt.values.map((x) => x.loss.abs()).reduce(max));

    final compareTxt = t.source == 0
        ? ''
        : t.lossPct > avgPct + 0.5
        ? ' Loss is HIGHER than the average (${_pct(avgPct)}). ⚠️'
        : t.lossPct < avgPct - 0.5
        ? ' Loss is lower than the average (${_pct(avgPct)}) — good work. 👍'
        : ' Same as the average.';

    return AiAnswer(
      text: '$name (${_filterLabel(q)}): ${t.rows} entries, source ${AiFmt.g(t.source)} g → '
          'receive ${AiFmt.g(t.receive)} g, bhuko ${AiFmt.g(t.bhuko)} g.\n'
          'Net ${_lt(t.loss)} (${_pct(t.lossPct)}).$compareTxt'
          '${rank > 0 ? ' Rank #$rank of ${ranks.length} by loss %.' : ''}'
          '${worst.loss < 0 ? ' Biggest loss: ${worst.voucherNo}${worst.buchNo != '-' ? ' (buch ${worst.buchNo})' : ''} — ${AiFmt.g(-worst.loss)} g.' : ''}'
          '${t.issues > 0 ? '\n⚠️ ${t.issues} entries do not add up.' : ''}',
      speech: '$name: ${_speakLoss(t.loss)} in ${t.rows} entries.',
      stats: [
        ..._totStats(t),
        if (rank > 0) AiStat('Rank (loss %)', '#$rank / ${ranks.length}'),
      ],
      sections: [
        if (q.stage == null) _stageSection(l),
        AiSection(
          'By month ($name)',
          mk.take(6).map((k) {
            final p = k.split('-');
            return AiRow('${AiPeriodParser.monthName(int.parse(p[1]))} ${p[0]}', _lt(mt[k]!.loss),
                sub: '${mt[k]!.rows} entries · ${AiFmt.g(mt[k]!.source)} g · ${_pct(mt[k]!.lossPct)}',
                bar: mt[k]!.loss.abs() / mMax);
          }).toList(),
        ),
        _voucherSection(l, n: 8, title: 'By voucher ($name)'),
      ],
      items: _rec(worstE),
      itemsTitle: 'Entries of $name (highest loss first)',
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: [
        '$name daily ledger',
        '$name detailed ledger',
        '$name voucher wise loss',
        '$name this month vs last month loss',
      ],
    );
  }

  AiAnswer _ranking(LossQuery q, {required bool worstFirst}) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final byPct = q.byPercent || !worstFirst;
    final g = _groupBy(l, (e) => e.worker)
        .map((k, v) => MapEntry(k, _Tot.of(v)))
        .entries
        .where((e) => e.value.source > 0 || !byPct)
        .toList()
      ..sort((a, b) {
        final x = byPct ? -a.value.lossPct : a.value.loss;
        final y = byPct ? -b.value.lossPct : b.value.loss;
        return worstFirst ? x.compareTo(y) : y.compareTo(x);
      });
    if (g.isEmpty) return _none(q);
    final f = g.first;

    final text = worstFirst
        ? 'Highest loss: ${f.key} — ${byPct ? _pct(f.value.lossPct) : _lt(f.value.loss)} '
        '(${f.value.rows} entries, ${AiFmt.g(f.value.source)} g source).'
        '${g.length > 1 ? ' Next: ${g[1].key} (${byPct ? _pct(g[1].value.lossPct) : _lt(g[1].value.loss)}).' : ''}'
        '${byPct ? '' : '\nTip: ask "loss in percent" — workers who handle more metal also show bigger gram loss.'}'
        : 'Best worker: ${f.key} — only ${_pct(f.value.lossPct)} loss '
        '(${f.value.rows} entries, on ${AiFmt.g(f.value.source)} g). '
        '${g.length > 1 ? 'Next: ${g[1].key} (${_pct(g[1].value.lossPct)}).' : ''}';

    return AiAnswer(
      text: text,
      speech: worstFirst ? 'The highest loss is with ${f.key}, ${_speakLoss(f.value.loss)}.' : 'The best worker is ${f.key}.',
      sections: [_workerSection(l, worstFirst: worstFirst, byPercent: byPct, n: q.limit ?? 20)],
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: [
        if (!byPct) 'Worker wise loss in percent',
        if (byPct && worstFirst) 'Worker wise loss in grams',
        worstFirst ? 'Best worker' : 'Who has the most loss?',
        'Stage wise loss',
      ],
    );
  }

  AiAnswer _stages(LossQuery q) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final t = _Tot.of(l);
    final g = _groupBy(l, (e) => e.stage).map((k, v) => MapEntry(k, _Tot.of(v))).entries.toList()
      ..sort((a, b) => a.value.loss.compareTo(b.value.loss));
    final w = g.first;
    return AiAnswer(
      text: 'Highest loss is in ${w.key} — ${_lt(w.value.loss)} (${_pct(w.value.lossPct)}, ${w.value.rows} entries). '
          'Total net ${_lt(t.loss)}.',
      speech: 'The highest loss is in ${w.key}, ${_speakLoss(w.value.loss)}.',
      sections: [_stageSection(l)],
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: g.map((e) => '${e.key} worker wise loss').take(3).toList(),
    );
  }

  AiAnswer _bhuko(LossQuery q) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final t = _Tot.of(l);
    final g = _groupBy(l, (e) => e.worker).map((k, v) => MapEntry(k, _Tot.of(v))).entries.where((e) => e.value.bhuko > 0).toList()
      ..sort((a, b) => b.value.bhuko.compareTo(a.value.bhuko));
    if (g.isEmpty) return AiAnswer(text: '${_filterLabel(q)}: no bhuko.', filterLabel: _filterLabel(q));
    final top = g.first.value.bhuko;
    final byPct = [...g]..sort((a, b) => b.value.bhukoPct.compareTo(a.value.bhukoPct));
    return AiAnswer(
      text: '${_filterLabel(q)}: total bhuko ${AiFmt.g(t.bhuko)} g (${AiFmt.g(t.bhukoPct)}% of source).\n'
          'Most: ${g.first.key} — ${AiFmt.g(g.first.value.bhuko)} g. '
          'Highest by percent: ${byPct.first.key} (${AiFmt.g(byPct.first.value.bhukoPct)}%).',
      speech: 'Total bhuko is ${AiFmt.g(t.bhuko).replaceAll(',', '')} grams. Most is from ${g.first.key}.',
      stats: [
        AiStat('Total bhuko', '${AiFmt.g(t.bhuko)} g'),
        AiStat('Bhuko %', '${AiFmt.g(t.bhukoPct)}%'),
        AiStat('Source', '${AiFmt.g(t.source)} g'),
      ],
      sections: [
        AiSection(
          'Bhuko by worker',
          g
              .map((e) => AiRow(e.key, '${AiFmt.g(e.value.bhuko)} g',
              sub: '${AiFmt.g(e.value.bhukoPct)}% · ${e.value.rows} entries · ${AiFmt.g(e.value.source)} g source',
              bar: e.value.bhuko / top,
              askOnTap: '${e.key} loss'))
              .toList(),
        ),
      ],
      filterLabel: _filterLabel(q),
      period: q.period,
    );
  }

  AiAnswer _entries(LossQuery q, {required bool ghat}) {
    final l = _base(q).where((e) => ghat ? e.loss < 0 : e.loss > 0).toList()
      ..sort((a, b) => ghat ? a.loss.compareTo(b.loss) : b.loss.compareTo(a.loss));
    if (l.isEmpty) {
      return AiAnswer(text: '${_filterLabel(q)}: no ${ghat ? 'loss' : 'gain'} entries.');
    }
    final f = l.first;
    final sum = l.fold(0.0, (s, e) => s + e.loss.abs());
    return AiAnswer(
      text: '${l.length} entries with ${ghat ? 'loss' : 'gain'}, total ${AiFmt.g(sum)} g.\n'
          'Biggest: ${f.worker} — ${f.voucherNo}${f.buchNo != '-' ? ' / buch ${f.buchNo}' : ''}, '
          '${f.stage}, ${AiFmt.g(f.loss.abs())} g (${AiFmt.date(f.date)}).'
          '${!ghat ? '\nA big gain can mean a wrong entry — ask "check wrong entries".' : ''}',
      speech: 'The biggest ${ghat ? 'loss' : 'gain'} is in an entry of ${f.worker}, ${AiFmt.g(f.loss.abs()).replaceAll(',', '')} grams.',
      items: _rec(l, q.limit ?? 50),
      itemsTitle: ghat ? 'Loss entries (biggest first)' : 'Gain entries',
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: ['Check wrong entries', 'Worker wise loss'],
    );
  }

  AiAnswer _check(LossQuery q) {
    final l = _base(q).where((e) => e.issue != null).toList()
      ..sort((a, b) => (b.loss - b.expectedLoss).abs().compareTo((a.loss - a.expectedLoss).abs()));
    if (l.isEmpty) {
      return AiAnswer(
          text: '${_filterLabel(q)} — all entries add up correctly. 👍', speech: 'All entries add up correctly.');
    }
    final byW = _groupBy(l, (e) => e.worker).entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    return AiAnswer(
      text: '${l.length} entries need checking — receive + bhuko − source does not match the loss, '
          'or the weight looks wrong (for example 5 g given and 530 g received).\n'
          'Most are from ${byW.first.key} (${byW.first.value.length}). Fix these so the report is correct.',
      speech: '${l.length} entries do not add up. Please check them.',
      sections: [
        AiSection(
          'By worker',
          byW.map((e) => AiRow(e.key, '${e.value.length} entries', askOnTap: '${e.key} loss')).toList(),
        ),
        AiSection(
          'What is wrong',
          l.take(12).map((e) => AiRow('${e.voucherNo}${e.buchNo != '-' ? ' · ${e.buchNo}' : ''} (${e.worker})',
              _lt(e.loss), sub: e.issue)).toList(),
        ),
      ],
      items: _rec(l),
      itemsTitle: 'Entries to check',
      filterLabel: _filterLabel(q),
    );
  }

  /// Mahina wise (default) athva divas wise ([byDay])
  AiAnswer _trend(LossQuery q, {bool byDay = false}) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    String two(int v) => v.toString().padLeft(2, '0');
    final g = _groupBy(
        l, (e) => byDay ? '${e.date.year}-${two(e.date.month)}-${two(e.date.day)}' : '${e.date.year}-${two(e.date.month)}');
    final keys = g.keys.toList()..sort((a, b) => b.compareTo(a));
    final tots = {for (final k in keys) k: _Tot.of(g[k]!)};
    final maxAbs = max(0.001, tots.values.map((t) => t.loss.abs()).reduce(max));
    String label(String k) {
      final p = k.split('-');
      return byDay ? '${p[2]}-${p[1]}-${p[0]}' : '${AiPeriodParser.monthName(int.parse(p[1]))} ${p[0]}';
    }

    // sauthi vadhu ghat (gram) vado divas / mahino
    final worst = keys.reduce((a, b) => tots[a]!.loss <= tots[b]!.loss ? a : b);
    final unit = byDay ? 'Day' : 'Month';
    final t = _Tot.of(l);
    return AiAnswer(
      text: '${_filterLabel(q)} — ${unit.toLowerCase()} wise loss (${keys.length} ${byDay ? 'days' : 'months'}).\n'
          'Highest loss: ${label(worst)} — ${_lt(tots[worst]!.loss)} (${_pct(tots[worst]!.lossPct)}). '
          'Total net ${_lt(t.loss)}.',
      speech: 'The highest loss was in ${label(worst)}, ${_speakLoss(tots[worst]!.loss)}.',
      stats: _totStats(t),
      sections: [
        AiSection(
          'By ${unit.toLowerCase()}',
          keys.map((k) {
            final x = tots[k]!;
            return AiRow(
              '${x.loss < -0.0005 ? '🔴' : x.loss > 0.0005 ? '🟡' : '🟢'} ${label(k)}',
              _lt(x.loss),
              sub: '${x.rows} entries · ${x.workers.length} workers · ${AiFmt.g(x.source)} → ${AiFmt.g(x.receive)} g'
                  ' · bhuko ${AiFmt.g(x.bhuko)} g · ${_pct(x.lossPct)}',
              bar: x.loss.abs() / maxAbs,
            );
          }).toList(),
        ),
      ],
      items: byDay ? _rec(l) : const [],
      itemsTitle: 'Entries (newest first)',
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: byDay
          ? ['Month wise loss', 'Voucher wise loss', 'Daily ledger']
          : ['This month vs last month loss', 'Day wise loss', 'Worker wise loss'],
    );
  }

  AiAnswer _compare(LossQuery q) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final cur = q.period ??
        AiPeriod(DateTime(today.year, today.month, 1), today,
            'This month (${AiPeriodParser.monthName(today.month)})', PeriodKind.month);
    final prev = cur.previous();
    final a = _Tot.of(_base(q, period: cur));
    final b = _Tot.of(_base(q, period: prev));
    if (a.rows == 0 && b.rows == 0) {
      return AiAnswer(text: 'No entries in ${cur.label} or ${prev.label}.', speech: 'No entries in either period.');
    }
    final better = a.lossPct < b.lossPct;

    // worker mujab farak (ghat %)
    final wa = _groupBy(_base(q, period: cur), (e) => e.worker).map((k, v) => MapEntry(k, _Tot.of(v)));
    final wb = _groupBy(_base(q, period: prev), (e) => e.worker).map((k, v) => MapEntry(k, _Tot.of(v)));
    final names = {...wa.keys, ...wb.keys}.toList();
    final rows = names.map((w) {
      final x = wa[w], y = wb[w];
      return AiRow(w, '${x == null ? '-' : _pct(x.lossPct)}  vs  ${y == null ? '-' : _pct(y.lossPct)}',
          sub: '${x == null ? 'no work now' : _lt(x.loss)}  ·  ${y == null ? 'no work before' : _lt(y.loss)}',
          askOnTap: '$w loss');
    }).toList();

    return AiAnswer(
      text: '${cur.label}: ${_lt(a.loss)} (${_pct(a.lossPct)}, ${a.rows} entries)\n'
          '${prev.label}: ${_lt(b.loss)} (${_pct(b.lossPct)}, ${b.rows} entries)\n'
          '${a.rows == 0 ? 'No entries yet in this period.' : better ? 'Loss went down — improving. 👍' : 'Loss went up. ⚠️'}',
      speech: a.rows == 0
          ? 'There are no entries yet in this period.'
          : better
          ? 'Loss is lower than the previous period.'
          : 'Loss is higher than the previous period.',
      stats: [
        AiStat('Loss % now', _pct(a.lossPct)),
        AiStat('Loss % before', _pct(b.lossPct)),
        AiStat('Source', '${AiFmt.g(a.source)} vs ${AiFmt.g(b.source)} g'),
        AiStat('Bhuko', '${AiFmt.g(a.bhuko)} vs ${AiFmt.g(b.bhuko)} g'),
      ],
      sections: [AiSection('Loss % by worker (now vs before)', rows)],
      filterLabel: _filterLabel(q, period: cur),
      period: cur,
      followUps: ['Month wise loss', 'Worker wise loss'],
    );
  }

  // =====================================================================
  //  🧾 VOUCHER WISE LOSS
  // =====================================================================

  AiSection _voucherSection(List<LossEntry> l, {int n = 30, String? title}) {
    final g = _groupBy(l, (e) => e.voucherNo).map((k, v) => MapEntry(k, _Tot.of(v))).entries.toList()
      ..sort((a, b) => a.value.loss.compareTo(b.value.loss));
    final maxAbs = g.isEmpty ? 1.0 : max(0.001, g.map((e) => e.value.loss.abs()).reduce(max));
    return AiSection(
      title ?? 'By voucher (highest loss first)',
      g.take(n).map((e) {
        final t = e.value;
        return AiRow(
          '${t.loss < -0.0005 ? '🔴' : t.loss > 0.0005 ? '🟡' : '🟢'} ${e.key}',
          _lt(t.loss),
          sub: '${t.workers.join(', ')} · ${t.rows} entries · ${AiFmt.g(t.source)} → ${AiFmt.g(t.receive)} g'
              ' · bhuko ${AiFmt.g(t.bhuko)} g · ${_pct(t.lossPct)}',
          bar: t.loss.abs() / maxAbs,
          askOnTap: e.key,
        );
      }).toList(),
    );
  }

  AiAnswer _voucherWise(LossQuery q) {
    final l = _base(q);
    if (l.isEmpty) return _none(q);
    final groups = _groupBy(l, (e) => e.voucherNo);
    final list = groups.entries.map((e) => MapEntry(e.key, _Tot.of(e.value))).toList()
      ..sort((a, b) => a.value.loss.compareTo(b.value.loss));
    final t = _Tot.of(l);
    final worst = list.first;

    // darek voucher no ek record (tap → details)
    final records = list.take(q.limit ?? 100).map((e) {
      final entries = groups[e.key]!..sort((a, b) => b.date.compareTo(a.date));
      final x = e.value;
      final stages = entries.map((z) => z.stage).toSet().join(', ');
      return VoucherDetails.attachLedger(AiRecord(
        title: e.key,
        subtitle: '${x.workers.join(', ')} · ${AiFmt.date(entries.first.date)}',
        value: '${AiFmt.g(x.source)} → ${AiFmt.g(x.receive)} g',
        badge: _lt(x.loss),
        badgeGood: x.loss >= 0,
        details: [
          AiStat('Voucher', e.key),
          AiStat('Date', AiFmt.date(entries.first.date)),
          AiStat('Worker', x.workers.join(', ')),
          AiStat('Stage', stages),
          AiStat('Entries', '${x.rows}'),
          AiStat('Source', '${AiFmt.g(x.source)} g'),
          AiStat('Receive', '${AiFmt.g(x.receive)} g'),
          AiStat('Bhuko', '${AiFmt.g(x.bhuko)} g'),
          AiStat('Loss', _lt(x.loss)),
          AiStat('Loss %', _pct(x.lossPct)),
          if (x.issues > 0) AiStat('⚠️ Check', '${x.issues} entries'),
        ],
      ), _voucherPopup(e.key));
    }).toList();

    return AiAnswer(
      text: '${_filterLabel(q)}: ${list.length} vouchers, ${t.rows} entries. Total net ${_lt(t.loss)} (${_pct(t.lossPct)}).\n'
          '${worst.value.loss < 0 ? 'Highest loss: ${worst.key} — ${AiFmt.g(-worst.value.loss)} g '
          '(${worst.value.workers.join(', ')}).' : 'No voucher has a loss.'}',
      speech: '${list.length} vouchers. ${worst.value.loss < 0 ? 'The highest loss is in ${worst.key}, ${_speakLoss(worst.value.loss)}.' : ''}',
      stats: [AiStat('Vouchers', '${list.length}'), ..._totStats(t)],
      sections: [_voucherSection(l, n: q.limit ?? 30)],
      items: records,
      itemsTitle: 'Vouchers (highest loss first)',
      filterLabel: _filterLabel(q),
      period: q.period,
      followUps: ['Worker wise loss', 'Day wise loss', 'Detailed ledger'],
    );
  }

  // =====================================================================
  //  📒 METAL LEDGER  (format: daily | detailed)
  //  Dr (+) = worker paase metal baaki,  Cr (−) = vadhu malyu
  // =====================================================================

  String _fmtLabel(String f) => ledgerFormats[f] ?? f;

  _LedgerView _view(LedgerGroup g, LossQuery q) {
    final p = q.period;
    final rows = g.rows.where((r) {
      if (p != null && !p.contains(r.date)) return false;
      if (q.voucherKey != null && r.voucherKey != q.voucherKey) return false;
      return true;
    }).toList();

    double opening = g.opening;
    double closing = g.closing;
    if (p != null) {
      // period pehla ni chhelli row nu balance = opening
      final before = g.rows.where((r) => r.date.isBefore(p.from)).toList();
      opening = before.isEmpty ? g.opening : before.last.balance;
      final upto = g.rows.where((r) => !r.date.isAfter(p.to)).toList();
      closing = upto.isEmpty ? g.opening : upto.last.balance;
    }
    return _LedgerView(
      g,
      rows,
      opening,
      rows.fold(0.0, (a, r) => a + r.debit),
      rows.fold(0.0, (a, r) => a + r.credit),
      closing,
    );
  }

  AiAnswer _ledger(LossQuery q) {
    final groups = LedgerStore.of(q.format);
    if (groups == null) {
      return AiAnswer(
        text: 'Could not load the metal ledger (${_fmtLabel(q.format)}).\n'
            'Tap ⋮ → "Refresh data" at the top and try again.',
        speech: 'Could not load the metal ledger.',
      );
    }
    if (q.worker == null && q.workerOptions.isNotEmpty) {
      return AiAnswer(
        text: 'There are ${q.workerOptions.length} workers with this name. Whose ledger?',
        speech: 'Which worker?',
        followUps: q.workerOptions.take(6).map((w) => '$w ${q.format} ledger').toList(),
      );
    }

    final views = groups
        .where((g) => q.worker == null || g.worker == q.worker)
        .map((g) => _view(g, q))
        .where((v) =>
    v.rows.isNotEmpty || (q.voucherKey == null && (v.opening.abs() > 0.0005 || v.closing.abs() > 0.0005)))
        .toList();

    final label = '${q.period?.label ?? 'All time'} · ${_fmtLabel(q.format)}'
        '${q.worker != null ? ' · ${q.worker}' : ''}${q.voucherKey != null ? ' · ${q.voucherKey}' : ''}';

    if (views.isEmpty) {
      return AiAnswer(
        text: '$label — no ledger entries.',
        speech: 'No ledger entries.',
        filterLabel: label,
        followUps: ['Metal ledger worker wise', 'Worker wise loss'],
      );
    }
    return q.worker != null ? _ledgerOne(q, views, label) : _ledgerAll(q, views, label);
  }

  /// Badha worker: kona paase ketlu metal baaki (closing)
  AiAnswer _ledgerAll(LossQuery q, List<_LedgerView> views, String label) {
    views.sort((a, b) => b.closing.compareTo(a.closing)); // vadhu baki pehla
    final multiMetal = views.map((v) => v.g.metal).toSet().length > 1;
    final pendingViews = views.where((v) => v.closing > 0.0005).toList();
    final pending = pendingViews.fold(0.0, (a, v) => a + v.closing);
    final excess = views.where((v) => v.closing < -0.0005).fold(0.0, (a, v) => a + v.closing.abs());
    final dr = views.fold(0.0, (a, v) => a + v.debit);
    final cr = views.fold(0.0, (a, v) => a + v.credit);
    final maxAbs = max(0.001, views.map((v) => v.closing.abs()).reduce(max));
    final top = views.first;
    String name(_LedgerView v) => '${v.g.worker}${multiMetal ? ' · ${v.g.metal}' : ''}';

    final sections = <AiSection>[
      AiSection(
        'By worker (closing — most pending first)',
        views.map((v) => AiRow(
          '${v.closing > 0.0005 ? '🔴' : v.closing < -0.0005 ? '🔵' : '🟢'} ${name(v)}',
          ledgerBal(v.closing),
          sub: 'Opening ${ledgerBal(v.opening)} · Dr ${AiFmt.g(v.debit)} · Cr ${AiFmt.g(v.credit)}'
              ' · ${v.rows.length} entries',
          bar: v.closing.abs() / maxAbs,
          askOnTap: '${v.g.worker} ${q.format} ledger',
        )).toList(),
      ),
    ];

    // Detailed: voucher mujab (badha worker)
    if (q.format == 'detailed') {
      sections.add(_ledgerVoucherSection([for (final v in views) ...v.rows], withWorker: views));
    }

    return AiAnswer(
      text: '$label: ${views.length} workers.\n'
          '${pendingViews.isNotEmpty ? '${pendingViews.length} workers have ${AiFmt.g(pending)} g metal pending (Dr). '
          'Most: ${name(top)} — ${ledgerBal(top.closing)}.' : 'No worker has metal pending. 👍'}'
          '${excess > 0.0005 ? ' ${AiFmt.g(excess)} g given extra (Cr).' : ''}',
      speech: pendingViews.isNotEmpty
          ? '${pendingViews.length} workers have ${AiFmt.g(pending).replaceAll(',', '')} grams of metal pending. '
          'The most is with ${top.g.worker}.'
          : 'No worker has metal pending.',
      stats: [
        AiStat('Workers', '${views.length}'),
        AiStat('Pending (Dr)', '${AiFmt.g(pending)} g'),
        if (excess > 0.0005) AiStat('Extra (Cr)', '${AiFmt.g(excess)} g'),
        AiStat('Debit', '${AiFmt.g(dr)} g'),
        AiStat('Credit', '${AiFmt.g(cr)} g'),
        AiStat('Format', _fmtLabel(q.format)),
      ],
      sections: sections,
      items: views.map((v) => VoucherDetails.attachLedger(AiRecord(
        title: name(v),
        subtitle: '${_fmtLabel(q.format)} · ${v.rows.length} entries',
        value: ledgerBal(v.closing),
        badge: v.closing > 0.0005 ? 'Pending' : v.closing < -0.0005 ? 'Extra' : 'Clear',
        badgeGood: v.closing <= 0.0005,
        details: [
          AiStat('Worker', v.g.worker),
          AiStat('Metal', v.g.metal),
          AiStat('Opening', ledgerBal(v.opening)),
          AiStat('Debit', '${AiFmt.g(v.debit)} g'),
          AiStat('Credit', '${AiFmt.g(v.credit)} g'),
          AiStat('Closing', ledgerBal(v.closing)),
          AiStat('Entries', '${v.rows.length}'),
        ],
      ), _workerPopup(v.g.worker, q.format, q.period))).toList(),
      itemsTitle: 'Worker ledger',
      filterLabel: label,
      period: q.period,
      followUps: [
        q.format == 'daily' ? 'Detailed ledger worker wise' : 'Daily ledger worker wise',
        if (pendingViews.isNotEmpty) '${top.g.worker} ${q.format} ledger',
        'Worker wise loss',
      ],
    );
  }

  /// Ek worker nu ledger (daily → divas mujab, detailed → voucher / entry mujab)
  AiAnswer _ledgerOne(LossQuery q, List<_LedgerView> views, String label) {
    final name = q.worker!;
    final daily = q.format == 'daily';
    final rows = [for (final v in views) ...v.rows]..sort((a, b) => b.date.compareTo(a.date));
    final opening = views.fold(0.0, (a, v) => a + v.opening);
    final closing = views.fold(0.0, (a, v) => a + v.closing);
    final dr = views.fold(0.0, (a, v) => a + v.debit);
    final cr = views.fold(0.0, (a, v) => a + v.credit);
    final multiMetal = views.length > 1;

    final sections = <AiSection>[
      if (multiMetal)
        AiSection(
          'By metal',
          views.map((v) => AiRow(v.g.metal, ledgerBal(v.closing),
              sub: 'Opening ${ledgerBal(v.opening)} · Dr ${AiFmt.g(v.debit)} · Cr ${AiFmt.g(v.credit)}')).toList(),
        ),
      if (daily)
        AiSection(
          'By day',
          rows.map((r) => AiRow(
            AiFmt.date(r.date),
            ledgerBal(r.balance),
            sub: 'Dr ${AiFmt.g(r.debit)} · Cr ${AiFmt.g(r.credit)}${r.item != '-' ? ' · ${r.item}' : ''}',
          )).toList(),
        )
      else
        _ledgerVoucherSection(rows),
    ];

    return AiAnswer(
      text: '$name — $label\n'
          'Opening ${ledgerBal(opening)} → Debit ${AiFmt.g(dr)} g, Credit ${AiFmt.g(cr)} g → '
          'Closing ${ledgerBal(closing)}. '
          '${closing > 0.0005 ? '$name has ${AiFmt.g(closing)} g metal pending.' : closing < -0.0005 ? '$name got ${AiFmt.g(-closing)} g extra.' : 'Account is clear. 👍'}',
      speech: closing > 0.0005
          ? '$name has ${AiFmt.g(closing).replaceAll(',', '')} grams of metal pending.'
          : closing < -0.0005
          ? '$name got ${AiFmt.g(-closing).replaceAll(',', '')} grams extra.'
          : '$name\'s account is clear.',
      stats: [
        AiStat('Opening', ledgerBal(opening)),
        AiStat('Debit', '${AiFmt.g(dr)} g'),
        AiStat('Credit', '${AiFmt.g(cr)} g'),
        AiStat('Closing', ledgerBal(closing)),
        AiStat('Entries', '${rows.length}'),
        AiStat('Format', _fmtLabel(q.format)),
      ],
      sections: sections,
      items: rows
          .map((r) => VoucherDetails.attachLedger(_ledgerRecord(r, name, daily), _workerPopup(name, q.format, q.period)))
          .toList(),
      itemsTitle: daily ? 'Days (newest first)' : 'Entries (newest first)',
      filterLabel: label,
      period: q.period,
      followUps: [
        daily ? '$name detailed ledger' : '$name daily ledger',
        '$name loss',
        '$name voucher wise loss',
        'Metal ledger worker wise',
      ],
    );
  }

  /// Detailed ledger rows → voucher mujab Dr / Cr
  AiSection _ledgerVoucherSection(List<LedgerRow> rows, {List<_LedgerView>? withWorker}) {
    final byV = <String, List<LedgerRow>>{};
    for (final r in rows) {
      byV.putIfAbsent(r.voucherNo, () => []).add(r);
    }
    // voucher → worker naam (badha worker vala ledger mate)
    final who = <String, Set<String>>{};
    for (final v in withWorker ?? const <_LedgerView>[]) {
      for (final r in v.rows) {
        who.putIfAbsent(r.voucherNo, () => {}).add(v.g.worker);
      }
    }
    final list = byV.entries.toList()
      ..sort((a, b) {
        final da = a.value.map((r) => r.date).reduce((x, y) => x.isAfter(y) ? x : y);
        final db = b.value.map((r) => r.date).reduce((x, y) => x.isAfter(y) ? x : y);
        return db.compareTo(da);
      });
    return AiSection(
      'By voucher (newest first)',
      list.map((e) {
        final dr = e.value.fold(0.0, (a, r) => a + r.debit);
        final cr = e.value.fold(0.0, (a, r) => a + r.credit);
        final types = e.value.map((r) => r.type).where((t) => t.isNotEmpty).toSet().join(' / ');
        final items = e.value.map((r) => r.item).where((t) => t != '-').toSet().take(3).join(', ');
        final w = who[e.key];
        return AiRow(
          e.key,
          'Dr ${AiFmt.g(dr)} · Cr ${AiFmt.g(cr)}',
          sub: [
            AiFmt.date(e.value.first.date),
            if (w != null) w.join(', '),
            if (types.isNotEmpty) types,
            if (items.isNotEmpty) items,
            'net ${ledgerBal(dr - cr)}',
          ].join(' · '),
          askOnTap: e.key == '-' ? null : '${e.key} ledger',
        );
      }).toList(),
    );
  }

  // =====================================================================
  //  📒 LEDGER POPUP (web na Worker Metal Ledger jevu)
  // =====================================================================
  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _dmy(DateTime d) => '${_two(d.day)}-${_two(d.month)}-${d.year}';
  static String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  String _particulars(LedgerRow r, String format) {
    if (format == 'daily') return r.item != '-' ? r.item : 'Daily total';
    return [r.voucherNo, r.type, r.item].where((x) => x.isNotEmpty && x != '-').join(' · ');
  }

  LedgerSheet _sheet(_LedgerView v, String format) => LedgerSheet(
    title: '${v.g.worker} — ${v.g.metal}',
    opening: v.opening,
    closing: v.closing,
    rows: v.rows
        .map((r) => LedgerSheetRow(
      date: _dmy(r.date),
      particulars: _particulars(r, format),
      debit: r.debit,
      credit: r.credit,
      balance: r.balance,
    ))
        .toList(),
  );

  /// Ek worker nu ledger — darek metal ni alag table
  LedgerPopup _workerPopup(String worker, String format, AiPeriod? period) {
    final groups = (LedgerStore.of(format) ?? const <LedgerGroup>[]).where((g) => g.worker == worker).toList();
    final ids = groups.map((g) => g.workerId).whereType<int>();
    final wid = ids.isEmpty ? null : ids.first;
    final fq = LossQuery()
      ..period = period
      ..format = format;
    final from = period?.from ?? DateTime(2020, 1, 1);
    final to = period?.to ?? DateTime.now();

    return LedgerPopup(
      title: 'Worker Ledger — $worker',
      subtitle: '${period?.label ?? 'All time'} · ${_fmtLabel(format)}',
      build: () => groups.map((g) => _sheet(_view(g, fq), format)).toList(),
      exportUrl: wid == null
          ? null
          : (type) => '${ApiConstants.worker_loss_report}/export/$type?mode=ledger&format=$format'
          '&worker_id=$wid&from_date=${_ymd(from)}&to_date=${_ymd(to)}',
    );
  }

  /// Ek voucher nu ledger: Detailed ledger ma male to e,
  /// nahi to loss entry (Source = Debit, Receive + Bhuko = Credit)
  LedgerPopup _voucherPopup(String voucherNo) {
    final key = voucherNo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return LedgerPopup(
      title: 'Voucher Ledger — $voucherNo',
      subtitle: 'By worker',
      build: () => _voucherSheets(key, voucherNo),
    );
  }

  List<LedgerSheet> _voucherSheets(String key, String voucherNo) {
    final sheets = <LedgerSheet>[];

    // 1) Detailed ledger ma aa voucher ni row
    for (final g in LedgerStore.of('detailed') ?? const <LedgerGroup>[]) {
      final idx = <int>[
        for (var i = 0; i < g.rows.length; i++)
          if (g.rows[i].voucherKey == key) i,
      ];
      if (idx.isEmpty) continue;
      final opening = idx.first == 0 ? g.opening : g.rows[idx.first - 1].balance;
      sheets.add(LedgerSheet(
        title: '${g.worker} — ${g.metal}',
        opening: opening,
        rows: idx
            .map((i) => g.rows[i])
            .map((r) => LedgerSheetRow(
          date: _dmy(r.date),
          particulars: _particulars(r, 'detailed'),
          debit: r.debit,
          credit: r.credit,
        ))
            .toList(),
      ));
    }
    if (sheets.isNotEmpty) return sheets;

    // 2) Ledger ma nathi → loss entry thi e j look
    final entries = all.where((e) => e.voucherKey == key).toList()..sort((a, b) => a.date.compareTo(b.date));
    final byW = _groupBy(entries, (e) => e.worker);
    for (final w in byW.entries) {
      sheets.add(LedgerSheet(
        title: '${w.key} — $voucherNo',
        debitLabel: 'Debit — Issued (Source)',
        creditLabel: 'Credit — Received + Bhuko',
        netLabel: 'Net (Dr = loss, Cr = gain)',
        openingLabel: 'Opening',
        footerLabel: 'Voucher totals / Net',
        rows: w.value
            .map((e) => LedgerSheetRow(
          date: _dmy(e.date),
          particulars: [
            e.stage,
            if (e.buchNo != '-') 'Buch ${e.buchNo}',
            'Receive ${AiFmt.g(e.receive)}',
            if (e.bhuko > 0) 'Bhuko ${AiFmt.g(e.bhuko)}',
          ].join(' · '),
          debit: e.source,
          credit: e.receive + e.bhuko,
        ))
            .toList(),
      ));
    }
    return sheets;
  }

  AiRecord _ledgerRecord(LedgerRow r, String worker, bool daily) => AiRecord(
    title: daily ? AiFmt.date(r.date) : r.voucherNo,
    subtitle: daily
        ? '${r.item != '-' ? '${r.item} · ' : ''}Dr ${AiFmt.g(r.debit)} · Cr ${AiFmt.g(r.credit)}'
        : '${r.type.isNotEmpty ? '${r.type} · ' : ''}${r.item} · ${AiFmt.date(r.date)}',
    value: ledgerBal(r.balance),
    badge: r.debit > 0 ? 'Dr ${AiFmt.g(r.debit)} g' : 'Cr ${AiFmt.g(r.credit)} g',
    badgeGood: r.debit <= 0,
    details: [
      AiStat('Worker', worker),
      AiStat('Date', AiFmt.date(r.date)),
      if (!daily) AiStat('Voucher', r.voucherNo),
      if (r.type.isNotEmpty) AiStat('Type', r.type),
      if (r.item != '-') AiStat(daily ? 'Particulars' : 'Item', r.item),
      AiStat('Debit', '${AiFmt.g(r.debit)} g'),
      AiStat('Credit', '${AiFmt.g(r.credit)} g'),
      AiStat('Balance', ledgerBal(r.balance)),
    ],
  );

  AiAnswer _unknown(String raw) => AiAnswer(
    text: 'Sorry, I did not understand "$raw" for worker loss. Try asking:',
    speech: 'Sorry, I did not understand. Please ask again.',
    followUps: suggestions.take(6).toList(),
  );
}

/// Ek worker+metal nu ledger, period / voucher filter pachhi
class _LedgerView {
  final LedgerGroup g;
  final List<LedgerRow> rows;
  final double opening;
  final double debit;
  final double credit;
  final double closing;
  _LedgerView(this.g, this.rows, this.opening, this.debit, this.credit, this.closing);
}