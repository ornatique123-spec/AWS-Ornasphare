import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../approval/approval_ai_engine.dart';
import '../approval/approval_ai_repository.dart';
import '../sales/sales_ai_engine.dart';
import '../sales/sales_ai_repository.dart';
import '../stock_ai_engine.dart';
import '../stock_ai_repository.dart';
import '../workerloss/worker_loss_engine.dart';
import '../workerloss/worker_loss_repository.dart';
import 'ai_core.dart';

/// =======================================================================
///  ASK AI MODULES
///  Navo module (Approval, Approval Return, Purchase...) umervo hoy to:
///   1. aa class extend karo (load + ask + relevance)
///   2. niche `AiModules.create()` ma list ma umero
///  Screen, voice, chips, auto-routing badhu automatic chalse.
/// =======================================================================
abstract class AiModule {
  String get id;
  String get title;
  IconData get icon;

  /// Drawer / screen ma batavvu ke nahi (permission)
  bool allowed(List<String> permissions) => true;

  List<String> get suggestions;
  bool get isLoaded;

  /// "370 piece" / "101 bill" jevu nanu status
  String get statusLine;

  Future<void> load({bool force = false, void Function(int done, int total)? onProgress});

  AiAnswer welcome();
  AiAnswer ask(String question);

  /// Sawal aa module no ketlo lage che (auto-routing mate). 0 = bilkul nahi.
  int relevance(String normalizedText);
}

class AiModules {
  static List<AiModule> create() => [
    StockAiModule(),
    SalesAiModule(),
    ApprovalAiModule(),
    WorkerLossAiModule(),
    // ApprovalReturnAiModule(),  // 👉 Approval Return no response mokalo etle umeri daish
  ];
}

// -----------------------------------------------------------------------
//  STOCK
// -----------------------------------------------------------------------
class StockAiModule extends AiModule {
  StockAiEngine? _engine;

  @override
  String get id => 'stock';
  @override
  String get title => 'Stock';
  @override
  IconData get icon => FontAwesomeIcons.gem;

  @override
  bool allowed(List<String> p) => p.contains('stock-gallery-view');

  @override
  List<String> get suggestions => StockAiEngine.suggestions;
  @override
  bool get isLoaded => _engine != null;
  @override
  String get statusLine => _engine == null ? 'Load thay che…' : '${_engine!.all.length} piece';

  @override
  Future<void> load({bool force = false, void Function(int, int)? onProgress}) async {
    final items = await StockAiRepository.loadAll(force: force, onProgress: onProgress);
    _engine = StockAiEngine(items);
  }

  @override
  AiAnswer welcome() => AiAnswer(
    text: '💎 Stock: ${_engine?.all.length ?? 0} piece load thaya. Weight range, juno stock, '
        'best seller, reorder — kai pan puchho.',
    speech: 'Stock tayar che. Shu jovu che?',
    followUps: StockAiEngine.suggestions.take(4).toList(),
  );

  @override
  AiAnswer ask(String q) => _engine?.ask(q) ?? const AiAnswer(text: 'Stock data haju load thay che…');

  @override
  int relevance(String t) {
    var s = AiText.score(t, [
      'stock', 'piece', 'label', 'photo', 'image', 'juno', 'junu', 'juna', 'reorder', 'padel', 'padela',
      'hajar', 'in stock', 'available', 'stone', 'nang', 'bhare', 'halk', 'item wise', 'category',
      'sell-through', 'na vechay', 'nathi vechay', 'banavvu',
    ]);
    if (_engine != null) {
      for (final n in _engine!.itemNames) {
        if (t.contains(n.toLowerCase())) s += 2;
      }
    }
    return s;
  }
}

// -----------------------------------------------------------------------
//  SALES
// -----------------------------------------------------------------------
class SalesAiModule extends AiModule {
  SalesAiEngine? _engine;

  @override
  String get id => 'sales';
  @override
  String get title => 'Sales';
  @override
  IconData get icon => FontAwesomeIcons.receipt;

  @override
  bool allowed(List<String> p) => p.any((e) => e.startsWith('report-sales-summary-'));

  @override
  List<String> get suggestions => SalesAiEngine.suggestions;
  @override
  bool get isLoaded => _engine != null;
  @override
  String get statusLine => _engine == null ? 'Load thay che…' : '${_engine!.all.length} bill';

