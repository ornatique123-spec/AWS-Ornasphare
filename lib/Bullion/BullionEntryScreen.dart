import 'dart:convert' show jsonDecode, latin1, utf8;
import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'dart:ui' show FontFeature;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart' show Dio, Options, ResponseType;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppMessage.dart';
import '../Extra/AppColors.dart';

import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

// ============================================================================
// API
//
//   GET   bullion/persons   -> dropdown list (screen khule tyare)
//   GET   <live rates>      -> GLD 999 IMP AMD T+1 / SLV 999 bhav (Ahmedabad)
//   POST  bullion/entries   -> entry save
//
//   Metal → Rupees (Postman):
//   {
//     "person_id": 193, "entry_date": "2026-10-19",
//     "entry_type": "convert_to_rupees", "metal_type": "silver",
//     "net_weight": 500, "purity": 100, "rate": 216.96,
//     "rate_confirmed": true, "remarks": "Silver conversion"
//   }
// ============================================================================
class BullionApi {
  static String _url(String path) => ApiConstants.company_branches
      .replaceFirst(RegExp(r'company/branches/?$'), path);

  static String get _entriesUrl => _url('bullion/entries');
  static String get _personsUrl => _url('bullion/persons');

  /// Export mate bahar thi vaprva
  static String get entriesUrl => _entriesUrl;
  static String get personsUrl => _personsUrl;

  /// 🏢 Branch Reports — "management_branches[]=1&management_branches[]=2"
  /// Screen "View" dabave tyare set thay, Clear thi khali
  static String branchQuery = '';

  /// URL ma branch umero (branch mode hoy to j)
  static String _b(String url) => branchQuery.isEmpty
      ? url
      : '$url${url.contains('?') ? '&' : '?'}$branchQuery';



  /// GET bullion/persons → {"success":true,"data":[{"id":191,"name":"..."}]}
  static Future<List<BullionPerson>> fetchPersons() async {
    final response = await ApiHelper().getRequest(_b(_personsUrl));
    final body = _check(response, 'Failed to load bullions');

    dynamic list = body is Map ? body['data'] : body;
    if (list is Map) {
      list = list['persons'] ?? list['data'] ?? list['items'] ?? const [];
    }
    if (list is! List) return const [];

    return list
        .whereType<Map>()
        .map((e) => BullionPerson.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.id > 0)
        .toList();
  }

