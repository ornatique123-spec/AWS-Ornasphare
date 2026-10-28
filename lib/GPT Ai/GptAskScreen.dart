import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'GptClient.dart';
import 'GptStock.dart';
import 'GptTools.dart';

/// =======================================================================
///  🤖 ASK AI · GPT (TEST) — a SEPARATE screen. Your own Ask AI is not touched.
///
///   • Ask in any language (type or 🎤) → ChatGPT understands
///   • ChatGPT calls tools → the app reads YOUR data → answer in the SAME language
///   • Stock loads quietly (no loader popup) — see the pill under the title
///   • Nothing can stay stuck: every step has a time limit + ⏹ Stop button
///
///  Open:  Navigator.push(context, MaterialPageRoute(builder: (_) => const GptAskScreen()));
///  Files: Ask AI GPT/  GptAskScreen · GptClient · GptTools · GptStock
/// =======================================================================
class GptAskScreen extends StatefulWidget {
  const GptAskScreen({Key? key}) : super(key: key);

  @override
  State<GptAskScreen> createState() => _GptAskScreenState();
}

class _Msg {
  final bool user;
  final String text;
  final String? note;
  final bool error;
  _Msg(this.user, this.text, {this.note, this.error = false});
}

class _GptAskScreenState extends State<GptAskScreen> with TickerProviderStateMixin {
  // 🎨 premium palette
  static const Color _green = Color(0xff10A37F);
  static const Color _greenDark = Color(0xff0B7A5F);
  static const Color _ink = Color(0xff111827);
  static const Color _muted = Color(0xff6B7280);
  static const Color _bg = Color(0xffF7F7F8);
  static const Color _line = Color(0xffE5E7EB);

  final List<_Msg> _msgs = [];
  final List<Map<String, dynamic>> _history = [];
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _rec = AudioRecorder();
  late final AnimationController _dots =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  bool _busy = false;
  int _run = 0; // increases on Stop / new question → old answers are ignored
  String _status = '';
  bool _recording = false;
  bool _speakOn = true;
  String? _recPath;
  StreamSubscription<Amplitude>? _amp;
  Timer? _recMax;
  double _level = 0;
  String _shopName = 'our shop';

