#!/usr/bin/env python3
"""search.py — wiki üzerinde TF-IDF tabanlı arama motoru.

Kullanım:
    # CLI arama
    ./scripts/search.py "rejim tespiti" --top 5
    ./scripts/search.py "regime detection" --json
    ./scripts/search.py "volatilite" --domain fetm

    # Web UI (Flask, localhost:5555)
    ./scripts/search.py serve

Amaç:
    - wiki/ altındaki markdown dosyalarını TF-IDF ile indeksler.
    - CLI'dan insan-okur (text) veya makine-okur (JSON) çıktı verir.
    - İsteğe bağlı Flask arayüzü ile tarayıcıdan arama + markdown render.
    - Gelecekte: embedding tabanlı semantic search entegrasyonu.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPO_ROOT / ".kb-config.yaml"


# ---------------------------------------------------------------------------
# Config & doc toplama
# ---------------------------------------------------------------------------


def load_config() -> dict[str, Any]:
    """`.kb-config.yaml` dosyasını okur. Eksikse varsayılanları döner."""
    try:
        import yaml
    except ImportError as exc:
        raise SystemExit(
            "pyyaml yüklü değil. Kur: pip install -r requirements.txt"
        ) from exc

    if not CONFIG_PATH.exists():
        return {"paths": {"wiki_path": "./wiki"}}
    with CONFIG_PATH.open("r", encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def wiki_path_from_config(cfg: dict[str, Any]) -> Path:
    raw = cfg.get("paths", {}).get("wiki_path", "./wiki")
    p = Path(raw)
    if not p.is_absolute():
        p = (REPO_ROOT / p).resolve()
    return p


def extract_title(content: str, fallback: str) -> str:
    """Markdown'dan ilk H1 başlığını çeker, yoksa fallback."""
    for line in content.splitlines():
        line = line.strip()
        if line.startswith("# "):
            return line[2:].strip()
    return fallback


def collect_docs(wiki_path: Path, domain: str | None = None) -> list[dict[str, Any]]:
    """wiki_path altındaki tüm .md dosyalarını yükler.

    Dönen her doc: {"path": relative_str, "title": str, "content": str}.
    `domain` verilirse yalnız ilk path segmenti eşleşenler dahil edilir.
    """
    if not wiki_path.exists():
        raise SystemExit(f"wiki yolu bulunamadı: {wiki_path}")

    docs: list[dict[str, Any]] = []
    for md_file in sorted(wiki_path.rglob("*.md")):
        rel = md_file.relative_to(wiki_path)
        if domain and (len(rel.parts) == 0 or rel.parts[0] != domain):
            continue
        try:
            content = md_file.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        docs.append(
            {
                "path": str(rel),
                "title": extract_title(content, md_file.stem),
                "content": content,
            }
        )
    return docs


# ---------------------------------------------------------------------------
# TF-IDF index & arama
# ---------------------------------------------------------------------------


def build_index(docs: list[dict[str, Any]]):
    """Doc listesinden TF-IDF vectorizer ve doc-term matrisi kurar."""
    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
    except ImportError as exc:
        raise SystemExit(
            "scikit-learn yüklü değil. Kur: pip install -r requirements.txt"
        ) from exc

    if not docs:
        return None, None

    corpus = [f"{d['title']}\n{d['content']}" for d in docs]
    vectorizer = TfidfVectorizer(
        stop_words="english",
        ngram_range=(1, 2),
        min_df=1,
        lowercase=True,
    )
    matrix = vectorizer.fit_transform(corpus)
    return vectorizer, matrix


