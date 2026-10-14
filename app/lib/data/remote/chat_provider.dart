import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'sse_decoder.dart';

sealed class ChatEvent {
  const ChatEvent();
}

class TextDelta extends ChatEvent {
  const TextDelta(this.text);
  final String text;
}

class UsageEvent extends ChatEvent {
  const UsageEvent(this.promptTokens, this.completionTokens);
  final int? promptTokens;
  final int? completionTokens;
}

class ChatDone extends ChatEvent {
  const ChatDone();
}

class ChatProviderException implements Exception {
  const ChatProviderException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class OpenAiCompatibleChatProvider {
  OpenAiCompatibleChatProvider({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Stream<ChatEvent> stream({
    required Uri baseUri,
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    Duration timeout = const Duration(seconds: 45),
  }) async* {
    if (baseUri.scheme != 'https' && !_isLoopback(baseUri.host)) {
      throw const ChatProviderException('仅允许 HTTPS；本机回环地址可用于调试');
    }
    if (apiKey.trim().isEmpty) {
      throw const ChatProviderException('API Key 不能为空');
    }
    var endpointPath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    if (!endpointPath.endsWith('/chat/completions')) {
      if (endpointPath.isEmpty) endpointPath = '/v1';
      endpointPath += '/chat/completions';
    }
    final endpoint = baseUri.replace(path: endpointPath);
    final request = http.Request('POST', endpoint)
      ..headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        'stream_options': {'include_usage': true},
        'messages': messages,
      });

    final response = await _client.send(request).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw ChatProviderException(
        _safeError(response.statusCode, body),
        statusCode: response.statusCode,
      );
    }

    await for (final event in decodeSse(response.stream)) {
      if (event.data.trim() == '[DONE]') {
        yield const ChatDone();
        return;
      }
      final dynamic decoded;
      try {
        decoded = jsonDecode(event.data);
      } on FormatException {
        throw const ChatProviderException('服务返回了无法解析的流式数据');
      }
      if (decoded is! Map<String, dynamic>) continue;
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final delta = first['delta'];
          if (delta is Map<String, dynamic>) {
            final content = delta['content'];
            if (content is String && content.isNotEmpty) {
              yield TextDelta(content);
            }
          }
        }
      }
      final usage = decoded['usage'];
      if (usage is Map<String, dynamic>) {
        yield UsageEvent(
          usage['prompt_tokens'] as int?,
          usage['completion_tokens'] as int?,
        );
      }
    }
    yield const ChatDone();
  }

  String _safeError(int statusCode, String body) {
    if (statusCode == 401 || statusCode == 403) return '认证失败，请检查 API Key';
    if (statusCode == 404) {
      return '接口不存在（HTTP 404），请检查 API Base URL 和模型名称';
    }
    if (statusCode == 429) return '请求过于频繁或额度不足，请稍后重试';
    if (statusCode >= 500) return '模型服务暂时不可用';
    // Do not expose arbitrary upstream bodies: some vendors echo secrets.
    return '模型服务返回错误（HTTP $statusCode）';
  }

  bool _isLoopback(String host) {
    final parsed = InternetAddress.tryParse(host);
    return host == 'localhost' || parsed?.isLoopback == true;
  }
}