  @override
  Future<void> load({bool force = false, void Function(int, int)? onProgress}) async {
    onProgress?.call(0, 1);
    final list = await SalesAiRepository.loadAll(force: force);
    _engine = SalesAiEngine(list, loadedFrom: SalesAiRepository.loadedFrom);
    onProgress?.call(1, 1);
  }

  @override
  AiAnswer welcome() {
    final e = _engine;
    if (e == null || e.all.isEmpty) {
      return const AiAnswer(text: '🧾 Sales: koi bill malyo nathi.');
    }
    final n = DateTime.now();
    final todayList = e.all.where((v) => v.date.year == n.year && v.date.month == n.month && v.date.day == n.day);
    final monthList = e.all.where((v) => v.date.year == n.year && v.date.month == n.month).toList();
    final net = monthList.fold(0.0, (a, v) => a + v.net);
    final amt = monthList.fold(0.0, (a, v) => a + v.netTotal);
    return AiAnswer(
      text: '🧾 Sales: ${e.all.length} bill load thaya. Aaje ${todayList.length} bill; '
          'aa mahine ${monthList.length} bill, ${AiFmt.g(net)} g, ${AiFmt.inr(amt)}.',
      speech: 'Sales tayar che. Aa mahine ${monthList.length} bill thaya.',
      followUps: SalesAiEngine.suggestions.take(4).toList(),
    );
  }

  @override
  AiAnswer ask(String q) => _engine?.ask(q) ?? const AiAnswer(text: 'Sales data haju load thay che…');

  @override
  int relevance(String t) {
    var s = AiText.score(t, [
      'vechan', 'sale', 'bill', 'voucher', 'customer', 'grahak', 'party', 'amount', 'rupiya', 'labour',
      'majuri', 'fine', 'aaje', 'kale ', 'mahina nu', 'mahine', 'athvadiy', 'kharid', 'staff', 'banavya',
      'purity', 'waste', 'compare', 'sarkhamni', 'vs ', 'trend', 'mahina wise', 'aavya nathi', 'nathi aavya',
      'motu bill', 'hisab', 'dhandho', 'business',
    ]);
    if (_engine != null) {
      for (final c in _engine!.customers) {
        final n = AiText.normalize(c);
        if (n.length >= 4 && ' $t '.contains(' $n ')) s += 3;
      }
      if (RegExp(r'\b(pt|sl)\s?-?\s?(sl)?\s?-?\s?\d{3,}').hasMatch(t)) s += 3;
    }
    return s;
  }
}

// -----------------------------------------------------------------------
//  APPROVAL (outstanding — customer pase gayelo maal)
// -----------------------------------------------------------------------
class ApprovalAiModule extends AiModule {
  ApprovalAiEngine? _engine;

  @override
  String get id => 'approval';
  @override
  String get title => 'Approval';
  @override
  IconData get icon => FontAwesomeIcons.handshake;

  @override
  bool allowed(List<String> p) => p.any((e) => e.startsWith('report-approval-outstanding-'));

  @override
  List<String> get suggestions => ApprovalAiEngine.suggestions;
  @override
  bool get isLoaded => _engine != null;
  @override
  String get statusLine => _engine == null ? 'Load thay che…' : '${_engine!.live.length} baki approval';

  @override
  Future<void> load({bool force = false, void Function(int, int)? onProgress}) async {
    onProgress?.call(0, 1);
    final list = await ApprovalAiRepository.loadAll(force: force);
    _engine = ApprovalAiEngine(list);
    onProgress?.call(1, 1);
  }

  @override
  AiAnswer welcome() {
    final e = _engine;
    if (e == null) return const AiAnswer(text: 'Approval data haju load thay che…');
    final l = e.live;
    if (l.isEmpty) return const AiAnswer(text: '🤝 Approval: koi maal baki nathi. 👍');
    final net = l.fold(0.0, (a, x) => a + x.net);
    final pcs = l.fold(0, (a, x) => a + x.pendingPcs);
    final old = l.where((x) => x.ageDays > 30).length;
    final cust = l.map((x) => x.customer).toSet().length;
    return AiAnswer(
      text: '🤝 Approval: ${l.length} approval baki — $cust customer pase $pcs piece, ${AiFmt.g(net)} g.'
          '${old > 0 ? ' $old approval 30 divas thi juna che.' : ''}',
      speech: '${l.length} approval baki che, $cust customer pase.',
      followUps: ApprovalAiEngine.suggestions.take(4).toList(),
    );
  }

  @override
  AiAnswer ask(String q) => _engine?.ask(q) ?? const AiAnswer(text: 'Approval data haju load thay che…');

