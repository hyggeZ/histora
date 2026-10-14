import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:liangsimajing/data/remote/sse_decoder.dart';

void main() {
  test('解析跨网络分片和跨 UTF-8 分片的 SSE', () async {
    final bytes = utf8.encode('data: {"text":"汉字"}\r\n\r\ndata: [DONE]\n\n');
    final chunks = <List<int>>[
      bytes.sublist(0, 8),
      bytes.sublist(8, 18),
      bytes.sublist(18, 21),
      bytes.sublist(21),
    ];
    final events = await decodeSse(Stream.fromIterable(chunks)).toList();
    expect(events, hasLength(2));
    expect(events.first.data, '{"text":"汉字"}');
    expect(events.last.data, '[DONE]');
  });

  test('多行 data 按 SSE 规范拼接', () async {
    final input = Stream.value(utf8.encode('data: first\ndata: second\n\n'));
    final events = await decodeSse(input).toList();
    expect(events.single.data, 'first\nsecond');
  });
}
