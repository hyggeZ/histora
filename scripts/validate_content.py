#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "app" / "assets" / "content" / "history.db"
MANIFEST_PATH = ROOT / "app" / "assets" / "content" / "manifest.json"
ALIASES_PATH = ROOT / "tests" / "retrieval-aliases.json"
NON_HAN = re.compile(r"[^\u3400-\u9fffA-Za-z0-9]+")


def fts_query(text: str) -> str:
    compact = NON_HAN.sub("", text).lower()
    tokens = []
    for index in range(max(0, len(compact) - 1)):
        token = compact[index : index + 2]
        if token not in tokens:
            tokens.append(token)
        if len(tokens) >= 24:
            break
    return " OR ".join(f'"{token}"' for token in tokens)


def retrieve(connection: sqlite3.Connection, query: str, limit: int = 5) -> list[str]:
    expression = fts_query(query)
    if not expression:
        return []
    return [
        row[0]
        for row in connection.execute(
            """
            SELECT c.case_id FROM case_fts f JOIN cases c ON c.case_id=f.case_id
            WHERE case_fts MATCH ? AND c.status='published'
            ORDER BY bm25(case_fts),c.title LIMIT ?
            """,
            (expression, limit),
        )
    ]


def main() -> int:
    errors: list[str] = []
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    actual_hash = hashlib.sha256(DB_PATH.read_bytes()).hexdigest()
    if actual_hash != manifest.get("database_sha256"):
        errors.append("数据库 SHA-256 与 manifest 不一致")
    connection = sqlite3.connect(DB_PATH)
    integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    if integrity != "ok":
        errors.append(f"SQLite integrity_check: {integrity}")
    counts = dict(connection.execute("SELECT status,count(1) FROM cases GROUP BY status"))
    if counts.get("published", 0) < 36:
        errors.append(f"published 案例不足 36：{counts.get('published', 0)}")
    bad_evidence = connection.execute(
        """
        SELECT c.case_id,count(cp.passage_id)
        FROM cases c LEFT JOIN case_passages cp USING(case_id)
        WHERE c.status='published'
        GROUP BY c.case_id HAVING count(cp.passage_id)<2
        """
    ).fetchall()
    if bad_evidence:
        errors.append(f"发布案例存在少于两段证据：{bad_evidence}")
    dangling = connection.execute(
        "SELECT count(1) FROM case_passages cp LEFT JOIN passages p USING(passage_id) WHERE p.passage_id IS NULL"
    ).fetchone()[0]
    if dangling:
        errors.append(f"悬空 passage 引用：{dangling}")
    mismatches = connection.execute(
        """
        SELECT cp.case_id,cp.passage_id,cp.matched_text
        FROM case_passages cp JOIN passages p USING(passage_id)
        WHERE instr(p.text_original,cp.matched_text)=0
        """
    ).fetchall()
    if mismatches:
        errors.append(f"证据匹配文本不在原文中：{mismatches[:5]}")

    title_passes = 0
    title_rows = connection.execute("SELECT case_id,title FROM cases WHERE status='published'").fetchall()
    for case_id, title in title_rows:
        if case_id in retrieve(connection, title):
            title_passes += 1
        else:
            errors.append(f"标题检索未召回自身案例：{title}")

    alias_cases = json.loads(ALIASES_PATH.read_text(encoding="utf-8"))
    alias_passes = 0
    alias_failures = []
    for item in alias_cases:
        results = retrieve(connection, item["query"])
        if set(results).intersection(item["expected_any"]):
            alias_passes += 1
        else:
            alias_failures.append({"query": item["query"], "results": results})
    if alias_failures:
        errors.append(f"语义别名检索失败：{alias_failures}")
    connection.close()
    report = {
        "database_sha256": actual_hash,
        "integrity_check": integrity,
        "published_cases": counts.get("published", 0),
        "title_retrieval": f"{title_passes}/{len(title_rows)}",
        "alias_retrieval": f"{alias_passes}/{len(alias_cases)}",
        "retrieval_checks": len(title_rows) + len(alias_cases),
        "errors": errors,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
