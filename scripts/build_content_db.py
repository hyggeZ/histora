#!/usr/bin/env python3
"""Build the read-only mobile history database from pinned source files.

The converter is deliberately deterministic. It never asks a language model to
invent passages or citations. Case evidence is accepted only when the exact
text (or the named actor for contextual evidence) exists in a source passage.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = ROOT / "content" / "upstream" / "chinese-history"
DEFAULT_OUTPUT = ROOT / "app" / "assets" / "content" / "history.db"
CASE_HEADER = re.compile(r"^\*\*(.+?)【(.+?)】\*\*\s*——\s*(.+)$")
QUOTE = re.compile(r'["“]([^"”]{4,120})["”]')
SHIJI_HEADING = re.compile(r"^●卷(.+)$")
TONGJIAN_JI = re.compile(r"^[周秦汉魏晋宋齐梁陈隋唐后梁后唐后晋后汉后周]+纪")
YEAR_LINE = re.compile(r"^.+年.*公元")
NON_HAN = re.compile(r"[^\u3400-\u9fffA-Za-z0-9]+")


@dataclass(frozen=True)
class Passage:
    passage_id: str
    work: str
    location: str
    text: str
    content_hash: str


@dataclass(frozen=True)
class CaseSeed:
    case_id: str
    title: str
    group_name: str
    source_hint: str
    summary: str
    body: str


GROUP_FEATURES = {
    "开创者与君主": (["领导者-组织"], ["组织治理", "用人与信任"], "advantaged"),
    "功臣与二号人物": (["上级-下属"], ["功劳与控制", "信任下降"], "disadvantaged"),
    "宰辅": (["领导者-顾问", "上级-下属"], ["进言风险", "授权与制衡"], "balanced"),
    "谋士与说客": (["顾问-决策者"], ["说服与采纳", "信息不对称"], "disadvantaged"),
    "权臣与佞幸": (["领导者-代理人"], ["权力失衡", "信息控制"], "advantaged"),
    "变革者": (["改革者-组织"], ["改革收益与个人风险"], "balanced"),
    "将相": (["领导者-执行者", "同僚"], ["专业能力与组织约束"], "balanced"),
    "忍者与复仇者": (["个人-对手"], ["延迟行动与执念"], "disadvantaged"),
    "商人与投机者": (["交易双方"], ["利益与信用"], "balanced"),
}

PERSON_ALIASES = {
    "刘邦": ["高祖", "沛公"],
    "勾践": ["句践", "越王"],
    "唐玄宗": ["玄宗"],
    "张孟谈": ["孟谈", "赵襄子", "晋阳"],
    "范雎": ["范睢", "应侯"],
}

CASE_SEARCH_ALIASES = {
    "李林甫": "报喜不报忧 信息失真 坏消息 上行 沉默组织",
    "唐玄宗": "报喜不报忧 信息失真 坏消息 上行 盛极转衰",
    "智伯": "能力很强 品德有问题 才胜德 骄傲轻敌",
    "吴起": "能力很强 品德有问题 才胜德 限定权限",
    "勾践": "弱势 忍耐 等待机会 蛰伏 积累",
    "伍子胥": "弱势 忍耐 等待机会 执念 复仇",
    "赵括": "只会理论 缺乏实际经验 纸上谈兵 不知合变",
    "刘邦": "领导者 使用比自己强的人 用人 授权 人才",
    "唐太宗": "领导者 使用比自己强的人 纳谏 用人 人才",
}


def normalize(text: str) -> str:
    return NON_HAN.sub("", text).lower()


def search_tokens(text: str) -> str:
    compact = normalize(text)
    bigrams = [compact[i : i + 2] for i in range(max(0, len(compact) - 1))]
    return " ".join([compact, *bigrams])


def parse_passages(path: Path, work: str, prefix: str) -> list[Passage]:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    location = work
    ji = ""
    year = ""
    passages: list[Passage] = []
    for line in lines:
        text = line.strip()
        if not text or set(text) <= {"─", "┌", "┐", "└", "┘", "│", " "}:
            continue
        if work == "史记":
            heading = SHIJI_HEADING.match(text)
            if heading:
                location = f"卷{heading.group(1)}"
                continue
        else:
            if TONGJIAN_JI.match(text) and len(text) <= 12:
                ji = text
            elif YEAR_LINE.match(text):
                year = text
            location = " · ".join(value for value in (ji, year) if value) or work
        if len(text) < 8:
            continue
        ordinal = len(passages) + 1
        passage_id = f"{prefix}-{ordinal:06d}"
        passages.append(
            Passage(
                passage_id=passage_id,
                work=work,
                location=location,
                text=text,
                content_hash=hashlib.sha256(text.encode("utf-8")).hexdigest(),
            )
        )
    return passages


def parse_case_seeds(path: Path) -> list[CaseSeed]:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    group_name = "未分类"
    seeds: list[CaseSeed] = []
    index = 0
    while index < len(lines):
        line = lines[index].strip()
        if line.startswith("## "):
            group_name = line[3:].strip()
            index += 1
            continue
        match = CASE_HEADER.match(line)
        if not match:
            index += 1
            continue
        title, source_hint, summary = match.groups()
        body_lines: list[str] = []
        index += 1
        while index < len(lines):
            candidate = lines[index].strip()
            if candidate.startswith("## ") or CASE_HEADER.match(candidate):
                break
            if candidate:
                body_lines.append(candidate)
            index += 1
        slug = hashlib.sha1(title.encode("utf-8")).hexdigest()[:10].upper()
        seeds.append(
            CaseSeed(
                case_id=f"CASE-{slug}",
                title=title,
                group_name=group_name,
                source_hint=source_hint,
                summary=summary,
                body="\n".join(body_lines),
            )
        )
    return seeds


def find_evidence(seed: CaseSeed, passages: list[Passage]) -> list[tuple[Passage, str]]:
    allowed_works = {"史记", "资治通鉴"}
    if "史" in seed.source_hint and "鉴" not in seed.source_hint:
        allowed_works = {"史记"}
    elif "鉴" in seed.source_hint and "史" not in seed.source_hint:
        allowed_works = {"资治通鉴"}
    candidates = [passage for passage in passages if passage.work in allowed_works]
    evidence: list[tuple[Passage, str]] = []
    seen: set[str] = set()
    for quote in QUOTE.findall(seed.body):
        compact_quote = quote.strip().replace("……", "")
        if len(compact_quote) < 4 or "…" in compact_quote:
            continue
        for passage in candidates:
            if compact_quote in passage.text and passage.passage_id not in seen:
                evidence.append((passage, compact_quote))
                seen.add(passage.passage_id)
                break
        if len(evidence) >= 4:
            break
    actor_names = re.split(r"[、与]", re.sub(r"（.*?）", "", seed.title))
    actor_names.extend(PERSON_ALIASES.get(seed.title, []))
    for actor in actor_names:
        actor = actor.strip()
        if len(actor) < 2:
            continue
        for passage in candidates:
            if actor in passage.text and passage.passage_id not in seen:
                evidence.append((passage, actor))
                seen.add(passage.passage_id)
                if len(evidence) >= 2:
                    break
        if len(evidence) >= 2:
            break
    return evidence


def feature_payload(seed: CaseSeed) -> dict[str, object]:
    relationships, conflicts, balance = GROUP_FEATURES.get(
        seed.group_name, (["个人-组织"], ["风险与取舍"], "unknown")
    )
    text = seed.summary + seed.body
    patterns = []
    for keyword in ("功高", "进谏", "用人", "隐忍", "退出", "信用", "联盟", "言路", "继承", "止损"):
        if keyword in text:
            patterns.append(keyword)
    risks = []
    for keyword in ("猜忌", "清算", "背叛", "失信", "冲突", "内耗", "失败", "被杀"):
        if keyword in text:
            risks.append(keyword)
    return {
        "relationships": relationships,
        "power_balance": balance,
        "core_conflicts": conflicts,
        "decision_stage": "escalating",
        "information_quality": "partial",
        "time_pressure": "medium",
        "reversibility": "low",
        "risk_types": risks or ["决策失误"],
        "patterns": patterns,
    }


def build_database(output: Path) -> dict[str, object]:
    passages = [
        *parse_passages(UPSTREAM / "assets" / "史记.txt", "史记", "SJ"),
        *parse_passages(UPSTREAM / "assets" / "资治通鉴.txt", "资治通鉴", "ZZTJ"),
    ]
    seeds = parse_case_seeds(UPSTREAM / "references" / "renjian.md")
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    connection = sqlite3.connect(output)
    connection.executescript(
        """
        PRAGMA journal_mode=DELETE;
        PRAGMA synchronous=FULL;
        CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE passages(
          passage_id TEXT PRIMARY KEY,
          work TEXT NOT NULL,
          location TEXT NOT NULL,
          text_original TEXT NOT NULL,
          content_hash TEXT NOT NULL
        );
        CREATE INDEX passages_work_location ON passages(work, location);
        CREATE TABLE cases(
          case_id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          group_name TEXT NOT NULL,
          source_hint TEXT NOT NULL,
          summary TEXT NOT NULL,
          body TEXT NOT NULL,
          status TEXT NOT NULL CHECK(status IN ('draft','reviewed','published')),
          features_json TEXT NOT NULL,
          verified_passage_count INTEGER NOT NULL
        );
        CREATE VIRTUAL TABLE case_fts USING fts5(
          case_id UNINDEXED, title, summary, body, search_text, tokenize='unicode61'
        );
        CREATE TABLE case_passages(
          case_id TEXT NOT NULL REFERENCES cases(case_id),
          passage_id TEXT NOT NULL REFERENCES passages(passage_id),
          matched_text TEXT NOT NULL,
          PRIMARY KEY(case_id, passage_id)
        );
        """
    )
    connection.executemany(
        "INSERT INTO passages VALUES(?,?,?,?,?)",
        [
            (p.passage_id, p.work, p.location, p.text, p.content_hash)
            for p in passages
        ],
    )
    published = 0
    for seed in seeds:
        evidence = find_evidence(seed, passages)
        status = "published" if len(evidence) >= 2 else "reviewed" if evidence else "draft"
        if status == "published":
            published += 1
        features = feature_payload(seed)
        connection.execute(
            "INSERT INTO cases VALUES(?,?,?,?,?,?,?,?,?)",
            (
                seed.case_id,
                seed.title,
                seed.group_name,
                seed.source_hint,
                seed.summary,
                seed.body,
                status,
                json.dumps(features, ensure_ascii=False, sort_keys=True),
                len(evidence),
            ),
        )
        searchable = " ".join(
            [
                seed.title,
                seed.group_name,
                seed.summary,
                seed.body,
                CASE_SEARCH_ALIASES.get(seed.title, ""),
                *features["core_conflicts"],
                *features["patterns"],
            ]
        )
        connection.execute(
            "INSERT INTO case_fts VALUES(?,?,?,?,?)",
            (seed.case_id, seed.title, seed.summary, seed.body, search_tokens(searchable)),
        )
        connection.executemany(
            "INSERT INTO case_passages VALUES(?,?,?)",
            [(seed.case_id, passage.passage_id, matched) for passage, matched in evidence],
        )
    metadata = {
        "schema_version": "1",
        "content_version": "0.1.0",
        "passage_count": str(len(passages)),
        "case_count": str(len(seeds)),
        "published_case_count": str(published),
        "source_commit": "c4ac8f15c34f393afd320bb3516b054e23a94b78",
    }
    connection.executemany("INSERT INTO metadata VALUES(?,?)", metadata.items())
    connection.commit()
    integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    dangling = connection.execute(
        "SELECT COUNT(*) FROM case_passages cp LEFT JOIN passages p USING(passage_id) WHERE p.passage_id IS NULL"
    ).fetchone()[0]
    connection.close()
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    return {
        **metadata,
        "integrity_check": integrity,
        "dangling_references": dangling,
        "database_sha256": digest,
        "database_bytes": output.stat().st_size,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    report = build_database(args.output.resolve())
    if args.output.resolve() == DEFAULT_OUTPUT.resolve():
        manifest_path = DEFAULT_OUTPUT.parent / "manifest.json"
        manifest = {
            "schema_version": "1.0.0",
            "content_version": report["content_version"],
            "release_blocked": False,
            "database_file": "history.db",
            "database_sha256": report["database_sha256"],
            "passage_count": int(report["passage_count"]),
            "case_count": int(report["case_count"]),
            "published_case_count": int(report["published_case_count"]),
            "source_commit": report["source_commit"],
        }
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