  /// GET live_metal_rates?latitude=&longitude=&device_id=
  /// (Live Rate screen jevu j — showLoading: false)
  static Future<LiveRates> fetchLiveRates() async {
    final query = await _liveRateQuery();
    debugPrint('📤 BULLION LIVE RATE QUERY => $query');

    final response = await ApiHelper().getRequestWithQuery(
      ApiConstants.live_metal_rates,
      queryParameters: query,
      showLoading: false,
    );
    final body = _check(response, 'Failed to load live rates');

    final list = body is Map && body['data'] is List
        ? (body['data'] as List)
        : const [];

    return LiveRates(
      updatedAt: body is Map ? body['updated_at']?.toString() : null,
      source: body is Map ? body['source']?.toString() : null,
      quotes: list
          .whereType<Map>()
          .map((e) => LiveQuote.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// Location + device id (kai na male to pan API call thay j)
  static Future<Map<String, dynamic>> _liveRateQuery() async {
    String latitude = '';
    String longitude = '';
    String deviceId = '';

    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 6),
              ),
            );
          } catch (_) {
            // GPS late hoy to chhelli jaanel location
            pos = await Geolocator.getLastKnownPosition();
          }
          if (pos != null) {
            latitude = pos.latitude.toString();
            longitude = pos.longitude.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Location Error => $e — proceeding without lat/long');
    }

    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        deviceId = (await info.androidInfo).id;
      } else if (Platform.isIOS) {
        deviceId = (await info.iosInfo).identifierForVendor ?? '';
      }
    } catch (e) {
      debugPrint('❌ Device ID Error => $e');
    }

    return {
      'latitude': latitude,
      'longitude': longitude,
      'device_id': deviceId,
    };
  }

  /// GET bullion/balance?person_id=191
  /// → data.balance {cash, gold, silver}
  static Future<BullionBalance> fetchBalance(int personId) async {
    final response = await ApiHelper().getRequestWithQuery(
      _b(_url('bullion/balance')),
      queryParameters: {'person_id': personId},
    );
    final body = _check(response, 'Failed to load balance');
    final data = body is Map && body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : <String, dynamic>{};
    return BullionBalance.fromJson(data);
  }

  /// GET bullion/entries?person_id=191&page=1
  /// → data {current_page, last_page, total, data: [...]}
  static Future<LedgerPage> fetchEntries(int personId, {int page = 1}) async {
    final response = await ApiHelper().getRequestWithQuery(
      _b(_entriesUrl),
      queryParameters: {'person_id': personId, 'page': page},
    );
    final body = _check(response, 'Failed to load ledger');
    final data = body is Map && body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : <String, dynamic>{};
    return LedgerPage.fromJson(data);
  }

  /// GET bullion/pdf?person_id=193 → PDF file (bytes) ke {url: "..."}
  static Future<File> downloadLedgerPdf(int personId, String name) async {
    /// ApiHelper.getPdfRequest → ResponseType.bytes (PDF corrupt na thay)
    final response = await ApiHelper().getPdfRequest(
      _b('${_url('bullion/pdf')}?person_id=$personId'),
    );

    final code = response?.statusCode ?? 0;
    dynamic data = response?.data;

    /// Error vakhte server JSON mokle → bytes mathi message vancho
    if (data is List<int> && data.isNotEmpty && data.first == 0x7B /* { */) {
      try {
        data = jsonDecode(utf8.decode(data));
      } catch (_) {}
    }

    if (code != 200) {
      throw BullionApiException(
          _errorMessage(data, code, 'Failed to download PDF'));
    }

    Uint8List? bytes;

    if (data is Uint8List) {
      bytes = data;
    } else if (data is List<int>) {
      bytes = Uint8List.fromList(data);
    } else if (data is String && data.startsWith('%PDF')) {
      // Binary String tarike aavyu → bytes ma pachhu
      bytes = Uint8List.fromList(latin1.encode(data));
    } else if (data is Map) {
      if (data['success'] == false) {
        throw BullionApiException(
            _errorMessage(data, code, 'Failed to download PDF'));
      }
      // JSON ma link aave to e link thi download
      final d = data['data'] is Map ? data['data'] as Map : data;
      final link = (d['url'] ??
          d['pdf_url'] ??
          d['file_url'] ??
          d['download_url'] ??
          d['pdf'])
          ?.toString();
      if (link == null || !link.startsWith('http')) {
        throw BullionApiException('PDF link not found');
      }
      final res = await Dio().get<List<int>>(
        link,
        options: Options(responseType: ResponseType.bytes),
      );
      bytes = Uint8List.fromList(res.data ?? const []);
    }

    if (bytes == null || bytes.isEmpty) {
      throw BullionApiException('Empty PDF');
    }

    final dir = await getApplicationDocumentsDirectory();
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final file = File('${dir.path}/Bullion_Ledger_${safe}_'
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> createEntry(BullionEntryRequest req) async {
    final body = req.toJson();
    debugPrint('📤 BULLION ENTRY BODY => $body');
    final response = await ApiHelper().postRequest(_entriesUrl, body);
    _check(response, 'Failed to save bullion entry', created: true);
  }

  static dynamic _check(dynamic response, String fallback,
      {bool created = false}) {
    final code = response?.statusCode ?? 0;
    final body = response?.data;
    final okCode = code == 200 || (created && code == 201);
    if (!okCode || (body is Map && body['success'] == false)) {
      throw BullionApiException(_errorMessage(body, code, fallback));
    }
    return body;
  }

  static String _errorMessage(dynamic body, int code, String fallback) {
    if (body is Map) {
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
      if (body['message'] != null) return body['message'].toString();
    }
    if (code == 401) return 'Session expired. Please login again.';
    return fallback;
  }
}

class BullionApiException implements Exception {
  final String message;
  BullionApiException(this.message);
  @override
  String toString() => message;
}

// ============================================================================
// Models
// ============================================================================
double _d(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;

class BullionPerson {
  final int id;
  final String name;
  final String? city;
  final double cash;
  final double gold;
  final double silver;

  /// API no aakho JSON (branch / company_id mate)
  final Map<String, dynamic> raw;

  const BullionPerson({
    required this.id,
    required this.name,
    this.city,
    this.cash = 0,
    this.gold = 0,
    this.silver = 0,
    this.raw = const {},
  });

  factory BullionPerson.fromJson(Map<String, dynamic> j) {
    final b = j['balances'] is Map
        ? Map<String, dynamic>.from(j['balances'] as Map)
        : j;
    String? s(dynamic v) =>
        (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();

    return BullionPerson(
      id: int.tryParse('${j['id'] ?? j['person_id'] ?? ''}') ?? 0,
      name: s(j['name'] ?? j['person_name']) ?? '-',
      city: s(j['city']),
      cash: _d(b['cash_balance'] ?? b['cash']),
      gold: _d(b['gold_fine_balance'] ?? b['gold_balance'] ?? b['gold']),
      silver:
      _d(b['silver_fine_balance'] ?? b['silver_balance'] ?? b['silver']),
      raw: j,
    );
  }

  BullionPerson copyWith({double? cash, double? gold, double? silver}) =>
      BullionPerson(
        id: id,
        name: name,
        city: city,
        cash: cash ?? this.cash,
        gold: gold ?? this.gold,
        silver: silver ?? this.silver,
        raw: raw,
      );
}

/// 💰 bullion/balance
class BullionBalance {
  final double cash;
  final double gold;
  final double silver;

  const BullionBalance({this.cash = 0, this.gold = 0, this.silver = 0});

  factory BullionBalance.fromJson(Map<String, dynamic> j) {
    final b = j['balance'] is Map
        ? Map<String, dynamic>.from(j['balance'] as Map)
        : j;
    return BullionBalance(
      cash: _d(b['cash']),
      gold: _d(b['gold']),
      silver: _d(b['silver']),
    );
  }
}

/// 📒 bullion/entries — ek row
class LedgerEntry {
  final int id;
  final DateTime? entryDate;
  final DateTime? createdAt;
  final String entryType;
  final String? paymentMode;
  final double cashIn;
  final double cashOut;
  final String? metalType;
  final double metalIn;
  final double metalOut;
  final double rate;
  final String remarks;

  /// Aa row pachhi nu balance (screen par ganay)
  double cashBalance = 0;
  double goldBalance = 0;
  double silverBalance = 0;

  LedgerEntry({
    required this.id,
    this.entryDate,
    this.createdAt,
    required this.entryType,
    this.paymentMode,
    this.cashIn = 0,
    this.cashOut = 0,
    this.metalType,
    this.metalIn = 0,
    this.metalOut = 0,
    this.rate = 0,
    this.remarks = '',
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> j) {
    DateTime? dt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
    String? s(dynamic v) =>
        (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();

    return LedgerEntry(
      id: int.tryParse('${j['id'] ?? ''}') ?? 0,
      entryDate: dt(j['entry_date']),
      createdAt: dt(j['created_at']),
      entryType: (j['entry_type'] ?? '').toString(),
      paymentMode: s(j['payment_mode']),
      cashIn: _d(j['cash_in']),
      cashOut: _d(j['cash_out']),
      metalType: s(j['metal_type'])?.toLowerCase(),
      metalIn: _d(j['metal_in']),
      metalOut: _d(j['metal_out']),
      rate: _d(j['rate']),
      remarks: s(j['remarks']) ?? '',
    );
  }

  double get cashDelta => cashIn - cashOut;
  double get goldDelta => metalType == 'gold' ? metalIn - metalOut : 0;
  double get silverDelta => metalType == 'silver' ? metalIn - metalOut : 0;

  /// "convert_to_metal" → "Convert Rupees to Metal"
  String get typeLabel {
    for (final t in EntryType.values) {
      if (t.apiValue == entryType) return t.label;
    }
    return entryType
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String get dateText {
    final d = entryDate ?? createdAt;
    if (d == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year}';
  }

  String get timeText {
    final d = createdAt;
    if (d == null) return '';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${h.toString().padLeft(2, '0')}:$m ${d.hour >= 12 ? 'pm' : 'am'}';
  }

  /// Search mate badhu ek text ma
  String get searchText => [
    dateText,
    typeLabel,
    entryType,
    metalType ?? '',
    paymentMode ?? '',
    remarks,
    cashIn.toStringAsFixed(2),
    cashOut.toStringAsFixed(2),
    metalIn.toStringAsFixed(3),
    metalOut.toStringAsFixed(3),
    rate.toStringAsFixed(2),
  ].join(' ').toLowerCase();
}

class LedgerPage {
  final List<LedgerEntry> entries;
  final int currentPage;
  final int lastPage;
  final int total;

  const LedgerPage({
    this.entries = const [],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  factory LedgerPage.fromJson(Map<String, dynamic> j) {
    final list = j['data'] is List ? j['data'] as List : const [];
    final entries = list
        .whereType<Map>()
        .map((e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return LedgerPage(
      entries: entries,
      currentPage: int.tryParse('${j['current_page'] ?? 1}') ?? 1,
      lastPage: int.tryParse('${j['last_page'] ?? 1}') ?? 1,
      total: int.tryParse('${j['total'] ?? entries.length}') ?? entries.length,
    );
  }
}

/// Live rate API nu ek item
class LiveQuote {
  final String symbol;
  final String city;
  final double rate;
  final bool available;

  const LiveQuote({
    required this.symbol,
    required this.city,
    required this.rate,
    required this.available,
  });

  factory LiveQuote.fromJson(Map<String, dynamic> j) => LiveQuote(
    symbol: (j['symbol'] ?? '').toString().trim(),
    city: (j['city'] ?? '').toString().trim(),
    rate: _d(j['rate']),
    available: j['available'] != false,
  );

  /// "SLV 999 (1 KG BAR)" → 1000 g, "GLD 999" → 10 g
  int unitFor(MetalType m) {
    final s = symbol.toUpperCase();
    if (s.contains('KG')) return 1000;
    if (RegExp(r'\b10\s*G').hasMatch(s)) return 10;
    if (RegExp(r'\b100\s*G').hasMatch(s)) return 100;
    return m == MetalType.gold ? 10 : 1000;
  }
}

class LiveRates {
  final String? updatedAt;
  final String? source;
  final List<LiveQuote> quotes;

  const LiveRates({this.updatedAt, this.source, this.quotes = const []});

  /// Ahmedabad no GLD / SLV bhav (na male to pehlo GLD / SLV)
  ///
  /// "GOLD" / "SILVER" (city: Gold / Silver) = international $ bhav →
  /// e kadhi nakhvana, fakt India na 999 vala j levana.
  /// ✅ Fix symbol (pehla aa j shodhay)
  static const String goldSymbol = 'GLD 999 IMP AMD T+1';
  static const String silverSymbol = 'SLV 999 (1 KG BAR) T+1';

  LiveQuote? quoteFor(MetalType m) {
    final isGold = m == MetalType.gold;

    // 1) Exact symbol match (space / case ignore)
    String norm(String v) => v.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final want = norm(isGold ? goldSymbol : silverSymbol);
    for (final q in quotes) {
      if (norm(q.symbol) == want && q.rate > 0) return q;
    }

    bool matches(LiveQuote q) {
      final s = q.symbol.toUpperCase();
      final c = q.city.toUpperCase();
      if (!q.available || q.rate <= 0) return false;
      if (c == 'GOLD' || c == 'SILVER' || c == 'CURRENCY') return false;
      return isGold
          ? (s.startsWith('GLD') || s.startsWith('GOLD '))
          : (s.startsWith('SLV') || s.startsWith('SILVER ') || s.contains('SLV'));
    }

    var list = quotes.where(matches).toList();

    // Market band hoy (available:false) to pan chhello bhav vaaparo
    if (list.isEmpty) {
      list = quotes.where((q) {
        final s = q.symbol.toUpperCase();
        final c = q.city.toUpperCase();
        if (q.rate <= 0 || c == 'GOLD' || c == 'SILVER' || c == 'CURRENCY') {
          return false;
        }
        return isGold
            ? (s.startsWith('GLD') || s.startsWith('GOLD '))
            : (s.startsWith('SLV') || s.startsWith('SILVER ') || s.contains('SLV'));
      }).toList();
    }

    debugPrint('📈 ${m.label} quotes => '
        '${list.map((q) => '${q.symbol} (${q.city}) ${q.rate}').join(', ')}');
    if (list.isEmpty) {
      debugPrint('❌ ${m.label} quote NOT FOUND. All symbols => '
          '${quotes.map((q) => '${q.symbol} [${q.city}]').join(' | ')}');
      return null;
    }

    for (final q in list) {
      final c = q.city.toLowerCase();
      final s = q.symbol.toUpperCase();
      if (c.contains('ahmedabad') || s.contains(' AMD') || s.contains('AHM')) {
        return q;
      }
    }
    return list.first;
  }
}

/// 📋 Transaction (web jevi j 6)
enum EntryType {
  receiveCash,
  receiveMetal,
  returnCash,
  returnMetal,
  toMetal,
  toRupees,
}

extension EntryTypeX on EntryType {
  String get label {
    switch (this) {
      case EntryType.receiveCash:
        return 'Receive cash deposit';
      case EntryType.receiveMetal:
        return 'Receive fine metal';
      case EntryType.returnCash:
        return 'Return cash';
      case EntryType.returnMetal:
        return 'Return fine metal (no cash conversion)';
      case EntryType.toMetal:
        return 'Convert Rupees to Metal';
      case EntryType.toRupees:
        return 'Convert Metal to Rupees';
    }
  }

  /// Backend (web select) jeva j value
  String get apiValue {
    switch (this) {
      case EntryType.receiveCash:
        return 'receive_amount';
      case EntryType.receiveMetal:
        return 'receive_metal';
      case EntryType.returnCash:
        return 'return_amount';
      case EntryType.returnMetal:
        return 'return_metal';
      case EntryType.toMetal:
        return 'convert_to_metal';
      case EntryType.toRupees:
        return 'convert_to_rupees';
    }
  }

  String get hint {
    switch (this) {
      case EntryType.receiveCash:
        return 'Enter the cash amount received. Cash balance increases.';
      case EntryType.receiveMetal:
        return 'Select gold or silver and enter weight and purity. Fine grams are credited.';
      case EntryType.returnCash:
        return 'Enter the cash amount returned. Cash balance decreases.';
      case EntryType.returnMetal:
        return 'Select gold or silver and enter weight and purity. Fine grams are debited.';
      case EntryType.toMetal:
        return 'Select gold or silver and enter rupees plus the rate per pure gram. Rupees ÷ rate = fine grams credited.';
      case EntryType.toRupees:
        return 'Select gold or silver and enter weight, purity and rate per pure gram. Fine grams × rate = rupees credited.';
    }
  }

  bool get usesMetal => this != EntryType.receiveCash && this != EntryType.returnCash;
  bool get usesWeight =>
      this == EntryType.receiveMetal ||
          this == EntryType.returnMetal ||
          this == EntryType.toRupees;
  bool get usesCash =>
      this == EntryType.receiveCash ||
          this == EntryType.returnCash ||
          this == EntryType.toMetal;
  bool get isConversion => this == EntryType.toMetal || this == EntryType.toRupees;
}

/// 💳 Payment mode
enum PaymentMode { cash, bank, upi }

extension PaymentModeX on PaymentMode {
  String get label {
    switch (this) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.bank:
        return 'Bank';
      case PaymentMode.upi:
        return 'UPI';
    }
  }

  String get apiValue => name; // cash / bank / upi

  IconData get icon {
    switch (this) {
      case PaymentMode.cash:
        return Icons.payments_outlined;
      case PaymentMode.bank:
        return Icons.account_balance_outlined;
      case PaymentMode.upi:
        return Icons.qr_code_2_rounded;
    }
  }
}

enum MetalType { gold, silver }

extension MetalTypeX on MetalType {
  String get label => this == MetalType.gold ? 'Gold' : 'Silver';
  String get apiValue => this == MetalType.gold ? 'gold' : 'silver';
  Color get color =>
      this == MetalType.gold ? const Color(0xFFD9A62E) : const Color(0xFF8A99A8);
}

class BullionEntryRequest {
  final int personId;
  final DateTime date;
  final EntryType type;
  final MetalType metal;
  final double netWeight;
  final double purity;
  final double cashAmount;
  final double rate;
  final bool rateConfirmed;
  final String remarks;
  final PaymentMode paymentMode;

  const BullionEntryRequest({
    required this.personId,
    required this.date,
    required this.type,
    required this.metal,
    required this.netWeight,
    required this.purity,
    required this.cashAmount,
    required this.rate,
    required this.rateConfirmed,
    required this.remarks,
    required this.paymentMode,
  });

  static num _n(double v) => v == v.roundToDouble() ? v.toInt() : v;

  static String apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  /// Postman jevi j — 9 field HAMESHA jay
  /// (cash vala type ma vadhara ma "cash_amount" pan jay)
  Map<String, dynamic> toJson() => {
    'person_id': personId,
    'entry_date': apiDate(date),
    'entry_type': type.apiValue,
    'metal_type': metal.apiValue,
    // Rupees → Metal: credit thayel FINE metal j net_weight ma jay
    'net_weight': _n(
        (type.usesWeight || type == EntryType.toMetal) ? netWeight : 0),
    'purity': _n(type.usesWeight ? purity : 100),
    'rate': _n(type.isConversion ? rate : 0),
    'rate_confirmed': rateConfirmed,
    'remarks': remarks,
    'payment_mode': paymentMode.apiValue,
    if (type.usesCash) 'amount': _n(cashAmount),
  };
}

// ============================================================================
// Theme (Branch Management jevi j)
// ============================================================================
class _C {
  static const bg = Color(0xFFF4F6FB);
  static const surface = Colors.white;
  static const tile = Color(0xFFF6F8FE);
  static const border = Color(0xFFE3E8F6);
  static const bar = Color(0xFF1E4DB7);
  static const g1 = Color(0xFF5B8DEF);
  static const g2 = Color(0xFF3F63C7);
  static const g3 = Color(0xFF2B479F);
  static const primary = Color(0xFF3F6FDB);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFE5484D);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF7A8194);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [g1, g2],
  );

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [g1, g2, g3],
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: g2.withValues(alpha: 0.07),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

String _fmt(double v, int digits) => v.toStringAsFixed(digits);

/// 1234567.5 → 12,34,567.50 (Indian style)
String _inr(double v, [int digits = 2]) {
  final neg = v < 0;
  final parts = v.abs().toStringAsFixed(digits).split('.');
  String s = parts[0];
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    String rest = s.substring(0, s.length - 3);
    final buf = <String>[];
    while (rest.length > 2) {
      buf.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) buf.insert(0, rest);
    s = '${buf.join(',')},$last3';
  }
  return '${neg ? '-' : ''}$s${digits > 0 ? '.${parts[1]}' : ''}';
}

/// Quote weight unit options
const Map<int, String> _units = {
  1: '1 gram',
  10: '10 grams',
  100: '100 grams',
  1000: '1 kilogram',
};

// ============================================================================
// Screen
// ============================================================================
class BullionEntryScreen extends StatefulWidget {
  final int? initialPersonId;
  final ValueChanged<BullionPerson>? onSaved;

  const BullionEntryScreen({super.key, this.initialPersonId, this.onSaved});

  @override
  State<BullionEntryScreen> createState() => _BullionEntryScreenState();
}

class _BullionEntryScreenState extends State<BullionEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cashCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _purityCtrl = TextEditingController(text: '100');
  final _rateCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _quotePurityCtrl = TextEditingController(text: '99.9');

  EntryType _type = EntryType.receiveCash;
  MetalType _metal = MetalType.gold;
  PaymentMode _payMode = PaymentMode.cash;
  DateTime _date = DateTime.now();
  bool _confirmed = false;
  bool _submitting = false;

  /// 👥 Dropdown
  List<BullionPerson> _persons = const [];
  BullionPerson? _person;
  bool _loadingPersons = true;
  String? _personsError;

  /// 📈 Live rates
  LiveRates? _rates;
  int _quoteUnit = 10;

  double get _cash => _person?.cash ?? 0;
  double get _gold => _person?.gold ?? 0;
  double get _silver => _person?.silver ?? 0;

  LiveQuote? get _quote => _rates?.quoteFor(_metal);

  // ============================================================
  // 🔥 BRANCH REPORTS (Sale Summary jevu j)
  // ============================================================

  /// Branch API mathi aavti companies (main + branches)
  List<Company> branchCompanies = [];

  /// Dropdown ma select kareli (haju apply nathi thai)
  Set<int> selectedCompanyIds = {};

  /// "View" dabavya pachhi apply thayeli
  List<int> appliedCompanyIds = [];

  /// Branch report chalu chhe?
  bool get _branchMode => appliedCompanyIds.isNotEmpty;

  bool branchesLoading = false;
  bool canViewBranches = false;
  bool branchExpanded = true;
  bool branchReportLoading = false;

  /// management_branches[]=1&management_branches[]=2
  String get _branchQuery => appliedCompanyIds
      .map((id) => "management_branches[]=$id")
      .join("&");

  /// bullion/persons?management_branches[]=1&management_branches[]=2 (branch mode only)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// bullion → branch name (company_id / branch / company_name)
  String _branchOf(Map user) {
    final int? id = int.tryParse("${user["company_id"] ?? ""}");
    if (id != null) {
      for (final c in branchCompanies) {
        if (c.id == id) return c.name;
      }
    }
    final dynamic b = user["branch"] ?? user["branch_name"] ?? user["company"];
    if (b is Map && b["name"] != null) return b["name"].toString();
    final String t = (b ?? user["company_name"] ?? "").toString().trim();
    return t.isEmpty || t == "null" ? "" : t;
  }

  /// Main company nu id (branch list mathi)
  int? get _mainCompanyId {
    for (final c in branchCompanies) {
      if (c.isMain) return c.id;
    }
    return null;
  }

  /// ✅ Aa bullion main company no chhe? (fakt eno j edit / delete)
  /// Branch list j na hoy (branch user) to potano j data → true
  bool _isMainData(Map user) {
    final int? mainId = _mainCompanyId;
    if (mainId == null) return true;

    final int? id = int.tryParse("${user["company_id"] ?? ""}");
    if (id != null) return id == mainId;

    // company_id na aave to branch na naam thi
    final String br = _branchOf(user).trim().toLowerCase();
    if (br.isEmpty) return true;
    for (final c in branchCompanies) {
      if (c.name.trim().toLowerCase() == br) return c.isMain;
    }
    return true;
  }

  /// 🔐 Select karelo bullion main company no chhe? (fakt eni j navi entry)
  bool get _canModifyPerson {
    final p = _person;
    if (p == null) return true;
    return _isMainData(p.raw);
  }


  static final _money =
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));
  static final _weight =
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'));

  @override
  void initState() {
    super.initState();
    for (final c in [_cashCtrl, _weightCtrl, _purityCtrl, _rateCtrl]) {
      c.addListener(() => setState(() {}));
    }
    _quotePurityCtrl.addListener(_applyQuote);
    // Bijā screen ni juni branch na rahe
    BullionApi.branchQuery = '';
    _loadAll();
    _loadBranches();
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _weightCtrl.dispose();
    _purityCtrl.dispose();
    _rateCtrl.dispose();
    _remarksCtrl.dispose();
    _quotePurityCtrl.dispose();
    _ledgerSearchCtrl.dispose();
    BullionApi.branchQuery = '';
    super.dispose();
  }

  /// Ek pachhi ek (be loader ek sathe na aave)
  Future<void> _loadAll() async {
    await _loadPersons();
    await _loadRates(showError: true);
  }

  // --- persons --------------------------------------------------------------
  Future<void> _loadPersons() async {
    setState(() {
      _loadingPersons = true;
      _personsError = null;
    });
    try {
      final list = await BullionApi.fetchPersons();
      if (!mounted) return;
      BullionPerson? keep;
      final wantId = _person?.id ?? widget.initialPersonId;
      for (final p in list) {
        if (p.id == wantId) keep = p;
      }
      setState(() {
        _persons = list;
        _person = keep;
      });
      if (keep != null) _loadPersonDetail(keep.id);
    } on BullionApiException catch (e) {
      if (mounted) setState(() => _personsError = e.message);
    } catch (_) {
      if (mounted) setState(() => _personsError = 'Failed to load bullions');
    } finally {
      if (mounted) setState(() => _loadingPersons = false);
    }
  }

  void _selectPerson(BullionPerson? p) {
    if (p == null || p.id == _person?.id) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _person = p;
      _resetForm();
      _ledgerSearchCtrl.clear();
      _ledgerQuery = '';
    });
    _loadPersonDetail(p.id); // 👈 balance + ledger API
  }

  // --- person detail: balance + ledger --------------------------------------
  /// 📒 Ledger
  List<LedgerEntry> _ledger = const [];
  int _ledgerPage = 1;
  int _ledgerLastPage = 1;
  int _ledgerTotal = 0;
  bool _loadingDetail = false;
  bool _loadingMore = false;
  String _ledgerQuery = '';
  final _ledgerSearchCtrl = TextEditingController();

  /// Chalu request (bijo person select thay to juno response ignore)
  int _detailReq = 0;

  /// Person select → 1) balance API  2) entries API
  Future<void> _loadPersonDetail(int personId) async {
    final req = ++_detailReq;
    setState(() {
      _loadingDetail = true;
      _ledger = const [];
      _ledgerPage = 1;
      _ledgerLastPage = 1;
      _ledgerTotal = 0;
    });

    try {
      /// 1) BALANCE
      final bal = await BullionApi.fetchBalance(personId);
      if (!mounted || req != _detailReq) return;

      setState(() {
        final p = _person;
        if (p != null && p.id == personId) {
          final updated =
          p.copyWith(cash: bal.cash, gold: bal.gold, silver: bal.silver);
          _person = updated;
          _persons = [
            for (final x in _persons) x.id == updated.id ? updated : x,
          ];
        }
      });

      /// 2) LEDGER (page 1)
      final page = await BullionApi.fetchEntries(personId, page: 1);
      if (!mounted || req != _detailReq) return;

      _applyRunningBalance(page.entries,
          cash: bal.cash, gold: bal.gold, silver: bal.silver);

      setState(() {
        _ledger = page.entries;
        _ledgerPage = page.currentPage;
        _ledgerLastPage = page.lastPage;
        _ledgerTotal = page.total;
      });
    } on BullionApiException catch (e) {
      if (mounted && req == _detailReq) AppMessage.error(context, e.message);
    } catch (e) {
      debugPrint('❌ PERSON DETAIL ERROR => $e');
      if (mounted && req == _detailReq) {
        AppMessage.error(context, 'Failed to load bullion details');
      }
    } finally {
      if (mounted && req == _detailReq) {
        setState(() => _loadingDetail = false);
      }
    }
  }

  /// Aagal na page (Load more)
  Future<void> _loadMoreLedger() async {
    final p = _person;
    if (p == null || _loadingMore || _ledgerPage >= _ledgerLastPage) return;

    final req = _detailReq;
    setState(() => _loadingMore = true);
    try {
      final page = await BullionApi.fetchEntries(p.id, page: _ledgerPage + 1);
      if (!mounted || req != _detailReq) return;

      /// Chhelli row na balance mathi aagal ganvanu
      final last = _ledger.isEmpty ? null : _ledger.last;
      _applyRunningBalance(
        page.entries,
        cash: last == null ? _cash : last.cashBalance - last.cashDelta,
        gold: last == null ? _gold : last.goldBalance - last.goldDelta,
        silver: last == null ? _silver : last.silverBalance - last.silverDelta,
      );

      setState(() {
        _ledger = [..._ledger, ...page.entries];
        _ledgerPage = page.currentPage;
        _ledgerLastPage = page.lastPage;
        _ledgerTotal = page.total;
      });
    } catch (e) {
      debugPrint('❌ LEDGER MORE ERROR => $e');
      if (mounted) AppMessage.error(context, 'Failed to load more entries');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// API row-wise balance nathi aapti → navi thi juni taraf ganvanu:
  /// pehli (navi) row nu balance = current balance,
  /// tena pachhi ni row = upar ni row nu balance − upar ni row no ferfar
  void _applyRunningBalance(
      List<LedgerEntry> rows, {
        required double cash,
        required double gold,
        required double silver,
      }) {
    double c = cash, g = gold, s = silver;
    for (final r in rows) {
      r.cashBalance = c;
      r.goldBalance = g;
      r.silverBalance = s;
      c -= r.cashDelta;
      g -= r.goldDelta;
      s -= r.silverDelta;
    }
  }

  List<LedgerEntry> get _filteredLedger {
    final q = _ledgerQuery.trim().toLowerCase();
    if (q.isEmpty) return _ledger;
    return _ledger.where((e) => e.searchText.contains(q)).toList();
  }

  bool _downloadingPdf = false;

  /// 📄 Ledger PDF (Cr / Dr)
  Future<void> _downloadPdf() async {
    final p = _person;
    if (p == null || _downloadingPdf) return;
    FocusScope.of(context).unfocus();
    _downloadingPdf = true;
    try {
      final file = await BullionApi.downloadLedgerPdf(p.id, p.name);
      if (!mounted) return;
      _showPdfReady(file);
    } on BullionApiException catch (e) {
      if (mounted) AppMessage.error(context, e.message);
    } catch (e) {
      debugPrint('❌ LEDGER PDF ERROR => $e');
      if (mounted) AppMessage.error(context, 'Failed to download PDF');
    } finally {
      _downloadingPdf = false;
    }
  }

  void _showPdfReady(File file) {
    final name = file.path.split('/').last;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _C.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: _C.success, size: 26),
              ),
              const SizedBox(height: 10),
              const Text('Ledger PDF ready',
                  style: TextStyle(
                      color: _C.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _C.muted, fontSize: 11.5)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheet);
                        final r = await OpenFile.open(file.path);
                        if (r.type != ResultType.done && mounted) {
                          AppMessage.error(context, 'Unable to open PDF');
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Open'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _C.primary,
                        side: const BorderSide(color: _C.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheet);
                        await Share.shareXFiles(
                          [XFile(file.path, mimeType: 'application/pdf')],
                          subject: name,
                        );
                      },
                      icon: const Icon(Icons.share_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Share',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 📒 LEDGER UI
  Widget _ledgerSection() {
    final rows = _filteredLedger;
    final hasMore = _ledgerPage < _ledgerLastPage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Bullion Ledger')),
            if (_ledgerTotal > 0)
              Container(
                margin: const EdgeInsets.only(top: 6, right: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_ledgerTotal entries',
                  style: const TextStyle(
                    color: _C.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            /// 📄 PDF (Cr / Dr)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _ledger.isEmpty ? null : _C.gradient,
                    color: _ledger.isEmpty ? _C.border : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _ledger.isEmpty ? null : _downloadPdf,
                    child: const Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 5),
                          Text(
                            'PDF (Cr / Dr)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        /// SEARCH
        if (_ledger.isNotEmpty) ...[
          TextField(
            controller: _ledgerSearchCtrl,
            onChanged: (v) => setState(() => _ledgerQuery = v),
            style: const TextStyle(color: _C.text, fontSize: 13.5),
            decoration: _decoration(
              hint: 'Search ledger',
              suffix: _ledgerQuery.isEmpty
                  ? const Icon(Icons.search_rounded, size: 18, color: _C.muted)
                  : IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: _C.muted),
                onPressed: () => setState(() {
                  _ledgerSearchCtrl.clear();
                  _ledgerQuery = '';
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        /// LOADING / EMPTY / LIST
        if (_loadingDetail && _ledger.isEmpty)
          const SizedBox(height: 40)
        else if (_ledger.isEmpty)
          const _LedgerEmpty(
            text:
            'No transactions yet. Save a bullion entry to start this customer\'s ledger.',
          )
        else if (rows.isEmpty)
            const _LedgerEmpty(text: 'No data found for your search.')
          else ...[
              for (final e in rows) _LedgerCard(entry: e),
              if (hasMore && _ledgerQuery.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: _loadingMore ? null : _loadMoreLedger,
                    icon: const Icon(Icons.expand_more_rounded, size: 18),
                    label: Text(_loadingMore
                        ? 'Loading…'
                        : 'Load more (${_ledger.length} / $_ledgerTotal)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: _C.primary.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
      ],
    );
  }


  // --- live rates -----------------------------------------------------------
  /// Chalu request no number (juno response navu rate overwrite na kare)
  int _rateReq = 0;
  bool _loadingRates = false;

  /// 📈 Live rate API call — FAKT:
  ///   1) page pehli vaar khule tyare
  ///   2) Gold / Silver select kare tyare
  ///   3) "Use latest quote" dabave tyare
  Future<void> _loadRates({bool showError = false}) async {
    final req = ++_rateReq;
    final metalAtCall = _metal;
    if (mounted) setState(() => _loadingRates = true);

    try {
      final r = await BullionApi.fetchLiveRates();
      if (!mounted || req != _rateReq) return;

      setState(() {
        _rates = r;
        _quoteUnit = r.quoteFor(_metal)?.unitFor(_metal) ??
            (_metal == MetalType.gold ? 10 : 1000);
      });
      _applyQuote();
      if (mounted) setState(() {}); // rate field + quote box turant refresh

      debugPrint('✅ LIVE RATE SET [${metalAtCall.label}] => '
          '${_quote?.symbol} ${_quote?.rate} → ${_rateCtrl.text} ₹/g');
    } catch (e) {
      debugPrint('⚠️ LIVE RATE ERROR => $e');
      if (mounted && showError && req == _rateReq) {
        AppMessage.error(context,
            e is BullionApiException ? e.message : 'Failed to load live rates');
      }
    } finally {
      if (mounted && req == _rateReq) setState(() => _loadingRates = false);
    }
  }

  /// Rate = quote ÷ weight ÷ purity fraction  → "rate" field ma set
  void _applyQuote() {
    final q = _quote;
    final purity = double.tryParse(_quotePurityCtrl.text.trim()) ?? 0;
    if (q == null) {
      // Juno (gold no) bhav silver ma na rahe
      if (_rateCtrl.text.isNotEmpty) _rateCtrl.clear();
      if (mounted) setState(() {});
      return;
    }
    if (purity <= 0 || _quoteUnit <= 0) return;
    final rate = q.rate / _quoteUnit / (purity / 100);
    _rateCtrl.value = TextEditingValue(
      text: _fmt(rate, 2),
      selection: TextSelection.collapsed(offset: _fmt(rate, 2).length),
    );
    if (mounted) setState(() {});
  }

  Future<void> _useLatestQuote() async {
    await _loadRates(showError: true);
    if (mounted && _quote == null) {
      AppMessage.error(context, 'No live ${_metal.label.toLowerCase()} quote');
    }
  }

  /// Gold / Silver select → live rate API call → e metal no per gram rate set
  void _changeMetal(MetalType m) {
    if (m == _metal) return;
    setState(() {
      _metal = m;
      _confirmed = false;
      _quoteUnit = m == MetalType.gold ? 10 : 1000;
    });

    // Junu bhav turant batavo (hoy to), pachhi API thi taaju bhav set thashe
    _applyQuote();
    _loadRates(showError: true);
  }

  void _changeType(EntryType t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      _confirmed = false;
    });
    if (t.isConversion) {
      if (_rates == null) {
        _loadRates(showError: true);
      } else {
        _applyQuote();
      }
    }
  }

  void _resetForm() {
    _cashCtrl.clear();
    _weightCtrl.clear();
    _remarksCtrl.clear();
    _purityCtrl.text = '100';
    _confirmed = false;
  }

  // --- calculation ----------------------------------------------------------
  double _v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  double get _rate => _v(_rateCtrl);

  double get _fine {
    if (_type.usesWeight) return _v(_weightCtrl) * _v(_purityCtrl) / 100;
    if (_type == EntryType.toMetal) {
      return _rate <= 0 ? 0 : _v(_cashCtrl) / _rate;
    }
    return 0;
  }

  double get _amount {
    if (_type == EntryType.toRupees) return _fine * _rate;
    if (_type.usesCash) return _v(_cashCtrl);
    return 0;
  }

  double get _cashAfter {
    switch (_type) {
      case EntryType.receiveCash:
      case EntryType.toRupees:
        return _cash + _amount;
      case EntryType.returnCash:
      case EntryType.toMetal:
        return _cash - _amount;
      default:
        return _cash;
    }
  }

  double _metalAfter(MetalType m) {
    final base = m == MetalType.gold ? _gold : _silver;
    if (!_type.usesMetal || m != _metal) return base;
    switch (_type) {
      case EntryType.receiveMetal:
      case EntryType.toMetal:
        return base + _fine;
      case EntryType.returnMetal:
      case EntryType.toRupees:
        return base - _fine;
      default:
        return base;
    }
  }

  // --- actions --------------------------------------------------------------
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _C.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? _positive(String? v, String field) {
    final d = double.tryParse(v?.trim() ?? '');
    if (d == null || d <= 0) return 'Enter $field';
    return null;
  }

  String? _purityValidator(String? v) {
    final d = double.tryParse(v?.trim() ?? '');
    if (d == null || d <= 0 || d > 100) return '1 – 100';
    return null;
  }

  Future<void> _submit() async {
    // ⌨️ Save dabavta j keyboard band
    FocusManager.instance.primaryFocus?.unfocus();
    if (_submitting) return;
    final person = _person;
    if (person == null) {
      AppMessage.error(context, 'Please select a bullion');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_confirmed) {
      AppMessage.error(context, 'Please confirm the transaction');
      return;
    }
    FocusScope.of(context).unfocus();

    final req = BullionEntryRequest(
      personId: person.id,
      date: _date,
      type: _type,
      metal: _metal,
      // Rupees → Metal ma gaṇel fine grams (3 decimal) net_weight tarike
      netWeight: _type == EntryType.toMetal
          ? double.parse(_fine.toStringAsFixed(3))
          : _v(_weightCtrl),
      purity: _type == EntryType.toMetal ? 100 : _v(_purityCtrl),
      cashAmount: _v(_cashCtrl),
      rate: _rate,
      rateConfirmed: _confirmed,
      remarks: _remarksCtrl.text.trim(),
      paymentMode: _payMode,
    );

    final updated = person.copyWith(
      cash: _cashAfter,
      gold: _metalAfter(MetalType.gold),
      silver: _metalAfter(MetalType.silver),
    );

    _submitting = true;
    try {
      await BullionApi.createEntry(req);
      if (!mounted) return;
      setState(() {
        _person = updated;
        _persons = [
          for (final p in _persons) p.id == updated.id ? updated : p,
        ];
        _resetForm();
      });
      _successToast('Bullion entry saved');
      widget.onSaved?.call(updated);
      _loadPersonDetail(person.id); // 👈 sacho balance + navi ledger row
    } on BullionApiException catch (e) {
      if (mounted) AppMessage.error(context, e.message);
    } catch (_) {
      if (mounted) AppMessage.error(context, 'Failed to save bullion entry');
    } finally {
      _submitting = false;
    }
  }

  void _successToast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: _C.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
  }

  /// =========================================================
  /// 📄 EXPORT — PDF / EXCEL (getPdfRequest → bytes)
  /// Bullion select hoy: bullion/entries?person_id=193&management_branches[]=1&export=pdf
  /// Na hoy:            bullion/persons?management_branches[]=1&export=pdf
  /// =========================================================

  /// "pdf" / "excel" chalu hoy tyare (bijo tap na thay)
  String? _exporting;

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _exporting = type);

    try {
      // Bullion select hoy to eni entries, nahi to badha bullion
      final p = _person;
      String base = p != null
          ? "${BullionApi.entriesUrl}?person_id=${p.id}"
          : BullionApi.personsUrl;
      base = _br(base);
      final String url = "$base${base.contains('?') ? '&' : '?'}export=$type";
      debugPrint("📤 EXPORT $type URL => $url");

      final response = await ApiHelper().getPdfRequest(
        url,
        receiveTimeout: const Duration(minutes: 2),
      );

      if (!mounted) return;

      if (response == null || response.statusCode != 200) {
        AppMessage.error(
          context,
          _exportError(response?.data) ??
              "Failed to download ${type == 'pdf' ? 'PDF' : 'Excel'}",
        );
        return;
      }

      final dynamic raw = response.data;
      final Uint8List? bytes = raw is Uint8List
          ? raw
          : (raw is List<int> ? Uint8List.fromList(raw) : null);

      // Bytes ni jagya e JSON error aave to
      if (bytes == null || bytes.isEmpty || bytes.first == 0x7B /* { */) {
        AppMessage.error(
          context,
          _exportError(raw) ?? "No file received from server",
        );
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final String stamp =
          "${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}";
      final String ext = type == "pdf" ? "pdf" : "xlsx";
      final String who = p != null
          ? "_${p.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}"
          : "";
      final file = File("${dir.path}/Bullion${who}_$stamp.$ext");
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      AppMessage.success(
          context, "${type == 'pdf' ? 'PDF' : 'Excel'} downloaded");
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ EXPORT $type ERROR => $e");
      if (mounted) AppMessage.error(context, "Download failed");
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  /// JSON (bytes / map / string) mathi message
  String? _exportError(dynamic data) {
    try {
      dynamic d = data;
      if (d is List<int>) d = utf8.decode(d);
      if (d is String) d = jsonDecode(d);
      if (d is Map && d["message"] != null) return d["message"].toString();
    } catch (_) {}
    return null;
  }

  /// Header ma white Excel / PDF button (radius 5)
  Widget _headerExportBtn({
    required IconData icon,
    required String tooltip,
    required bool busy,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: _exporting != null ? null : onTap,
          // Loader fakt ApiHelper nu j (button ma spinner nahi)
          child: Opacity(
            opacity: busy ? 0.5 : 1,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  /// Biji branch no bullion → navi entry na thay e batavo
  Widget _otherBranchNote() {
    final String br = _person == null ? "" : _branchOf(_person!.raw);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffFFF7ED),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xffFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 18, color: Color(0xffC2410C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              br.isEmpty
                  ? "This bullion belongs to another branch. New entry is not allowed."
                  : "This bullion belongs to $br. New entry is not allowed.",
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xff9A3412),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Column(
          children: [
            _Header(
              onBack: () => Navigator.maybePop(context),
              actions: [
                // _headerExportBtn(
                //   icon: Icons.table_chart_rounded,
                //   tooltip: "Excel",
                //   busy: _exporting == "excel",
                //   onTap: () => _export("excel"),
                // ),
                // const SizedBox(width: 8),
                // _headerExportBtn(
                //   icon: Icons.picture_as_pdf_rounded,
                //   tooltip: "PDF",
                //   busy: _exporting == "pdf",
                //   onTap: () => _export("pdf"),
                // ),
              ],
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: RefreshIndicator(
                  color: _C.primary,
                  onRefresh: () async {
                    _loadAll(); // await nathi → fakt API nu loader
                  },
                  child: _buildBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingPersons && _persons.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [],
      );
    }

    if (_personsError != null && _persons.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(10),
        children: [
          _buildBranchCard(),
          const SizedBox(height: 70),
          const Icon(Icons.cloud_off_rounded, size: 36, color: _C.muted),
          const SizedBox(height: 10),
          Text(_personsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.muted, fontSize: 13)),
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: _C.primary),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 28),
      children: [
        // 🔥 Branch Reports tab sauthi upar
        _buildBranchCard(),

        _personDropdown(),
        const SizedBox(height: 12),
        if (_person == null)
          _selectPrompt()
        else ...[
          _infoLine(),
          const SizedBox(height: 12),
          _balances(),

          // 🔐 Biji branch na bullion ma navi entry nahi
          if (_canModifyPerson) ...[
            const _SectionTitle('New Bullion Entry'),
            _entryCard(),
          ] else
            _otherBranchNote(),

          const SizedBox(height: 6),
          _ledgerSection(),
        ],
      ],
    );
  }

  /// 👥 BULLION DROPDOWN
  Widget _personDropdown() {
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: _C.gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Bullion'),
                DropdownButtonFormField<int>(
                  key: ValueKey('person-${_person?.id}-${_persons.length}'),
                  value: _person?.id,
                  isExpanded: true,
                  hint: Text(
                    _persons.isEmpty ? 'No bullion found' : 'Select bullion',
                    style: const TextStyle(
                        color: Color(0xFFB4BACB), fontSize: 13.5),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _C.muted),
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                  menuMaxHeight: 380,
                  decoration: _decoration(),
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  items: [
                    for (final p in _persons)
                      DropdownMenuItem<int>(
                        value: p.id,
                        child: Text(
                          [
                            p.name,
                            if (p.city != null) p.city!,
                            // 🏢 Branch mode ma branch nu naam
                            if (_branchMode && _branchOf(p.raw).isNotEmpty)
                              _branchOf(p.raw),
                          ].join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _persons.isEmpty
                      ? null
                      : (id) {
                    for (final p in _persons) {
                      if (p.id == id) _selectPerson(p);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.touch_app_rounded,
                color: _C.primary, size: 24),
          ),
          const SizedBox(height: 12),
          const Text(
            'Select a bullion',
            style: TextStyle(
              color: _C.text,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_persons.length} bullion available. Choose one above to see balances and add an entry.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _infoLine() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.primary.withValues(alpha: 0.14)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: _C.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Gold and silver balances are in fine grams. These entries do not receive physical stock.',
              style: TextStyle(color: _C.text, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balances() {
    return Column(
      children: [
        _CashHeroCard(value: _cash, personName: _person?.name ?? ''),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetalCard(
                label: 'Gold Fine',
                value: _gold,
                colors: const [
                  Color(0xFFF7D774),
                  Color(0xFFD9A62E),
                  Color(0xFFB07A12),
                ],
                ink: const Color(0xFF4A3305),
                icon: Icons.workspace_premium_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetalCard(
                label: 'Silver Fine',
                value: _silver,
                colors: const [
                  Color(0xFFF1F4F7),
                  Color(0xFFC3CCD5),
                  Color(0xFF8E9AA6),
                ],
                ink: const Color(0xFF26313D),
                icon: Icons.diamond_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================================
  // ENTRY CARD
  // ==========================================================================
  Widget _entryCard() {
    const numKb = TextInputType.numberWithOptions(decimal: true);

    return _Panel(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// QUICK BUTTONS → dropdown ma e j select thay
            Row(
              children: [
                Expanded(
                  child: _QuickButton(
                    label: 'Rupees → Metal',
                    icon: Icons.south_east_rounded,
                    selected: _type == EntryType.toMetal,
                    onTap: () => _changeType(EntryType.toMetal),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickButton(
                    label: 'Metal → Rupees',
                    icon: Icons.north_east_rounded,
                    selected: _type == EntryType.toRupees,
                    onTap: () => _changeType(EntryType.toRupees),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_type.hint,
                style: const TextStyle(
                    color: _C.muted, fontSize: 11.5, height: 1.4)),
            const SizedBox(height: 14),

            /// TRANSACTION DROPDOWN
            _transactionDropdown(),
            const SizedBox(height: 12),

            /// DATE + METAL
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _dateField()),
                if (_type.usesMetal) ...[
                  const SizedBox(width: 10),
                  Expanded(child: _metalPicker()),
                ],
              ],
            ),
            const SizedBox(height: 12),

            /// WEIGHT + PURITY
            if (_type.usesWeight) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(
                      label: 'Net metal weight',
                      controller: _weightCtrl,
                      hint: '0.000',
                      keyboard: numKb,
                      formatters: [_weight],
                      suffix: 'g',
                      validator: (v) => _positive(v, 'weight'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _field(
                      label: 'Purity',
                      controller: _purityCtrl,
                      keyboard: numKb,
                      formatters: [_money],
                      suffix: '%',
                      validator: _purityValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            /// CASH
            if (_type.usesCash) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(
                      label: 'Cash amount (INR)',
                      controller: _cashCtrl,
                      hint: '0.00',
                      keyboard: numKb,
                      formatters: [_money],
                      suffix: '₹',
                      validator: (v) => _positive(v, 'cash amount'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _paymentModeDropdown()),
                ],
              ),
              const SizedBox(height: 12),
            ],

            /// RATE (live quote mathi auto)
            if (_type.isConversion) ...[
              _field(
                label: '${_metal.label} conversion rate (INR / pure gram)',
                controller: _rateCtrl,
                hint: '0.00',
                keyboard: numKb,
                formatters: [_money],
                suffix: '₹/g',
                validator: (v) => _positive(v, 'rate'),
              ),
              const SizedBox(height: 12),
            ],

            _field(
              label: 'Reference / remarks',
              controller: _remarksCtrl,
              hint: 'Optional',
              caps: TextCapitalization.sentences,
              action: TextInputAction.done,
            ),
            const SizedBox(height: 14),

            /// RESULT
            _resultBox(),
            const SizedBox(height: 12),

            /// LIVE QUOTE (image jevu)
            if (_type.isConversion) ...[
              _quoteBox(),
              const SizedBox(height: 12),
            ],

            /// AFTER SAVING
            _afterSaving(),
            const SizedBox(height: 12),

            /// CONFIRM
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _confirmed = !_confirmed),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
                decoration: BoxDecoration(
                  color: _confirmed
                      ? _C.success.withValues(alpha: 0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _confirmed,
                      activeColor: _C.success,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      onChanged: (v) =>
                          setState(() => _confirmed = v ?? false),
                    ),
                    Expanded(
                      child: Text(
                        _type.isConversion
                            ? 'I have checked the transaction and conversion rate.'
                            : 'I have checked the transaction.',
                        style: const TextStyle(
                          color: _C.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            /// SAVE (fakt API nu loader)
            _SaveButton(enabled: _confirmed, onPressed: _submit),
          ],
        ),
      ),
    );
  }

  /// 💳 PAYMENT MODE — Cash / Bank / UPI
  Widget _paymentModeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Payment mode'),
        DropdownButtonFormField<PaymentMode>(
          key: ValueKey('pay-${_payMode.name}'),
          value: _payMode,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _C.muted, size: 20),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          decoration: _decoration(),
          style: const TextStyle(
            color: _C.text,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final m in PaymentMode.values)
              DropdownMenuItem<PaymentMode>(
                value: m,
                child: Row(
                  children: [
                    Icon(m.icon, size: 16, color: _C.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(m.label,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (m) {
            if (m != null) setState(() => _payMode = m);
          },
        ),
      ],
    );
  }

  Widget _transactionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Transaction'),
        DropdownButtonFormField<EntryType>(
          key: ValueKey('txn-${_type.name}'),
          value: _type,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.muted),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          decoration: _decoration(),
          style: const TextStyle(
            color: _C.text,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          selectedItemBuilder: (_) => [
            for (final t in EntryType.values)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(t.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          items: [
            for (final t in EntryType.values)
              DropdownMenuItem<EntryType>(
                value: t,
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: t == _type
                          ? const Icon(Icons.check_rounded,
                          size: 16, color: _C.primary)
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        t.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                          t == _type ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (t) {
            if (t != null) _changeType(t);
          },
        ),
      ],
    );
  }

  Widget _resultBox() {
    String title;
    String value;
    String sub;

    switch (_type) {
      case EntryType.toRupees:
        title = 'Amount credited';
        value = '₹ ${_inr(_amount)}';
        sub = 'Fine ${_fmt(_fine, 3)} g × ₹${_fmt(_rate, 2)}';
        break;
      case EntryType.toMetal:
        title = 'Fine metal credited';
        value = '${_fmt(_fine, 3)} g';
        sub = '₹${_inr(_amount)} ÷ ₹${_fmt(_rate, 2)}';
        break;
      case EntryType.receiveCash:
        title = 'Cash received';
        value = '₹ ${_inr(_amount)}';
        sub = 'Cash balance increases';
        break;
      case EntryType.returnCash:
        title = 'Cash returned';
        value = '₹ ${_inr(_amount)}';
        sub = 'Cash balance decreases';
        break;
      case EntryType.receiveMetal:
        title = 'Fine ${_metal.label.toLowerCase()} received';
        value = '${_fmt(_fine, 3)} g';
        sub = '${_fmt(_v(_weightCtrl), 3)} g × ${_fmt(_v(_purityCtrl), 2)}%';
        break;
      case EntryType.returnMetal:
        title = 'Fine ${_metal.label.toLowerCase()} returned';
        value = '${_fmt(_fine, 3)} g';
        sub = '${_fmt(_v(_weightCtrl), 3)} g × ${_fmt(_v(_purityCtrl), 2)}%';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: _C.headerGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _C.g2.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11.5)),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11)),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _type.isConversion
                  ? Icons.swap_horiz_rounded
                  : Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  /// 📈 LIVE QUOTE BOX (image jevu)
  Widget _quoteBox() {
    final q = _quote;
    final unitLabel = _units[_quoteUnit] ?? '$_quoteUnit grams';
    final head = q == null
        ? 'Live ${_metal.label.toLowerCase()} quote not available'
        : '${q.symbol}  |  Quote: INR ${_inr(q.rate, 0)}';
    final status = _loadingRates ? 'Fetching latest rate…' : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: q == null ? _C.muted : _C.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  head,
                  maxLines: 2,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 3),
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Text('Fetching latest rate…',
                  style: TextStyle(color: _C.primary, fontSize: 11)),
            ),
          ] else if (_rates?.updatedAt != null) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                'Retrieved: ${_rates!.updatedAt}'
                    '${_rates?.source == null ? '' : '  ·  ${_rates!.source}'}',
                style: const TextStyle(color: _C.muted, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Quote weight unit'),
                    DropdownButtonFormField<int>(
                      key: ValueKey('unit-$_quoteUnit-${_metal.name}'),
                      value: _units.containsKey(_quoteUnit) ? _quoteUnit : 10,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _C.muted, size: 20),
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: Colors.white,
                      decoration: _decoration(),
                      style: const TextStyle(color: _C.text, fontSize: 13),
                      items: [
                        for (final e in _units.entries)
                          DropdownMenuItem<int>(
                              value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (u) {
                        if (u == null) return;
                        setState(() => _quoteUnit = u);
                        _applyQuote();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  label: 'Quote purity',
                  controller: _quotePurityCtrl,
                  keyboard:
                  const TextInputType.numberWithOptions(decimal: true),
                  formatters: [_money],
                  suffix: '%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _useLatestQuote,
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: Text('Use latest quote  ·  $unitLabel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.primary,
              backgroundColor: Colors.white,
              side: BorderSide(color: _C.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Confirm the quoted unit and purity before saving. Rate = quote ÷ weight ÷ purity fraction. You may enter an agreed rate manually.',
            style: TextStyle(color: _C.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// AFTER SAVING (image jevu, left patti sathe)
  Widget _afterSaving() {
    Color tone(double v) => v < 0 ? _C.danger : _C.text;
    final g = _metalAfter(MetalType.gold);
    final s = _metalAfter(MetalType.silver);

    String? conversion;
    if (_type == EntryType.toMetal) {
      conversion = '₹${_inr(_amount)} → ${_fmt(_fine, 3)} g';
    } else if (_type == EntryType.toRupees) {
      conversion = '${_fmt(_fine, 3)} g → ₹${_inr(_amount)}';
    }

    Widget cell(String label, String value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: _C.muted, fontSize: 10.5)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: _C.tile,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: _C.gradient,
                borderRadius:
                BorderRadius.horizontal(left: Radius.circular(10)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AFTER SAVING',
                        style: TextStyle(
                          color: _C.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        )),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        cell('Cash', '₹${_inr(_cashAfter)}', tone(_cashAfter)),
                        cell('Gold', '${_fmt(g, 3)} g', tone(g)),
                        cell('Silver', '${_fmt(s, 3)} g', tone(s)),
                      ],
                    ),
                    if (conversion != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.swap_horiz_rounded,
                              size: 14, color: _C.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Conversion: $conversion',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _C.muted, fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField() {
    final d = '${_date.day.toString().padLeft(2, '0')}-'
        '${_date.month.toString().padLeft(2, '0')}-${_date.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Date'),
        InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: _pickDate,
          child: InputDecorator(
            decoration: _decoration(
              suffix: const Icon(Icons.calendar_month_rounded,
                  size: 18, color: _C.primary),
            ),
            child:
            Text(d, style: const TextStyle(color: _C.text, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _metalPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Metal'),
        Container(
          height: 41,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _C.tile,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            children: [
              for (final m in MetalType.values)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _changeMetal(m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _metal == m ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _metal == m ? m.color : Colors.transparent,
                          width: 1.3,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: m.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            m.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _metal == m
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _metal == m ? _C.text : _C.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// =========================================================
  /// 🔥 LOAD BRANCHES (Sale Summary jevu j)
  /// =========================================================

  Future<void> _loadBranches() async {
    setState(() => branchesLoading = true);

    try {
      // 🔐 Fakt main company admin ne j Branch Reports dekhay
      final bool isAdmin = await BranchAccess.isMainCompanyAdmin();
      if (!isAdmin) {
        if (mounted) setState(() => canViewBranches = false);
        return;
      }

      final overview = await BranchApi.fetchOverview();

      if (!mounted) return;

      final List<Company> list = [
        if (overview.mainCompany != null) overview.mainCompany!,
        ...overview.branches,
      ];

      setState(() {
        branchCompanies = list;

        // Main company + ek branch hoy tyare j tab dekhay
        canViewBranches = list.length > 1;

        // Default: main company select
        selectedCompanyIds = {
          if (overview.mainCompany != null) overview.mainCompany!.id,
        };
      });
    } catch (e) {
      // Branch access nathi (branch user / staff) → tab nahi dekhay
      debugPrint("❌ Branch list load failed: $e");
      if (mounted) setState(() => canViewBranches = false);
    } finally {
      if (mounted) setState(() => branchesLoading = false);
    }
  }

  String _companyLabel(Company c) =>
      c.isMain ? "${c.name} (Main Company)" : c.name;

  /// From / To date (dd-MM-yyyy → yyyy-MM-dd), khotu hoy to null

  /// Bullion list farithi (branch mujab)
  Future<void> _reloadBullion() async {
    // 🔥 Badhi bullion API ma e j branch jay
    BullionApi.branchQuery = _branchMode ? _branchQuery : '';
    await _loadPersons();
  }

  Future<void> viewBranchReport() async {
    if (selectedCompanyIds.isEmpty) {
      AppMessage.error(context, "Please select at least one branch");
      return;
    }

    setState(() {
      appliedCompanyIds = selectedCompanyIds.toList();
      branchReportLoading = true;
    });

    try {
      await _reloadBullion();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadBullion();
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (expand tab) — Sale Summary jevu j
  // ============================================================

  Widget _buildBranchCard() {
    if (branchesLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: _branchCardDecoration(),
        child: Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Loading branches...",
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (!canViewBranches) return const SizedBox.shrink();

    final selectedList =
    branchCompanies.where((c) => selectedCompanyIds.contains(c.id)).toList();

    final bool appliedDiffers = appliedCompanyIds.toSet().length !=
        selectedCompanyIds.length ||
        !appliedCompanyIds.toSet().containsAll(selectedCompanyIds);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _branchCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- HEADER (tap = expand) ----------------
          InkWell(
            onTap: () => setState(() => branchExpanded = !branchExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.secondaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.account_tree_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Branch Reports",
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${selectedCompanyIds.length}/${branchCompanies.length}",
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: branchExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- BODY ----------------
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !branchExpanded
                ? const SizedBox(width: double.infinity)
                : Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Multi select box
                  InkWell(
                    onTap: _openBranchPicker,
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: selectedList.isEmpty
                                ? Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                "Select branches",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            )
                                : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final c in selectedList)
                                  _branchChip(c),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Select one or more branches to see their bullions.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _viewReportButton(highlight: appliedDiffers),

                  // Branch report chalu hoy tyare info + clear
                  if (_branchMode) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xff16A34A).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xff16A34A).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: Color(0xff16A34A),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Showing bullions of "
                                  "${appliedCompanyIds.length} "
                                  "${appliedCompanyIds.length == 1 ? 'branch' : 'branches'}",
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xff166534),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: clearBranchReport,
                            style: TextButton.styleFrom(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "Clear",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xffD32F2F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchChip(Company c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            c.isMain ? Icons.verified_rounded : c.type.icon,
            size: 13,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _companyLabel(c),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: () => setState(() => selectedCompanyIds.remove(c.id)),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewReportButton({required bool highlight}) {
    return InkWell(
      onTap: branchReportLoading ? null : viewBranchReport,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff22C55E), Color(0xff16A34A)],
          ),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color:
              const Color(0xff16A34A).withOpacity(highlight ? 0.35 : 0.15),
              blurRadius: highlight ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: branchReportLoading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics_rounded, size: 17, color: Colors.white),
              SizedBox(width: 6),
              Text(
                "View",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔥 Multi-select bottom sheet
  Future<void> _openBranchPicker() async {
    final Set<int> temp = {...selectedCompanyIds};

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final bool allSelected = temp.length == branchCompanies.length;

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Select Branches",
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff172033),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheet(() {
                                if (allSelected) {
                                  temp.clear();
                                } else {
                                  temp.addAll(branchCompanies.map((c) => c.id));
                                }
                              });
                            },
                            child: Text(
                              allSelected ? "Clear All" : "Select All",
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: branchCompanies.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade200,
                        ),
                        itemBuilder: (context, i) {
                          final c = branchCompanies[i];
                          final bool checked = temp.contains(c.id);

                          return InkWell(
                            onTap: () => setSheet(() {
                              checked ? temp.remove(c.id) : temp.add(c.id);
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryDark
                                          .withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      c.isMain
                                          ? Icons.verified_rounded
                                          : c.type.icon,
                                      size: 17,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _companyLabel(c),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xff172033),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            c.isMain ? "Main" : c.type.label,
                                            if (c.city != null) c.city!,
                                            if (!c.active) "Inactive",
                                          ].join(" • "),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: c.active
                                                ? Colors.grey.shade600
                                                : Colors.red.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration:
                                    const Duration(milliseconds: 150),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: checked
                                          ? AppColors.gradientBlue
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: checked
                                            ? AppColors.gradientBlue
                                            : Colors.grey.shade400,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: checked
                                        ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.border),
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => Navigator.pop(sheetContext, temp),
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryDark,
                                      AppColors.secondaryDark,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Center(
                                  child: Text(
                                    "Done (${temp.length})",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => selectedCompanyIds = result);
    }
  }

  BoxDecoration _branchCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.primaryDark.withOpacity(0.12)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? suffix,
    String? Function(String?)? validator,
    TextCapitalization caps = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboard,
          inputFormatters: formatters,
          textCapitalization: caps,
          textInputAction: action,
          style: const TextStyle(color: _C.text, fontSize: 13.5),
          decoration: _decoration(
            hint: hint,
            suffix: suffix == null
                ? null
                : Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(suffix,
                  style: const TextStyle(
                      color: _C.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Widgets
// ============================================================================
InputDecoration _decoration({String? hint, Widget? suffix}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFB4BACB), fontSize: 13),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    errorStyle: const TextStyle(fontSize: 11),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border(_C.border),
    disabledBorder: border(_C.border),
    focusedBorder: border(_C.primary, 1.3),
    errorBorder: border(_C.danger),
    focusedErrorBorder: border(_C.danger, 1.3),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(text,
        style: const TextStyle(
            color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w500)),
  );
}

class _QuickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _QuickButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            gradient: selected ? _C.gradient : null,
            color: selected ? null : _C.tile,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: selected ? Colors.transparent : _C.border),
            boxShadow: selected
                ? [
              BoxShadow(
                color: _C.g2.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15, color: selected ? Colors.white : _C.primary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : _C.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final List<Widget> actions;
  const _Header({required this.onBack, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    const radius = BorderRadius.vertical(bottom: Radius.circular(22));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _C.headerGradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: _C.g2.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(right: -30, top: -40, child: _glow(130, 0.10)),
            Positioned(left: -20, bottom: -60, child: _glow(110, 0.06)),
            Padding(
              padding: EdgeInsets.fromLTRB(14, top + 8, 14, 16),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onBack,
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BULLION BALANCES & TRANSACTIONS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Bullion Management',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ✅ EXCEL + PDF
                  ...actions,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

// ============================================================================
// 💳 CASH — premium gradient card
// ============================================================================
class _CashHeroCard extends StatelessWidget {
  final double value;
  final String personName;

  const _CashHeroCard({required this.value, required this.personName});

  @override
  Widget build(BuildContext context) {
    final negative = value < 0;

    return Container(
      decoration: BoxDecoration(
        gradient: _C.headerGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _C.g2.withValues(alpha: 0.32),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned(right: -40, top: -50, child: _ring(150, 0.10)),
            Positioned(right: 40, bottom: -70, child: _ring(120, 0.07)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white, size: 17),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CASH BALANCE',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              personName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'INR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _inr(value),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        negative
                            ? Icons.south_east_rounded
                            : Icons.north_east_rounded,
                        size: 13,
                        color: negative
                            ? const Color(0xFFFFB4B4)
                            : const Color(0xFFB8F5CB),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        negative ? 'Payable to bullion' : 'Available cash',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

// ============================================================================
// 🥇 GOLD / 🥈 SILVER — metallic card
// ============================================================================
class _MetalCard extends StatelessWidget {
  final String label;
  final double value;
  final List<Color> colors;
  final Color ink;
  final IconData icon;

  const _MetalCard({
    required this.label,
    required this.value,
    required this.colors,
    required this.ink,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors[1].withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              left: -30,
              top: -20,
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: 60,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.35),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -18,
              bottom: -18,
              child: Icon(icon, size: 70, color: ink.withValues(alpha: 0.08)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 15, color: ink),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _inr(value, 3),
                          style: TextStyle(
                            color: ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'g',
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fine weight',
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.65),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 📒 LEDGER CARD (web table ni ek row = mobile ma ek card)
// ============================================================================
class _LedgerCard extends StatelessWidget {
  final LedgerEntry entry;
  const _LedgerCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final isGold = e.metalType == 'gold';
    final metalColor = e.metalType == null
        ? _C.muted
        : (isGold ? MetalType.gold.color : MetalType.silver.color);
    final hasMetal = e.metalIn > 0 || e.metalOut > 0;
    final hasCash = e.cashIn > 0 || e.cashOut > 0;

    Color tone(double v) => v < 0 ? _C.danger : _C.text;

    Widget kv(String label, String value, {Color? color, bool bold = false}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: _C.muted, fontSize: 10.5)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: color ?? _C.text,
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: _C.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// TOP — date + type
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: _C.gradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    e.entryType.startsWith('convert')
                        ? Icons.swap_horiz_rounded
                        : (e.cashIn > 0 || e.metalIn > 0
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded),
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.timeText.isEmpty
                            ? e.dateText
                            : '${e.dateText}  ·  ${e.timeText}',
                        style: const TextStyle(color: _C.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (e.metalType != null)
                  _chip(e.metalType![0].toUpperCase() + e.metalType!.substring(1),
                      metalColor),
                if (e.paymentMode != null) ...[
                  const SizedBox(width: 4),
                  _chip(e.paymentMode!.toUpperCase(), _C.primary),
                ],
              ],
            ),
          ),

          /// IN / OUT
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              color: _C.tile,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    kv('Cash in', '₹${_inr(e.cashIn)}',
                        color: e.cashIn > 0 ? _C.success : _C.muted),
                    kv('Cash out', '₹${_inr(e.cashOut)}',
                        color: e.cashOut > 0 ? _C.danger : _C.muted),
                    kv('Rate (₹/g)', e.rate > 0 ? _fmt(e.rate, 2) : '-'),
                  ],
                ),
                if (hasMetal || !hasCash) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      kv('Fine in', '${_fmt(e.metalIn, 3)} g',
                          color: e.metalIn > 0 ? _C.success : _C.muted),
                      kv('Fine out', '${_fmt(e.metalOut, 3)} g',
                          color: e.metalOut > 0 ? _C.danger : _C.muted),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ],
            ),
          ),

          /// BALANCE (aa entry pachhi)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                kv('Cash bal.', '₹${_inr(e.cashBalance)}',
                    color: tone(e.cashBalance), bold: true),
                kv('Gold bal.', '${_fmt(e.goldBalance, 3)} g',
                    color: tone(e.goldBalance), bold: true),
                kv('Silver bal.', '${_fmt(e.silverBalance, 3)} g',
                    color: tone(e.silverBalance), bold: true),
              ],
            ),
          ),

          /// REMARKS
          if (e.remarks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 14, color: _C.muted),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      e.remarks,
                      style: const TextStyle(
                          color: _C.muted, fontSize: 11.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color == MetalType.silver.color
            ? const Color(0xFF55616E)
            : color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _LedgerEmpty extends StatelessWidget {
  final String text;
  const _LedgerEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: _C.primary, size: 22),
          ),
          const SizedBox(height: 10),
          const Text(
            'No data found',
            style: TextStyle(
              color: _C.text,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: _C.softShadow,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: _C.bar,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                color: _C.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _SaveButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: enabled
                ? [
              BoxShadow(
                color: _C.success.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onPressed,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 7),
                  Text(
                    'Save Bullion Entry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}