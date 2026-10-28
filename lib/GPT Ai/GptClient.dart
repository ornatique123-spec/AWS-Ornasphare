import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// =======================================================================
///  🤖 AI CLIENT — FREE providers + OpenAI (TEST ONLY)
///
///   provider   | cost          | key from                         | key looks like
///   -----------|---------------|----------------------------------|---------------
///   gemini ⭐  | FREE tier     | https://aistudio.google.com/apikey | AIza…
///   groq       | FREE tier     | https://console.groq.com/keys      | gsk_…
///   openai     | paid          | https://platform.openai.com        | sk-…
///
///  All three use the same "chat completions + tools" format, so the rest of
///  the screen (tools, answers) works the same.
///
///  • Key is typed in ⚙️ settings and saved on THIS phone only.
///  • Free tiers have per-minute / per-day limits (fine for testing).
///  • ⚠️ A key inside an app can be extracted — move it to the server for real use.
///
///  File: Ask AI GPT/GptClient.dart
/// =======================================================================
class AiProvider {
  final String id, name, baseUrl, chatModel, sttModel, keyHint, keyUrl;
  final bool free;
  const AiProvider(this.id, this.name, this.baseUrl, this.chatModel, this.sttModel, this.keyHint, this.keyUrl,
      {this.free = true});
}

class GptClient {
  GptClient._();

  /// 👉 model names change over time — you can edit them in ⚙️ settings
  static const List<AiProvider> providers = [
    AiProvider('gemini', 'Google Gemini', 'https://generativelanguage.googleapis.com/v1beta/openai/',
        'gemini-3.8-flash', 'gemini-3.8-flash', 'AIza…', 'aistudio.google.com/apikey'),
    AiProvider('groq', 'Groq (Llama)', 'https://api.groq.com/openai/v1/', 'llama-3.3-70b-versatile',
        'whisper-large-v3-turbo', 'gsk_…', 'console.groq.com/keys'),
    AiProvider('openai', 'OpenAI ChatGPT', 'https://api.openai.com/v1/', 'gpt-5.4-mini', 'gpt-4o-mini-transcribe',
        'sk-…', 'platform.openai.com', free: false),
  ];

  static const _kProvider = 'gpt_test_provider';
  static String _kKey(String p) => 'gpt_test_key_$p';
  static String _kModel(String p) => 'gpt_test_model_$p';
  static String _kStt(String p) => 'gpt_test_stt_$p';

  static String providerId = 'gemini';
  static String key = '';
  static String model = providers.first.chatModel;
  static String sttModel = providers.first.sttModel;

  static AiProvider get provider => byId(providerId);
  static AiProvider byId(String id) => providers.firstWhere((p) => p.id == id, orElse: () => providers.first);

