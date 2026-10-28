import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../Approval/ApproveListScreen.dart';
import '../../../Approval/CreateApprovalScreen.dart';
import '../../../Extra/ItemProvider.dart';
import '../../../Item_Mangement/Label Print/Label_print_Screen.dart';
import '../../../Job Work/JobWork Receive/JobworkReceiveScreen.dart';
import '../../../Reports/SaleSumryReport.dart';
import '../../../Reports/StockPositionReport.dart';
import '../../../Reports/WorkerLossReportScreen.dart';
import '../../../Reports/WorkerMetalLedgerScreen.dart';
import '../../../Sell_estimate/SellScreen.dart';
import '../../../Stock Gallary/StockGalleryScreen.dart';
import 'AskAI/core/ai_core.dart';

/// =======================================================================
///  🧭 APP NAVIGATOR AI — boli ne screen kholo
///
///   • "Divya nu sale estimate kholo"      → Sale Estimate, Divya select
///   • "D test ni approval banav"          → Create Approval, D test select
///   • "navu sale estimate"                → Sale Estimate (customer vagar)
///   • "label print kholo" / "stock gallery kholo" / "metal ledger kholo"
///
///  Kholva no shabd (kholo / open / banav / navu / chalu kar) hoy to j —
///  "Divya nu sale ketlu" jeva sawal Sales module ne j jay.
///  File: Ask AI/Nav/AppNavigatorAi.dart
/// =======================================================================
class NavResult {
  final AiAnswer answer;

  /// null = customer pasand karvano baki (answer ma options che)
  final Widget Function()? screen;

  NavResult(this.answer, this.screen);
}

class _Target {
  final String title;
  final List<String> words;
  final bool needsCustomer; // customer bolay to select kari ne kholo
  final Widget Function(String? customerId) build;

  const _Target(this.title, this.words, this.build, {this.needsCustomer = false});
}

class AppNavigatorAi {
  static const List<String> _openWords = [
    'kholo', 'khol', 'kholi', 'kholje', 'open', 'banav', 'banavo', 'banavi', 'navu', 'navi', 'new', 'chalu kar',
    'start', 'shuru', 'jao', 'lai ja', 'le ja', 'screen', 'karvu che', 'karvi che', 'create',
  ];

  /// 👉 Navi screen umervi hoy to ahi ek line
  static final List<_Target> _targets = [
    // _Target('Sale Estimate', ['sale estimate', 'sell estimate', 'estimate', 'sale', 'sell', 'bill', 'vechan', 'vechanu'],
    //         (c) => Sellscreen(prefillCustomerId: c),
    //    needsCustomer: true),
    // _Target('Approval', ['approval', 'aproval', 'apruval', 'apruvel'],
    //         (c) => Createapprovalscreen(prefillCustomerId: c),
    //     needsCustomer: true),
    _Target('Approval List', ['approval list', 'approval ni list'], (_) => const InvoiceScreen()),
    _Target('Label Print', ['label print', 'barcode print', 'label chhap', 'print label'], (_) => const LabelPrintScreen()),
    _Target('Stock Gallery', ['stock gallery', 'gallery'], (_) => const StockGalleryScreen()),
    _Target('Stock Position', ['stock position report', 'stock position'], (_) => const Stockpositionreport()),
    _Target('Job Work Receive', ['job work receive', 'jobwork receive', 'job work', 'jobwork'],
            (_) => const Jobworkreceivescreen()),
    _Target('Worker Loss Report', ['worker loss', 'loss report'], (_) => const WorkerLossReportScreen()),
    _Target('Metal Ledger', ['metal ledger', 'worker ledger', 'ledger'], (_) => const WorkerMetalLedgerScreen()),
    _Target('Sales Summary', ['sales summary', 'sale summary', 'sale report', 'sales report'], (_) => const Salesumryreport()),
  ];

