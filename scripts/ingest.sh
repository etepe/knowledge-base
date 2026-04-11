#!/usr/bin/env bash
# ingest.sh — yeni ham kaynak ekleme yardımcısı.
#
# Kullanım:
#   ./scripts/ingest.sh --domain <domain> --url "https://example.com/paper"
#   ./scripts/ingest.sh --domain <domain> --file ./some-paper.pdf
#
# Davranış:
#   - URL'i çeker, markdown'a çevirir, resimleri indirir ve markdown içindeki
#     referansları lokal path'lere günceller.
#   - Dosyayı raw/<domain>/ altına kopyalar; PDF ise pdftotext ile .md türevi
#     üretir.
#   - Her ingest işlemini raw/<domain>/_manifest.json içine kaydeder.

set -euo pipefail

VALID_DOMAINS=("fetm" "hmm-crypto" "geopolitical" "general")

usage() {
    cat <<'EOF'
Usage:
  ingest.sh --domain <fetm|hmm-crypto|geopolitical|general> --url <url>
  ingest.sh --domain <fetm|hmm-crypto|geopolitical|general> --file <path>

Options:
  --domain <name>   Hedef domain (zorunlu).
  --url <url>       HTTP(S) kaynağı; indirilip markdown'a çevrilir.
  --file <path>     Lokal dosya (pdf, txt, md, ...); raw/<domain>/ altına kopyalanır.
  -h, --help        Bu mesajı yazdır.
EOF
}

err() { echo "ingest.sh: $*" >&2; }
die() { err "$*"; exit 1; }

