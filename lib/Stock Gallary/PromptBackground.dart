import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Extra/AppColors.dart';
import 'Batchbgtemplates.dart';

/// =======================================================================
///  ✨ PROMPT BACKGROUND — type a prompt, get a background for the batch
///
///  Two ways (user picks in the sheet):
///   1) AI Generate (online, FREE) → app j free public image AI ne prompt
///      mokle (koi server / key / paisa nahi), photo phone ma save thay.
///   2) Instant (offline)     → understands the prompt ("maroon velvet with
///      gold bokeh", "white marble", "diwali", "lal satin") and paints it with
///      the existing template painter. Free, instant, no internet.
///
///  Result is a normal BgTemplate → works with preview, compose, share, PDF.
///
///  Use:   final t = await PromptBackground.open(context);
///         if (t != null) setState(() => _bg = t);
///  File:  Stock Gallary/AiPromptBackground.dart
/// =======================================================================
class PromptBackground {
  PromptBackground._();

  static Future<BgTemplate?> open(BuildContext context) {
    return showModalBottomSheet<BgTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => const _PromptSheet(),
    );
  }

  // ---------------------------------------------------------------------
  //  🌐 AI GENERATE — app mathi sidhu, FREE, koi key / server nahi
  //  Free public image AI (Pollinations). Kyarek dhimu ke bandh hoy to
  //  "Instant" style pote aave che.
  // ---------------------------------------------------------------------
  /// Old free endpoint — now often returns 402 (no free quota without a key)
  static const String _freeImageApi = 'https://image.pollinations.ai/prompt/';

  /// New endpoint (needs a key)
  static const String _keyImageApi = 'https://gen.pollinations.ai/image/';

  /// 🔑 Optional Pollinations key (from enter.pollinations.ai).
  /// Empty = try the old free endpoint once, then fall back to Instant.
  /// NOTE: a key inside an app can be extracted — use a limited key only.
  static const String pollinationsKey = '';

  /// After a 402/429 we stop calling the server for a while (no repeated waits)
  static DateTime? _blockedUntil;
  static bool get onlineBlocked =>
      _blockedUntil != null && DateTime.now().isBefore(_blockedUntil!);

  // ---------------------------------------------------------------------
  //  🎯 PROMPT BUILDER — user prompt → professional photo prompt
  //  Image AI (Flux) understands POSITIVE descriptions best. Long "no podium,
  //  no candles…" lists often ADD those things, so we describe an empty,
  //  seamless surface instead. User's own words always come first.
  // ---------------------------------------------------------------------
  static const Map<String, String> _colorEnglish = {
    'maroon': 'deep royal maroon', 'wine': 'rich wine red', 'red': 'deep crimson red',
    'gold': 'warm antique gold', 'champagne': 'soft champagne gold', 'pink': 'soft blush pink',
    'peach': 'warm peach', 'blue': 'soft powder blue', 'navy': 'midnight navy blue',
    'green': 'muted sage green', 'emerald': 'deep emerald green', 'black': 'pure deep black',
    'white': 'clean pure white', 'ivory': 'warm ivory cream', 'purple': 'royal plum purple',
    'grey': 'soft silver grey', 'brown': 'rich chocolate brown', 'teal': 'deep teal',
    'orange': 'warm saffron orange', 'yellow': 'soft golden yellow',
  };

  /// material word → rich texture description (first match wins)
  static const List<List<String>> _materials = [
    ['velvet', 'plush velvet fabric backdrop with fine soft pile texture and a gentle sheen'],
    ['satin', 'smooth satin fabric backdrop with soft liquid highlights, folds only at the far edges'],
    ['silk', 'luxurious silk fabric backdrop with soft flowing sheen, folds only at the far edges'],
    ['marble', 'polished marble surface with fine natural veins, seen from directly above'],
    ['granite', 'polished granite stone surface with fine speckles, seen from directly above'],
    ['travertine', 'honed travertine stone surface with soft natural pores, seen from directly above'],
    ['stone', 'smooth natural stone surface with subtle texture, seen from directly above'],
    ['wood', 'fine-grain polished wooden surface, seen from directly above'],
    ['leather', 'fine premium leather texture backdrop with subtle grain'],
    ['linen', 'fine natural linen fabric texture backdrop'],
    ['paper', 'seamless fine-art paper studio backdrop'],
    ['bokeh', 'smooth backdrop with large soft out-of-focus bokeh lights only around the edges'],
    ['glitter', 'smooth backdrop with very fine soft glitter shimmer, slightly out of focus'],
    ['gradient', 'smooth seamless gradient studio backdrop'],
    ['water', 'calm water surface with gentle soft ripples, seen from above'],
  ];

  static String buildAiPrompt(String user) {
    final raw = user.trim().replaceAll(RegExp(r'\s+'), ' ');
    final t = ' ${raw.toLowerCase().replaceAll(RegExp(r'[^a-z\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ')} ';
    bool has(String w) => t.contains(' $w ');

    // colours (English + Gujlish) in the order the user wrote them
    final hits = <MapEntry<int, String>>[];
    _colorWords.forEach((w, key) {
      final i = t.indexOf(' $w ');
      if (i >= 0) hits.add(MapEntry(i, key));
    });
    hits.sort((a, b) => a.key.compareTo(b.key));
    final colors = <String>[];
    for (final h in hits) {
      if (!colors.contains(h.value)) colors.add(h.value);
    }

    String material = 'seamless premium studio backdrop with a subtle fine texture';
    for (final m in _materials) {
      if (has(m[0]) || t.contains(' ${m[0]}s ')) {
        material = m[1];
        break;
      }
    }
    if (has('kapdu') || has('cloth') || has('fabric')) {
      if (material.startsWith('seamless')) material = _materials[0][1];
    }

    final dark = _darkWords.any(has) ||
        (colors.isNotEmpty && const {'maroon', 'wine', 'navy', 'black', 'emerald', 'brown'}.contains(colors.first));
    final festive = _festiveWords.any(has);

    final colourText = colors.isEmpty
        ? (dark ? 'deep rich' : 'soft neutral')
        : colors.take(2).map((c) => _colorEnglish[c] ?? c).join(' with ');

    final lighting = has('spotlight') || has('dramatic')
        ? 'a single soft spotlight glowing in the centre, edges falling off into darkness'
        : dark
        ? 'soft warm light glowing in the centre, gently darker towards the edges, elegant vignette'
        : 'bright soft diffused daylight, even and airy, very gentle gradient';

    final mood = festive
        ? 'festive Indian luxury mood, warm and celebratory'
        : (dark ? 'dark luxury mood, rich and elegant' : 'clean premium minimal mood');

    // ✅ ONLY BACKGROUND: the user's own sentence is NOT sent (words like diya,
    // flowers, podium, model, ring made the AI draw things). Only the colours,
    // material and light we understood from it go to the AI — as a pure texture.
    final festiveTone = festive ? ', warm festive colour tone' : '';
    return 'seamless $colourText $material, full-frame close-up of the surface texture only, '
        'flat straight-on view, $lighting, $mood$festiveTone, '
        'plain empty background, no subject, nothing else in the image, '
        'photorealistic texture photograph, high detail, sharp';
  }

  static const String _negative =
      'person, people, model, woman, man, girl, face, hand, fingers, body, skin, mannequin, jewellery, '
      'necklace, ring, earring, bracelet, product, object, objects, flowers, petals, candle, diya, lamp, '
      'podium, pedestal, box, vase, furniture, room, plant, leaves, frame, text, letters, logo, watermark';

  /// Old name kept (used by history / other screens)
  static String _fullPrompt(String user) => buildAiPrompt(user);

  /// ⏱️ Max total wait for AI. After this → stop and keep Instant styles.
  static const Duration aiMaxWait = Duration(seconds: 40);

  /// Free (no key) service allows only ONE request at a time → many parallel
  /// requests just wait in a queue and time out. So:
  ///   • no key  → 1 photo, 768px (faster), single request
  ///   • key     → [count]+1 photos in parallel, 1024px, best ones kept
  static Future<List<BgTemplate>> generateOnline(String prompt, {int count = 2, CancelToken? cancel}) async {
    if (onlineBlocked) {
      throw Exception('Free AI limit reached. Instant styles are ready below.');
    }
    final bool keyed = pollinationsKey.isNotEmpty;
    final int size = keyed ? 1024 : 768;
    final int n = keyed ? count + 1 : 1;
    final token = cancel ?? CancelToken();

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: aiMaxWait,
      sendTimeout: const Duration(seconds: 12),
      responseType: ResponseType.bytes,
      followRedirects: true,
    ));
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/ai_bg');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final enc = Uri.encodeComponent(_fullPrompt(prompt));
    final base = DateTime.now().millisecondsSinceEpoch % 1000000;
    final scores = <String, double>{};
    int? lastStatus;
    bool slow = false;

    Future<BgTemplate?> one(int i) async {
      final seed = base + i * 7919; // darek photo alag
      // enhance=false → AI does not rewrite our prompt (stays prompt-wise)
      final q = 'width=$size&height=$size&nologo=true&enhance=false&private=true&seed=$seed'
          '&negative_prompt=${Uri.encodeComponent(_negative)}';
      final url = keyed
          ? '$_keyImageApi$enc?$q&model=flux&key=$pollinationsKey'
          : '$_freeImageApi$enc?$q';
      try {
        final r = await dio.get<List<int>>(url, cancelToken: token);
        final type = r.headers.value('content-type') ?? '';
        final data = r.data;
        // image j hovi joie (error page / nano jawab nahi)
        if (data == null || data.length < 8000 || (type.isNotEmpty && !type.startsWith('image'))) return null;
        final bytes = Uint8List.fromList(data);
        // 🔍 every image is checked: model / person / object in the middle → rejected
        final score = await compute(_clutterScore, bytes);
        if (score > _maxClutter) {
          debugPrint('✨ AI BG $i rejected (subject in middle, score ${score.toStringAsFixed(2)})');
          return null;
        }
        final f = File('${dir.path}/ai_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await f.writeAsBytes(bytes, flush: true);
        scores[f.path] = score;
        return _aiFileTemplate(f.path, prompt);
      } on DioException catch (e) {
        lastStatus = e.response?.statusCode;
        if (e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout) slow = true;
        debugPrint('✨ AI BG $i fail: ${e.type.name} HTTP ${e.response?.statusCode}');
        return null;
      } catch (e) {
        debugPrint('✨ AI BG $i fail: $e');
        return null;
      }
    }

    List<BgTemplate?> res;
    try {
      res = await Future.wait(List.generate(n, one)).timeout(aiMaxWait + const Duration(seconds: 5));
    } on TimeoutException {
      token.cancel('timeout');
      slow = true;
      res = const [];
    } finally {
      dio.close(force: true);
    }

    if (token.isCancelled && !slow) throw Exception('AI stopped. Instant styles are ready below.');

    final out = res.whereType<BgTemplate>().toList();
    if (out.isEmpty) {
      if (lastStatus == 402 || lastStatus == 401 || lastStatus == 403 || lastStatus == 429) {
        _blockedUntil = DateTime.now().add(const Duration(minutes: 10));
        throw Exception(keyed
            ? 'AI key limit reached. Instant styles are ready below.'
            : 'The free AI image service now needs a key. Instant styles are ready below.');
      }
      if (slow) {
        // free server overloaded → don't make the user wait again for 5 min
        _blockedUntil = DateTime.now().add(const Duration(minutes: 2));
        throw Exception('AI is too slow right now (free server busy). Instant styles are ready below.');
      }
      throw Exception('AI did not respond. Check internet — Instant styles are ready below.');
    }
    out.sort((a, b) => (scores[a.filePath] ?? 9).compareTo(scores[b.filePath] ?? 9));
    // drop clearly cluttered ones (object in the middle), but always keep at least 1
    // only clean backgrounds are kept (never a picture with a model / object)
    final keep = out.take(count).toList();
    for (final t in out.where((t) => !keep.contains(t))) {
      try {
        File(t.filePath!).deleteSync();
      } catch (_) {}
    }
    await _saveHistory(keep.map((t) => '${t.filePath}|$prompt').toList());
    return keep;
  }

  static BgTemplate _aiFileTemplate(String path, String prompt) => BgTemplate(
    id: 'aigen_$path',
    name: _short(prompt),
    kind: BgKind.image,
    filePath: path,
    category: BgCategory.ai,
  );

  // ---------- saved AI backgrounds (phone ma rahe, bijee var pan dekhay) ----------
  static const _histKey = 'ai_bg_history';

  static Future<void> _saveHistory(List<String> add) async {
    try {
      final p = await SharedPreferences.getInstance();
      final cur = p.getStringList(_histKey) ?? [];
      final all = [...add, ...cur.where((e) => !add.contains(e))].take(24).toList();
      await p.setStringList(_histKey, all);
    } catch (_) {}
  }

  static Future<List<BgTemplate>> savedAi() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(_histKey) ?? [];
      return list
          .map((e) => e.split('|'))
          .where((a) => a.isNotEmpty && File(a.first).existsSync())
          .map((a) => _aiFileTemplate(a.first, a.length > 1 ? a.sublist(1).join('|') : 'AI'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Can the user delete this background? (AI photos / prompt results)
  static bool isDeletable(BgTemplate t) =>
      t.id.startsWith('aigen_') || t.id.startsWith('inst_') || t.id.startsWith('prompt_');

  /// User picked a photo result → keep it saved (survives app restart)
  static Future<BgTemplate> keep(BgTemplate t) async {
    if (!t.isImage || t.filePath == null) return t;
    final kept = _aiFileTemplate(t.filePath!, t.name);
    await _saveHistory(['${t.filePath}|${t.name}']);
    return kept;
  }

  /// 🗑️ Delete one saved AI / prompt background (history + file)
  static Future<void> deleteSaved(BgTemplate t) async {
    final path = t.filePath;
    try {
      final p = await SharedPreferences.getInstance();
      final cur = p.getStringList(_histKey) ?? [];
      if (path != null) {
        await p.setStringList(_histKey, cur.where((e) => e.split('|').first != path).toList());
      }
    } catch (_) {}
    if (path != null && path.contains('/ai_bg/')) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  /// 🗑️ Delete all saved AI / prompt backgrounds
  static Future<void> deleteAllSaved() async {
    for (final t in await savedAi()) {
      await deleteSaved(t);
    }
    try {
      (await SharedPreferences.getInstance()).remove(_histKey);
    } catch (_) {}
  }

  static const _recentKey = 'ai_bg_recent_prompts';

  static Future<List<String>> recentPrompts() async {
    try {
      return (await SharedPreferences.getInstance()).getStringList(_recentKey) ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _remember(String prompt) async {
    try {
      final p = await SharedPreferences.getInstance();
      final cur = p.getStringList(_recentKey) ?? [];
      await p.setStringList(_recentKey, [prompt, ...cur.where((e) => e.toLowerCase() != prompt.toLowerCase())].take(6).toList());
    } catch (_) {}
  }

  static String _short(String p) {
    final s = p.trim();
    return s.length <= 18 ? s : '${s.substring(0, 17)}…';
  }

  // ---------------------------------------------------------------------
  //  ⚡ OFFLINE — prompt → painted template (4 variations)
  // ---------------------------------------------------------------------

  /// [light, mid, dark, accent]
  static const Map<String, List<int>> _palette = {
    'maroon': [0xffF3D9DD, 0xff8C2A3A, 0xff3A0610, 0xffD7A35A],
    'wine': [0xffF0D6DC, 0xff7A1F33, 0xff2E0510, 0xffD7A35A],
    'red': [0xffF8D7DA, 0xffC62A3D, 0xff4A0710, 0xffF5C76A],
    'gold': [0xffFFF7E3, 0xffE9CF8E, 0xff6B4E16, 0xffF5C76A],
    'champagne': [0xffFFF8EC, 0xffEAD6AE, 0xff8A6A3A, 0xffFFFFFF],
    'pink': [0xffFCEBEE, 0xffF0B9C6, 0xff8C3B52, 0xffFFFFFF],
    'peach': [0xffFCE6D8, 0xffF4C1A4, 0xff8A4A2E, 0xffFFF4EC],
    'blue': [0xffE6EEF6, 0xff7FA6D9, 0xff14234B, 0xff9CC4FF],
    'navy': [0xffD6E0F0, 0xff2B4A80, 0xff060B1C, 0xffC9A24A],
    'green': [0xffDDEFE7, 0xff6FAE8E, 0xff0F3D2E, 0xffE8D7A0],
    'emerald': [0xffCDEBDD, 0xff1F7A55, 0xff05150F, 0xffD7B05A],
    'black': [0xff6A6A72, 0xff2C2C31, 0xff0B0B0D, 0xffC9A24A],
    'white': [0xffFFFFFF, 0xffEBEBF0, 0xffB9B9C2, 0xffF5F5F7],
    'ivory': [0xffFBF8F1, 0xffEDE4D1, 0xffA8916A, 0xffFFFFFF],
    'purple': [0xffE8E3F3, 0xff9A7CC4, 0xff2E1A47, 0xffF1D9FF],
    'grey': [0xffF5F5F7, 0xffC4C4CB, 0xff4A4A52, 0xffFFFFFF],
    'brown': [0xffE9DCC8, 0xffA27A4A, 0xff3B2A0C, 0xffD9B77A],
    'teal': [0xffD3F0EE, 0xff3E9E98, 0xff0E3B3A, 0xffF2E6C2],
    'orange': [0xffFFE7CC, 0xffF2A65A, 0xff7A3410, 0xffFFD27F],
    'yellow': [0xffFFF8D6, 0xffF2D46B, 0xff7A5E10, 0xffFFFFFF],
  };

  /// prompt na shabdo → palette (English + Gujlish + Hindi)
  static const Map<String, String> _colorWords = {
    'maroon': 'maroon', 'burgundy': 'maroon', 'wine': 'wine', 'red': 'red', 'lal': 'red', 'laal': 'red',
    'gold': 'gold', 'golden': 'gold', 'sonu': 'gold', 'sonera': 'gold', 'sona': 'gold', 'champagne': 'champagne',
    'pink': 'pink', 'rose': 'pink', 'blush': 'pink', 'gulabi': 'pink', 'peach': 'peach', 'coral': 'peach',
    'blue': 'blue', 'sky': 'blue', 'vadli': 'blue', 'neelo': 'blue', 'nila': 'blue', 'navy': 'navy',
    'royal blue': 'navy', 'navy blue': 'navy', 'midnight': 'navy', 'rose gold': 'peach', 'green': 'green', 'lilo': 'green', 'hara': 'green', 'mint': 'green',
    'emerald': 'emerald', 'black': 'black', 'kalo': 'black', 'kali': 'black', 'kala': 'black', 'dark': 'black',
    'white': 'white', 'safed': 'white', 'ivory': 'ivory', 'cream': 'ivory', 'beige': 'ivory', 'offwhite': 'ivory',
    'off white': 'ivory', 'purple': 'purple', 'violet': 'purple', 'lavender': 'purple', 'jambli': 'purple',
    'grey': 'grey', 'gray': 'grey', 'silver': 'grey', 'chandi': 'grey', 'brown': 'brown', 'chocolate': 'brown',
    'coffee': 'brown', 'teal': 'teal', 'turquoise': 'teal', 'aqua': 'teal', 'orange': 'orange', 'saffron': 'orange',
    'kesari': 'orange', 'yellow': 'yellow', 'pilo': 'yellow', 'peela': 'yellow',
  };

  /// prompt na shabdo → painter style
  static const Map<String, BgKind> _styleWords = {
    'marble': BgKind.marble, 'granite': BgKind.marble, 'stone': BgKind.marble,
    'silk': BgKind.silk, 'satin': BgKind.satin, 'velvet': BgKind.velvet, 'makhmal': BgKind.velvet,
    'suede': BgKind.velvet, 'fabric': BgKind.satin, 'cloth': BgKind.satin, 'kapdu': BgKind.satin,
    'arch': BgKind.arch, 'niche': BgKind.arch, 'boutique': BgKind.arch, 'showroom': BgKind.arch,
    'foil': BgKind.goldFoil, 'flakes': BgKind.goldFoil, 'flake': BgKind.goldFoil, 'leaf gold': BgKind.goldFoil,
    'box': BgKind.jewelBox, 'case': BgKind.jewelBox, 'dabbi': BgKind.jewelBox, 'dabba': BgKind.jewelBox, 'wood': BgKind.wood, 'wooden': BgKind.wood, 'table': BgKind.wood, 'lakdu': BgKind.wood,
    'calacatta': BgKind.marbleLux, 'nero': BgKind.marbleLux, 'veined': BgKind.marbleLux,
    'veins': BgKind.marbleLux, 'italian': BgKind.marbleLux, 'stage': BgKind.stageBeam,
    'beam': BgKind.stageBeam, 'rays': BgKind.stageBeam, 'liquid': BgKind.liquidMetal,
    'molten': BgKind.liquidMetal, 'metallic': BgKind.liquidMetal, 'chrome': BgKind.liquidMetal,
    'sparkle': BgKind.sparkle, 'sparkling': BgKind.sparkle, 'diamond': BgKind.sparkle,
    'diamonds': BgKind.sparkle, 'twinkle': BgKind.sparkle,
    'bokeh': BgKind.bokeh, 'lights': BgKind.bokeh, 'blur': BgKind.bokeh,
    'diya': BgKind.bokeh, 'diwali': BgKind.bokeh, 'glitter': BgKind.glitter, 'shimmer': BgKind.glitter,
    'shine': BgKind.glitter, 'stars': BgKind.glitter, 'petal': BgKind.petals, 'petals': BgKind.petals,
    'flower': BgKind.petals, 'flowers': BgKind.petals, 'floral': BgKind.petals, 'phool': BgKind.petals,
    'leaf': BgKind.leaves, 'leaves': BgKind.leaves, 'nature': BgKind.leaves, 'plant': BgKind.leaves,
    'garden': BgKind.leaves, 'tropical': BgKind.leaves, 'mandala': BgKind.mandala, 'rangoli': BgKind.mandala,
    'pattern': BgKind.mandala, 'traditional': BgKind.mandala, 'ethnic': BgKind.mandala, 'temple': BgKind.mandala,
    'podium': BgKind.podium, 'stand': BgKind.podium, 'pedestal': BgKind.podium,
    'display': BgKind.podium, 'mirror': BgKind.mirror, 'reflection': BgKind.mirror, 'glass': BgKind.mirror,
    'glossy': BgKind.mirror, 'arso': BgKind.mirror, 'window': BgKind.window, 'sunlight': BgKind.window,
    'daylight': BgKind.window, 'morning': BgKind.window, 'shadow': BgKind.window, 'water': BgKind.ripple,
    'ripple': BgKind.ripple, 'pool': BgKind.ripple, 'pani': BgKind.ripple,
    'wave': BgKind.silkWave, 'waves': BgKind.silkWave, 'wavy': BgKind.silkWave, 'dune': BgKind.silkWave,
    'dunes': BgKind.silkWave, 'sand': BgKind.silkWave, 'flowing': BgKind.silkWave, 'drape': BgKind.silkWave,
    'draped': BgKind.silkWave, 'folds': BgKind.silkWave,
    'candle': BgKind.glowTable, 'candlelight': BgKind.glowTable, 'amber': BgKind.glowTable,
    'tabletop': BgKind.glowTable, 'glowing': BgKind.glowTable, 'lamp': BgKind.glowTable,
    'spotlight': BgKind.spotlight, 'dramatic': BgKind.spotlight, 'studio': BgKind.studio, 'plain': BgKind.studio,
    'clean': BgKind.studio, 'minimal': BgKind.studio, 'frame': BgKind.frame, 'border': BgKind.frame,
    'gradient': BgKind.mesh, 'aurora': BgKind.mesh, 'abstract': BgKind.mesh, 'modern': BgKind.mesh,
    'pastel': BgKind.mesh, 'dreamy': BgKind.mesh,
  };

  static const Set<String> _darkWords = {
    'dark', 'night', 'luxury', 'luxurious', 'royal', 'premium', 'elegant', 'moody', 'deep', 'rich', 'black', 'kalo',
    'midnight', 'velvet',
  };
  static const Set<String> _lightWords = {
    'light', 'bright', 'pastel', 'soft', 'white', 'clean', 'minimal', 'airy', 'day', 'daylight', 'fresh', 'safed',
  };
  static const Set<String> _festiveWords = {
    'diwali', 'festive', 'festival', 'diya', 'wedding', 'shaadi', 'celebration', 'navratri', 'christmas', 'party',
    'tyohar', 'lagna',
  };

  // ---------------------------------------------------------------------
  //  🎨 INSTANT PRO — gradient + colour combination + material, exactly as
  //  typed. e.g. "maroon to gold gradient velvet", "black navy diagonal
  //  marble", "pink peach ombre silk", "emerald gold radial glitter".
  //  Paints a real image on the phone (offline, free, < 1 s).
  // ---------------------------------------------------------------------
  static const Set<String> _gradWords = {
    'gradient', 'gradiant', 'gradent', 'ombre', 'fade', 'fading', 'blend', 'blended', 'shade', 'shaded',
    'mix', 'mixed', 'combination', 'combo', 'duotone', 'tone', 'transition', 'to',
  };
  static const Map<String, String> _dirWords = {
    'vertical': 'v', 'top': 'v', 'bottom': 'v', 'upar': 'v', 'niche': 'v', 'up': 'v', 'down': 'v',
    'horizontal': 'h', 'left': 'h', 'right': 'h', 'side': 'h', 'sideways': 'h',
    'diagonal': 'd', 'corner': 'd', 'tirchu': 'd', 'angle': 'd', 'cross': 'd',
    'radial': 'r', 'center': 'r', 'centre': 'r', 'circle': 'r', 'circular': 'r', 'round': 'r',
    'glow': 'r', 'vachche': 'r', 'middle': 'r',
  };
  /// material word → texture painter (centre-safe ones only)
  static const Map<String, BgKind> _matWords = {
    'marble': BgKind.marble, 'granite': BgKind.marble, 'stone': BgKind.marble, 'travertine': BgKind.marble,
    'silk': BgKind.silk, 'satin': BgKind.satin, 'velvet': BgKind.satin, 'fabric': BgKind.satin,
    'cloth': BgKind.satin, 'kapdu': BgKind.satin, 'wood': BgKind.wood, 'wooden': BgKind.wood,
    'lakdu': BgKind.wood, 'glitter': BgKind.glitter, 'shimmer': BgKind.glitter, 'sparkle': BgKind.glitter,
    'shine': BgKind.glitter, 'bokeh': BgKind.bokeh, 'lights': BgKind.bokeh, 'water': BgKind.ripple,
    'ripple': BgKind.ripple, 'pani': BgKind.ripple,
    'wave': BgKind.silkWave, 'waves': BgKind.silkWave, 'wavy': BgKind.silkWave, 'dune': BgKind.silkWave,
    'dunes': BgKind.silkWave, 'sand': BgKind.silkWave, 'draped': BgKind.silkWave, 'folds': BgKind.silkWave,
  };

  /// true → prompt asks for a gradient / colour combo (Instant Pro handles it)
  static bool wantsPro(String prompt) {
    final t = _norm(prompt);
    final colours = _coloursIn(t);
    final grad = _gradWords.any((w) => w != 'to' && t.contains(' $w '));
    return grad || colours.length >= 2;
  }

  static String _norm(String p) =>
      ' ${p.toLowerCase().replaceAll(RegExp(r'[^a-z\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ')} ';

  static List<String> _coloursIn(String t) {
    // longest words first ("navy blue", "off white") so "blue" isn't counted twice
    final words = _colorWords.keys.where((w) => w != 'dark').toList()
      ..sort((a, b) => b.length - a.length);
    var rest = t;
    final hits = <MapEntry<int, String>>[];
    for (final w in words) {
      while (true) {
        final i = rest.indexOf(' $w ');
        if (i < 0) break;
        hits.add(MapEntry(i, _colorWords[w]!));
        rest = rest.replaceRange(i + 1, i + 1 + w.length, ' ' * w.length);
      }
    }
    hits.sort((a, b) => a.key.compareTo(b.key));
    final out = <String>[];
    for (final h in hits) {
      if (!out.contains(h.value)) out.add(h.value);
    }
    if (out.isEmpty && t.contains(' dark ')) out.add('black');
    return out.take(4).toList();
  }

  /// Instant results: Pro painter for gradients / combos, classic otherwise
  static Future<List<BgTemplate>> generateInstant(String prompt) async {
    if (!wantsPro(prompt)) return generateOffline(prompt);
    try {
      return await _generatePro(prompt);
    } catch (e) {
      debugPrint('🎨 instant pro fail: $e');
      return generateOffline(prompt);
    }
  }

  static Future<List<BgTemplate>> _generatePro(String prompt) async {
    final t = _norm(prompt);
    bool has(String w) => t.contains(' $w ');

    // ---- colours exactly in the typed order ----
    var keys = _coloursIn(t);
    final dark = _darkWords.any(has) && !_lightWords.any(has) ||
        (keys.isNotEmpty && const {'maroon', 'wine', 'navy', 'black', 'emerald', 'brown'}.contains(keys.first) &&
            !_lightWords.any(has));
    if (keys.isEmpty) keys = [dark ? 'black' : 'ivory'];

    List<Color> stops;
    if (keys.length == 1) {
      // one colour + "gradient" → its own light → deep ramp
      final p = _palette[keys.first]!.map((e) => Color(e)).toList();
      stops = dark ? [p[1], p[2]] : [p[0], p[1]];
    } else {
      stops = keys.map((k) {
        final p = _palette[k]!.map((e) => Color(e)).toList();
        // dark mood → richer tone, light mood → softer tone
        return dark ? Color.lerp(p[1], p[2], 0.35)! : Color.lerp(p[1], p[0], 0.25)!;
      }).toList();
    }

    // ---- direction ----
    String dir = 'd';
    for (final e in _dirWords.entries) {
      if (has(e.key)) {
        dir = e.value;
        break;
      }
    }

    // ---- material (first one typed) ----
    BgKind? mat;
    int at = 1 << 30;
    _matWords.forEach((w, k) {
      final i = t.indexOf(' $w ');
      if (i >= 0 && i < at) {
        at = i;
        mat = k;
      }
    });
    final velvet = has('velvet');
    final spotlight = has('spotlight') || has('dramatic');

    final dir0 = Directory('${(await getApplicationDocumentsDirectory()).path}/ai_bg');
    if (!dir0.existsSync()) dir0.createSync(recursive: true);
    await _cleanOldInstant(dir0);

    // 4 results — same colours, same direction, same material;
    // only depth / texture strength changes a little
    const tone = [0.0, -0.06, 0.06, -0.03];
    const tex = [0.70, 0.80, 0.55, 0.95];
    const names = ['', ' · Deep', ' · Soft', ' · Rich'];
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final label = _short(prompt);
    final out = <BgTemplate>[];
    for (var i = 0; i < 4; i++) {
      final cs = stops.map((c) {
        final h = HSLColor.fromColor(c);
        return h.withLightness((h.lightness + tone[i]).clamp(0.03, 0.97)).toColor();
      }).toList();
      final bytes = await _paintPro(
        colors: cs,
        dir: dir,
        material: mat,
        texture: velvet ? tex[i] * 0.6 : tex[i],
        dark: dark,
        spotlight: spotlight,
        seed: i,
      );
      final f = File('${dir0.path}/inst_${stamp}_$i.png');
      await f.writeAsBytes(bytes, flush: true);
      out.add(BgTemplate(
        id: 'inst_${f.path}',
        name: '$label${names[i]}',
        kind: BgKind.image,
        filePath: f.path,
        category: BgCategory.ai,
        dark: dark,
      ));
    }
    _remember(prompt);
    return out;
  }

  /// old unused instant images → removed (the ones the user kept stay)
  static Future<void> _cleanOldInstant(Directory d) async {
    try {
      final keepPaths = (await savedAi()).map((t) => t.filePath).toSet();
      final limit = DateTime.now().subtract(const Duration(days: 3));
      for (final f in d.listSync().whereType<File>()) {
        if (f.path.contains('/inst_') && !keepPaths.contains(f.path) && f.statSync().modified.isBefore(limit)) {
          f.deleteSync();
        }
      }
    } catch (_) {}
  }

  /// neutral grey version of a material → laid over the gradient with
  /// "overlay" blend, so the texture shows but the user's colours stay exact
  static BgTemplate _neutralMaterial(BgKind k) {
    const g = Color(0xff808080);
    List<Color> c;
    switch (k) {
      case BgKind.marble:
        c = const [g, Color(0xff2E2E2E), g, Color(0xffC8C8C8)];
        break;
      case BgKind.satin:
      case BgKind.silkWave:
        c = const [g, Color(0xffE0E0E0), Color(0xff3A3A3A), Color(0xffC8C8C8)];
        break;
      case BgKind.silk:
        c = const [g, Color(0xff9C9C9C), Color(0xff6A6A6A), Color(0xffD0D0D0)];
        break;
      case BgKind.wood:
        c = const [Color(0xff8C8C8C), Color(0xff585858), Color(0xffA4A4A4), Color(0xff6E6E6E)];
        break;
      case BgKind.glitter:
      case BgKind.bokeh:
        c = const [g, g, Color(0xffF4F4F4), Color(0xffD8D8D8)];
        break;
      default:
        c = const [g, Color(0xff9E9E9E), Color(0xff626262), Color(0xffBDBDBD)];
    }
    return BgTemplate(id: 'neutral_${k.name}', name: 'n', kind: k, colors: c, accent: c[3], dark: true);
  }

  static Future<Uint8List> _paintPro({
    required List<Color> colors,
    required String dir,
    required BgKind? material,
    required double texture,
    required bool dark,
    required bool spotlight,
    required int seed,
  }) async {
    const double side = 1080;
    final size = const Size(side, side);
    final rect = Offset.zero & size;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, rect);

    // 1) the gradient — user's colours in order
    final stops = colors.length == 1 ? [colors[0], colors[0]] : colors;
    final Shader shader = dir == 'r'
        ? RadialGradient(center: Alignment.center, radius: 0.85, colors: stops).createShader(rect)
        : LinearGradient(
      begin: dir == 'v' ? Alignment.topCenter : (dir == 'h' ? Alignment.centerLeft : Alignment.topLeft),
      end: dir == 'v' ? Alignment.bottomCenter : (dir == 'h' ? Alignment.centerRight : Alignment.bottomRight),
      colors: stops,
    ).createShader(rect);
    c.drawRect(rect, Paint()..shader = shader);

    // 2) material texture (overlay keeps colours exact)
    if (material != null) {
      c.saveLayer(rect, Paint()
        ..blendMode = BlendMode.overlay
        ..color = Colors.white.withOpacity(texture.clamp(0.0, 1.0)));
      BgTemplatePainter.paint(c, size, _neutralMaterial(material));
      c.restore();
    }

    // 3) premium light: soft glow in the middle (where jewellery sits)
    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.05),
          radius: spotlight ? 0.45 : 0.7,
          colors: [
            Colors.white.withOpacity(spotlight ? 0.22 : (dark ? 0.10 : 0.18)),
            Colors.white.withOpacity(0),
          ],
        ).createShader(rect),
    );

    // 4) soft vignette on the edges
    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            Colors.black.withOpacity(0),
            Colors.black.withOpacity(spotlight ? 0.55 : (dark ? 0.32 : 0.10)),
          ],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );

    // 5) very fine grain → looks like a photo, not flat vector
    final rnd = math.Random(97 + seed);
    final pts = List.generate(9000, (_) => Offset(rnd.nextDouble() * side, rnd.nextDouble() * side));
    c.drawPoints(ui.PointMode.points, pts.sublist(0, 4500),
        Paint()..color = Colors.white.withOpacity(dark ? 0.035 : 0.05)..strokeWidth = 1.2);
    c.drawPoints(ui.PointMode.points, pts.sublist(4500),
        Paint()..color = Colors.black.withOpacity(dark ? 0.05 : 0.035)..strokeWidth = 1.2);

    final image = await rec.endRecording().toImage(side.toInt(), side.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  static List<BgTemplate> generateOffline(String prompt) {
    final t = ' ${prompt.toLowerCase().replaceAll(RegExp(r'[^a-z\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ')} ';
    bool has(String w) => t.contains(' $w ');

    // colours in order of appearance
    final hits = <MapEntry<int, String>>[];
    _colorWords.forEach((w, key) {
      final i = t.indexOf(' $w ');
      if (i >= 0) hits.add(MapEntry(i, key));
    });
    hits.sort((a, b) => a.key.compareTo(b.key));
    final colorKeys = <String>[];
    for (final h in hits) {
      if (!colorKeys.contains(h.value)) colorKeys.add(h.value);
    }

    // styles in order of appearance
    final sHits = <MapEntry<int, BgKind>>[];
    _styleWords.forEach((w, k) {
      final i = t.indexOf(' $w ');
      if (i >= 0) sHits.add(MapEntry(i, k));
    });
    sHits.sort((a, b) => a.key.compareTo(b.key));
    final kinds = <BgKind>[];
    for (final h in sHits) {
      if (!kinds.contains(h.value)) kinds.add(h.value);
    }

    final festive = _festiveWords.any(has);
    final darkMain = colorKeys.isNotEmpty && const {'maroon', 'wine', 'navy', 'black', 'emerald'}.contains(colorKeys.first);
    bool dark = _darkWords.any(has) || darkMain;
    if (_lightWords.any(has) && !_darkWords.any(has)) dark = false;

    if (colorKeys.isEmpty) colorKeys.add(festive ? 'maroon' : (dark ? 'black' : 'ivory'));
    final main = _palette[colorKeys.first]!.map((e) => Color(e)).toList();
    final second = colorKeys.length > 1
        ? _palette[colorKeys[1]]!.map((e) => Color(e)).toList()
        : (festive || dark ? _palette['gold']!.map((e) => Color(e)).toList() : main);

    // ✅ PROMPT-WISE ONLY:
    //  • only the styles written in the prompt (no extra random styles)
    //  • same colours + same mood in every result (no dark↔light flip)
    //  • centre always empty → podium / mirror / frame / mandala / petals
    //    are turned into a clean style with the same feel
    const safe = {
      BgKind.podium: BgKind.spotlight,
      BgKind.mirror: BgKind.studio,
      BgKind.window: BgKind.studio,
      BgKind.frame: BgKind.radial,
      BgKind.mandala: BgKind.radial,
      BgKind.petals: BgKind.satin,
      BgKind.leaves: BgKind.mesh,
    };
    final pick = <BgKind>[];
    for (final k in kinds) {
      final sk = safe[k] ?? k;
      if (!pick.contains(sk)) pick.add(sk);
    }
    if (pick.isEmpty) pick.add(dark ? BgKind.spotlight : BgKind.studio);

    // 4 results = same prompt, only light / depth changes a little
    const shades = [0.0, -0.07, 0.07, -0.14];
    const shadeNames = ['', ' · Deep', ' · Soft', ' · Rich'];
    List<Color> tone(List<Color> c, double d) => c.map((x) {
      if (d == 0 || x == Colors.white) return x;
      final h = HSLColor.fromColor(x);
      return h.withLightness((h.lightness + d).clamp(0.03, 0.97)).toColor();
    }).toList();

    final id = DateTime.now().millisecondsSinceEpoch;
    final name = _short(prompt);
    final out = <BgTemplate>[];
    for (var i = 0; i < 4; i++) {
      final k = pick[i % pick.length];
      final m = tone(main, shades[i]);
      final s2 = tone(second, shades[i] / 2);
      out.add(BgTemplate(
        id: 'prompt_${id}_$i',
        name: '$name${pick.length == 1 ? shadeNames[i] : ''}',
        kind: k,
        colors: _colorsFor(k, m, s2, dark),
        accent: s2[3] == Colors.white ? m[3] : s2[3],
        category: BgCategory.ai,
        dark: dark,
      ));
    }
    _remember(prompt);
    return out;
  }

  /// Each painter style reads its colours differently — give each the right order
  static List<Color> _colorsFor(BgKind k, List<Color> p, List<Color> s, bool dark) {
    final light = p[0], mid = p[1], deep = p[2], acc = s[3] == Colors.white ? s[1] : s[3];
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
    switch (k) {
      case BgKind.bokeh:
        return dark ? [mix(mid, deep, 0.55), deep, acc, s[1]] : [light, mix(light, mid, 0.5), Colors.white, acc];
      case BgKind.podium:
      case BgKind.mirror:
        return dark
            ? [mix(deep, mid, 0.25), deep, mix(deep, Colors.black, 0.2), acc]
            : [light, mix(light, mid, 0.45), mix(light, Colors.white, 0.4), acc];
      case BgKind.satin:
        return dark ? [mid, mix(mid, Colors.white, 0.35), deep, acc] : [mix(light, mid, 0.5), Colors.white, mid, acc];
      case BgKind.marble:
        return dark ? [deep, mix(light, Colors.white, 0.5), mid, acc] : [light, mix(mid, Colors.black, 0.25), mid, acc];
      case BgKind.mesh:
        return dark ? [deep, mid, s[2], acc] : [light, mid, s[0] == light ? mix(mid, Colors.white, 0.4) : s[0], acc];
      case BgKind.petals:
        return dark ? [deep, mix(deep, mid, 0.4), mid, acc] : [light, mix(light, Colors.white, 0.5), mid, s[1]];
      case BgKind.glitter:
        return dark ? [mix(deep, mid, 0.3), deep, acc, s[1]] : [light, mix(light, mid, 0.4), acc, s[1]];
      case BgKind.mandala:
        return dark ? [mid, deep, acc, s[1]] : [light, mix(light, mid, 0.4), acc, s[1]];
      case BgKind.spotlight:
        return dark ? [mix(mid, Colors.white, 0.15), deep, acc, s[1]] : [Colors.white, mid, acc, s[1]];
      case BgKind.wood:
        return dark ? [mid, deep, acc, s[1]] : [mix(light, mid, 0.55), mid, acc, s[1]];
      case BgKind.silkWave:
        return dark
            ? [mid, mix(mid, Colors.white, 0.45), mix(deep, Colors.black, 0.3)]
            : [mix(light, mid, 0.55), mix(light, Colors.white, 0.6), mix(mid, Colors.black, 0.25)];
      case BgKind.marbleLux:
        return dark
            ? [mix(deep, Colors.black, 0.45), mix(mid, Colors.white, 0.3)]
            : [mix(light, Colors.white, 0.5), mix(mid, Colors.grey, 0.5)];
      case BgKind.stageBeam:
        return [mix(deep, Colors.black, 0.75), mix(mid, Colors.white, 0.35)];
      case BgKind.liquidMetal:
        return [mid, mix(light, Colors.white, 0.6), mix(deep, Colors.black, 0.3)];
      case BgKind.sparkle:
        return [mix(deep, Colors.black, 0.55), mix(mid, Colors.white, 0.45)];
      case BgKind.velvet:
        return [dark ? mix(mid, deep, 0.35) : mix(light, mid, 0.6)];
      case BgKind.arch:
        return dark
            ? [mix(deep, Colors.black, 0.4), mix(deep, Colors.black, 0.55)]
            : [mix(light, Colors.white, 0.3), mix(light, mid, 0.18)];
      case BgKind.goldFoil:
        return [dark ? mix(deep, Colors.black, 0.35) : mix(light, Colors.white, 0.4)];
      case BgKind.jewelBox:
        return [dark ? mix(mid, deep, 0.3) : mix(light, mid, 0.3), dark ? const Color(0xff141416) : mix(deep, Colors.black, 0.3)];
      case BgKind.glowTable:
      // light = the prompt's colour (gold if the colour itself is very dark)
        final glowC = mid.computeLuminance() < 0.12 ? acc : mid;
        return [
          mix(const Color(0xff16130F), deep, 0.25),
          mix(const Color(0xff2C2D33), deep, 0.15),
          glowC,
        ];
      default:
        return dark ? [mid, deep, mix(deep, Colors.black, 0.3), acc] : [light, mid, mix(light, Colors.white, 0.5), acc];
    }
  }
}

// =======================================================================
//  SHEET
// =======================================================================
class _PromptSheet extends StatefulWidget {
  const _PromptSheet();

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  final TextEditingController _ctrl = TextEditingController();
  bool _online = true;
  bool _busy = false;
  bool _aiWorking = false;
  int _aiSeconds = 0;
  Timer? _aiTimer;
  CancelToken? _aiCancel;
  String? _note;
  List<BgTemplate> _results = [];
  List<BgTemplate> _saved = [];
  List<String> _recent = [];

  /// Only message the user ever sees when AI fails (no "limit" / "key" / "API")
  static const String _busyMsg =
      'AI server is busy right now. Please try again after some time. You can use the backgrounds below meanwhile.';
  static const Duration _minWait = Duration(seconds: 4);

  static const List<String> _ideas = [
    'Royal maroon velvet with soft gold bokeh',
    'White marble with soft daylight',
    'Diwali diyas warm glow',
    'Rose petals on pink silk',
    'Black podium with spotlight',
    'Emerald green luxury satin',
    'Ivory podium, minimal studio',
    'Navy blue with golden sparkle',
  ];

  @override
  void initState() {
    super.initState();
    PromptBackground.savedAi().then((v) => mounted ? setState(() => _saved = v) : null);
    PromptBackground.recentPrompts().then((v) => mounted ? setState(() => _recent = v) : null);
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _aiCancel?.cancel('closed');
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final p = _ctrl.text.trim();
    if (p.isEmpty) {
      setState(() => _note = 'Type what background you want, e.g. "maroon velvet with gold bokeh".');
      return;
    }
    FocusScope.of(context).unfocus();
    _stopAi(silent: true);

    // ⚡ Instant styles (gradient / colour combo / material exactly as typed)
    final instant = await PromptBackground.generateInstant(p);
    if (!mounted) return;
    setState(() {
      _note = null;
      _results = instant;
      _busy = _online;
    });
    if (!_online) return;

    // 🌐 AI photo in the background — added on top when ready
    final cancel = CancelToken();
    _aiCancel = cancel;
    setState(() {
      _aiWorking = true;
      _aiSeconds = 0;
    });
    _aiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _aiSeconds++);
    });
    final sw = Stopwatch()..start();
    try {
      final r = await PromptBackground.generateOnline(p, count: 2, cancel: cancel);
      if (!mounted || cancel != _aiCancel) return;
      setState(() {
        _results = [...r, ...instant]; // AI photos first, same-prompt instant after
        _saved = [...r, ..._saved];
        _note = null;
      });
    } catch (e) {
      // real reason only in log (limit / key / timeout) — user sees a simple "busy"
      debugPrint('✨ AI BG fail: $e');
      // show the spinner a few seconds so the tap always feels answered
      final left = _minWait - sw.elapsed;
      if (left > Duration.zero) await Future.delayed(left);
      if (!mounted || cancel != _aiCancel) return;
      setState(() => _note = _busyMsg);
    } finally {
      if (mounted && cancel == _aiCancel) _endAi();
    }
  }

  void _endAi() {
    _aiTimer?.cancel();
    _aiTimer = null;
    _aiCancel = null;
    if (mounted) {
      setState(() {
        _aiWorking = false;
        _busy = false;
      });
    }
  }

  void _stopAi({bool silent = false}) {
    if (_aiCancel == null) return;
    _aiCancel!.cancel('user');
    _endAi();
    // no message — instant backgrounds are already on screen
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                      width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primaryDark.withOpacity(0.7)]),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Background from prompt',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xff1B2433))),
                      Text('Describe it — colours, material, mood, festival',
                          style: TextStyle(fontSize: 11.5, color: Color(0xff6B7487))),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),

                // ---- prompt ----
                TextField(
                  controller: _ctrl,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _generate(),
                  style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. Royal maroon velvet with soft gold bokeh',
                    hintStyle: const TextStyle(color: Color(0xff9AA1AE), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xffF5F7FB),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    suffixIcon: _ctrl.text.isEmpty
                        ? null
                        : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _ctrl.clear()),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),

                // ---- ideas / recent ----
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ..._recent.take(3).map((p) => _chip(p, icon: Icons.history_rounded)),
                    ..._ideas.where((i) => !_recent.contains(i)).take(_recent.isEmpty ? 6 : 4).map((p) => _chip(p)),
                  ],
                ),
                const SizedBox(height: 14),

                // ---- mode ----
                Row(children: [
                  Expanded(
                      child: _mode(true, Icons.cloud_rounded, 'AI Generate', 'Real photo · needs internet')),
                  const SizedBox(width: 8),
                  Expanded(child: _mode(false, Icons.bolt_rounded, 'Instant', 'Painted style · offline · free')),
                ]),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _busy ? null : _generate,
                    icon: _busy
                        ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome_rounded, size: 19),
                    label: Text(_busy ? 'Creating… ${_aiSeconds}s' : 'Generate background',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  ),
                ),

                if (_aiWorking) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Creating AI background… you can pick one below now.',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xff1B2433)),
                        ),
                      ),
                      TextButton(onPressed: () => _stopAi(), child: const Text('Stop')),
                    ]),
                  ),
                ],

                if (_note != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xffFFF6E5), borderRadius: BorderRadius.circular(10)),
                    child: Text(_note!, style: const TextStyle(fontSize: 12, color: Color(0xff7A5A12))),
                  ),
                ],

                // ---- results ----
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Tap one to use it for the batch',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xff1B2433))),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: _results.map((t) => _resultTile(t, big: true)).toList(),
                  ),
                ],

                // ---- earlier AI backgrounds ----
                if (_saved.isNotEmpty && _results.isEmpty) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    const Expanded(
                      child: Text('Your AI backgrounds',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xff1B2433))),
                    ),
                    TextButton.icon(
                      onPressed: _clearAll,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 17, color: Color(0xffC62828)),
                      label: const Text('Delete all', style: TextStyle(fontSize: 12, color: Color(0xffC62828))),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _saved.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => SizedBox(
                        width: 80,
                        child: Stack(children: [
                          Positioned.fill(child: _resultTile(_saved[i])),
                          Positioned(
                            top: 3,
                            right: 3,
                            child: GestureDetector(
                              onTap: () => _deleteOne(_saved[i]),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Tip: tap ✕ to delete a background you don\'t need.',
                      style: TextStyle(fontSize: 10.5, color: Color(0xff6B7487))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xffC62828), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteOne(BgTemplate t) async {
    if (!await _confirm('Delete background?', 'This AI background will be removed from your phone.')) return;
    await PromptBackground.deleteSaved(t);
    if (!mounted) return;
    setState(() => _saved = _saved.where((e) => e.filePath != t.filePath).toList());
  }

  Future<void> _clearAll() async {
    if (!await _confirm('Delete all AI backgrounds?', 'All ${_saved.length} saved AI backgrounds will be removed.')) return;
    await PromptBackground.deleteAllSaved();
    if (!mounted) return;
    setState(() => _saved = []);
  }

  Widget _chip(String p, {IconData? icon}) => ActionChip(
    visualDensity: VisualDensity.compact,
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xffE4EAF5)),
    avatar: icon == null ? null : Icon(icon, size: 14, color: const Color(0xff6B7487)),
    label: Text(p, style: const TextStyle(fontSize: 11.5, color: Color(0xff1B2433))),
    onPressed: () {
      setState(() => _ctrl.text = p);
      _generate();
    },
  );

  Widget _mode(bool online, IconData icon, String title, String sub) {
    final sel = _online == online;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _online = online),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sel ? AppColors.primaryDark.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AppColors.primaryDark : const Color(0xffE4EAF5), width: sel ? 1.6 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: sel ? AppColors.primaryDark : const Color(0xff6B7487)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: sel ? AppColors.primaryDark : const Color(0xff1B2433))),
              Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xff6B7487))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _resultTile(BgTemplate t, {bool big = false}) => GestureDetector(
    onTap: () async {
      // photo results are kept (saved) so they come back next time / can be deleted
      final pick = await PromptBackground.keep(t);
      if (mounted) Navigator.pop(context, pick);
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(big ? 14 : 10),
      child: Stack(fit: StackFit.expand, children: [
        BgTemplateView(template: t),
        if (big)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(8)),
              child: Text(
                t.id.startsWith('inst_')
                    ? 'Instant'
                    : (t.isImage ? 'AI photo' : t.kind.name[0].toUpperCase() + t.kind.name.substring(1)),
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ]),
    ),
  );
}