def make_snippet(content: str, query: str, length: int = 200) -> str:
    """Sorgu terimlerinden birini içeren bölgeden ~length karakterlik özet."""
    flat = re.sub(r"\s+", " ", content).strip()
    if not flat:
        return ""

    terms = [t for t in re.findall(r"\w+", query.lower()) if len(t) > 1]
    lower = flat.lower()
    idx = -1
    for t in terms:
        pos = lower.find(t)
        if pos != -1:
            idx = pos
            break

    if idx == -1:
        return flat[:length] + ("…" if len(flat) > length else "")

    start = max(0, idx - length // 4)
    end = min(len(flat), start + length)
    prefix = "…" if start > 0 else ""
    suffix = "…" if end < len(flat) else ""
    return prefix + flat[start:end] + suffix


def search(
    query: str,
    vectorizer,
    matrix,
    docs: list[dict[str, Any]],
    top_k: int = 5,
) -> list[dict[str, Any]]:
    """TF-IDF cosine similarity ile top_k sonuç döner."""
    if vectorizer is None or matrix is None or not docs:
        return []

    from sklearn.metrics.pairwise import cosine_similarity

    q_vec = vectorizer.transform([query])
    sims = cosine_similarity(q_vec, matrix).ravel()

    # skoru > 0 olanları azalan sırayla, en fazla top_k tane
    ranked = sorted(
        ((i, float(s)) for i, s in enumerate(sims) if s > 0),
        key=lambda x: x[1],
        reverse=True,
    )[:top_k]

    results: list[dict[str, Any]] = []
    for i, score in ranked:
        doc = docs[i]
        results.append(
            {
                "path": doc["path"],
                "title": doc["title"],
                "score": round(score, 4),
                "snippet": make_snippet(doc["content"], query),
            }
        )
    return results


# ---------------------------------------------------------------------------
# CLI çıktı formatları
# ---------------------------------------------------------------------------


def format_text(results: list[dict[str, Any]], query: str) -> str:
    if not results:
        return f'Sonuç yok: "{query}"'
    lines = [f'"{query}" için {len(results)} sonuç:', ""]
    for i, r in enumerate(results, 1):
        lines.append(f"{i}. [{r['score']:.4f}] {r['path']}")
        lines.append(f"   {r['title']}")
        lines.append(f"   {r['snippet']}")
        lines.append("")
    return "\n".join(lines).rstrip()


def format_json(results: list[dict[str, Any]]) -> str:
    return json.dumps(results, ensure_ascii=False, indent=2)


# ---------------------------------------------------------------------------
# Flask web UI
# ---------------------------------------------------------------------------


INDEX_TEMPLATE = """<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>Wiki Arama{% if q %} — {{ q }}{% endif %}</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; max-width: 780px;
         margin: 2em auto; padding: 0 1em; color: #111; }
  h1 { font-size: 1.3em; }
  form { margin-bottom: 1.5em; }
  input[type=text] { width: 70%; padding: 0.5em; font-size: 1em;
                     border: 1px solid #888; }
  button { padding: 0.5em 1em; font-size: 1em; cursor: pointer; }
  .result { border-bottom: 1px solid #ddd; padding: 0.8em 0; }
  .result a { color: #06c; text-decoration: none; font-weight: 600; }
  .result a:hover { text-decoration: underline; }
  .score { color: #888; font-size: 0.85em; margin-left: 0.5em; }
  .snippet { color: #333; font-size: 0.95em; margin-top: 0.3em; }
  .empty { color: #666; font-style: italic; }
</style>
</head>
<body>
<h1>Wiki Arama</h1>
<form method="get" action="/">
  <input type="text" name="q" value="{{ q or '' }}" placeholder="sorgu…" autofocus>
  <button type="submit">Ara</button>
</form>
{% if q %}
  {% if results %}
    <p>{{ results|length }} sonuç:</p>
    {% for r in results %}
      <div class="result">
        <a href="/doc?path={{ r.path|urlencode }}">{{ r.title }}</a>
        <span class="score">{{ "%.4f"|format(r.score) }} · {{ r.path }}</span>
        <div class="snippet">{{ r.snippet }}</div>
      </div>
    {% endfor %}
  {% else %}
    <p class="empty">Sonuç bulunamadı.</p>
  {% endif %}
{% endif %}
</body>
</html>
"""


DOC_TEMPLATE = """<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>{{ title }}</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; max-width: 780px;
         margin: 2em auto; padding: 0 1em; color: #111; line-height: 1.55; }
  a.back { color: #06c; text-decoration: none; font-size: 0.9em; }
  a.back:hover { text-decoration: underline; }
  .meta { color: #888; font-size: 0.85em; margin-bottom: 1.5em; }
  pre { background: #f4f4f4; padding: 0.8em; overflow-x: auto; }
  code { background: #f4f4f4; padding: 0.1em 0.3em; }
  table { border-collapse: collapse; }
  th, td { border: 1px solid #ccc; padding: 0.4em 0.8em; }
  blockquote { border-left: 3px solid #ccc; margin: 0; padding: 0 1em; color: #555; }
</style>
</head>
<body>
<a class="back" href="/?q={{ q|urlencode }}">← geri</a>
<div class="meta">{{ path }}</div>
{{ body|safe }}
</body>
</html>
"""


def run_server(host: str, port: int, wiki_path: Path, domain: str | None) -> int:
    """Basit Flask arayüzü. Her istekte aramayı mevcut indeks üzerinden yapar."""
    try:
        from flask import Flask, abort, render_template_string, request
    except ImportError as exc:
        raise SystemExit(
            "flask yüklü değil. Kur: pip install -r requirements.txt"
        ) from exc
    try:
        import markdown as md_lib
    except ImportError as exc:
        raise SystemExit(
            "markdown yüklü değil. Kur: pip install -r requirements.txt"
        ) from exc

    docs = collect_docs(wiki_path, domain=domain)
    vectorizer, matrix = build_index(docs)

    app = Flask(__name__)

    @app.route("/")
    def index():
        q = (request.args.get("q") or "").strip()
        results = search(q, vectorizer, matrix, docs, top_k=20) if q else []
        return render_template_string(INDEX_TEMPLATE, q=q, results=results)

    @app.route("/doc")
    def doc():
        rel = (request.args.get("path") or "").strip()
        if not rel:
            abort(404)
        # Path traversal koruması
        target = (wiki_path / rel).resolve()
        try:
            target.relative_to(wiki_path.resolve())
        except ValueError:
            abort(404)
        if not target.is_file() or target.suffix != ".md":
            abort(404)

        content = target.read_text(encoding="utf-8")
        title = extract_title(content, target.stem)
        body_html = md_lib.markdown(
            content,
            extensions=["extra", "tables", "fenced_code", "toc"],
        )
        q = (request.args.get("q") or "").strip()
        return render_template_string(
            DOC_TEMPLATE, title=title, path=rel, body=body_html, q=q
        )

    print(f"Wiki arama sunucusu: http://{host}:{port}  (wiki: {wiki_path})")
    app.run(host=host, port=port, debug=False)
    return 0


# ---------------------------------------------------------------------------
# CLI giriş noktası
# ---------------------------------------------------------------------------


def build_search_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="search.py",
        description=(
            "Wiki üzerinde TF-IDF tabanlı basit arama. "
            "Web UI için: search.py serve [--host H --port P]"
        ),
    )
    parser.add_argument("query", help="arama sorgusu")
    parser.add_argument("--top", type=int, default=5, help="gösterilecek sonuç sayısı")
    parser.add_argument("--json", action="store_true", help="JSON çıktı (LLM tool use)")
    parser.add_argument("--domain", default=None, help="yalnız bu domain'de ara")
    return parser


def build_serve_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="search.py serve")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5555)
    parser.add_argument("--domain", default=None, help="yalnız bu domain'i indeksle")
    return parser


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    cfg = load_config()
    wiki_path = wiki_path_from_config(cfg)

    # "serve" alt-komutunu pozisyonel query ile çakışmayacak şekilde manuel dispatch
    if argv and argv[0] == "serve":
        args = build_serve_parser().parse_args(argv[1:])
        return run_server(args.host, args.port, wiki_path, args.domain)

    args = build_search_parser().parse_args(argv)
    docs = collect_docs(wiki_path, domain=args.domain)
    vectorizer, matrix = build_index(docs)
    results = search(args.query, vectorizer, matrix, docs, top_k=args.top)

    if args.json:
        print(format_json(results))
    else:
        print(format_text(results, args.query))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