  static const Duration _chatLimit = Duration(seconds: 100);
  static const Duration _toolLimit = Duration(seconds: 70);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await GptClient.load();
    try {
      final p = await SharedPreferences.getInstance();
      final n = (p.getString('companyName') ?? '').trim();
      if (n.isNotEmpty && n != 'null') _shopName = n;
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
    // 📦 stock in the background, no popup, after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GptStock.safe();
      if (!GptClient.hasKey) _settings();
    });
  }

  @override
  void dispose() {
    _run++;
    _amp?.cancel();
    _recMax?.cancel();
    _rec.dispose();
    _tts.stop();
    _dots.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  //  SYSTEM PROMPT
  // ---------------------------------------------------------------------
  String get _system {
    final today = DateFormat('yyyy-MM-dd (EEEE)').format(DateTime.now());
    return '''
You are "Ask AI", the assistant inside the jewellery ERP of $_shopName (India). Today is $today.

LANGUAGE
- Always reply in the SAME language and script as the user's last message.
  Gujarati script → Gujarati. Hindi → Hindi. English → English.
  Gujlish (Gujarati written in English letters) → reply in simple Gujlish (English letters).
- Keep item names, customer names, barcodes, numbers and units exactly as in the data.

DATA
- Never guess numbers. For any stock / sale / approval / return / barcode question, call a tool first.
- Dates: resolve words like today, yesterday, aaje, kale, parmdivase, aa mahine, gaya mahine, September
  into yyyy-mm-dd using today's date. Financial year starts 1 April.
- If a tool returns an error or nothing, say so plainly in one line. If the customer or date is unclear,
  ask one short question.

STYLE
- Short and clear, like ChatGPT. Lead with the answer in **bold**, then up to 8 bullet points starting with "- ".
- Weights in g with 3 decimals; amounts like ₹1,25,000.00.
- Do not show JSON, tool names or ids.
''';
  }

  // ---------------------------------------------------------------------
  //  ASK
  // ---------------------------------------------------------------------
  Future<void> _ask(String q) async {
    q = q.trim();
    if (q.isEmpty || _busy) return;
    if (!GptClient.hasKey) return _settings();
    _tts.stop();
    _input.clear();
    _focus.unfocus();
    final myRun = ++_run;
    setState(() {
      _msgs.add(_Msg(true, q));
      _busy = true;
      _status = 'Thinking…';
    });
    _down();

    _history.add({'role': 'user', 'content': q});
    if (_history.length > 16) _history.removeRange(0, _history.length - 16);

    final used = <String>{};
    try {
      final convo = <Map<String, dynamic>>[
        {'role': 'system', 'content': _system},
        ..._history,
      ];
      String answer = '';
      for (var step = 0; step < 6; step++) {
        final m = await GptClient.chat(convo, GptTools.definitions).timeout(_chatLimit);
        if (myRun != _run) return; // stopped
        final calls = (m['tool_calls'] as List?) ?? const [];
        if (calls.isEmpty) {
          answer = (m['content'] ?? '').toString().trim();
          break;
        }
        convo.add({'role': 'assistant', 'content': m['content'], 'tool_calls': calls});
        for (final c in calls.whereType<Map>()) {
          final fn = c['function'] as Map? ?? {};
          final name = '${fn['name']}';
          used.add(name);
          if (mounted) setState(() => _status = _label(name));
          final out = await GptTools.run(name, '${fn['arguments'] ?? '{}'}')
              .timeout(_toolLimit, onTimeout: () => '{"error":"data took too long, try a smaller date range"}');
          if (myRun != _run) return;
          convo.add({'role': 'tool', 'tool_call_id': c['id'], 'content': out});
        }
      }
      if (answer.isEmpty) answer = 'Sorry, I could not get an answer. Please ask again.';
      _history.add({'role': 'assistant', 'content': answer});
      _finish(myRun, _Msg(false, answer, note: used.isEmpty ? null : used.map(_short).join(' · ')));
      if (_speakOn && myRun == _run) _speak(answer);
    } catch (e) {
      if (_history.isNotEmpty && _history.last['role'] == 'user') _history.removeLast();
      _finish(myRun, _Msg(false, _friendly(e), error: true));
    }
  }

  void _finish(int myRun, _Msg m) {
    if (!mounted || myRun != _run) return;
    setState(() {
      _msgs.add(m);
      _busy = false;
      _status = '';
    });
    _down();
  }

  void _stop() {
    _run++;
    _tts.stop();
    if (_history.isNotEmpty && _history.last['role'] == 'user') _history.removeLast();
    setState(() {
      _busy = false;
      _status = '';
      _msgs.add(_Msg(false, 'Stopped.', error: true));
    });
  }

  String _friendly(Object e) {
    final s = '$e';
    final low = s.toLowerCase();
    if (e is TimeoutException) return 'It is taking too long. Please try again.';
    if (s.contains('401') || low.contains('api key') || s.contains('403')) return 'The API key is not valid. Check it in ⚙️ settings.';
    if (s.contains('429') || low.contains('quota') || low.contains('rate limit') || low.contains('exhausted')) return 'The free limit is reached for now. Wait a minute and try again.';
    if (s.contains('model')) return 'The model name is not available. Change it in ⚙️ settings.\n($s)';
    if (s.contains('SocketException') || s.contains('connection')) return 'No internet connection. Please check and try again.';
    return 'Something went wrong. Please try again.\n($s)';
  }

  String _label(String tool) => switch (tool) {
    'search_stock' => 'Searching stock…',
    'stock_summary' => 'Reading stock totals…',
    'top_items' => 'Ranking items…',
    'barcode_history' => 'Checking barcode history…',
    'sales_list' => 'Reading sales…',
    'approvals_list' => 'Reading approvals…',
    'returns_list' => 'Reading returns…',
    'voucher_items' => 'Opening voucher…',
    _ => 'Working…',
  };

  String _short(String tool) => switch (tool) {
    'search_stock' || 'stock_summary' || 'top_items' => 'Stock',
    'barcode_history' => 'Barcode',
    'sales_list' => 'Sales',
    'approvals_list' => 'Approvals',
    'returns_list' => 'Returns',
    'voucher_items' => 'Voucher',
    _ => tool,
  };

  // ---------------------------------------------------------------------
  //  🔊 SPEAK
  // ---------------------------------------------------------------------
  Future<void> _speak(String s) async {
    final clean = s
        .replaceAll(RegExp(r'[*#_`>|]'), ' ')
        .replaceAll('₹', ' rupees ')
        .replaceAll(RegExp(r'(\d) ?g\b'), r'$1 grams')
        .replaceAll(RegExp(r'\s+'), ' ');
    final lang = RegExp(r'[઀-૿]').hasMatch(s)
        ? 'gu-IN'
        : (RegExp(r'[ऀ-ॿ]').hasMatch(s) ? 'hi-IN' : 'en-IN');
    try {
      await _tts.setLanguage(lang);
      await _tts.setSpeechRate(0.48);
      await _tts.speak(clean.length > 600 ? clean.substring(0, 600) : clean);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  //  🎤 VOICE
  // ---------------------------------------------------------------------
  Future<void> _mic() async {
    if (_recording) return _stopMic();
    if (!GptClient.hasKey) return _settings();
    try {
      if (!await _rec.hasPermission()) {
        _toast('Please allow the microphone');
        return;
      }
      await _tts.stop();
      HapticFeedback.lightImpact();
      final dir = await getTemporaryDirectory();
      _recPath = '${dir.path}/gpt_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: _recPath!,
      );
      setState(() => _recording = true);
      final start = DateTime.now();
      DateTime? lastLoud;
      var spoke = false;
      _amp = _rec.onAmplitudeChanged(const Duration(milliseconds: 150)).listen((a) {
        final db = a.current.isFinite ? a.current : -60.0;
        if (mounted) setState(() => _level = ((db + 50) / 45).clamp(0.0, 1.0));
        final now = DateTime.now();
        if (db > -38) {
          spoke = true;
          lastLoud = now;
        }
        if ((spoke && now.difference(lastLoud!) > const Duration(milliseconds: 1600)) ||
            (!spoke && now.difference(start) > const Duration(seconds: 7))) {
          _stopMic();
        }
      });
      _recMax = Timer(const Duration(seconds: 30), _stopMic);
    } catch (e) {
      _toast('Mic error: $e');
    }
  }

  Future<void> _stopMic() async {
    if (!_recording) return;
    _recMax?.cancel();
    await _amp?.cancel();
    _amp = null;
    try {
      await _rec.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recording = false;
      _level = 0;
      _busy = true;
      _status = 'Understanding your voice…';
    });
    final path = _recPath;
    _recPath = null;
    String text = '';
    try {
      final f = File(path ?? '');
      if (path != null && await f.exists() && await f.length() >= 2500) {
        // names from stock only if already loaded (never wait for it)
        final hints = GptStock.ready ? (await GptStock.safe()).map((s) => s.item).toSet().take(80).join(', ') : '';
        text = await GptClient.transcribe(f, hints: hints).timeout(const Duration(seconds: 40));
        try {
          f.deleteSync();
        } catch (_) {}
      }
    } catch (e) {
      _toast(_friendly(e).split('\n').first);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = '';
    });
    if (text.isEmpty) {
      _toast('Could not hear clearly — please try again');
      return;
    }
    _ask(text);
  }

  // ---------------------------------------------------------------------
  //  ⚙️ SETTINGS
  // ---------------------------------------------------------------------
  Future<void> _settings() async {
    if (!mounted) return;
    var prov = GptClient.providerId;
    final key = TextEditingController(text: GptClient.key);
    final model = TextEditingController(text: GptClient.model);
    final stt = TextEditingController(text: GptClient.sttModel);
    InputDecoration deco(String l, IconData i, {String? hint}) => InputDecoration(
      labelText: l,
      hintText: hint,
      prefixIcon: Icon(i, size: 20),
      filled: true,
      fillColor: _bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (d) => StatefulBuilder(builder: (d, setSheet) {
        final pr = GptClient.byId(prov);
        Future<void> pick(String id) async {
          final s = await GptClient.savedFor(id);
          setSheet(() {
            prov = id;
            key.text = s.key;
            model.text = s.model;
            stt.text = s.stt;
          });
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(d).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(height: 16),
              const Text('AI settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 4),
              const Text('Pick a provider · the key stays on this phone', style: TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in GptClient.providers)
                  ChoiceChip(
                    selected: prov == p.id,
                    onSelected: (_) => pick(p.id),
                    selectedColor: const Color(0xffD1FAE5),
                    backgroundColor: _bg,
                    side: BorderSide(color: prov == p.id ? _green : _line),
                    label: Text('${p.name} · ${p.free ? 'FREE' : 'paid'}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: prov == p.id ? _greenDark : _ink)),
                  ),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xffECFDF5), borderRadius: BorderRadius.circular(10)),
                child: Text('Get a key: ${pr.keyUrl}  (looks like ${pr.keyHint})',
                    style: const TextStyle(fontSize: 12, color: _greenDark, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              TextField(controller: key, obscureText: true, decoration: deco('${pr.name} API key', Icons.key_rounded, hint: pr.keyHint)),
              const SizedBox(height: 10),
              TextField(controller: model, decoration: deco('Chat model', Icons.auto_awesome_rounded, hint: pr.chatModel)),
              const SizedBox(height: 10),
              TextField(controller: stt, decoration: deco('Voice model', Icons.graphic_eq_rounded, hint: pr.sttModel)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xffFFF7ED), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  pr.free
                      ? 'Free tier has per-minute and per-day limits — fine for testing. Move the key to the server before giving the app to others.'
                      : 'Paid: set a monthly budget limit in your account. Move the key to the server before giving the app to others.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xff9A3412)),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  await GptClient.save(newProvider: prov, newKey: key.text, newModel: model.text, newStt: stt.text);
                  if (d.mounted) Navigator.pop(d);
                  if (mounted) setState(() {});
                },
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        );
      }),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  }

  void _down() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent + 300,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  });

  // ---------------------------------------------------------------------
  //  UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: const IconThemeData(color: _ink),
        titleSpacing: 0,
        title: Row(children: [
          _logo(17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Ask AI · Pro', style: TextStyle(color: _ink, fontSize: 16.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              _stockPill(),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: _speakOn ? 'Mute voice' : 'Voice on',
            icon: Icon(_speakOn ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            onPressed: () {
              setState(() => _speakOn = !_speakOn);
              if (!_speakOn) _tts.stop();
            },
          ),
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _busy
                ? null
                : () => setState(() {
              _tts.stop();
              _msgs.clear();
              _history.clear();
            }),
          ),
          IconButton(tooltip: 'Settings', icon: const Icon(Icons.tune_rounded), onPressed: _settings),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: _line)),
      ),
      body: Column(children: [
        Expanded(child: _msgs.isEmpty && !_busy ? _empty() : _list()),
        _inputBar(),
      ]),
    );
  }

  Widget _logo(double r) => Container(
    width: r * 2,
    height: r * 2,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [_green, _greenDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Icon(Icons.auto_awesome, size: r, color: Colors.white),
  );

  Widget _stockPill() => ValueListenableBuilder<String>(
    valueListenable: GptStock.status,
    builder: (_, s, __) {
      final ok = s.startsWith('Stock ready');
      final bad = s.contains('retry');
      final txt = s.isEmpty ? 'Any language' : s;
      return GestureDetector(
        onTap: bad ? () => GptStock.safe() : null,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? _green : (bad ? Colors.redAccent : Colors.orange),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(txt,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: bad ? Colors.redAccent : _muted, fontWeight: FontWeight.w500)),
          ),
        ]),
      );
    },
  );

  Widget _empty() {
    const ideas = [
      (Icons.today_rounded, 'આજે કેટલું વેચાણ થયું?'),
      (Icons.assignment_outlined, 'Lado Creation ne September ma ketla approval apya?'),
      (Icons.trending_up_rounded, 'Which item sold the most this month?'),
      (Icons.scale_outlined, '10 થી 15 ગ્રામ ની ring stock માં બતાવો'),
      (Icons.qr_code_2_rounded, 'BR8 ક્યાં છે?'),
      (Icons.inventory_2_outlined, 'आज कितना स्टॉक है?'),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(20, 48, 20, 20), children: [
      Center(child: _logo(28)),
      const SizedBox(height: 16),
      const Center(
        child: Text('What can I help with?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
      ),
      const SizedBox(height: 6),
      const Center(
        child: Text('Ask in Gujarati, Hindi or English — I reply in the same language.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _muted)),
      ),
      const SizedBox(height: 26),
      ...ideas.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _ask(e.$2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
              child: Row(children: [
                Icon(e.$1, size: 19, color: _green),
                const SizedBox(width: 12),
                Expanded(child: Text(e.$2, style: const TextStyle(fontSize: 14, color: _ink))),
                const Icon(Icons.north_east_rounded, size: 16, color: _muted),
              ]),
            ),
          ),
        ),
      )),
    ]);
  }

  Widget _list() => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
    itemCount: _msgs.length + (_busy ? 1 : 0),
    itemBuilder: (_, i) {
      if (i == _msgs.length) return _thinkingRow();
      final m = _msgs[i];
      return m.user ? _userBubble(m) : _botBubble(m);
    },
  );

  Widget _userBubble(_Msg m) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(left: 60, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: SelectableText(m.text, style: const TextStyle(fontSize: 15, color: _ink, height: 1.35)),
    ),
  );

  Widget _botBubble(_Msg m) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      m.error
          ? const CircleAvatar(radius: 14, backgroundColor: Color(0xffFEF2F2), child: Icon(Icons.info_outline, size: 16, color: Colors.redAccent))
          : _logo(14),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 3),
          _rich(m.text, m.error),
          if (!m.error) ...[
            const SizedBox(height: 4),
            Row(children: [
              _mini(Icons.copy_rounded, () {
                Clipboard.setData(ClipboardData(text: m.text.replaceAll('**', '')));
                _toast('Copied');
              }),
              _mini(Icons.volume_up_outlined, () => _speak(m.text)),
              if (m.note != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xffECFDF5), borderRadius: BorderRadius.circular(20)),
                  child: Text('Data: ${m.note}', style: const TextStyle(fontSize: 10.5, color: _greenDark, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ],
        ]),
      ),
    ]),
  );

  /// light markdown: **bold**, "- " / "• " / "1. " bullets, # headings
  Widget _rich(String text, bool error) {
    final base = TextStyle(fontSize: 15, height: 1.5, color: error ? const Color(0xffB91C1C) : _ink);
    final lines = text.split('\n');
    final out = <Widget>[];
    for (var raw in lines) {
      var line = raw.trimRight();
      if (line.trim().isEmpty) {
        out.add(const SizedBox(height: 6));
        continue;
      }
      final t = line.trimLeft();
      final bullet = RegExp(r'^([-•*])\s+').firstMatch(t);
      final numM = RegExp(r'^(\d+)[.)]\s+').firstMatch(t);
      final head = RegExp(r'^#{1,4}\s+').firstMatch(t);
      if (head != null) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text.rich(_spans(t.substring(head.end), base.copyWith(fontWeight: FontWeight.w800, fontSize: 15.5))),
        ));
      } else if (bullet != null || numM != null) {
        final body = t.substring((bullet ?? numM)!.end);
        out.add(Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 18,
              child: bullet != null
                  ? const Padding(
                padding: EdgeInsets.only(top: 9),
                child: CircleAvatar(radius: 2.6, backgroundColor: _green),
              )
                  : Text('${numM![1]}.', style: base.copyWith(color: _green, fontWeight: FontWeight.w700)),
            ),
            Expanded(child: Text.rich(_spans(body, base))),
          ]),
        ));
      } else {
        out.add(Text.rich(_spans(t, base)));
      }
    }
    return SelectionArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: out));
  }

  TextSpan _spans(String s, TextStyle base) {
    final parts = s.split('**');
    return TextSpan(children: [
      for (var i = 0; i < parts.length; i++)
        TextSpan(text: parts[i], style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w800) : base),
    ]);
  }

  Widget _thinkingRow() => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(children: [
      _logo(14),
      const SizedBox(width: 10),
      AnimatedBuilder(
        animation: _dots,
        builder: (_, __) => Row(
          children: List.generate(3, (i) {
            final t = ((_dots.value * 3) - i).clamp(0.0, 1.0);
            final a = t < 0.5 ? t * 2 : (1 - t) * 2;
            return Container(
              margin: const EdgeInsets.only(right: 4),
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: _green.withOpacity(0.3 + a * 0.7), shape: BoxShape.circle),
            );
          }),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(child: Text(_status, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: _muted))),
    ]),
  );

  Widget _mini(IconData i, VoidCallback f) => IconButton(
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    padding: EdgeInsets.zero,
    icon: Icon(i, size: 17, color: _muted),
    onPressed: f,
  );

  Widget _inputBar() {
    final hasText = _input.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_recording)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 10 + _level * 8,
                height: 10 + _level * 8,
                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text('Listening… stop talking to send', style: TextStyle(fontSize: 12.5, color: _muted)),
            ]),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _line),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _focus,
                enabled: !_recording,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: _ask,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 15, color: _ink),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Ask anything',
                  hintStyle: TextStyle(color: _muted),
                ),
              ),
            ),
            if (!_busy)
              IconButton(
                icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                    color: _recording ? Colors.redAccent : _ink),
                onPressed: _mic,
              ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: _busy ? _stop : (hasText ? () => _ask(_input.text) : null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _busy ? _ink : (hasText ? _green : const Color(0xffD1D5DB)),
                ),
                child: Icon(_busy ? Icons.stop_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 22),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
