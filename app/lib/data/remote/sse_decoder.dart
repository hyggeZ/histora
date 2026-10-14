import 'dart:convert';

class SseEvent {
  const SseEvent({required this.data, this.event, this.id});

  final String data;
  final String? event;
  final String? id;
}

/// Parses Server-Sent Events without assuming network chunks align to lines.
Stream<SseEvent> decodeSse(Stream<List<int>> input) async* {
  var buffer = '';
  await for (final chunk in input.cast<List<int>>().transform(utf8.decoder)) {
    buffer += chunk.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    while (true) {
      final boundary = buffer.indexOf('\n\n');
      if (boundary < 0) break;
      final block = buffer.substring(0, boundary);
      buffer = buffer.substring(boundary + 2);
      final event = _parseBlock(block);
      if (event != null) yield event;
    }
  }
  if (buffer.trim().isNotEmpty) {
    final event = _parseBlock(buffer);
    if (event != null) yield event;
  }
}

SseEvent? _parseBlock(String block) {
  final data = <String>[];
  String? event;
  String? id;
  for (final line in block.split('\n')) {
    if (line.isEmpty || line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'data':
        data.add(value);
      case 'event':
        event = value;
      case 'id':
        id = value;
    }
  }
  if (data.isEmpty) return null;
  return SseEvent(data: data.join('\n'), event: event, id: id);
}
