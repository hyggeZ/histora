import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class HistoricalCaseRecord {
  const HistoricalCaseRecord({
    required this.caseId,
    required this.title,
    required this.groupName,
    required this.summary,
    required this.body,
    required this.features,
    required this.evidence,
  });

  final String caseId;
  final String title;
  final String groupName;
  final String summary;
  final String body;
  final Map<String, dynamic> features;
  final List<HistoricalEvidence> evidence;
}

class HistoricalEvidence {
  const HistoricalEvidence({
    required this.passageId,
    required this.work,
    required this.location,
    required this.textOriginal,
    required this.matchedText,
  });

  final String passageId;
  final String work;
  final String location;
  final String textOriginal;
  final String matchedText;
}

class HistoryRepository {
  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;
    final manifestData =
        await rootBundle.loadString('assets/content/manifest.json');
    final manifest = jsonDecode(manifestData) as Map<String, dynamic>;
    final expectedHash = manifest['database_sha256'] as String?;
    if (expectedHash == null || expectedHash.isEmpty) {
      throw StateError('内容清单尚未发布，缺少数据库哈希');
    }
    final support = await getApplicationSupportDirectory();
    final target = File(path.join(support.path, 'history.db'));
    if (!await _matchesHash(target, expectedHash)) {
      final data = await rootBundle.load('assets/content/history.db');
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      if (sha256.convert(bytes).toString() != expectedHash) {
        await temporary.delete();
        throw StateError('内置史料数据库完整性校验失败');
      }
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
    }
    final database = sqlite3.open(target.path, mode: OpenMode.readOnly);
    final integrity =
        database.select('PRAGMA integrity_check').first.values.first;
    if (integrity != 'ok') {
      database.dispose();
      throw StateError('史料数据库损坏：$integrity');
    }
    _database = database;
  }

  Future<bool> _matchesHash(File file, String expected) async {
    if (!await file.exists()) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expected;
  }

  List<HistoricalCaseRecord> searchCases(String question, {int limit = 3}) {
    final database = _database;
    if (database == null) throw StateError('史料库尚未初始化');
    final query = _ftsQuery(question);
    ResultSet rows;
    if (query.isEmpty) {
      rows = database.select(
        "SELECT case_id FROM cases WHERE status='published' ORDER BY title LIMIT ?",
        [limit],
      );
    } else {
      rows = database.select(
        '''
        SELECT c.case_id
        FROM case_fts f JOIN cases c ON c.case_id=f.case_id
        WHERE case_fts MATCH ? AND c.status='published'
        ORDER BY bm25(case_fts), c.title
        LIMIT ?
        ''',
        [query, limit],
      );
    }
    if (rows.isEmpty) {
      rows = database.select(
        "SELECT case_id FROM cases WHERE status='published' ORDER BY verified_passage_count DESC, title LIMIT ?",
        [limit],
      );
    }
    return rows
        .map((row) => _loadCase(database, row['case_id'] as String))
        .toList(growable: false);
  }

  HistoricalCaseRecord _loadCase(Database database, String caseId) {
    final row =
        database.select('SELECT * FROM cases WHERE case_id=?', [caseId]).first;
    final evidenceRows = database.select(
      '''
      SELECT p.passage_id,p.work,p.location,p.text_original,cp.matched_text
      FROM case_passages cp JOIN passages p USING(passage_id)
      WHERE cp.case_id=? ORDER BY p.passage_id LIMIT 4
      ''',
      [caseId],
    );
    return HistoricalCaseRecord(
      caseId: caseId,
      title: row['title'] as String,
      groupName: row['group_name'] as String,
      summary: row['summary'] as String,
      body: row['body'] as String,
      features:
          jsonDecode(row['features_json'] as String) as Map<String, dynamic>,
      evidence: evidenceRows
          .map(
            (item) => HistoricalEvidence(
              passageId: item['passage_id'] as String,
              work: item['work'] as String,
              location: item['location'] as String,
              textOriginal: item['text_original'] as String,
              matchedText: item['matched_text'] as String,
            ),
          )
          .toList(growable: false),
    );
  }

  String _ftsQuery(String input) {
    final compact = input
        .replaceAll(RegExp(r'[^\u3400-\u9fffA-Za-z0-9]+'), '')
        .toLowerCase();
    if (compact.length < 2) return '';
    final tokens = <String>{};
    for (var index = 0; index < compact.length - 1; index++) {
      tokens.add(compact.substring(index, index + 2));
      if (tokens.length >= 24) break;
    }
    return tokens.map((token) => '"$token"').join(' OR ');
  }

  void dispose() {
    _database?.dispose();
    _database = null;
  }
}