  /// null = aa "screen kholo" no command nathi
  static NavResult? handle(BuildContext context, String raw) {
    final t = ' ${_norm(raw)} ';
    if (!_openWords.any((w) => t.contains(' $w'))) return null;

    // lambo shabd pehla ("approval list" > "approval", "sale estimate" > "sale")
    _Target? target;
    int bestLen = 0;
    for (final tg in _targets) {
      for (final w in tg.words) {
        if (t.contains(' $w') && w.length > bestLen) {
          target = tg;
          bestLen = w.length;
        }
      }
    }
    if (target == null) return null;
    final tg = target;

    if (!tg.needsCustomer) {
      return NavResult(
        AiAnswer(text: '🧭 ${tg.title} kholu chhu…', speech: '${tg.title} kholu chhu.'),
            () => tg.build(null),
      );
    }

    // ---- customer shodho ----
    final customers = List<Map>.from(
      (Provider.of<ItemProvider>(context, listen: false).customers as List? ?? const []).whereType<Map>(),
    );
    final matches = _matchCustomers(t, customers, tg.words);

    if (matches.isEmpty) {
      // naam j nathi bolyu → khali screen
      final spokeName = _leftover(t, tg.words).isNotEmpty;
      return NavResult(
        AiAnswer(
          text: spokeName
              ? '🧭 Aa naam no customer malyo nathi — ${tg.title} customer vagar kholu chhu.'
              : '🧭 Navu ${tg.title} kholu chhu…',
          speech: '${tg.title} kholu chhu.',
        ),
            () => tg.build(null),
      );
    }

    if (matches.length > 1) {
      return NavResult(
        AiAnswer(
          text: 'Aa naam na ${matches.length} customer che — kona mate ${tg.title} kholu?',
          speech: 'Kayo customer?',
          followUps: matches.take(6).map((c) => '${_name(c)} nu ${tg.title} kholo').toList(),
        ),
        null,
      );
    }

    final c = matches.first;
    return NavResult(
      AiAnswer(
        text: '🧭 ${_name(c)} nu ${tg.title} kholu chhu…',
        speech: '${_name(c)} nu ${tg.title} kholu chhu.',
      ),
          () => tg.build(c['id']?.toString()),
    );
  }

  static List<Map> _matchCustomers(String t, List<Map> all, List<String> screenWords) {
    // 1) puru naam
    final full = all.where((c) {
      final n = _norm(_name(c));
      return n.length >= 2 && t.contains(' $n ');
    }).toList()
      ..sort((a, b) => _name(b).length.compareTo(_name(a).length));
    if (full.isNotEmpty) {
      final best = _norm(_name(full.first));
      return full.where((c) => _norm(_name(c)) == best).toList();
    }
    // 2) mobile number
    final mob = RegExp(r'\d{10}').firstMatch(t.replaceAll(' ', ''));
    if (mob != null) {
      final m = all.where((c) => (c['mobile_no'] ?? c['mobile'] ?? '').toString().contains(mob[0]!)).toList();
      if (m.isNotEmpty) return m;
    }
    // 3) shabd thi ("divya" → "Divya Patel")
    final left = _leftover(t, screenWords);
    if (left.isEmpty) return [];
    return all.where((c) => _norm(_name(c)).split(' ').any(left.contains)).toList();
  }

  /// command / screen na shabd kadhi ne bachela shabd (customer nu naam hovu joie)
  static Set<String> _leftover(String t, List<String> screenWords) {
    const stop = {
      'nu', 'ni', 'no', 'na', 'ne', 'mate', 'kholo', 'khol', 'kholi', 'open', 'banav', 'banavo', 'navu',
      'navi', 'new', 'chalu', 'kar', 'karo', 'start', 'shuru', 'jao', 'screen', 'karvu', 'karvi', 'che', 'mane',
      'customer', 'party', 'create', 'lai', 'le', 'ja',
    };
    final screen = screenWords.expand((w) => w.split(' ')).toSet();
    return t.trim().split(' ').where((w) => w.length >= 3 && !stop.contains(w) && !screen.contains(w)).toSet();
  }

  static String _name(Map c) => (c['name'] ?? c['customer_name'] ?? '').toString().trim();

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9઀-૿\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}