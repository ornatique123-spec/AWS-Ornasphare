import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../Extra/AppColors.dart';
import '../../Stock Gallary/ImageSearchScreen.dart';
import '../AppNavigatorAi.dart';
import '../Stock Postition/StockPositionAi.dart';
import '../VoucherDetails.dart';
import 'Barcode/BarcodeAi.dart';
import 'package:provider/provider.dart';
import '../../Extra/ItemProvider.dart';
import 'BranchWise/BranchAi.dart';
import 'Date/DateAi.dart';
import 'Jobwork/JobWorkAi.dart';
import 'Casting/CastingAi.dart';
import 'core/AiEnglish.dart';
import 'core/AiPdf.dart';
import 'core/AiGraph.dart';
import 'Report/AiReportBuilder.dart';
import 'core/AiTranslator.dart';
import 'core/VoiceBrain.dart';
import 'core/VoiceLearn.dart';
import 'stock_ai_repository.dart';
import 'core/ai_core.dart';
import 'core/ai_modules.dart';

/// =======================================================================
///  ASK AI — ek j screen, badha module (Stock, Sales, ...)
///
///  Drawer thi:      AskAiScreen()                          // Stock
///  Sales page thi:  AskAiScreen(initialModule: 'sales', autoListen: true)
///
///  • Upar chips thi module badlo — athva sidhu puchho, sawal joi ne
///    AI pote j saro module pasand kare (auto-routing).
///  • Hands-free 🎧: jawab bolya pachhi mic pote chalu thay.
/// =======================================================================
class AskAiScreen extends StatefulWidget {
  final String initialModule;
  final bool autoListen;

  /// Answer ma date range hoy tyare "Report ma kholo" button batave.
  /// Udaharan: Sales Summary screen ne e date thi kholo.
  final void Function(BuildContext context, String moduleId, AiPeriod period)? onOpenPeriod;

  const AskAiScreen({
    super.key,
    this.initialModule = 'stock',
    this.autoListen = false,
    this.onOpenPeriod,
  });

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _ChatMsg {
  final String? userText;
  final AiAnswer? answer;
  final String? moduleId;
  final bool routed;

  /// 🎤 mic thi aavyo hoy to ✏️ sudharo batavo
  final bool voice;

  /// 🎤 mic e kharekhar shu lakhyu hatu (sudharya pehla) — alag hoy to j
  final String? heard;

  /// 🌐 local language question → English (je samjine javab aapyo)
  String? meaning;
  _ChatMsg.user(this.userText, {this.voice = false, this.heard})
      : answer = null,
        moduleId = null,
        routed = false;
  _ChatMsg.ai(this.answer, this.moduleId, {this.routed = false})
      : userText = null,
        voice = false,
        heard = null;
  bool get isUser => userText != null;
}

class _AskAiScreenState extends State<AskAiScreen> with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  /// ✏️ mic no khoto text sudharva lidho hoy to e mul text (sikhva mate)
  String? _editFrom;

  /// ⏱️ Mic e text box ma lakhyu → thodi var pachhi pote mokle
  ///    (vachche text par tap karo to roke, sudhari ne moklo)
  Timer? _autoSend;
  String? _pendingHeard;
  // ⚡ FAST: text box ma dekhay pachhi aatla time ma pote mokle (tap karo to roke)
  static const Duration _autoSendDelay = Duration(milliseconds: 600);

  // ⚡ FAST: chhello shabd bolya pachhi aatli shanti → turat sambhdvanu bandh
  static const Duration _quietGap = Duration(milliseconds: 1100);
  Timer? _quietTimer;
  late final AnimationController _pulse =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  List<AiModule> _modules = [];
  late String _currentId = widget.initialModule;
  final Set<String> _loading = {};
  final Map<String, String> _errors = {};
  int _loadDone = 0, _loadTotal = 0;

  /// ⏳ ONE loader only — the first time the screen opens
  bool _firstLoad = true;

  /// ⚡ Modules stay loaded between visits (same app session, same permissions)
  static List<AiModule>? _modCache;
  static String? _modCacheKey;
  static DateTime? _modCacheAt;
  static const Duration _modCacheLife = Duration(minutes: 10);

  final List<_ChatMsg> _msgs = [];
  bool _thinking = false;

  bool _speechReady = false;
  bool _listening = false;
  bool _speaking = false;
  String _partial = '';
  double _level = 0;
  bool _speakOn = true;
  bool _handsFree = false;

  /// 🔎 Upar "Barcode" chip select hoy tyare — badhu barcode tarike shodho
  bool _barcodeMode = false;
  final List<String> _recentCodes = [];

  /// 📦 Upar "Stock Position" chip — item / category bolo etle badhi vigat
  bool _stockPosMode = false;

  /// 🛠️ Upar "Job Work" chip — job work issue / receive / pending (worker wise)
  bool _jobMode = false;

  /// 🔥 Upar "Casting" chip — heating · metal issue · receive · tree cutting · sorting
  bool _castMode = false;

  /// 🏢 Upar "Branch" chip (main company admin only) — every question → selected branches
  bool _branchMode = false;
  bool get _toolMode => _barcodeMode || _stockPosMode || _jobMode || _castMode || _branchMode;

  /// 🧩 "All" chip (default): ek page thi badhu — sawal jova thi module pote pasand.
  ///    Koi module chip dabavo → e module ma j (pehla jevu).
  bool _allMode = true;
  int _emptyListens = 0;

  /// 🔥 Engine no chhello result (alternates sathe) — final text ahi thi lo
  SpeechRecognitionResult? _lastResult;

  /// 🔥 "notListening" status pachhi final result thodo moda aave che,
  /// etle turat partial text mokalva ne badle thodi rah juo
  Timer? _finalWait;

  /// Phone ma kai mic language install che
  final Set<String> _deviceLocales = {};

  String _localeId = 'en_IN';

  /// 🌐 Answers are ALWAYS in English (question can be in any language).
  ///    To allow other answer languages later, return _answerPref here.
  String _answerPref = 'en';
  String get _answerLang => 'en';
  static const Map<String, String> _locales = {
    'en_IN': 'English / Gujlish',
    'gu_IN': 'ગુજરાતી',
    'hi_IN': 'हिंदी',
  };

  AiModule? get _current {
    for (final m in _modules) {
      if (m.id == _currentId) return m;
    }
    return _modules.isEmpty ? null : _modules.first;
  }

  // -------------------- theme --------------------
  Color _lighten(Color c, double a) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  // ✨ PREMIUM palette — navy + gold (same as the voucher popup)
  // ✨ LIGHT BLUE premium palette (names kept so nothing else changes)
  static const Color _navy = Color(0xff1D4ED8); // deep blue
  static const Color _navy2 = Color(0xff3B82F6); // primary blue
  static const Color _gold = Color(0xff60A5FA); // accent blue
  static const Color _goldLight = Color(0xffDBEAFE);
  static const Color _goldSoft = Color(0xffEFF6FF);
  static const Color _ivory = Color(0xffF4F8FF);
  static const Color _hair = Color(0xffDCE7F7);

  Color get _blue => _navy2;
  Color get _blueSoft => const Color(0xffD6E6FF);
  Color get _blueSofter => const Color(0xffEEF5FF);