DOMAIN=""
URL=""
FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)
            [[ $# -ge 2 ]] || die "--domain değeri eksik"
            DOMAIN="$2"; shift 2 ;;
        --url)
            [[ $# -ge 2 ]] || die "--url değeri eksik"
            URL="$2"; shift 2 ;;
        --file)
            [[ $# -ge 2 ]] || die "--file değeri eksik"
            FILE="$2"; shift 2 ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            err "bilinmeyen argüman: $1"; usage; exit 1 ;;
    esac
done

[[ -n "$DOMAIN" ]] || { usage; die "--domain zorunlu"; }

domain_ok=0
for d in "${VALID_DOMAINS[@]}"; do
    if [[ "$d" == "$DOMAIN" ]]; then domain_ok=1; break; fi
done
[[ $domain_ok -eq 1 ]] || die "geçersiz domain: $DOMAIN (izinli: ${VALID_DOMAINS[*]})"

if [[ -n "$URL" && -n "$FILE" ]]; then
    die "--url ve --file aynı anda verilemez"
fi
if [[ -z "$URL" && -z "$FILE" ]]; then
    usage; die "--url veya --file gerekli"
fi

# Repo kökünü bul: script scripts/ altında olduğundan bir üst dizin.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

DOMAIN_DIR="raw/$DOMAIN"
IMAGES_ROOT="$DOMAIN_DIR/images"
MANIFEST="$DOMAIN_DIR/_manifest.json"
mkdir -p "$DOMAIN_DIR" "$IMAGES_ROOT"
[[ -f "$MANIFEST" ]] || printf '[]\n' > "$MANIFEST"

INGEST_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

FILENAME=""
SOURCE_URL=""
TYPE=""

if [[ -n "$URL" ]]; then
    command -v python3 >/dev/null 2>&1 || die "python3 gerekli"

    # slug üret (host+path sanitize, uzunluk sınırlı, unix ts eklenmiş)
    SLUG="$(python3 - "$URL" <<'PY'
import re, sys, time
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
base = (u.netloc + u.path).strip("/")
slug = re.sub(r"[^a-zA-Z0-9]+", "-", base).strip("-").lower()
if not slug:
    slug = "page"
slug = slug[:80].rstrip("-")
print(f"{slug}-{int(time.time())}")
PY
)"

    TMPDIR="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR"' EXIT
    HTML_PATH="$TMPDIR/page.html"

    echo "fetching: $URL"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 2 -A "knowledge-base-ingest/1.0" -o "$HTML_PATH" "$URL" \
            || die "curl indirme başarısız"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -U "knowledge-base-ingest/1.0" -O "$HTML_PATH" "$URL" \
            || die "wget indirme başarısız"
    else
        die "curl veya wget gerekli"
    fi

    MD_OUT="$DOMAIN_DIR/${SLUG}.md"
    IMG_DIR="$IMAGES_ROOT/$SLUG"
    mkdir -p "$IMG_DIR"

    if command -v pandoc >/dev/null 2>&1; then
        pandoc -f html -t gfm --wrap=preserve -o "$MD_OUT" "$HTML_PATH" \
            || die "pandoc dönüşümü başarısız"
    else
        err "uyarı: pandoc bulunamadı, basit python fallback kullanılıyor"
        python3 - "$HTML_PATH" "$MD_OUT" <<'PY'
import re, sys
from html.parser import HTMLParser

src, dst = sys.argv[1], sys.argv[2]
with open(src, "r", encoding="utf-8", errors="replace") as f:
    html = f.read()

# script/style bloklarını at
html = re.sub(r"<script[\s\S]*?</script>", "", html, flags=re.I)
html = re.sub(r"<style[\s\S]*?</style>", "", html, flags=re.I)

out_parts = []

class P(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.skip = 0
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in ("h1","h2","h3","h4","h5","h6"):
            n = int(tag[1])
            out_parts.append("\n\n" + "#" * n + " ")
        elif tag == "p":
            out_parts.append("\n\n")
        elif tag == "br":
            out_parts.append("  \n")
        elif tag == "li":
            out_parts.append("\n- ")
        elif tag == "a":
            href = a.get("href", "")
            out_parts.append(f"[")
            self._href = href
        elif tag == "img":
            src = a.get("src", "")
            alt = a.get("alt", "")
            out_parts.append(f"![{alt}]({src})")
        elif tag in ("strong","b"):
            out_parts.append("**")
        elif tag in ("em","i"):
            out_parts.append("*")
        elif tag == "code":
            out_parts.append("`")
        elif tag == "pre":
            out_parts.append("\n\n```\n")
    def handle_endtag(self, tag):
        if tag == "a":
            href = getattr(self, "_href", "")
            out_parts.append(f"]({href})")
        elif tag in ("strong","b"):
            out_parts.append("**")
        elif tag in ("em","i"):
            out_parts.append("*")
        elif tag == "code":
            out_parts.append("`")
        elif tag == "pre":
            out_parts.append("\n```\n")
    def handle_data(self, data):
        out_parts.append(data)

p = P()
p.feed(html)
text = "".join(out_parts)
text = re.sub(r"\n{3,}", "\n\n", text).strip() + "\n"
with open(dst, "w", encoding="utf-8") as f:
    f.write(text)
PY
    fi

    # Resim indirme ve markdown path rewrite
    python3 - "$MD_OUT" "$IMG_DIR" "$URL" <<'PY'
import hashlib
import os
import re
import sys
import urllib.parse
import urllib.request

md_path, img_dir, base_url = sys.argv[1], sys.argv[2], sys.argv[3]
with open(md_path, "r", encoding="utf-8") as f:
    content = f.read()

pattern = re.compile(r'!\[([^\]]*)\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)')

_cache = {}

def download(src: str):
    if src.startswith("data:"):
        return None
    full = urllib.parse.urljoin(base_url, src)
    if full in _cache:
        return _cache[full]
    parsed = urllib.parse.urlparse(full)
    if parsed.scheme not in ("http", "https"):
        _cache[full] = None
        return None
    ext = os.path.splitext(parsed.path)[1].lower()
    if not ext or len(ext) > 6:
        ext = ".img"
    name = hashlib.sha1(full.encode("utf-8")).hexdigest()[:10] + ext
    dst = os.path.join(img_dir, name)
    if not os.path.exists(dst):
        try:
            req = urllib.request.Request(
                full, headers={"User-Agent": "knowledge-base-ingest/1.0"}
            )
            with urllib.request.urlopen(req, timeout=30) as resp, open(dst, "wb") as out:
                out.write(resp.read())
        except Exception as e:  # noqa: BLE001
            print(f"warn: image indirilemedi {full}: {e}", file=sys.stderr)
            _cache[full] = None
            return None
    rel = os.path.relpath(dst, os.path.dirname(md_path))
    _cache[full] = rel
    return rel

def repl(m):
    alt, src = m.group(1), m.group(2)
    local = download(src)
    if local is None:
        return m.group(0)
    return f"![{alt}]({local})"

new = pattern.sub(repl, content)
if new != content:
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(new)
PY

    FILENAME="${SLUG}.md"
    SOURCE_URL="$URL"
    TYPE="url"
else
    [[ -f "$FILE" ]] || die "dosya bulunamadı: $FILE"
    BASENAME="$(basename -- "$FILE")"
    DEST="$DOMAIN_DIR/$BASENAME"
    cp -- "$FILE" "$DEST"

    EXT="${BASENAME##*.}"
    EXT_LC="$(printf '%s' "$EXT" | tr '[:upper:]' '[:lower:]')"

    case "$EXT_LC" in
        pdf)
            MD_TWIN="$DOMAIN_DIR/${BASENAME%.*}.md"
            if command -v pdftotext >/dev/null 2>&1; then
                pdftotext -layout "$DEST" "$MD_TWIN" \
                    || err "uyarı: pdftotext başarısız oldu"
            else
                err "uyarı: pdftotext bulunamadı; PDF metin türevi üretilmedi"
            fi
            ;;
        txt|md)
            : # dosya kopyalandı, başka dönüşüm yok
            ;;
        *)
            err "uyarı: bilinmeyen uzantı '.${EXT_LC}'; dosya olduğu gibi kopyalandı"
            ;;
    esac

    ABS_PATH="$(cd "$(dirname -- "$FILE")" && pwd)/$BASENAME"
    FILENAME="$BASENAME"
    SOURCE_URL="file://$ABS_PATH"
    TYPE="$EXT_LC"
fi

# Manifest'e yeni entry ekle
python3 - "$MANIFEST" "$FILENAME" "$SOURCE_URL" "$INGEST_DATE" "$TYPE" <<'PY'
import json
import sys

path = sys.argv[1]
entry = {
    "filename": sys.argv[2],
    "source_url": sys.argv[3],
    "ingest_date": sys.argv[4],
    "type": sys.argv[5],
    "status": "pending_compile",
}

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError("manifest liste değil")
except (FileNotFoundError, ValueError, json.JSONDecodeError):
    data = []

data.append(entry)

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

echo "ingested: $FILENAME → $DOMAIN_DIR (type=$TYPE)"