/// Centre clutter score (runs in an isolate).
///  ≈1.0  → centre as calm as the edges (good empty backdrop)
///  >1.45 → something busy / an object sits in the middle
const double _maxClutter = 1.45;

double _clutterScore(Uint8List bytes) {
  final img.Image? src = img.decodeImage(bytes);
  if (src == null) return 99;
  final img.Image g = img.copyResize(src, width: 64, height: 64);
  final lum = List.generate(64, (y) => List.generate(64, (x) {
    final p = g.getPixel(x, y);
    return 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  }));
  double centre = 0, ring = 0;
  int nc = 0, nr = 0;
  for (var y = 1; y < 63; y++) {
    for (var x = 1; x < 63; x++) {
      final e = (lum[y][x + 1] - lum[y][x - 1]).abs() + (lum[y + 1][x] - lum[y - 1][x]).abs();
      final inCentre = x >= 19 && x < 45 && y >= 19 && y < 45;
      if (inCentre) {
        centre += e;
        nc++;
      } else {
        ring += e;
        nr++;
      }
    }
  }
  final c = centre / nc, r = ring / nr;
  final double edgeScore = (c + 2) / (r + 2); // +2 = very smooth images don't divide by ~0

  // 👤 skin-tone pixels much more in the middle than at the edges → a model / hand
  bool skin(img.Pixel p) {
    final num rr = p.r, gg = p.g, bb = p.b;
    final num mx = [rr, gg, bb].reduce((a, b) => a > b ? a : b);
    final num mn = [rr, gg, bb].reduce((a, b) => a < b ? a : b);
    return rr > 95 && gg > 40 && bb > 20 && mx - mn > 15 && (rr - gg).abs() > 15 && rr > gg && rr > bb;
  }

  int sc = 0, sr = 0;
  for (var y = 0; y < 64; y++) {
    for (var x = 0; x < 64; x++) {
      final inCentre = x >= 19 && x < 45 && y >= 19 && y < 45;
      if (skin(g.getPixel(x, y))) inCentre ? sc++ : sr++;
    }
  }
  final double centreSkin = sc / (26 * 26);
  final double ringSkin = sr / (64 * 64 - 26 * 26);
  if (centreSkin > 0.15 && centreSkin > ringSkin * 2.5) return 99; // person in the middle

  return edgeScore;
}