  /// ⌨️ keyboard band (voucher / card / list par tap thay tyare)
  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_inputFocus.hasFocus) _inputFocus.unfocus();
    // 🔒 make sure the soft keyboard really closes (some Android keyboards stay open)
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  // =====================================================================
  //  LIFECYCLE
  // =====================================================================
  @override
  void initState() {
    super.initState();
    _setup();
    // 🏢 admin? → branch chip appears
    BranchAi.init().then((_) {
      if (mounted && BranchAi.canUse) setState(() {});
    });
  }

  Future<void> _setup() async {
    final prefs = await SharedPreferences.getInstance();
    final perms = prefs.getStringList('user_permissions') ?? [];
    _localeId = prefs.getString('ai_mic_locale') ?? _localeId;
    if (_localeId != 'en_IN') AiTranslator.ensureModel(_localeId.substring(0, 2));
    final key = perms.join('|');
    final reuse = _modCache != null &&
        _modCacheKey == key &&
        _modCacheAt != null &&
        DateTime.now().difference(_modCacheAt!) < _modCacheLife;
    if (reuse) {
      _modules = _modCache!; // ⚡ already loaded — opens instantly
    } else {
      final all = AiModules.create();
      final allowed = perms.isEmpty ? all : all.where((m) => m.allowed(perms)).toList();
      _modules = allowed;
      _modCache = allowed;
      _modCacheKey = key;
      _modCacheAt = DateTime.now();
    }
    if (!_modules.any((m) => m.id == _currentId) && _modules.isNotEmpty) {
      _currentId = _modules.first.id;
    }
    if (mounted) setState(() {});

    // 🧭 boli ne screen kholva customer list joie
    if (mounted) Provider.of<ItemProvider>(context, listen: false).loadCustomers();
    // 🧩 ONE PAGE, ONE LOADER: data + mic + voice all start together
    await Future.wait([
      _loadAll(),
      _initSpeech(),
      _initTts(),
      VoiceLearn.load(),
    ]);
    if (mounted) setState(() => _firstLoad = false);
    _buildVocab(); // stock list is already in memory → instant
    if (widget.autoListen && mounted) _startListening();
  }

  /// Badha module parallel ma load → ek j welcome
  Future<void> _loadAll({bool force = false}) async {
    if (force) StockAiRepository.clearCache();
    await Future.wait([
      ..._modules.map((m) => _ensureLoaded(m, force: force)),
      // stock list shared by Stock module, voice dictionary and screen opener
      StockAiRepository.loadAll(force: force).then((_) {}, onError: (_) {}),
    ]);
    if (!mounted) return;
    setState(() => _addAi(force ? _refreshedMsg() : _welcomeAll(), null));
    _scrollDown();
  }

  AiAnswer _welcomeAll() {
    final ok = _modules.where((m) => m.isLoaded).toList();
    final bad = _modules.where((m) => !m.isLoaded).toList();
    return AiAnswer(
      text: '👋 Ask me anything in one place — ${ok.map((m) => m.title).join(', ')}, '
          'barcode history, stock position and date-wise reports.\n'
          'You can ask in English, Gujarati, Hindi or Gujlish — by voice or typing.'
          '${bad.isEmpty ? '' : '\n⚠️ Could not load: ${bad.map((m) => m.title).join(', ')}. Use ⋮ → Refresh data.'}',
      speech: 'Ask me anything about ${ok.map((m) => m.title).join(', ')}.',
      followUps: [
        for (final m in ok)
          if (m.suggestions.isNotEmpty) m.suggestions.first,
        'Sales today',
        'Where is BR8',
        'Stock position total',
      ],
    );
  }

  AiAnswer _refreshedMsg() {
    final bad = _modules.where((m) => !m.isLoaded).toList();
    return AiAnswer(
      text: bad.isEmpty
          ? '✅ All data refreshed.'
          : '⚠️ Refreshed, but could not load: ${bad.map((m) => m.title).join(', ')}.',
      speech: bad.isEmpty ? 'All data refreshed.' : 'Some data could not be loaded.',
    );
  }

  @override
  void dispose() {
    _finalWait?.cancel();
    _quietTimer?.cancel();
    _autoSend?.cancel();
    AiTranslator.dispose();
    _speech.stop();
    _tts.stop();
    _pulse.dispose();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<bool> _ensureLoaded(AiModule m, {bool force = false, bool showWelcome = false}) async {
    if (m.isLoaded && !force) return true;
    if (_loading.contains(m.id)) return false;
    setState(() {
      _loading.add(m.id);
      _errors.remove(m.id);
      _loadDone = 0;
      _loadTotal = 0;
    });
    try {
      await m.load(
        force: force,
        onProgress: (d, t) {
          if (mounted) setState(() {
            _loadDone = d;
            _loadTotal = t;
          });
        },
      );
      if (showWelcome) _addAi(m.welcome(), m.id);
    } catch (e) {
      _errors[m.id] = 'Could not load ${m.title} data.\n$e';
    }
    if (mounted) setState(() => _loading.remove(m.id));
    _scrollDown();
    return m.isLoaded;
  }

  Future<void> _switchModule(AiModule m) async {
    if (_allMode) {
      setState(() => _allMode = false);
      if (m.id == _currentId && m.isLoaded) {
        setState(() => _addAi(m.welcome(), m.id));
        _scrollDown();
        return;
      }
    }
    if (_toolMode) {
      setState(() {
        _barcodeMode = false;
        _stockPosMode = false;
        _jobMode = false;
        _castMode = false;
        _branchMode = false;
      });
      if (m.id == _currentId) {
        setState(() => _addAi(m.welcome(), m.id));
        _scrollDown();
        return;
      }
    }
    if (m.id == _currentId) return;
    setState(() => _currentId = m.id);
    if (!m.isLoaded) {
      await _ensureLoaded(m, showWelcome: true);
    } else {
      setState(() => _addAi(m.welcome(), m.id));
      _scrollDown();
    }
  }

  // =====================================================================
  //  VOICE
  // =====================================================================
  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (s) {
          // 🔥 FIX: turat finish nahi — final result aavva do (max 700ms)
          if ((s == 'done' || s == 'notListening') && _listening) _waitForFinal();
        },
        onError: (e) {
          if (!mounted) return;
          // 🔥 FIX: error aavyo pan kaik sambhdayu hatu to e text gumavo nahi
          if (_listening && _partial.trim().isNotEmpty) {
            _finishListening();
            return;
          }
          _pulse.stop();
          setState(() => _listening = false);
          if (e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout') {
            _emptyListens++;
            if (!_handsFree) _toast('I did not hear anything, please speak again 🎤');
          } else {
            _toast('Mic error: ${e.errorMsg}');
          }
        },
      );
    } catch (_) {
      _speechReady = false;
    }

    if (_speechReady && _deviceLocales.isEmpty) {
      try {
        final list = await _speech.locales();
        _deviceLocales.addAll(list.map((l) => l.localeId.replaceAll('-', '_')));
        debugPrint('🎤 Phone ma mic languages: ${_deviceLocales.join(', ')}');
      } catch (_) {}
    }
  }

  /// Phone ma aa language nu speech model che?
  bool _localeAvailable(String id) =>
      _deviceLocales.isEmpty || _deviceLocales.contains(id);

  void _waitForFinal() {
    _finalWait?.cancel();
    _finalWait = Timer(const Duration(milliseconds: 350), _finishListening);
  }

  /// 🔥 Engine 3-5 andaj (alternates) aape che. Je andaj tamara data
  /// (item naam, label code, keyword) sathe sauthi vadhu match thay te lo —
  /// fakt pehlo nahi.
  String _bestText() {
    final fallback = _partial.trim();
    final r = _lastResult;
    if (r == null || r.alternates.isEmpty) return VoiceLearn.apply(fallback);

    String best = r.alternates.first.recognizedWords.trim();
    num bestScore = -1;

    for (final alt in r.alternates) {
      // 🔥 tame pehla sudharela shabdo pehla lagavo
      final words = VoiceLearn.apply(alt.recognizedWords.trim());
      if (words.isEmpty) continue;
      final t = AiText.normalize(words);
      num score = 0;
      for (final m in _modules) {
        final s = m.relevance(t);
        if (s > score) score = s;
      }
      // 📅 "aaje / kale / umerayo / vechayu" samjay te andaj ne vadhu gun
      score += DateAi.relevance(words);
      // 🧠 tamara item / customer / command na shabdo vadhu hoy e andaj sacho
      score += VoiceBrain.coverage(VoiceBrain.correct(words)) * 3;
      debugPrint('🎤 ALT "$words" conf=${alt.confidence.toStringAsFixed(2)} score=$score');
      // ">" — barabar score hoy to engine no pehlo (vadhu confident) andaj rahe
      if (score > bestScore) {
        bestScore = score;
        best = words;
      }
    }
    return best.isEmpty ? fallback : best;
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-IN');
      await _pickEnglishVoice();
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);
      _tts.setStartHandler(() {
        if (mounted) setState(() => _speaking = true);
      });
      _tts.setCompletionHandler(_afterSpeak);
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
    } catch (_) {}
  }

  void _afterSpeak() {
    if (!mounted) return;
    setState(() => _speaking = false);
    // Hands-free: jawab pachhi pote sambhdvanu chalu (2 var khali gayu to bandh)
    if (_handsFree && _emptyListens < 2 && !_listening) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && _handsFree && !_listening) _startListening();
      });
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      _waitForFinal(); // 🔥 stop pachhi pan final result aave che
    } else {
      _emptyListens = 0;
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_modules.any((m) => m.isLoaded)) return;
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        _toast('Please allow mic permission / turn on Google speech service');
        return;
      }
    }
    await _tts.stop();
    HapticFeedback.lightImpact();
    _finalWait?.cancel();
    _quietTimer?.cancel();
    _autoSend?.cancel();
    _autoSend = null;
    _pendingHeard = null;
    if (VoiceBrain.size < 120) _buildVocab();
    _lastResult = null;
    setState(() {
      _listening = true;
      _speaking = false;
      _partial = '';
      _level = 0;
    });
    _pulse.repeat(reverse: true);
    _scrollDown();

    await _speech.listen(
      onResult: (SpeechRecognitionResult r) {
        if (!mounted) return;
        _lastResult = r;
        // ⚡ words aave etle timer fari chalu — 1.1 sec shanti = bolvanu puru
        _quietTimer?.cancel();
        if (!r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          _quietTimer = Timer(_quietGap, () async {
            if (!mounted || !_listening) return;
            await _speech.stop();
            _waitForFinal(); // final result aave to e, nahi to 350 ms pachhi partial j
          });
        }
        setState(() {
          _partial = r.recognizedWords;
          // ⌨️ bolta bolta j text box ma lakhay
          _input.value = TextEditingValue(
            text: r.recognizedWords,
            selection: TextSelection.collapsed(offset: r.recognizedWords.length),
          );
        });
        if (r.finalResult) _finishListening();
      },
      onSoundLevelChange: (l) {
        if (mounted && _listening) setState(() => _level = l.clamp(0.0, 12.0) / 12.0);
      },
      localeId: _localeId,
      listenFor: const Duration(seconds: 25),
      // 🎤 fallback (engine side) — main end detection upar _quietGap thi (1.1 sec)
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        // 🔥 FIX: "confirmation" yes/no jeva nana javab mate che.
        // Sawal/query mate "search" model vadhu sacho che.
        listenMode: stt.ListenMode.search,
      ),
    );
  }

  Future<void> _finishListening() async {
    _finalWait?.cancel();
    _quietTimer?.cancel();
    if (!_listening) return;
    _pulse.stop();
    final heard = (_lastResult?.recognizedWords ?? _partial).trim(); // mic nu kachu
    var best = _bestText(); // sacho andaj + sikhela sudhara
    // 🌐 Gujarati / Hindi script → proper English sentence in the text box
    //    (item / customer names are protected, then corrected with your data)
    if (AiTranslator.scriptOf(best) != null) {
      setState(() => _listening = false);
      final en = await AiTranslator.toEnglish(best);
      if (!mounted) return;
      if (en != null && en.trim().isNotEmpty) best = en.trim();
    }
    final text = VoiceBrain.correct(best); // 🧠 tamara data sathe sudharo
    debugPrint('🎤 HEARD => "$heard"');
    debugPrint('🎤 FINAL TEXT => "$text"');
    setState(() {
      _listening = false;
      _partial = '';
      _level = 0;
    });
    if (text.isEmpty) {
      _input.clear();
      _emptyListens++;
      return;
    }
    _emptyListens = 0;
    // ⌨️ sudharelo text box ma → 1.4 sec pachhi pote mokle
    setState(() {
      _input.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
      _pendingHeard = heard.isEmpty ? text : heard;
      _autoSend?.cancel();
      _autoSend = Timer(_autoSendDelay, _fireAutoSend);
    });
  }

  void _fireAutoSend() {
    final text = _input.text.trim();
    final heard = _pendingHeard;
    _autoSend = null;
    _pendingHeard = null;
    if (!mounted || text.isEmpty) return;
    _ask(text, voice: true, heard: heard);
  }

  /// Text par tap / badlav → auto-send rokvo; tame sudhari ne send dabavo
  void _cancelAutoSend() {
    if (_autoSend == null) return;
    _autoSend!.cancel();
    setState(() {
      _autoSend = null;
      _editFrom = _pendingHeard; // send karo tyare sudharo yaad rakhse
      _pendingHeard = null;
    });
  }

  /// 🧠 Mic mate dictionary: item master + stock item + customer + label code
  Future<void> _buildVocab() async {
    final items = <String>{};
    final customers = <String>{};
    final codes = <String>{};
    try {
      final p = Provider.of<ItemProvider>(context, listen: false);
      for (final e in (p.items as List? ?? const []).whereType<Map>()) {
        final n = (e['item_name'] ?? e['name'] ?? '').toString().trim();
        if (n.isNotEmpty) items.add(n);
      }
      for (final list in [p.customers, p.Approval_customers]) {
        for (final e in (list as List? ?? const []).whereType<Map>()) {
          final n = (e['name'] ?? e['customer_name'] ?? '').toString().trim();
          if (n.isNotEmpty) customers.add(n);
        }
      }
    } catch (_) {}
    try {
      final stock = await StockAiRepository.loadAll();
      for (final s in stock) {
        items.add(s.itemName);
        codes.add(s.labelCode);
      }
    } catch (_) {}
    VoiceBrain.build(items: items, customers: customers, codes: codes);
    AiTranslator.setProtected([...items, ...customers]); // 🌐 aa naam translate na thay
    debugPrint('🧠 Voice dictionary: ${VoiceBrain.size} shabd (${items.length} item, ${customers.length} customer)');
  }

  /// 🌐 English javab → pasand kareli bhasha, pachhi e j bhasha na avaj ma bolo
  Future<void> _speak(String s) async {
    await _tts.stop();
    var lang = _answerLang;
    var say = lang == 'en' ? await AiEnglish.fixAsync(s) : s; // 🇬🇧 English j bolo
    if (lang != 'en') {
      final t = await AiTranslator.translate(s, lang);
      final voice = lang == 'gu' ? 'gu-IN' : 'hi-IN';
      bool ok = false;
      try {
        ok = (await _tts.isLanguageAvailable(voice)) == true;
      } catch (_) {}
      if (t != null && ok) {
        say = t;
        await _tts.setLanguage(voice);
      } else {
        if (!ok && !_voiceWarned) {
          _voiceWarned = true;
          _toast('${AiTranslator.names[lang]} voice is not installed — speaking English. '
              'Add it in phone Settings → Text-to-speech → Google → Install voice data.');
        }
        lang = 'en';
      }
    }
    if (lang == 'en') {
      await _tts.setLanguage('en-IN');
      if (_enVoice != null) await _tts.setVoice(_enVoice!);
    }
    await _tts.speak(_cleanForSpeech(say, ascii: lang == 'en'));
  }

  bool _voiceWarned = false;

  /// 🌐 Javab chat ma umero — English na hoy to pehla translate (names / numbers safe)
  void _addAi(AiAnswer a, String? moduleId, {bool routed = false}) {
    final lang = _answerLang;
    if (lang == 'en') {
      // 🇬🇧 Gujlish / Gujarati / Hindi rahi gayu hoy to English ma
      if (!AiEnglish.needsWork(a)) {
        _msgs.add(_ChatMsg.ai(a, moduleId, routed: routed));
        return;
      }
      AiEnglish.answer(a).then((e) {
        if (!mounted) return;
        setState(() => _msgs.add(_ChatMsg.ai(e, moduleId, routed: routed)));
        _scrollDown();
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _msgs.add(_ChatMsg.ai(a, moduleId, routed: routed)));
      });
      return;
    }
    AiTranslator.answer(a, lang).then((t) {
      if (!mounted) return;
      setState(() => _msgs.add(_ChatMsg.ai(t, moduleId, routed: routed)));
      _scrollDown();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _msgs.add(_ChatMsg.ai(a, moduleId, routed: routed)));
    });
  }

  /// 🌐 Answer language pasand + model download (ek j var, ~30 MB)
  Future<void> _setAnswerLang(String v) async {
    setState(() => _answerPref = v);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('ai_answer_lang', v);
    } catch (_) {}
    final lang = _answerLang;
    if (lang == 'en') {
      _toast('Answers in English');
      return;
    }
    if (await AiTranslator.isReady(lang)) {
      _toast('Answers in ${AiTranslator.names[lang]}');
      return;
    }
    _toast('Downloading ${AiTranslator.names[lang]} language (one time, ~30 MB)…');
    final ok = await AiTranslator.ensureModel(lang);
    _toast(ok
        ? '✅ ${AiTranslator.names[lang]} ready — answers will come in ${AiTranslator.names[lang]}'
        : '⚠️ Could not download ${AiTranslator.names[lang]}. Check internet and try again.');
  }

  /// 🔊 Saro English avaj: Indian English (en-IN) voice, phone ma hoy e
  Map<String, String>? _enVoice;
  Future<void> _pickEnglishVoice() async {
    try {
      final list = await _tts.getVoices;
      if (list is! List) return;
      final voices = list
          .whereType<Map>()
          .map((v) => {'name': '${v['name']}', 'locale': '${v['locale']}'})
          .where((v) => v['locale']!.toLowerCase().replaceAll('_', '-').startsWith('en-in'))
          .toList();
      if (voices.isEmpty) return;
      // phone ma install (offline) voice pehla — jaldi ane hamesha chale
      voices.sort((a, b) => (a['name']!.contains('network') ? 1 : 0) - (b['name']!.contains('network') ? 1 : 0));
      _enVoice = voices.first;
      await _tts.setVoice(_enVoice!);
      debugPrint('🔊 TTS voice: ${_enVoice!['name']}');
    } catch (_) {}
  }

  static const List<String> _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October',
    'November', 'December',
  ];

  /// 🔊 Text → saru bolay evu English
  ///   "₹5,000" → "5000 rupees" · "12.5 g" → "12.5 grams" · "12-10-2026" → "12 October 2026"
  ///   "BR9" → "B R 9" · "3 pcs" → "3 pieces" · emoji / "·" / "—" → pause
  String _cleanForSpeech(String s, {bool ascii = true}) {
    String g(Match m, int i) => m.group(i) ?? '';
    String spaced(String v) => v.split('').join(' ');

    // one step at a time — a bad step never breaks speech
    var t = s;
    void step(String Function(String) f) {
      try {
        t = f(t);
      } catch (e) {
        debugPrint('🔊 speech clean step skipped => $e');
      }
    }

    if (ascii) {
      // first 3 sentences only (long lists are on the screen)
      step((x) {
        final parts = x.replaceAll('\n', '. ').split(RegExp(r'(?<=[.!?])\s+'));
        return parts.length > 3 ? parts.take(3).join(' ') : parts.join(' ');
      });
      // 12-10-2026 → 12 October 2026
      step((x) => x.replaceAllMapped(RegExp(r'\b(\d{1,2})-(\d{1,2})-(\d{4})\b'), (m) {
        final d = int.tryParse(g(m, 1)) ?? 0;
        final mo = int.tryParse(g(m, 2)) ?? 0;
        return (mo >= 1 && mo <= 12) ? '$d ${_monthsEn[mo - 1]} ${g(m, 3)}' : g(m, 0);
      }));
      // ₹5,000 → 5000 rupees
      step((x) => x
          .replaceAllMapped(RegExp(r'₹\s?([\d,]+(?:\.\d+)?)'), (m) => '${g(m, 1).replaceAll(',', '')} rupees')
          .replaceAll('₹', ' rupees '));
      step((x) => x.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${g(m, 1)}${g(m, 2)}'));
      step((x) => x.replaceAllMapped(RegExp(r'(\d)\s*[–-]\s*(\d)'), (m) => '${g(m, 1)} to ${g(m, 2)}'));
      // units
      step((x) => x
          .replaceAllMapped(RegExp(r'(\d)\s*g\b'), (m) => '${g(m, 1)} grams')
          .replaceAll(RegExp(r'\b1 grams\b'), '1 gram')
          .replaceAllMapped(RegExp(r'(\d)\s*pcs\b', caseSensitive: false), (m) => '${g(m, 1)} pieces')
          .replaceAll(RegExp(r'\bpcs\b', caseSensitive: false), 'pieces')
          .replaceAll(RegExp(r'\bwt\b', caseSensitive: false), 'weight')
          .replaceAll(RegExp(r'\bqty\b', caseSensitive: false), 'quantity')
          .replaceAll(RegExp(r'\bvs\b'), 'compared to')
          .replaceAll(RegExp(r'\bHUID\b'), 'H U I D'));
      // barcode / voucher: "BR9" → "B R 9", "PT-SL-004" → "P T S L 004"
      step((x) => x.replaceAllMapped(
          RegExp(r'\b([A-Z]{2,4})-([A-Z]{2,4})-(\d+)\b'), (m) => '${spaced(g(m, 1))} ${spaced(g(m, 2))} ${g(m, 3)}'));
      step((x) => x.replaceAllMapped(
          RegExp(r'\b([A-Z]{1,5})-?(\d[A-Za-z0-9_\-]*)\b'), (m) => '${spaced(g(m, 1))} ${g(m, 2).replaceAll('-', ' ')}'));
      step((x) => x.replaceAllMapped(
          RegExp(r'\b([A-Z]{2,4})-([A-Z]{2,4})\b'), (m) => '${spaced(g(m, 1))} ${spaced(g(m, 2))}'));
      // symbols
      step((x) => x
          .replaceAll('%', ' percent')
          .replaceAll(RegExp(r'[·•|→—]'), ', ')
          .replaceAll(RegExp(r'[()"“”]'), ' ')
          .replaceAll(RegExp(r'[^\x00-\x7F]'), ' '));
    } else {
      // remove emoji (no unicode regex — works on every Flutter version)
      step((x) => String.fromCharCodes(x.runes.map((r) =>
      (r >= 0x1F000 && r <= 0x1FFFF) || (r >= 0x2600 && r <= 0x27BF) || r == 0xFE0F ? 0x20 : r)));
      step((x) => x
          .replaceAll(RegExp(r'[·•|→—]'), ', ')
          .replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${g(m, 1)}${g(m, 2)}'));
    }
    step((x) => x
        .replaceAll(RegExp(r'\s*,\s*(,\s*)+'), ', ')
        .replaceAllMapped(RegExp(r'\s+([,.:])'), (m) => g(m, 1))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim());
    return t;
  }

  // =====================================================================
  //  ASK (auto-routing)
  // =====================================================================
  /// ⌨️ Type karelu / sudharelu moklo — mic no text sudharyo hoy to yaad rakho
  Future<void> _submitTyped(String text) async {
    // ⌨️ Send dabavyu (keyboard nu ➤ athva ↑ button) → keyboard turat band
    _hideKeyboard();
    final from = _editFrom;
    _editFrom = null;
    final v = text.trim();
    if (v.isEmpty) return;
    if (from != null && from.trim().toLowerCase() != v.toLowerCase()) {
      final learned = await VoiceLearn.learn(from, v);
      if (learned.isNotEmpty) {
        _toast('🎤 Learned: ${learned.entries.map((e) => '"${e.key}" → "${e.value}"').join(', ')}');
      }
    }
    await _ask(v);
  }

  /// User bubble par ✏️ — mic e lakhelu text box ma, sudhari ne moklo
  void _editVoice(String text, {String? heard}) {
    _tts.stop();
    _autoSend?.cancel();
    _autoSend = null;
    setState(() {
      _editFrom = heard ?? text; // mic nu kachu → tamaru sachu (yaad rakhva)
      _input.text = text;
      _input.selection = TextSelection.collapsed(offset: text.length);
    });
    _inputFocus.requestFocus();
  }

  Future<void> _ask(String text, {bool voice = false, String? heard}) async {
    _autoSend?.cancel();
    _autoSend = null;
    final q0 = text.trim();
    final cur = _current;
    if (q0.isEmpty || cur == null) return;
    _input.clear();
    _hideKeyboard();

    setState(() {
      _msgs.add(_ChatMsg.user(
        q0,
        voice: voice,
        heard: (heard != null && heard.trim().toLowerCase() != q0.toLowerCase()) ? heard.trim() : null,
      ));
      _thinking = true;
    });
    _scrollDown();

    // 🌐 Gujarati / Hindi lipi → English. Engine ne English + mul shabdo bey aapo
    //    (jethi "કાલે" jeva shabdo no sacho arth pan na gumay)
    final userMsg = _msgs.last;
    // ⚡ English / Gujlish (Latin letters) → translate step skip (no wait)
    final en = AiTranslator.scriptOf(q0) == null ? null : await AiTranslator.toEnglish(q0);
    if (!mounted) return;
    final q = en == null ? q0 : '$en ; $q0';
    if (en != null) setState(() => userMsg.meaning = en);

    // 🧭 "Divya nu sale estimate kholo" → screen kholo (customer select)
    // (sync ke async — bey AppNavigatorAi version chale)
    final nav = await Future.value(AppNavigatorAi.handle(context, q));
    if (!mounted) return;
    if (nav != null) {
      setState(() {
        _thinking = false;
        _addAi(nav.answer, null);
      });
      _scrollDown();
      if (_speakOn) _speak(nav.answer.speech); // await nahi — bolta bolta screen khule
      if (nav.screen != null) {
        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        _handsFree = false; // bije screen par mic chalu na thay
        await Navigator.push(context, MaterialPageRoute(builder: (_) => nav.screen!()));
      }
      return;
    }

    // 📑 "Lado creation september approval report pdf" → Report builder (pre-filled)
    final lq = q.toLowerCase();
    if ((lq.contains('report') || lq.contains('pdf')) &&
        (lq.contains('approval') || lq.contains('aproval') || lq.contains('return'))) {
      setState(() {
        _thinking = false;
        _addAi(
            const AiAnswer(
              text: 'Opening the report builder — check the customer, range and action, then tap "Make PDF report".',
              speech: 'Opening the report builder.',
            ),
            null);
      });
      _scrollDown();
      await AiReportBuilder.open(context, query: q0);
      return;
    }

    // 🏢 Branch: chip select hoy to badhu selected branch ma,
    //    nahi to "Dishank branch sales today" / "all branches …" / "branch wise …"
    if (!_barcodeMode && !_stockPosMode) {
      final AiAnswer? br = await BranchAi.handle(q, force: _branchMode);
      if (!mounted) return;
      if (br != null) {
        setState(() {
          _thinking = false;
          _addAi(br, null);
        });
        _scrollDown();
        if (AiPdf.wantsPdf(q) && br.items.isNotEmpty && mounted) {
          AiPdf.makeAndShow(context, br, withImages: false);
        }
        if (_speakOn) {
          await _speak(br.speech);
        } else if (_handsFree) {
          _afterSpeak();
        }
        return;
      }
    }

    // 🖼️ "image search" / "photo thi shodho" / "similar design" → Image Search screen
    if (RegExp(r'\b(image search|search by (photo|image)|photo search|photo thi|image thi|similar (design|item|photo)s?)\b',
        caseSensitive: false)
        .hasMatch(q0)) {
      setState(() {
        _thinking = false;
        _addAi(
          const AiAnswer(
            text: '🖼️ Opening Image Search — click or upload a photo to see the exact match and similar items.',
            speech: 'Opening image search.',
          ),
          null,
        );
      });
      _scrollDown();
      await _openImageSearch();
      return;
    }

    // 🛠️ Job work: chip select hoy to badhu ahi j,
    //    nahi to "job work / karigar" + issue / receive / pending shabd hoy to
    if (!_barcodeMode && !_stockPosMode && !_castMode) {
      final AiAnswer? jw = await JobWorkAi.handle(q, force: _jobMode);
      if (!mounted) return;
      if (jw != null) {
        setState(() {
          _thinking = false;
          _addAi(jw, null);
        });
        _scrollDown();
        if (AiPdf.wantsPdf(q) && jw.items.isNotEmpty && mounted) {
          AiPdf.makeAndShow(context, jw, withImages: false);
        }
        if (_speakOn) {
          await _speak(jw.speech);
        } else if (_handsFree) {
          _afterSpeak();
        }
        return;
      }
    }

    // 🔥 Casting: chip select hoy to badhu ahi j,
    //    nahi to "casting / tree cutting / heating / sorting / vacuum" shabd hoy to
    if (!_barcodeMode && !_stockPosMode && !_jobMode) {
      final AiAnswer? ca = await CastingAi.handle(q, force: _castMode);
      if (!mounted) return;
      if (ca != null) {
        setState(() {
          _thinking = false;
          _addAi(ca, null);
        });
        _scrollDown();
        if (AiPdf.wantsPdf(q) && ca.items.isNotEmpty && mounted) {
          AiPdf.makeAndShow(context, ca, withImages: false);
        }
        if (_speakOn) {
          await _speak(ca.speech);
        } else if (_handsFree) {
          _afterSpeak();
        }
        return;
      }
    }

    // 📅 "aaje ketlo stock umerayo" / "kale ketlu vechayu" / "parmdivase" …
    //    (Gujarati / Hindi / English / Gujlish badhi bhasha)
    if (!_barcodeMode) {
      // All: only when the question has "added / sold / stock" words; chip: that module
      final AiAnswer? da =
      await DateAi.handle(q, moduleId: _allMode ? null : (_stockPosMode ? 'stock' : _currentId));
      if (!mounted) return;
      if (da != null) {
        setState(() {
          _thinking = false;
          _addAi(da, null);
        });
        _scrollDown();
        if (AiPdf.wantsPdf(q) && da.items.isNotEmpty && mounted) {
          AiPdf.makeAndShow(context, da, withImages: AiPdf.wantsImages(q));
        }
        if (_speakOn) {
          await _speak(da.speech);
        } else if (_handsFree) {
          _afterSpeak();
        }
        return;
      }
    }

    // 📦 Stock Position: chip select hoy to badhu ahi j,
    //    nahi to "position / raw material / customer received" shabd hoy to
    if (!_barcodeMode) {
      // ⚖️ "10 thi 15 gram temple ring" = weight no sawal → Stock module (position nahi)
      final bool weightQ = RegExp(r'\d+(\.\d+)?\s*(gram|grams|gm|g)\b|\d+\s*(thi|to|se|-)\s*\d+')
          .hasMatch(VoiceLearn.builtIn(q));
      if (weightQ && _stockPosMode) setState(() => _stockPosMode = false);
      final AiAnswer? sp = weightQ ? null : await StockPositionAi.handle(q, force: _stockPosMode);
      if (!mounted) return;
      if (sp != null) {
        setState(() {
          if (!_allMode) _stockPosMode = true; // chip mode: aagal na sawal pan ahi j
          _thinking = false;
          _addAi(sp, null);
        });
        _scrollDown();
        if (_speakOn) {
          await _speak(sp.speech);
        } else if (_handsFree) {
          _afterSpeak();
        }
        return;
      }
    }

    // 🔎 Barcode: "BR8 kya che" / "TS3 nu status" / fakt "BR8"
    //    Barcode chip select hoy to je code bolo te barcode j gano
    final code = BarcodeAi.detect(q, force: _barcodeMode);
    if (_barcodeMode && code == null) {
      setState(() {
        _thinking = false;
        _addAi(
          const AiAnswer(
            text: 'I could not understand the barcode. Say or type it like: "BR8", "TS 12", "OWG15".',
            speech: 'I could not understand the barcode, please say it again.',
          ),
          null,
        );
      });
      _scrollDown();
      return;
    }
    if (code != null) {
      final AiAnswer? ba = await BarcodeAi.lookup(code);
      if (!mounted) return;
      if (ba == null && _barcodeMode) {
        setState(() {
          _thinking = false;
          _addAi(
            AiAnswer(
              text: 'No barcode found with the code "$code". Please check the code.',
              speech: 'No barcode found with the code $code.',
            ),
            null,
          );
        });
        _scrollDown();
        if (_speakOn) await _speak('No barcode found with the code $code.');
        return;
      }
      if (ba != null) {
        _recentCodes
          ..remove(code)
          ..insert(0, code);
        if (_recentCodes.length > 6) _recentCodes.removeLast();
        setState(() {
          _thinking = false;
          _addAi(ba, null);
        });
        _scrollDown();
        if (_speakOn) {
          await _speak(ba.speech);
        } else if (_handsFree) {
          _afterSpeak();
        }
        return;
      }
      // barcode na malyo → normal module javab aape
    }

    // 🧩 ONE PAGE: sawal jova thi sauthi saro module pote pasand thay
    //    (barabar score → chhello vaparelo module; koi match nahi → chhello / Stock)
    final t = AiText.normalize(q);
    AiModule? best;
    num bestScore = 0;
    for (final m in _modules) {
      if (!m.isLoaded) continue;
      final s = m.relevance(t);
      if (s > bestScore || (s == bestScore && s > 0 && m.id == _currentId)) {
        bestScore = s;
        best = m;
      }
    }
    final last = _moduleById(_currentId);
    AiModule target = best ??
        ((last != null && last.isLoaded) ? last : null) ??
        _moduleById('stock') ??
        cur;
    var routed = false;
    if (!_allMode) {
      // 📌 Chip mode (pehla jevu): selected module j, bijo module SPASHT hoy to j tya
      target = cur;
      final curScore = cur.relevance(t);
      for (final m in _modules) {
        if (m.id == cur.id) continue;
        final s = m.relevance(t);
        final clearlyOther = (s >= 2 && s > curScore + 1) || (s >= 1 && curScore == 0);
        if (clearlyOther && s > target.relevance(t)) target = m;
      }
      routed = target.id != cur.id;
    }
    if (target.id != _currentId) setState(() => _currentId = target.id);

    if (!target.isLoaded) await _ensureLoaded(target);
    if (!mounted) return;

    AiAnswer answer;
    try {
      answer = target.isLoaded
          ? target.ask(q)
          : AiAnswer(text: _errors[target.id] ?? 'Could not load ${target.title} data.');
    } catch (e) {
      answer = AiAnswer(text: 'Something went wrong: $e');
    }

    setState(() {
      _thinking = false;
      _addAi(answer, target.id, routed: routed);
    });
    _scrollDown();

    // 📄 "… ni pdf" bolya hoy to list ni PDF sidhi banavo
    if (AiPdf.wantsPdf(q) && answer.items.isNotEmpty && mounted) {
      // "image vadi pdf" → photo sathe; "photo vagar na item ni pdf" → fakt list
      AiPdf.makeAndShow(context, answer, withImages: AiPdf.wantsImages(q));
    }

    if (_speakOn) {
      await _speak(answer.speech);
    } else if (_handsFree) {
      _afterSpeak();
    }
  }

  /// 🎤 Sikhela sudhara jovo / kadhi nakho
  void _showVoiceFixes() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final fixes = VoiceLearn.all.entries.toList();
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('🎤 Learned words', style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: double.maxFinite,
              child: fixes.isEmpty
                  ? const Text(
                  'Nothing learned yet.\nIf the mic writes something wrong, tap "✏️ Fix" under your question, '
                      'type the correct text and send it — next time that word is fixed automatically.',
                  style: TextStyle(color: _inkSoft, fontSize: 13))
                  : ListView(
                shrinkWrap: true,
                children: fixes
                    .map((e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('"${e.key}"  →  "${e.value}"',
                      style: const TextStyle(color: _ink, fontSize: 13.5)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () async {
                      await VoiceLearn.forget(e.key);
                      setD(() {});
                    },
                  ),
                ))
                    .toList(),
              ),
            ),
            actions: [
              if (fixes.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await VoiceLearn.clear();
                    setD(() {});
                  },
                  child: const Text('Clear all', style: TextStyle(color: Colors.redAccent)),
                ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 300,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      }
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  }

  AiModule? _moduleById(String? id) {
    for (final m in _modules) {
      if (m.id == id) return m;
    }
    return null;
  }

  // =====================================================================
  //  UI
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    final cur = _current;
    return Scaffold(
      backgroundColor: _ivory,
      appBar: _appBar(cur),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideKeyboard,
              child: _buildBody(),
            ),
          ),
          _buildSuggestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _moduleBar() => Container(
    height: 48,
    decoration: const BoxDecoration(color: Colors.white),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      itemCount: _modules.length + 6 + (BranchAi.canUse ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, idxAll) {
        // 🧩 pehli chip "All" · 🏢 Branch (admin) right after it
        if (idxAll == 0) return _allChip();
        if (BranchAi.canUse && idxAll == 1) return _branchChip();
        final idx = idxAll - (BranchAi.canUse ? 2 : 1);
        // 🔎 Barcode + 📦 Stock Position chip — pehla module (Stock) pachhi
        final int at = _modules.isEmpty ? 0 : 1;
        if (idx == at) return _barcodeChip();
        if (idx == at + 1) return _stockPosChip();
        if (idx == at + 2) return _jobChip();
        if (idx == at + 3) return _castChip();
        if (idx == at + 4) return _imageChip();
        final i = idx > at + 4 ? idx - 5 : idx;
        final m = _modules[i];
        final sel = !_allMode && !_toolMode && m.id == _currentId;
        return ChoiceChip(
          selected: sel,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          selectedColor: _navy,
          backgroundColor: Colors.white,
          side: BorderSide(color: sel ? _gold : _hair),
          avatar: _loading.contains(m.id) && !_firstLoad
              ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: sel ? Colors.white : _blue))
              : FaIcon(m.icon, size: 12, color: sel ? _goldLight : _blue),
          label: Text(m.title,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : _ink)),
          onSelected: (_) => _switchModule(m),
        );
      },
    ),
  );

  /// 🧩 All — badha module ek sathe (default)
  Widget _allChip() => ChoiceChip(
    selected: _allMode,
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    selectedColor: _navy,
    backgroundColor: Colors.white,
    side: BorderSide(color: _allMode ? _gold : _hair),
    avatar: FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 12, color: _allMode ? _goldLight : _blue),
    label: Text('All',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _allMode ? Colors.white : _ink)),
    onSelected: (_) {
      if (_allMode) return;
      setState(() {
        _allMode = true;
        _barcodeMode = false;
        _stockPosMode = false;
        _jobMode = false;
        _castMode = false;
        _branchMode = false;
        _addAi(_welcomeAll(), null);
      });
      _scrollDown();
    },
  );

  /// 📦 Stock Position chip — select karta j aakho saransh
  Widget _stockPosChip() => ChoiceChip(
    selected: _stockPosMode,
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    selectedColor: _navy,
    backgroundColor: Colors.white,
    side: BorderSide(color: _stockPosMode ? _gold : _hair),
    avatar: FaIcon(FontAwesomeIcons.boxesStacked, size: 12, color: _stockPosMode ? _goldLight : _blue),
    label: Text('Stock Position',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: _stockPosMode ? Colors.white : _ink)),
    onSelected: (_) {
      if (_stockPosMode) return;
      setState(() {
        _allMode = false;
        _stockPosMode = true;
        _barcodeMode = false;
        _jobMode = false;
        _castMode = false;
        _branchMode = false;
      });
      _ask('Stock position total');
    },
  );

  /// 🛠️ Job Work chip — issue · receive · pending (worker wise)
  Widget _jobChip() => ChoiceChip(
    selected: _jobMode,
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    selectedColor: _navy,
    backgroundColor: Colors.white,
    side: BorderSide(color: _jobMode ? _gold : _hair),
    avatar: FaIcon(FontAwesomeIcons.screwdriverWrench, size: 12, color: _jobMode ? _goldLight : _blue),
    label: Text('Job Work',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _jobMode ? Colors.white : _ink)),
    onSelected: (_) {
      if (_jobMode) return;
      setState(() {
        _allMode = false;
        _jobMode = true;
        _castMode = false;
        _branchMode = false;
        _barcodeMode = false;
        _stockPosMode = false;
      });
      _ask('Job work summary');
    },
  );

  /// 🔥 Casting chip — heating · metal issue · receive · tree cutting office / issue / receive · sorting
  Widget _castChip() => ChoiceChip(
    selected: _castMode,
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    selectedColor: _navy,
    backgroundColor: Colors.white,
    side: BorderSide(color: _castMode ? _gold : _hair),
    avatar: FaIcon(FontAwesomeIcons.fire, size: 12, color: _castMode ? _goldLight : _blue),
    label: Text('Casting',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _castMode ? Colors.white : _ink)),
    onSelected: (_) {
      if (_castMode) return;
      setState(() {
        _allMode = false;
        _castMode = true;
        _jobMode = false;
        _branchMode = false;
        _barcodeMode = false;
        _stockPosMode = false;
      });
      _ask('Casting summary');
    },
  );

  /// 🖼️ Image Search chip — photo upload → exact + similar stock items (PDF · WhatsApp)
  Widget _imageChip() => ChoiceChip(
    selected: false,
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    selectedColor: _navy,
    backgroundColor: Colors.white,
    side: const BorderSide(color: _hair),
    avatar: FaIcon(FontAwesomeIcons.images, size: 12, color: _blue),
    label: const Text('Image Search', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
    onSelected: (_) => _openImageSearch(),
  );

  Future<void> _openImageSearch() async {
    _hideKeyboard();
    _handsFree = false;
    await _tts.stop();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImageSearchScreen()),
    );
  }

  /// 🏢 Branch chip — pick branches once, then ask anything (sales · approval · loss · job work · stock)
  Widget _branchChip() => ChoiceChip(
    selected: _branchMode,
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    selectedColor: _navy,
    backgroundColor: Colors.white,
    side: BorderSide(color: _branchMode ? _gold : _hair),
    avatar: FaIcon(FontAwesomeIcons.sitemap, size: 12, color: _branchMode ? _goldLight : _blue),
    label: Text(_branchMode ? 'Branch · ${BranchAi.selectedText}' : 'Branch',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _branchMode ? Colors.white : _ink)),
    onSelected: (_) => _pickBranches(),
  );

  Future<void> _pickBranches() async {
    _hideKeyboard();
    final temp = {...BranchAi.selected};
    if (temp.isEmpty) temp.addAll(BranchAi.branches.map((c) => c.id));
    final res = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final all = temp.length == BranchAi.branches.length;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(children: [
                  Icon(Icons.account_tree_rounded, size: 18, color: _blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Ask AI · branches',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
                  ),
                  TextButton(
                    onPressed: () => set(() => all ? temp.clear() : temp.addAll(BranchAi.branches.map((c) => c.id))),
                    child: Text(all ? 'Clear all' : 'Select all',
                        style: TextStyle(fontWeight: FontWeight.w700, color: _blue)),
                  ),
                ]),
              ),
              const Divider(height: 1, color: _hair),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final c in BranchAi.branches)
                    CheckboxListTile(
                      dense: true,
                      value: temp.contains(c.id),
                      activeColor: _blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      title: Text(BranchAi.label(c),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _ink)),
                      secondary: Icon(c.isMain ? Icons.verified_rounded : Icons.store_mall_directory_rounded,
                          size: 18, color: _blue),
                      onChanged: (v) => set(() => v == true ? temp.add(c.id) : temp.remove(c.id)),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  if (_branchMode)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          side: const BorderSide(color: _hair),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx, <int>{-1}),
                        child: const Text('Turn off', style: TextStyle(color: Color(0xffD32F2F), fontWeight: FontWeight.w800)),
                      ),
                    ),
                  if (_branchMode) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: temp.isEmpty ? null : () => Navigator.pop(ctx, temp),
                      child: Text('Use ${temp.length} branch${temp.length == 1 ? '' : 'es'}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
    if (res == null || !mounted) return;
    if (res.contains(-1)) {
      // turn branch mode off → back to All
      setState(() {
        _branchMode = false;
        _allMode = true;
        _addAi(_welcomeAll(), null);
      });
      _scrollDown();
      return;
    }
    BranchAi.selected
      ..clear()
      ..addAll(res);
    BranchAi.clearCache();
    setState(() {
      _allMode = false;
      _branchMode = true;
      _barcodeMode = false;
      _stockPosMode = false;
      _jobMode = false;
      _castMode = false;
    });
    _ask('Branch summary this month');
  }

  /// 🔎 Barcode chip (module jevo j look)
  Widget _barcodeChip() => ChoiceChip(
    selected: _barcodeMode,
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    selectedColor: _navy,
    backgroundColor: Colors.white,
    side: BorderSide(color: _barcodeMode ? _gold : _hair),
    avatar: FaIcon(FontAwesomeIcons.barcode, size: 12, color: _barcodeMode ? _goldLight : _blue),
    label: Text('Barcode',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: _barcodeMode ? Colors.white : _ink)),
    onSelected: (_) {
      if (_barcodeMode) return;
      setState(() {
        _allMode = false;
        _barcodeMode = true;
        _stockPosMode = false;
        _jobMode = false;
        _castMode = false;
        _branchMode = false;
        _addAi(
          const AiAnswer(
            text: '🔎 Say or type a barcode — I will show where it is now '
                '(stock / approval / sold / return) and its full history.\n'
                'Tap a voucher to see full details.',
            speech: 'Say the barcode.',
            followUps: ['BR8', 'Where is BR8'],
          ),
          null,
        );
      });
      _scrollDown();
    },
  );

  Widget _buildBody() {
    final cur = _current;
    if (_modules.isEmpty) {
      return const Center(child: Text('You do not have permission to use Ask AI.'));
    }
    if (_msgs.isEmpty && (_firstLoad || _loading.isNotEmpty)) {
      // ⏳ ONE loader for everything (no popups, no chip spinners)
      final done = _modules.where((m) => m.isLoaded).length;
      final total = _modules.isEmpty ? 1 : _modules.length;
      final pct = _loadTotal > 0 ? (_loadDone / _loadTotal) : (done / total);
      return Center(
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_navy2, _navy]),
                  border: Border.all(color: _gold, width: 1.2),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: _goldLight, size: 22),
              ),
              const SizedBox(height: 10),
              const Text('Getting your data ready…',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.black87)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: pct <= 0 || pct >= 1 ? null : pct,
                  minHeight: 5,
                  backgroundColor: _goldSoft,
                  color: _gold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$done of $total ready',
                style: const TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }
    if (_msgs.isEmpty && cur != null && _errors[cur.id] != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.black38),
              const SizedBox(height: 12),
              Text(_errors[cur.id]!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: () => _loadAll(force: true),
                  child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final extra = (_listening ? 1 : 0) + (_thinking ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: _msgs.length + extra,
      itemBuilder: (_, i) {
        if (i >= _msgs.length) {
          return (_thinking && i == _msgs.length) ? _thinkingBubble() : _listeningBubble();
        }
        final m = _msgs[i];
        return m.isUser ? _userBubble(m.userText!, voice: m.voice, heard: m.heard, meaning: m.meaning) : _aiBubble(m);
      },
    );
  }

  Widget _userBubble(String text, {bool voice = false, String? heard, String? meaning}) => Align(
    alignment: Alignment.centerRight,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_navy2, _navy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            boxShadow: [BoxShadow(color: _navy.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35)),
        ),
        // 🌐 local bhasha no sawal English ma shu samjayo
        if (meaning != null)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 4, top: 0),
            child: Text('🌐 $meaning',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
          ),
        // 🎤 mic e khotu lakhyu? → ✏️ sudharo (ek var sudharo, pachhi yaad rahe)
        if (voice)
          Transform.translate(
            offset: const Offset(0, -6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _editVoice(text, heard: heard),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.mic_rounded, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      heard != null ? 'Heard "$heard" → fixed · ' : 'Heard wrong? ',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    ),
                  ),
                  Icon(Icons.edit_rounded, size: 12, color: _blue),
                  const SizedBox(width: 2),
                  Text('Fix', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _blue)),
                ]),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _thinkingBubble() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _hair),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: _gold)),
        const SizedBox(width: 10),
        const Text('Thinking…', style: TextStyle(color: _inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _listeningBubble() => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10, left: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _blueSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _levelBars(),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _partial.isEmpty ? 'Listening… speak now' : _partial,
              style: TextStyle(
                color: _partial.isEmpty ? Colors.black45 : Colors.black87,
                fontStyle: _partial.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// Avaj pramane halti nani bars
  Widget _levelBars() => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(4, (i) {
      final h = 6 + (_level * 16 * (i.isEven ? 1 : 0.7)) + (i == 1 ? 2 : 0);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        width: 3,
        height: h.clamp(4.0, 22.0),
        decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)),
      );
    }),
  );

  Widget _aiBubble(_ChatMsg msg) {
    final a = msg.answer!;
    final mod = _moduleById(msg.moduleId);
    const maxInline = 8;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 14),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          border: Border.all(color: _hair),
          boxShadow: [BoxShadow(color: _navy.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- module + filter tag ----
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (mod != null && _modules.length > 1)
                  _tag(mod.icon, msg.routed ? '↪ ${mod.title}' : mod.title, strong: msg.routed),
                if (a.filterLabel != null) _tag(Icons.filter_alt_rounded, a.filterLabel!),
              ],
            ),
            if ((mod != null && _modules.length > 1) || a.filterLabel != null) const SizedBox(height: 8),

            _answerText(a.text),

            if (a.stats.isNotEmpty) ...[
              const SizedBox(height: 12),
              _statGrid(a.stats),
            ],

            for (final s in a.sections)
              if (s.rows.isNotEmpty) _sectionView(s),

            if (a.items.isNotEmpty) ...[
              const SizedBox(height: 14),
              _listHeader(
                a.itemsTitle ?? 'List',
                a.items.length,
                onAll: a.items.length > maxInline ? () => _showAllItems(a, msg.moduleId) : null,
              ),
              const SizedBox(height: 8),
              ...a.items.take(maxInline).map((r) => _recordTile(r, moduleId: msg.moduleId)),
              if (a.items.length > maxInline)
                _showMoreButton(a.items.length - maxInline, () => _showAllItems(a, msg.moduleId)),
            ],

            if (a.followUps.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: a.followUps
                    .map((f) => ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _goldSoft,
                  side: BorderSide(color: _gold.withOpacity(0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  avatar: const Icon(Icons.subdirectory_arrow_right_rounded, size: 13, color: _navy),
                  label: Text(f,
                      style: const TextStyle(fontSize: 11.5, color: _navy, fontWeight: FontWeight.w600)),
                  onPressed: () => _ask(AiEnglish.originalOf(AiTranslator.originalOf(f))),
                ))
                    .toList(),
              ),
            ],

            // ---- actions ----
            const SizedBox(height: 4),
            Row(
              children: [
                _miniAction(Icons.volume_up_rounded, 'Listen again', () => _speak(a.speech)),
                _miniAction(Icons.copy_rounded, 'Copy', () {
                  Clipboard.setData(ClipboardData(text: _plainText(a)));
                  _toast('Copied');
                }),
                // 📄 list hoy to PDF (print / WhatsApp)
                if (a.items.isNotEmpty)
                  _pdfButton(a),
                const Spacer(),
                if (a.period != null && widget.onOpenPeriod != null && msg.moduleId != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
                    onPressed: () => widget.onOpenPeriod!(context, msg.moduleId!, a.period!),
                    icon: Icon(Icons.open_in_new_rounded, size: 15, color: _blue),
                    label: Text('Open in report', style: TextStyle(fontSize: 12, color: _blue)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 📄 premium PDF button (answer card bottom)
  Widget _pdfButton(AiAnswer a) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          _hideKeyboard();
          AiPdf.makeAndShow(context, a);
        },
        child: Ink(
          height: 32,
          padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xffF43F5E), Color(0xffE11D48), Color(0xffBE123C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xffE11D48).withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Color(0xffE11D48)),
            ),
            const SizedBox(width: 7),
            const Text('PDF',
                style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(10)),
              child: Text('${a.items.length}',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.download_rounded, size: 15, color: Colors.white),
          ]),
        ),
      ),
    ),
  );

  String _plainText(AiAnswer a) {
    final b = StringBuffer(a.text);
    if (a.stats.isNotEmpty) {
      b.writeln();
      for (final s in a.stats) {
        b.writeln('${s.label}: ${s.value}');
      }
    }
    for (final s in a.sections) {
      b.writeln('\n${s.title}');
      for (final r in s.rows) {
        b.writeln('• ${r.title} — ${r.value}${r.sub != null ? ' (${r.sub})' : ''}');
      }
    }
    return b.toString();
  }

  Widget _tag(IconData icon, String text, {bool strong = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: strong ? _goldSoft : _blueSofter,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: strong ? _gold.withOpacity(0.35) : _hair),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      FaIcon(icon, size: 10, color: _blue),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: _blue, fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  Widget _miniAction(IconData icon, String tip, VoidCallback onTap) => IconButton(
    tooltip: tip,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    icon: Icon(icon, size: 17, color: Colors.black38),
    onPressed: onTap,
  );

  Widget _sectionView(AiSection s) {
    const maxRows = 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Row(children: [
                Container(width: 3, height: 13, decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(10))),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(s.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ink)),
                ),
              ]),
            ),
            // 📊 Graph view
            if (AiGraph.canShow(s))
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                  backgroundColor: _blueSofter,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  _hideKeyboard();
                  AiGraph.open(context, s, onAsk: _ask);
                },
                icon: Icon(Icons.bar_chart_rounded, size: 16, color: _blue),
                label: Text('Graph', style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            if (s.rows.length > maxRows)
              TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 28)),
                onPressed: () {
                  _hideKeyboard();
                  _showAllRows(s);
                },
                child: Text('All ${s.rows.length}', style: TextStyle(color: _blue, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hair),
            boxShadow: [BoxShadow(color: _navy.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(children: [
            for (var i = 0; i < s.rows.length && i < maxRows; i++) ...[
              if (i > 0) const Divider(height: 1, color: _hair),
              _rowTile(s.rows[i], rank: i + 1),
            ],
          ]),
        ),
      ],
    );
  }

  // =====================================================================
  //  💎 PREMIUM ANSWER — headline · callouts · stat grid
  // =====================================================================
  /// 1st line = headline · "⚠️ …" = amber callout · "✅ / 🧹 / ⏳ / 🔻 …" = soft callout
  Widget _answerText(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return const SizedBox.shrink();
    Widget callout(String l, Color c, Color bg, IconData icon) => Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: c, width: 3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 7),
        Expanded(
          child: Text(l.replaceFirst(RegExp(r'^[^\w₹]+'), ''),
              style: TextStyle(fontSize: 12.5, height: 1.4, color: _ink, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
    final out = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (i == 0) {
        out.add(Text(l,
            style: const TextStyle(fontSize: 14.5, height: 1.4, color: _ink, fontWeight: FontWeight.w700)));
      } else if (l.startsWith('⚠️') || l.startsWith('⚠')) {
        out.add(callout(l, const Color(0xffD97706), const Color(0xffFFF7E6), Icons.warning_amber_rounded));
      } else if (l.startsWith('🧹') || l.startsWith('🔻') || l.startsWith('❌')) {
        out.add(callout(l, const Color(0xffDC2626), const Color(0xffFEF2F2), Icons.cleaning_services_rounded));
      } else if (l.startsWith('✅') || l.startsWith('🔺')) {
        out.add(callout(l, const Color(0xff16A34A), const Color(0xffF0FDF4), Icons.check_circle_rounded));
      } else if (const ['⏳', '📍', '🏢', '📤', '📥', '⚖', '🛠', '🔥', '🧾', '📋', '📦'].any(l.startsWith)) {
        out.add(callout(l, _navy, _blueSofter, Icons.info_rounded));
      } else {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l, style: const TextStyle(fontSize: 13, height: 1.45, color: _inkSoft, fontWeight: FontWeight.w500)),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }

  IconData _statIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('customer') || l.contains('worker') || l.contains('party')) return Icons.people_alt_rounded;
    if (l.contains('piece') || l.contains('pcs') || l.contains('qty')) return Icons.diamond_outlined;
    if (l.contains('fine')) return Icons.auto_awesome_rounded;
    if (l.contains('wt') || l.contains('weight') || l.contains('gross') || l.contains('net')) return Icons.scale_rounded;
    if (l.contains('amount') || l.contains('₹') || l.contains('total')) return Icons.currency_rupee_rounded;
    if (l.contains('age') || l.contains('day')) return Icons.schedule_rounded;
    if (l.contains('open') || l.contains('partial') || l.contains('pending')) return Icons.pending_actions_rounded;
    if (l.contains('issued') || l.contains('issue')) return Icons.outbox_rounded;
    if (l.contains('received') || l.contains('receive')) return Icons.move_to_inbox_rounded;
    if (l.contains('entries') || l.contains('count')) return Icons.format_list_numbered_rounded;
    if (l.contains('loss') || l.contains('result')) return Icons.balance_rounded;
    if (l.contains('branch')) return Icons.store_mall_directory_rounded;
    if (l.contains('approval') || l.contains('voucher') || l.contains('bill')) return Icons.receipt_long_rounded;
    return Icons.insights_rounded;
  }

  /// equal tiles · 3 per row on phone (4 on wide) · first tile = highlighted
  Widget _statGrid(List<AiStat> stats) => LayoutBuilder(builder: (_, c) {
    final per = c.maxWidth >= 560 ? 4 : (c.maxWidth >= 300 ? 3 : 2);
    const gap = 8.0;
    final w = (c.maxWidth - (per - 1) * gap) / per;
    return Wrap(spacing: gap, runSpacing: gap, children: [
      for (var i = 0; i < stats.length; i++) SizedBox(width: w, child: _statTile(stats[i], hero: i == 0)),
    ]);
  });

  Widget _statTile(AiStat s, {bool hero = false}) => Container(
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
    decoration: BoxDecoration(
      gradient: hero
          ? const LinearGradient(colors: [_navy2, _navy], begin: Alignment.topLeft, end: Alignment.bottomRight)
          : const LinearGradient(colors: [Color(0xffF7FAFF), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: hero ? _navy : _hair),
      boxShadow: [BoxShadow(color: _navy.withOpacity(hero ? 0.18 : 0.05), blurRadius: hero ? 10 : 6, offset: const Offset(0, 3))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: hero ? Colors.white.withOpacity(0.18) : _blueSofter,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_statIcon(s.label), size: 12, color: hero ? Colors.white : _navy),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(s.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w800,
                  color: hero ? Colors.white.withOpacity(0.85) : _inkSoft)),
        ),
      ]),
      const SizedBox(height: 5),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(s.value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: hero ? Colors.white : _navy)),
      ),
    ]),
  );

  Widget _statChip(AiStat s) => Container(
    padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _hair),
      boxShadow: [BoxShadow(color: _navy.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.label.toUpperCase(),
            style: const TextStyle(fontSize: 8.5, color: _inkSoft, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 2),
        Text(s.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
      ],
    ),
  );

  Widget _rowTile(AiRow r, {int? rank}) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: r.askOnTap == null
        ? null
        : () {
      _hideKeyboard();
      Navigator.of(context).popUntil((route) => route is! PopupRoute);
      _ask(r.askOnTap!);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (rank != null) ...[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: rank <= 3 ? const LinearGradient(colors: [_gold, _navy]) : null,
                    color: rank <= 3 ? null : _blueSofter,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$rank',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w800, color: rank <= 3 ? Colors.white : _navy)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(r.title,
                    overflow: TextOverflow.ellipsis,
                    // 🔥 theme no aachho rang nahi — hamesha ghatto
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
              ),
              const SizedBox(width: 8),
              Text(r.value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _blue)),
              if (r.askOnTap != null) Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade400),
            ],
          ),
          if (r.bar != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.only(left: rank != null ? 30 : 0),
              child: LayoutBuilder(builder: (_, c) {
                final v = r.bar!.clamp(0.0, 1.0);
                return Stack(children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(color: _blueSofter, borderRadius: BorderRadius.circular(10)),
                  ),
                  Container(
                    height: 6,
                    width: c.maxWidth * v,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_gold, _navy]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ]);
              }),
            ),
          ],
          if (r.sub != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: rank != null ? 30 : 0),
              child: Text(r.sub!, style: const TextStyle(fontSize: 11, color: _inkSoft, fontWeight: FontWeight.w500)),
            ),
          ],
        ],
      ),
    ),
  );

  // =====================================================================
  //  💎 PREMIUM LIST
  // =====================================================================
  static const Color _ink = Color(0xff1B2433); // title (theme par aadhar nahi)
  static const Color _inkSoft = Color(0xff6B7487); // subtitle
  static const Color _line = Color(0xffE4EAF5); // card border

  /// "Najik na piece  [6]   Badha juo ›"
  Widget _listHeader(String title, int count, {VoidCallback? onAll}) => Row(
    children: [
      Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_goldLight, _gold],
          ),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink, letterSpacing: 0.2)),
      ),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)),
        child: Text('$count',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      const Spacer(),
      if (onAll != null)
        InkWell(
          onTap: onAll,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('See all',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _blue)),
              Icon(Icons.chevron_right_rounded, size: 16, color: _blue),
            ]),
          ),
        ),
    ],
  );

  Widget _showMoreButton(int more, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _blueSofter,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _blueSoft),
        ),
        alignment: Alignment.center,
        child: Text('+ See $more more',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _blue)),
      ),
    ),
  );

  /// Card ma batavva layak details (Item / Net to upar dekhay che j)
  List<AiStat> _miniDetails(AiRecord r) => r.details
      .where((d) =>
  d.label != 'Item' &&
      d.label != 'Net' &&
      !RegExp(r'^0(\.0+)?\s*g$').hasMatch(d.value.trim()))
      .take(3)
      .toList();

  // =====================================================================
  //  ✨ PREMIUM VOUCHER CARD (barcode timeline: approval / sale / return / job work / label)
  // =====================================================================
  static const Color _vNavy = _navy;
  static const Color _vGold = _gold;

  ({IconData icon, Color color, String kind}) _voucherStyle(String module, String title) {
    final m = module.toLowerCase();
    final t = title.toLowerCase();
    if (m.contains('sale') || t.contains('sale')) {
      return (icon: Icons.receipt_long_rounded, color: const Color(0xff059669), kind: 'SALE');
    }
    if (m.contains('return') || t.contains('return')) {
      return (icon: Icons.assignment_return_rounded, color: const Color(0xff2563EB), kind: 'RETURN');
    }
    if (m.contains('receive') || t.contains('receive')) {
      return (icon: Icons.move_to_inbox_rounded, color: const Color(0xff7C3AED), kind: 'JOB RECEIVE');
    }
    if (m.contains('job') || t.contains('job')) {
      return (icon: Icons.handyman_rounded, color: const Color(0xff7C3AED), kind: 'JOB ISSUE');
    }
    if (m.contains('approval') || t.contains('approval')) {
      return (icon: Icons.assignment_turned_in_rounded, color: const Color(0xffD97706), kind: 'APPROVAL');
    }
    if (t.contains('print')) return (icon: Icons.print_rounded, color: const Color(0xff475569), kind: 'LABEL');
    return (icon: Icons.sell_rounded, color: _vGold, kind: 'LABEL');
  }

  bool _isTimelineCard(AiRecord r) =>
      VoucherDetails.voucherOf(r) != null || r.title.startsWith('🏷️') || r.title.startsWith('🖨️');

  Widget _voucherTile(AiRecord r, {String? moduleId}) {
    final ref = VoucherDetails.voucherOf(r);
    final style = _voucherStyle(ref?.module ?? '', r.title);
    // "📋 Approval · APP123" → "APP123"
    var title = r.title.replaceFirst(RegExp(r'^[^A-Za-z0-9]+'), '').trim();
    if (title.contains(' · ')) title = title.split(' · ').last.trim();
    final sub = AiEnglish.fix(r.subtitle ?? '');
    String? date, person, personRole;
    for (final part in sub.split(' · ')) {
      final p = part.trim();
      if (RegExp(r'^\d{1,2}[-/]\d{1,2}[-/]\d{2,4}').hasMatch(p)) {
        date = p;
      } else if (p.contains(':')) {
        personRole = p.split(':').first.trim();
        person = p.split(':').sublist(1).join(':').trim();
      } else if (date == null && p.isNotEmpty && ref == null) {
        date = p;
      }
    }
    final c = style.color;
    final isVoucher = ref != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffE9EBF2)),
        boxShadow: [
          BoxShadow(color: _vNavy.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openRecord(r, moduleId),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 4, color: c),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [c.withOpacity(0.16), c.withOpacity(0.06)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: c.withOpacity(0.25)),
                        ),
                        child: Icon(style.icon, color: c, size: 21),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(style.kind,
                              style: TextStyle(
                                  color: c, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                          const SizedBox(height: 2),
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _vNavy, fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                        ]),
                      ),
                      if (r.badge != null) _premiumBadge(AiEnglish.fix(r.badge!), r.badgeGood),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 14, runSpacing: 6, children: [
                      if (date != null && date.isNotEmpty) _metaLine(Icons.event_rounded, date),
                      if (person != null)
                        _metaLine(
                          personRole == 'Worker' ? Icons.engineering_rounded : Icons.person_rounded,
                          person,
                          strong: true,
                          muted: person == 'Not set',
                        ),
                      if (!isVoucher && r.value != null) _metaLine(Icons.qr_code_2_rounded, r.value!, strong: true),
                    ]),
                    if (isVoucher) ...[
                      const SizedBox(height: 10),
                      Container(height: 1, color: const Color(0xffF0F1F6)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xffFFF1F3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xffFECDD3)),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.picture_as_pdf_rounded, size: 13, color: Color(0xffE11D48)),
                            SizedBox(width: 4),
                            Text('PDF',
                                style: TextStyle(
                                    color: Color(0xffE11D48), fontSize: 10.5, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        const Text('Items, totals & download',
                            style: TextStyle(color: Color(0xff8A90A6), fontSize: 11.5)),
                        const Spacer(),
                        const Text('View',
                            style: TextStyle(color: _vNavy, fontSize: 12.5, fontWeight: FontWeight.w800)),
                        const Icon(Icons.chevron_right_rounded, color: _vNavy, size: 20),
                      ]),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _metaLine(IconData i, String t, {bool strong = false, bool muted = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 14, color: const Color(0xff9AA1B5)),
      const SizedBox(width: 4),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: muted ? const Color(0xffB0B5C5) : (strong ? _ink : _inkSoft),
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              fontStyle: muted ? FontStyle.italic : FontStyle.normal,
            )),
      ),
    ],
  );

  Widget _premiumBadge(String text, bool good) {
    final l = text.toLowerCase();
    final Color fg = l.contains('sold')
        ? const Color(0xffDC2626)
        : l.contains('return')
        ? const Color(0xff2563EB)
        : (l.contains('approval') || l.contains('pending'))
        ? const Color(0xffD97706)
        : good
        ? const Color(0xff059669)
        : const Color(0xffDC2626);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
      ]),
    );
  }

  Widget _recordTile(AiRecord r, {String? moduleId}) {
    if (BranchAi.isBranchCard(r)) return _branchTile(r);
    if (_isTimelineCard(r)) return _voucherTile(r, moduleId: moduleId);
    final minis = _miniDetails(r);
    final style = _recordStyle(r);
    final flow = r.value != null && r.value!.contains('→') ? r.value!.split('→').map((e) => e.trim()).toList() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openRecord(r, moduleId),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ---- colour strip (type) ----
              Container(width: 4, color: style.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (r.showThumb) ...[
                      _thumb(r, 66),
                      const SizedBox(width: 10),
                    ] else ...[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: style.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: style.color.withOpacity(0.18)),
                        ),
                        child: Icon(style.icon, size: 18, color: style.color),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // ---- title (full, 2 lines) + chevron ----
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Text(
                              r.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w800, color: _ink, letterSpacing: 0.2, height: 1.25),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xffB6C2D9)),
                        ]),
                        if (r.subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            AiEnglish.fix(r.subtitle!),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.8, color: _inkSoft, fontWeight: FontWeight.w500, height: 1.3),
                          ),
                        ],
                        // ---- value: issued → received (2 boxes) or one pill ----
                        if (r.value != null) ...[
                          const SizedBox(height: 8),
                          if (flow != null && flow.length == 2)
                            _flowRow(flow[0], flow[1])
                          else
                            Align(alignment: Alignment.centerLeft, child: _weightPill(r.value!, margin: false)),
                        ],
                        // ---- status + small facts ----
                        if (r.badge != null || minis.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (r.badge != null) _badge(AiEnglish.fix(r.badge!), r.badgeGood),
                              ...minis.map(_miniChip),
                            ],
                          ),
                        ],
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// type colour + icon from the record text (receive / issue / sale / approval / loss …)
  ({Color color, IconData icon}) _recordStyle(AiRecord r) {
    final t = '${r.title} ${r.subtitle ?? ''} ${r.badge ?? ''}'.toLowerCase();
    if (t.contains('receive') || t.contains('recive')) return (color: const Color(0xff7C3AED), icon: Icons.move_to_inbox_rounded);
    if (t.contains('issue')) return (color: const Color(0xffEA580C), icon: Icons.outbox_rounded);
    if (t.contains('sale') || t.contains('-sl-')) return (color: const Color(0xff059669), icon: Icons.receipt_long_rounded);
    if (t.contains('approval') || t.contains('-app-')) return (color: const Color(0xffD97706), icon: Icons.assignment_turned_in_rounded);
    if (t.contains('return')) return (color: const Color(0xff2563EB), icon: Icons.assignment_return_rounded);
    if (t.contains('loss') || t.contains('gain')) return (color: const Color(0xff0891B2), icon: Icons.balance_rounded);
    if (t.contains('casting') || t.contains('tree') || t.contains('sorting')) {
      return (color: const Color(0xffDC2626), icon: Icons.local_fire_department_rounded);
    }
    return (color: _navy, icon: Icons.description_rounded);
  }

  /// "0.000 → 400.000 g"  →  [ISSUED 0.000 g] → [RECEIVED 400.000 g]
  Widget _flowRow(String a, String b) {
    String unit(String v) => v.endsWith('g') ? v : '$v g';
    Widget box(String label, String v, bool strong) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
        decoration: BoxDecoration(
          gradient: strong ? const LinearGradient(colors: [_navy2, _navy]) : null,
          color: strong ? null : _blueSofter,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: strong ? _navy : _hair),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w800,
                  color: strong ? Colors.white.withOpacity(0.85) : _inkSoft)),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(unit(v),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: strong ? Colors.white : _navy)),
          ),
        ]),
      ),
    );
    return Row(children: [
      box('ISSUED', a.replaceAll(RegExp(r'\s*g$'), ''), false),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.arrow_forward_rounded, size: 16, color: _blue),
      ),
      box('RECEIVED', b.replaceAll(RegExp(r'\s*g$'), ''), true),
    ]);
  }

  Future<void> _openBranchCard(AiRecord r, Future<AiAnswer> Function() load) async {
    setState(() {
      _msgs.add(_ChatMsg.user('🏢 ${r.title} — details'));
      _thinking = true;
    });
    _scrollDown();
    AiAnswer a;
    try {
      a = await load();
    } catch (_) {
      a = const AiAnswer(text: 'Could not open this branch. Please try again.');
    }
    if (!mounted) return;
    setState(() {
      _thinking = false;
      _addAi(a, null);
    });
    _scrollDown();
  }

  /// 🏢 premium branch card — tap → that branch's vouchers
  Widget _branchTile(AiRecord r) {
    String? stat(String k) {
      for (final d in r.details) {
        if (d.label.toLowerCase() == k.toLowerCase()) return d.value;
      }
      return null;
    }

    final tiles = r.details.where((d) => d.label != 'Branch').take(4).toList();
    final good = r.badgeGood;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _hair),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openRecord(r, null),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ---- header: gradient strip ----
            Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xffEFF6FF), Color(0xffFFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: _hair)),
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_gold, _navy]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: _navy.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Icon(Icons.store_mall_directory_rounded, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _ink)),
                    if (r.subtitle != null)
                      Text(r.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: _inkSoft, fontWeight: FontWeight.w500)),
                  ]),
                ),
                if (r.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: (good ? const Color(0xff16A34A) : const Color(0xffDC2626)).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: (good ? const Color(0xff16A34A) : const Color(0xffDC2626)).withOpacity(0.25)),
                    ),
                    child: Text(r.badge!,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: good ? const Color(0xff15803D) : const Color(0xffB91C1C))),
                  ),
              ]),
            ),
            // ---- big value + stat tiles ----
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (r.value != null)
                  Row(children: [
                    const Icon(Icons.scale_rounded, size: 15, color: _navy),
                    const SizedBox(width: 6),
                    Text(r.value!,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy, letterSpacing: 0.2)),
                  ]),
                if (tiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (_, c) {
                    final per = c.maxWidth >= 520 ? 4 : 2;
                    final w = (c.maxWidth - (per - 1) * 8) / per;
                    return Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final d in tiles)
                        Container(
                          width: w,
                          padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                          decoration: BoxDecoration(
                            color: const Color(0xffF7FAFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _hair),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.label.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 9, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: _inkSoft)),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(d.value,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
                            ),
                          ]),
                        ),
                    ]);
                  }),
                ],
                const SizedBox(height: 9),
                Container(
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_gold, _navy]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('View ${stat('Entries') ?? stat('Sale bills') ?? ''} details'.replaceAll('  ', ' '),
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _weightPill(String value, {bool margin = true}) => Container(
    margin: EdgeInsets.only(left: margin ? 6 : 0),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      gradient: LinearGradient(colors: [_blueSofter, _blueSoft.withOpacity(0.55)]),
      border: Border.all(color: _blueSoft),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.scale_rounded, size: 12, color: _blue),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _blue)),
    ]),
  );

  Widget _miniChip(AiStat s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xffF5F7FB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: Text.rich(
      TextSpan(children: [
        TextSpan(text: '${AiEnglish.fix(s.label)} ', style: const TextStyle(color: _inkSoft)),
        TextSpan(text: AiEnglish.fix(s.value), style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
      ]),
      style: const TextStyle(fontSize: 10.5),
    ),
  );

  Widget _badge(String text, bool good) {
    final fg = good ? const Color(0xff1E8449) : const Color(0xffC0392B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: good ? const Color(0xffE8F6EE) : const Color(0xffFDECEC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }

  Widget _thumb(AiRecord r, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: _thumbFill(r),
    ),
  );

  /// Photo hoy to image (loading shimmer sathe), na hoy to premium placeholder
  Widget _thumbFill(AiRecord r) {
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blueSofter, _blueSoft.withOpacity(0.6)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.diamond_outlined, color: _blue, size: 22),
          const SizedBox(height: 2),
          Text('No photo', style: TextStyle(fontSize: 8.5, color: _blue, fontWeight: FontWeight.w600)),
        ],
      ),
    );
    if (r.imageUrl == null) return placeholder;
    return Image.network(
      r.imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
        color: _blueSofter,
        alignment: Alignment.center,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
        ),
      ),
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  void _showAllItems(AiAnswer a, [String? moduleId]) {
    _hideKeyboard();
    final grid = a.items.any((e) => e.showThumb);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: _listHeader(a.itemsTitle ?? 'List', a.items.length),
            ),
            Expanded(
              child: grid
                  ? GridView.builder(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.70,
                ),
                itemCount: a.items.length,
                itemBuilder: (_, i) {
                  final r = a.items[i];
                  final good = r.badgeGood;
                  return GestureDetector(
                    onTap: () => _openRecord(r, moduleId),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _line),
                        boxShadow: [
                          BoxShadow(
                              color: _blue.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(children: [
                        Expanded(
                          child: Stack(children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                child: _thumbFill(r),
                              ),
                            ),
                            if (r.badge != null)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    color: good ? const Color(0xff1E8449) : const Color(0xffC0392B),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
                          child: Column(children: [
                            Text(r.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w800, color: _ink)),
                            if (r.value != null) ...[
                              const SizedBox(height: 2),
                              Text(r.value!,
                                  style: TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w700)),
                            ],
                          ]),
                        ),
                      ]),
                    ),
                  );
                },
              )
                  : ListView.separated(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: a.items.length,
                separatorBuilder: (_, __) => const SizedBox.shrink(),
                itemBuilder: (_, i) => _recordTile(a.items[i], moduleId: moduleId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllRows(AiSection s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(s.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...s.rows.map((r) => _rowTile(r)),
          ],
        ),
      ),
    );
  }

  /// AiRecord ma `refId` field hoy to e lo — na hoy to null (compile error vagar).
  /// VoucherDetails pachhi voucher no parthi id pote shodhi le che.
  String? _refIdOf(AiRecord r) {
    try {
      final v = (r as dynamic).refId;
      return v?.toString();
    } catch (_) {
      return null;
    }
  }

  /// 🔥 BADHA voucher (Sales, Approval, Job Work, Return, ...) → EK j
  ///    web jevu "Details" dialog (info + item table + Excel/PDF).
  ///    Fakt photo vala Stock piece → photo popup.
  void _openRecord(AiRecord r, String? moduleId) {
    // ⌨️ koi pan voucher / card par tap → keyboard band (ane pachhu na khule)
    _hideKeyboard();
    // 🏢 branch card → that branch's full details (as a new answer)
    final bt = BranchAi.tapOf(r);
    if (bt != null) {
      _openBranchCard(r, bt);
      return;
    }
    // 📒 Worker loss / ledger record → web jevu ledger popup
    final ledger = VoucherDetails.ledgerOf(r);
    if (ledger != null) {
      VoucherDetails.openLedger(context, ledger).whenComplete(_hideKeyboard);
      return;
    }
    // 🔗 Barcode history: Sale / Approval / Return voucher → details
    final ref = VoucherDetails.voucherOf(r);
    if (ref != null) {
      VoucherDetails.openRef(context, ref).whenComplete(_hideKeyboard);
      return;
    }
    final isPhotoItem = r.showThumb;
    if (isPhotoItem) {
      _showRecord(r);
      return;
    }
    final mod = _moduleById(moduleId);
    VoucherDetails.open(
      context,
      module: moduleId,
      id: _refIdOf(r), // null hoy to voucher no parthi id shodhi le
      title: mod != null ? '${mod.title} Details' : null,
      voucherNo: r.title,
      info: [for (final d in r.details) MapEntry(d.label, d.value)],
    ).whenComplete(_hideKeyboard);
  }

  // =====================================================================
  //  💎 PREMIUM DETAIL POPUP
  // =====================================================================
  void _showRecord(AiRecord r) {
    _hideKeyboard();
    final hasPhoto = r.showThumb && r.imageUrl != null;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => Dialog(
        // 🔥 theme no dark dialog color override — hamesha safed
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              hasPhoto ? _detailPhotoHeader(r, ctx) : _detailGradientHeader(r, ctx),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: _detailGrid(r),
                ),
              ),
              _detailFooter(r, ctx),
            ],
          ),
        ),
      ),
    );
  }

  /// Photo vala record (Stock): moti photo + niche gradient par title
  Widget _detailPhotoHeader(AiRecord r, BuildContext ctx) => AspectRatio(
    aspectRatio: 4 / 3,
    child: Stack(
      fit: StackFit.expand,
      children: [
        _thumbFill(r),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.45, 1],
              colors: [Colors.transparent, Color(0xCC0B1220)],
            ),
          ),
        ),
        Positioned(top: 10, right: 10, child: _closeButton(ctx, onDark: true)),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: _headerTexts(r),
        ),
      ],
    ),
  );

  /// Photo vagar na record (Sales, Approval, ...): brand gradient header
  Widget _detailGradientHeader(AiRecord r, BuildContext ctx) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 10, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_navy2, _navy],
      ),
      border: Border(bottom: BorderSide(color: _gold, width: 1.6)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.only(right: 12, top: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
        ),
        Expanded(child: _headerTexts(r)),
        _closeButton(ctx, onDark: true),
      ],
    ),
  );

  Widget _headerTexts(AiRecord r) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        r.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      if (r.subtitle != null) ...[
        const SizedBox(height: 2),
        Text(
          AiEnglish.fix(r.subtitle!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.85)),
        ),
      ],
      if (r.badge != null || r.value != null) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (r.value != null) _glassPill(Icons.scale_rounded, r.value!),
          if (r.badge != null) _badge(AiEnglish.fix(r.badge!), r.badgeGood),
        ]),
      ],
    ],
  );

  Widget _glassPill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.white),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
    ]),
  );

  Widget _closeButton(BuildContext ctx, {bool onDark = false}) => InkWell(
    onTap: () => Navigator.pop(ctx),
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onDark ? Colors.black.withOpacity(0.25) : _blueSofter,
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Icon(Icons.close_rounded, size: 18, color: onDark ? Colors.white : _ink),
    ),
  );

  /// Details: 2 column grid, lambi value (customer naam) puri line ma
  Widget _detailGrid(AiRecord r) {
    if (r.details.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (_, c) {
      const gap = 8.0;
      final half = (c.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: r.details.map((d) {
          final wide = d.value.length > 14 || d.label.length > 14;
          return SizedBox(width: wide ? c.maxWidth : half, child: _detailTile(d));
        }).toList(),
      );
    });
  }

  Widget _detailTile(AiStat d) {
    final money = d.value.contains('₹');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xffF7F9FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: money ? const Color(0xffFFF4E0) : _blueSofter,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconFor(d.label), size: 17, color: money ? const Color(0xffC98A0C) : _blue),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AiEnglish.fix(d.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: _inkSoft, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(AiEnglish.fix(d.value),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Label pramane icon (badha module mate)
  IconData _iconFor(String label) {
    final l = label.toLowerCase();
    bool has(List<String> w) => w.any(l.contains);
    if (has(['customer', 'party', 'grahak', 'worker', 'karigar'])) return Icons.person_rounded;
    if (has(['date', 'tarikh', 'divas'])) return Icons.calendar_month_rounded;
    if (has(['qty', 'piece', 'pcs', 'nang'])) return Icons.inventory_2_rounded;
    if (has(['purity', 'touch', 'karat'])) return Icons.verified_rounded;
    if (has(['fine'])) return Icons.workspace_premium_rounded;
    if (has(['gross', 'net', 'other', 'wt', 'weight', 'vajan'])) return Icons.scale_rounded;
    if (has(['total', 'amount', 'rakam', 'rate', 'baki', 'pending'])) return Icons.currency_rupee_rounded;
    if (has(['banavyu', 'created', 'user', 'admin', 'by'])) return Icons.badge_rounded;
    if (has(['huid'])) return Icons.qr_code_2_rounded;
    if (has(['age'])) return Icons.schedule_rounded;
    if (has(['item', 'design'])) return Icons.diamond_rounded;
    if (has(['status'])) return Icons.info_rounded;
    return Icons.label_rounded;
  }

  Widget _detailFooter(AiRecord r, BuildContext ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: BorderSide(color: _blueSoft),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final b = StringBuffer(r.title);
              if (r.subtitle != null) b.write('\n${r.subtitle}');
              for (final d in r.details) {
                b.write('\n${d.label}: ${d.value}');
              }
              Clipboard.setData(ClipboardData(text: b.toString()));
              _toast('Copied');
            },
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('Copy', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () => Navigator.pop(ctx),
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(colors: [_navy2, _navy]),
              ),
              child: const Center(
                child: Text('Close',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // -------------------- bottom --------------------
  Widget _buildSuggestions() {
    final cur = _current;
    if (_stockPosMode) {
      const list = [
        'Stock position total', 'Raw material', 'Finished stock', 'Customer received stock',
        'Temple Ring', 'All kada items',
      ];
      return SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => ActionChip(
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.white,
            side: const BorderSide(color: _hair),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            label: Text(list[i], style: const TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.w500)),
            onPressed: () => _ask(list[i]),
          ),
        ),
      );
    }
    if (_branchMode) {
      const list = [
        'Branch summary today', 'Sales today', 'Sales this month', 'Approval pending', 'Worker loss this month',
        'Job work this month', 'Stock position', 'All branches sales last month',
      ];
      return SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => ActionChip(
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.white,
            side: const BorderSide(color: _hair),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            label: Text(list[i], style: const TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.w500)),
            onPressed: () => _ask(list[i]),
          ),
        ),
      );
    }
    if (_castMode) {
      const list = [
        'Casting today', 'Casting pending', 'Casting loss this month', 'Casting heating today',
        'Metal issue today', 'Casting receive this month', 'Tree cutting office', 'Tree cutting issue today',
        'Tree cutting receive loss', 'Sorting today',
      ];
      return SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => ActionChip(
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.white,
            side: const BorderSide(color: _hair),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            label: Text(list[i], style: const TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.w500)),
            onPressed: () => _ask(list[i]),
          ),
        ),
      );
    }
    if (_jobMode) {
      const list = [
        'Job work pending', 'Job work issue today', 'Job work receive today', 'Job work issue this month',
        'Job work receive this month', 'Job work last month',
      ];
      return SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => ActionChip(
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.white,
            side: const BorderSide(color: _hair),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            label: Text(list[i], style: const TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.w500)),
            onPressed: () => _ask(list[i]),
          ),
        ),
      );
    }
    if (_barcodeMode) {
      final list = _recentCodes.isNotEmpty ? _recentCodes : const ['BR8', 'Where is BR8'];
      return SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => ActionChip(
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.white,
            side: const BorderSide(color: _hair),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            avatar: Icon(Icons.qr_code_2_rounded, size: 14, color: _blue),
            label: Text(list[i], style: const TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.w600)),
            onPressed: () => _ask(list[i]),
          ),
        ),
      );
    }
    // 🧩 badha module na suggestion mix (darek mathi 2)
    final mix = <String>[
      for (final m in _modules.where((m) => m.isLoaded)) ...m.suggestions.take(2),
      'Sales today',
      'Stock position total',
      'Job work pending',
      'Casting today',
      'Where is BR8',
    ];
    if (!_allMode && cur != null && cur.isLoaded) {
      mix
        ..clear()
        ..addAll(cur.suggestions);
    }
    if (cur == null || mix.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: mix.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final s = mix[i];
          return ActionChip(
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.white,
            side: const BorderSide(color: _hair),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            label: Text(s, style: const TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.w500)),
            onPressed: () => _ask(s),
          );
        },
      ),
    );
  }

  /// ⏱️ "Moklu chhu…" — sacho na hoy to tap kari ne sudharo
  Widget _autoSendBar() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(Icons.graphic_eq_rounded, size: 16, color: _blue),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sending… tap the text to fix it if wrong',
                  style: TextStyle(fontSize: 11.5, color: _inkSoft, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                key: ValueKey(_pendingHeard),
                tween: Tween(begin: 0, end: 1),
                duration: _autoSendDelay,
                builder: (_, v, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(value: v, minHeight: 4, backgroundColor: _blueSofter, color: _blue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _cancelAutoSend,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 30),
            backgroundColor: _blueSofter,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('✋ Stop', style: TextStyle(color: _blue, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () {
            _autoSend?.cancel();
            _fireAutoSend();
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 30),
            backgroundColor: _blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ],
    ),
  );

  Widget _buildInputBar() {
    final ready = _modules.any((m) => m.isLoaded);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _gold.withOpacity(0.35), width: 0.8)),
          boxShadow: [BoxShadow(color: _navy.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_autoSend != null) _autoSendBar(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocus,
                    enabled: ready,
                    // 🔥 type karelo text hamesha kalo (theme no safed color nahi)
                    style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w500),
                    cursorColor: _navy,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _submitTyped,
                    // tap outside the box → keyboard band
                    onTapOutside: (_) => _hideKeyboard(),
                    // ✋ auto-send vakhte text par tap → roko, sudharo, pachhi send
                    onTap: _cancelAutoSend,
                    onChanged: (_) => _cancelAutoSend(),
                    decoration: InputDecoration(
                      hintText: _listening
                          ? 'Listening…'
                          : _barcodeMode
                          ? 'Barcode code: "BR8"…'
                          : _stockPosMode
                          ? 'Item name: "Temple Ring"…'
                          : _jobMode
                          ? 'Ask: "Ramesh pending" / "issue this month"…'
                          : _castMode
                          ? 'Ask: "metal issue today" / "VV-001"…'
                          : _branchMode
                          ? 'Ask: "sales today" / "Dishank branch loss"…'
                          : (_current?.suggestions.isNotEmpty ?? false)
                          ? 'Ask: "${_current!.suggestions.first}"'
                          : 'Ask…',
                      hintStyle: const TextStyle(fontSize: 12.5, color: _inkSoft),
                      filled: true,
                      fillColor: const Color(0xffF7F8FB),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _hair)),
                      disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _hair)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _gold, width: 1.3)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(5),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _submitTyped(_input.text),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [_navy2, _navy]),
                            ),
                            child: const Icon(Icons.arrow_upward_rounded, color: _goldLight, size: 19),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: !ready
                      ? null
                      : _speaking
                      ? () {
                    _tts.stop();
                    setState(() => _speaking = false);
                  }
                      : _toggleMic,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, child) {
                      final glow = _listening ? 4 + _pulse.value * 4 + _level * 14 : 0.0;
                      final active = _listening || _speaking;
                      return Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: active
                                ? [const Color(0xffFF7A7A), const Color(0xffD9534F)]
                                : [_navy2, _navy],
                          ),
                          border: Border.all(color: active ? Colors.white : _gold, width: 1.4),
                          boxShadow: [
                            BoxShadow(
                              color: (active ? const Color(0xffD9534F) : _navy).withOpacity(0.35),
                              blurRadius: 10 + glow,
                              spreadRadius: glow / 3,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Icon(
                      _listening
                          ? Icons.stop_rounded
                          : _speaking
                          ? Icons.volume_off_rounded
                          : Icons.mic_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
//  📱 RESPONSIVE APP BAR — AskAiScreen.dart
//
//  STEP 1: In build(), replace the whole   appBar: AppBar( ... ),
//          with just:
//
//              appBar: _appBar(cur),
//
//  STEP 2: Paste this method inside _AskAiScreenState
//          (for example just above  Widget _moduleBar() => ...).
//
//  Small phone (< 400 px wide): Hands-free + Voice move into the ⋮ menu,
//  so the title never gets squeezed / overflows.
//  Normal phone / tablet: all icons show as before.
// =====================================================================

  PreferredSizeWidget _appBar(AiModule? cur) {
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 400; // small phones
    final tiny = w < 340; // very small phones
    final logo = tiny ? 28.0 : 34.0;

    final status = _speaking
        ? '🔊 Speaking…'
        : _listening
        ? '🎤 Listening…'
        : cur == null
        ? ''
        : _barcodeMode
        ? 'Barcode · where is it now + history'
        : _stockPosMode
        ? 'Stock Position · item / type / customer'
        : _jobMode
        ? 'Job Work · issue · receive · pending'
        : _castMode
        ? 'Casting · heating · metal · receive · tree cutting · sorting'
        : _branchMode
        ? 'Branch · ${BranchAi.selectedText}'
        : _allMode
        ? _modules.map((m) => m.title).join(' · ')
        : '${cur.title} · ${cur.statusLine}';

    Widget action(IconData icon, String tip, Color color, VoidCallback onTap) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: compact ? 36 : 42, minHeight: 40),
      iconSize: compact ? 21 : 23,
      icon: Icon(icon, color: color),
      onPressed: onTap,
    );

    void toggleHandsFree() {
      setState(() {
        _handsFree = !_handsFree;
        _emptyListens = 0;
      });
      _toast(_handsFree ? 'Hands-free on: the mic turns on by itself after each answer' : 'Hands-free off');
    }

    void toggleSpeak() {
      setState(() => _speakOn = !_speakOn);
      if (!_speakOn) _tts.stop();
    }

    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: _navy,
      titleSpacing: 0,
      toolbarHeight: tiny ? 52 : 56,
      shape: Border(bottom: BorderSide(color: _gold.withOpacity(0.45), width: 0.8)),
      title: Row(
        children: [
          Container(
            height: logo,
            width: logo,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_navy2, _navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: _gold, width: 1.2),
              boxShadow: [BoxShadow(color: _navy.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: FaIcon(FontAwesomeIcons.wandMagicSparkles, size: tiny ? 12 : 14, color: _goldLight),
          ),
          SizedBox(width: tiny ? 8 : 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      'Ask AI',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: tiny ? 14.5 : 16,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_goldLight, _gold]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('PRO',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: _navy, letterSpacing: 0.8)),
                  ),
                ]),
                if (status.isNotEmpty)
                  Text(
                    status,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: tiny ? 9.5 : 10.5, color: _inkSoft, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // 📑 Report builder: Customer + Range + Action → item-wise PDF
        action(Icons.summarize_rounded, 'Report builder (PDF)', _blue, () {
          _hideKeyboard();
          AiReportBuilder.open(context);
        }),
        if (!compact) ...[
          action(
            _handsFree ? Icons.headset_mic_rounded : Icons.headset_off_rounded,
            _handsFree ? 'Hands-free off' : 'Hands-free (keep talking)',
            _handsFree ? _gold : Colors.black38,
            toggleHandsFree,
          ),
          action(
            _speakOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            _speakOn ? 'Mute voice' : 'Turn on voice',
            _blue,
            toggleSpeak,
          ),
        ],
        PopupMenuButton<String>(
          tooltip: 'More',
          padding: EdgeInsets.zero,
          icon: Icon(Icons.more_vert_rounded, color: _blue, size: compact ? 21 : 23),
          // ✨ premium menu: white card, soft blue shadow, radius 10, opens under the icon
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 10,
          shadowColor: _navy.withOpacity(0.25),
          constraints: const BoxConstraints(minWidth: 236, maxWidth: 280),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _hair),
          ),
          onSelected: (v) {
            if (v == 'handsfree') {
              toggleHandsFree();
            } else if (v == 'speak') {
              toggleSpeak();
            } else if (v == 'refresh') {
              StockPositionAi.clearCache();
              DateAi.clearCache();
              JobWorkAi.clearCache();
              CastingAi.clearCache();
              BranchAi.clearCache();
              _loadAll(force: true);
            } else if (v == 'clear') {
              setState(() => _msgs.clear());
            } else if (v.startsWith('ans_')) {
              _setAnswerLang(v.substring(4));
            } else if (v == 'voicefix') {
              _showVoiceFixes();
            } else if (_locales.containsKey(v)) {
              setState(() => _localeId = v);
              SharedPreferences.getInstance().then((p) => p.setString('ai_mic_locale', v)).catchError((_) => false);
              // 🌐 Gujarati / Hindi mic → question translator (one-time download, background)
              if (v != 'en_IN') AiTranslator.ensureModel(v.substring(0, 2));
              if (!_localeAvailable(v)) {
                _toast('${_locales[v]} voice is not installed on this phone — add this language in the '
                    'Google app Voice settings, otherwise English will be used.');
              }
            }
          },
          itemBuilder: (_) => [
            // 📱 small phone → these two live here instead of the top bar
            if (compact) ...[
              _menuLabel('VOICE'),
              _menuItem('handsfree', Icons.headset_mic_rounded, 'Hands-free',
                  sub: 'Mic turns on after each answer', color: const Color(0xff7C3AED), on: _handsFree),
              _menuItem('speak', Icons.volume_up_rounded, 'Voice answers',
                  sub: 'Read answers aloud', color: const Color(0xff0891B2), on: _speakOn),
              _menuDivider(),
            ],
            _menuLabel('CHAT & DATA'),
            _menuItem('refresh', Icons.refresh_rounded, 'Refresh data',
                sub: 'Load the latest stock, sales…', color: const Color(0xff2563EB)),
            _menuItem('voicefix', Icons.record_voice_over_rounded, 'Learned words',
                sub: 'Mic corrections you taught', color: const Color(0xff059669)),
            _menuItem('clear', Icons.cleaning_services_rounded, 'Clear chat',
                sub: 'Remove all messages', color: const Color(0xffE11D48)),
            _menuDivider(),
            _menuLabel('MIC LANGUAGE'),
            ..._locales.entries.map((e) => _menuItem(
              e.key,
              Icons.mic_rounded,
              e.value,
              color: const Color(0xffD97706),
              selected: e.key == _localeId,
            )),
          ],
        ),
        SizedBox(width: compact ? 2 : 4),
      ],
      // 🧩 "All" chip (badhu ek sathe) + module chips (jene alag vaparvu hoy)
      bottom: _modules.isNotEmpty ? PreferredSize(preferredSize: const Size.fromHeight(48), child: _moduleBar()) : null,
    );
  }

  // =====================================================================
  //  ✨ PREMIUM ⋮ MENU ITEMS
  // =====================================================================
  PopupMenuItem<String> _menuLabel(String t) => PopupMenuItem<String>(
    enabled: false,
    height: 26,
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
    child: Text(t,
        style: const TextStyle(fontSize: 9.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: _inkSoft)),
  );

  PopupMenuItem<String> _menuDivider() => const PopupMenuItem<String>(
    enabled: false,
    height: 9,
    padding: EdgeInsets.symmetric(horizontal: 12),
    child: Divider(height: 1, thickness: 1, color: _hair),
  );

  /// [on] = switch style (Hands-free / Voice) · [selected] = radio tick (mic language)
  PopupMenuItem<String> _menuItem(String value, IconData icon, String title,
      {String? sub, Color color = _navy2, bool? on, bool selected = false}) {
    final active = selected || (on ?? false);
    return PopupMenuItem<String>(
      value: value,
      height: sub == null ? 44 : 52,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _goldSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _goldLight : Colors.transparent),
        ),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w700, color: _ink)),
              if (sub != null)
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: _inkSoft)),
            ]),
          ),
          if (on != null)
          // small switch look (tap row to toggle)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 34,
              height: 20,
              padding: const EdgeInsets.all(2),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: on ? _navy2 : const Color(0xffD5DBE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            )
          else if (selected)
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: _navy2, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
            ),
        ]),
      ),
    );
  }
}