  static bool get hasKey => key.trim().length > 20;

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 90),
    sendTimeout: const Duration(seconds: 60),
    validateStatus: (s) => s != null && s < 600,
  ));

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    providerId = p.getString(_kProvider) ?? 'gemini';
    await loadFor(providerId);
  }

  /// read saved key/model of one provider (used when switching in ⚙️)
  static Future<({String key, String model, String stt})> savedFor(String id) async {
    final p = await SharedPreferences.getInstance();
    final pr = byId(id);
    return (
    key: p.getString(_kKey(id)) ?? (id == 'openai' ? (p.getString('gpt_test_key') ?? '') : ''),
    model: _fix(p.getString(_kModel(id))) ?? pr.chatModel,
    stt: _fix(p.getString(_kStt(id))) ?? pr.sttModel,
    );
  }

  /// old model names that Google / OpenAI turned off → use the new default
  static const _retired = {'gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash'};
  static String? _fix(String? m) => (m == null || m.trim().isEmpty || _retired.contains(m.trim())) ? null : m;

  static Future<void> loadFor(String id) async {
    final s = await savedFor(id);
    providerId = id;
    key = s.key;
    model = s.model;
    sttModel = s.stt;
  }

  static Future<void> save({
    required String newProvider,
    required String newKey,
    required String newModel,
    required String newStt,
  }) async {
    final pr = byId(newProvider);
    providerId = pr.id;
    key = newKey.trim();
    model = newModel.trim().isEmpty ? pr.chatModel : newModel.trim();
    sttModel = newStt.trim().isEmpty ? pr.sttModel : newStt.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kProvider, providerId);
    await p.setString(_kKey(providerId), key);
    await p.setString(_kModel(providerId), model);
    await p.setString(_kStt(providerId), sttModel);
  }

  static Options get _auth => Options(headers: {'Authorization': 'Bearer ${key.trim()}'});

  /// Gemini is strict about empty schemas → clean the tool list
  static List<Map<String, dynamic>> _cleanTools(List<Map<String, dynamic>> tools) =>
      tools.map<Map<String, dynamic>>((t) {
        final f = Map<String, dynamic>.from(t['function'] as Map);
        final Map? params = f['parameters'] is Map ? f['parameters'] as Map : null;
        final Map? props = params?['properties'] is Map ? params!['properties'] as Map : null;
        if (props == null || props.isEmpty) {
          f.remove('parameters');
        } else {
          final pm = Map<String, dynamic>.from(params!);
          final req = pm['required'];
          if (req is! List || req.isEmpty) pm.remove('required');
          f['parameters'] = pm;
        }
        return <String, dynamic>{'type': 'function', 'function': f};
      }).toList();

  /// assistant messages must have text content for some providers
  static List<Map<String, dynamic>> _cleanMessages(List<Map<String, dynamic>> msgs) =>
      msgs.map<Map<String, dynamic>>((m) {
        if (m['role'] == 'assistant' && m['content'] == null) return <String, dynamic>{...m, 'content': ''};
        return m;
      }).toList();

  /// Chat Completions with tools → the assistant message (Map)
  static Future<Map<String, dynamic>> chat(List<Map<String, dynamic>> messages, List<Map<String, dynamic>> tools) async {
    final res = await _dio.post(
      '${provider.baseUrl}chat/completions',
      data: {
        'model': model,
        'messages': _cleanMessages(messages),
        if (tools.isNotEmpty) 'tools': _cleanTools(tools),
        if (tools.isNotEmpty) 'tool_choice': 'auto',
        'temperature': 0.2,
      },
      options: _auth,
    );
    final body = _body(res);
    dynamic m;
    if (body is Map && body['choices'] is List && (body['choices'] as List).isNotEmpty) {
      m = (body['choices'] as List).first['message'];
    }
    if (m is! Map) throw GptError('Empty answer from ${provider.name}');
    return Map<String, dynamic>.from(m);
  }

  /// Speech → text, in the language that was spoken.
  static Future<String> transcribe(File audio, {String hints = ''}) async {
    if (providerId == 'gemini') return _geminiTranscribe(audio, hints);
    final name = audio.path.split('/').last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(audio.path, filename: name),
      'model': sttModel,
      'prompt': 'Jewellery shop ERP. Gujarati, Hindi, English or mixed. Words: sale, vechan, approval, '
          'return, stock, barcode, gram, customer, worker.${hints.isEmpty ? '' : ' Names: $hints'}',
    });
    final res = await _dio.post('${provider.baseUrl}audio/transcriptions', data: form, options: _auth);
    final body = _body(res);
    return body is Map ? '${body['text'] ?? ''}'.trim() : '';
  }

  /// Gemini hears audio directly (free) via generateContent
  static Future<String> _geminiTranscribe(File audio, String hints) async {
    final bytes = await audio.readAsBytes();
    final ext = audio.path.split('.').last.toLowerCase();
    final String mime = ext == 'wav'
        ? 'audio/wav'
        : ext == 'mp3'
        ? 'audio/mp3'
        : ext == 'ogg'
        ? 'audio/ogg'
        : 'audio/aac';
    final res = await _dio.post(
      'https://generativelanguage.googleapis.com/v1beta/models/$sttModel:generateContent',
      data: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': 'Write down exactly what is said in this audio from a jewellery shop owner. '
                    'Keep the SAME language and script: Gujarati → Gujarati script, Hindi → Devanagari, '
                    'English → English, Gujlish → Latin letters. Do not translate or answer. '
                    'Barcodes like "B R 8" → BR8. Numbers as digits. '
                    '${hints.isEmpty ? '' : 'Names used in this shop: $hints. '}'
                    'Return only the text. If it is silent or noise, return nothing.'
              },
              {
                'inline_data': {'mime_type': mime, 'data': base64Encode(bytes)}
              },
            ],
          }
        ],
        'generationConfig': {'temperature': 0},
      },
      options: Options(headers: {'x-goog-api-key': key.trim()}),
    );
    final body = _body(res);
    dynamic parts;
    if (body is Map && body['candidates'] is List && (body['candidates'] as List).isNotEmpty) {
      final c = (body['candidates'] as List).first;
      if (c is Map && c['content'] is Map) parts = (c['content'] as Map)['parts'];
    }
    if (parts is! List) return '';
    return parts.map((p) => p is Map ? '${p['text'] ?? ''}' : '').join(' ').trim();
  }

  static dynamic _body(Response res) {
    final dynamic raw = res.data;
    final dynamic body = raw is String ? (raw.isEmpty ? null : jsonDecode(raw)) : raw;
    if ((res.statusCode ?? 500) >= 400) {
      dynamic err = body is List && body.isNotEmpty ? body.first : body;
      err = err is Map ? (err['error'] ?? err) : err;
      final msg = err is Map ? (err['message'] ?? err.toString()) : '$err';
      throw GptError('${res.statusCode}: $msg');
    }
    return body;
  }
}

class GptError implements Exception {
  final String message;
  GptError(this.message);
  @override
  String toString() => message;
}