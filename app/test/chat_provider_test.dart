import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liangsimajing/data/remote/chat_provider.dart';

void main() {
  final addresses = {
    'https://dashscope.aliyuncs.com/compatible-mode/v1':
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
    'https://dashscope.aliyuncs.com/compatible-mode/v1/':
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
    'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions':
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
    'https://api.openai.com': 'https://api.openai.com/v1/chat/completions',
    'https://api.openai.com/v1': 'https://api.openai.com/v1/chat/completions',
    'https://example.test/workspace/compatible-mode/v1':
        'https://example.test/workspace/compatible-mode/v1/chat/completions',
  };
  for (final entry in addresses.entries) {
    test('requests correct endpoint for ${entry.key}', () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.url.toString(), entry.value);
        expect(request.method, 'POST');
        expect(jsonDecode(request.body)['model'], 'qwen-plus');
        return http.Response(
          'data: {"choices":[{"delta":{"content":"测试成功"}}]}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      });
      final events = await OpenAiCompatibleChatProvider(client: client).stream(
        baseUri: Uri.parse(entry.key),
        apiKey: 'test-only-placeholder',
        model: 'qwen-plus',
        messages: const [
          {'role': 'user', 'content': '测试'}
        ],
      ).toList();
      expect(requests, 1);
      expect(events.whereType<TextDelta>().single.text, '测试成功');
      expect(events.last, isA<ChatDone>());
      client.close();
    });
  }
}