  @override
  int relevance(String t) {
    // "approval" shabd customer na naam ma pan che (Approval Tester), etle mazboot
    // shabdo ne 3 point, saamanya ne 1.
    var s = 3 *
        AiText.score(t, [
          'approval ma', 'approval na', 'approval no', 'approval nu', 'approval ketla', 'approval baki',
          'approval che', 'baki approval', 'pending approval', 'open approval', 'partial approval',
          'juna approval', 'approval batav', 'approval list', 'approval summary', 'khali approval',
          'motu approval', 'jangad', 'memo', 'outstanding', 'pase maal', 'pase ketlo', 'maal pase',
          'approvals',
        ]);
    s += AiText.score(t, ['approval', 'pase', 'maal', 'partial', 'follow', 'paachhu', 'pachhu', 'mangav',
      'customer', 'party', 'grahak', 'kona', 'top']);
    final e = _engine;
    if (e != null) {
      for (final c in e.customers) {
        final n = AiText.normalize(c);
        if (n.length >= 4 && ' $t '.contains(' $n ') && AiText.has(t, ['pase', 'maal', 'approval'])) s += 2;
      }
      if (RegExp(r'app\s?\d{6,}').hasMatch(t)) s += 3;
    }
    return s;
  }
}

// -----------------------------------------------------------------------
//  WORKER LOSS (karigar mujab ghat / vadharo / bhuko)
// -----------------------------------------------------------------------
class WorkerLossAiModule extends AiModule {
  WorkerLossEngine? _engine;

  @override
  String get id => 'loss';
  @override
  String get title => 'Worker Loss';
  @override
  IconData get icon => FontAwesomeIcons.scaleUnbalanced;

  @override
  bool allowed(List<String> p) => p.any((e) => e.startsWith('report-worker-loss-'));

  @override
  List<String> get suggestions => WorkerLossEngine.suggestions;
  @override
  bool get isLoaded => _engine != null;
  @override
  String get statusLine => _engine == null ? 'Load thay che…' : '${_engine!.all.length} entry';

  @override
  Future<void> load({bool force = false, void Function(int, int)? onProgress}) async {
    onProgress?.call(0, 1);
    final list = await WorkerLossRepository.loadAll(force: force);
    _engine = WorkerLossEngine(list);
    onProgress?.call(1, 1);
  }

  @override
  AiAnswer welcome() {
    final e = _engine;
    if (e == null || e.all.isEmpty) return const AiAnswer(text: '⚖️ Worker Loss: koi entry nathi.');
    final n = DateTime.now();
    final month = e.all.where((x) => x.date.year == n.year && x.date.month == n.month).toList();
    final src = month.fold(0.0, (a, x) => a + x.source);
    final loss = month.fold(0.0, (a, x) => a + x.loss);
    final issues = e.all.where((x) => x.issue != null).length;
    return AiAnswer(
      text: '⚖️ Worker Loss: ${e.all.length} entry, ${e.workers.length} worker. '
          'Aa mahine ${month.length} entry — ${month.isEmpty ? 'haju kai nathi' : '${loss < 0 ? 'ghat' : 'vadharo'} ${AiFmt.g(loss.abs())} g'}'
          '${src > 0 ? ' (${AiFmt.g(-loss / src * 100)}%)' : ''}.'
          '${issues > 0 ? ' ⚠️ $issues entry no hisab match nathi.' : ''}',
      speech: 'Worker loss tayar che. Kono loss jovo che?',
      followUps: WorkerLossEngine.suggestions.take(4).toList(),
    );
  }

  @override
  AiAnswer ask(String q) => _engine?.ask(q) ?? const AiAnswer(text: 'Worker loss data haju load thay che…');

  @override
  int relevance(String t) {
    var s = 3 *
        AiText.score(t, [
          'loss', 'ghat', 'bhuko', 'bhukko', 'karigar', 'kaarigar', 'worker', 'vadharo', 'nuksan',
        ]);
    s += AiText.score(t, ['casting', 'tree', 'cutting', 'jobwork', 'receive', 'source', 'stage', 'buch', 'galat entry']);
    final e = _engine;
    if (e != null) {
      for (final w in e.workers) {
        final n = AiText.normalize(w);
        if (n.length >= 4 && ' $t '.contains(' $n ')) s += 2;
      }
      if (RegExp(r'\b(vv|ji|pt)\s?-?\s?\d').hasMatch(t)) s += 2;
    }
    return s;
  }
}
