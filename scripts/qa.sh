#!/usr/bin/env bash
# qa.sh — wiki üzerinde soru-cevap.
#
# Kullanım:
#   ./scripts/qa.sh "Soru metni" [--domain <domain>]
#   ./scripts/qa.sh --help
#
# Amaç:
#   - Verilen soru için wiki/ altındaki indeksleri ve makaleleri bağlam olarak
#     toplar, prompts/qa.md şablonunu doldurur, headless `claude -p` komutuna
#     gönderir ve cevabı outputs/reports/qa-<tarih>-<slug>.md altına kaydeder.
#   - Opsiyonel olarak, kullanıcı onaylarsa cevabı prompts/qa-filing.md ile
#     wiki/ altına kalıcı bir makale olarak file eder (Claude doğrudan yazar).
#   - Oturumu outputs/qa-log-<tarih>.md dosyasına loglar.
#
# Gereksinimler:
#   - jq
#   - claude CLI

set -euo pipefail

# ---------------------------------------------------------------------------
# Sabitler
# ---------------------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/.kb-config.yaml"
QA_PROMPT="$REPO_ROOT/prompts/qa.md"
FILING_PROMPT="$REPO_ROOT/prompts/qa-filing.md"
WIKI_DIR="$REPO_ROOT/wiki"
OUTPUTS_DIR="$REPO_ROOT/outputs"
REPORTS_DIR="$OUTPUTS_DIR/reports"
TODAY="$(date +%F)"
LOG_FILE="$OUTPUTS_DIR/qa-log-$TODAY.md"

FALLBACK_DOMAINS=(fetm hmm-crypto geopolitical)

# Argümanlardan doldurulur.
QUESTION=""
DOMAIN=""

# resolve_target_domains buraya yazar.
TARGET_DOMAINS=()

# ---------------------------------------------------------------------------
# Yardımcılar
# ---------------------------------------------------------------------------

die() {
    echo "HATA: $*" >&2
    exit 1
}

warn() {
    echo "UYARI: $*" >&2
}

info() {
    echo "• $*"
}

usage() {
    cat <<'EOF'
Kullanım:
  ./scripts/qa.sh "Soru metni" [--domain <domain>]
  ./scripts/qa.sh --help

Argümanlar:
  <soru>            Pozisyonel, zorunlu. Tırnak içinde ver.
  --domain <name>   Sadece bu domain'in wiki içeriğini bağlam yap.
                    Verilmezse tüm domain'ler taranır.
  --help, -h        Bu yardımı göster.

Örnek:
  ./scripts/qa.sh "FETM rejim filtreleme nasıl çalışıyor?" --domain fetm
EOF
}

check_deps() {
    if ! command -v jq >/dev/null 2>&1; then
        die "'jq' bulunamadı. Kurulum: https://jqlang.github.io/jq/download/"
    fi
    if ! command -v claude >/dev/null 2>&1; then
        die "'claude' CLI bulunamadı. Kurulum: https://docs.claude.com/en/docs/claude-code"
    fi
    if [[ ! -f "$QA_PROMPT" ]]; then
        die "Q&A şablonu yok: $QA_PROMPT"
    fi
    if [[ ! -f "$FILING_PROMPT" ]]; then
        die "Filing şablonu yok: $FILING_PROMPT"
    fi
    if [[ ! -f "$CONFIG_FILE" ]]; then
        die "Konfigürasyon dosyası yok: $CONFIG_FILE"
    fi
}

# compile.sh ile aynı awk tabanlı domain okuyucu.
read_domains_from_config() {
    local domains
    domains=$(awk '
        /^domains:[[:space:]]*$/ { in_block = 1; next }
        in_block && /^[[:space:]]*-[[:space:]]/ {
            sub(/^[[:space:]]*-[[:space:]]*/, "")
            sub(/[[:space:]]*#.*$/, "")
            sub(/[[:space:]]+$/, "")
            if (length($0) > 0) print $0
            next
        }
        in_block && /^[^[:space:]]/ { in_block = 0 }
    ' "$CONFIG_FILE")

    if [[ -z "$domains" ]]; then
        warn ".kb-config.yaml'dan domain listesi okunamadı; fallback kullanılıyor."
        printf '%s\n' "${FALLBACK_DOMAINS[@]}"
    else
        printf '%s\n' "$domains"
    fi
}

resolve_target_domains() {
    local arg="${1:-}"
    local all_domains
    mapfile -t all_domains < <(read_domains_from_config)

    if [[ -z "$arg" ]]; then
        TARGET_DOMAINS=("${all_domains[@]}")
        return 0
    fi

    local d
    for d in "${all_domains[@]}"; do
        if [[ "$d" == "$arg" ]]; then
            TARGET_DOMAINS=("$d")
            return 0
        fi
    done
    die "Bilinmeyen domain: '$arg'. Tanımlı domain'ler: ${all_domains[*]}"
}

parse_args() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --domain)
                [[ $# -ge 2 ]] || die "--domain bir değer bekliyor"
                DOMAIN="$2"
                shift 2
                ;;
            --domain=*)
                DOMAIN="${1#--domain=}"
                shift
                ;;
            --)
                shift
                ;;
            -*)
                die "Bilinmeyen seçenek: $1"
                ;;
            *)
                if [[ -z "$QUESTION" ]]; then
                    QUESTION="$1"
                else
                    die "Birden fazla pozisyonel argüman verildi. Soruyu tırnak içine al."
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$QUESTION" ]]; then
        usage
        exit 1
    fi
}

# Soru metninden dosya-güvenli kısa bir slug üretir.
# iconv varsa Türkçe karakterleri ASCII'ye çevirir; yoksa basit tr fallback'i.
slugify() {
    local raw="$1"
    local slug
    if command -v iconv >/dev/null 2>&1; then
        slug=$(printf '%s' "$raw" \
            | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
            | tr '[:upper:]' '[:lower:]' \
            | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
    fi
    if [[ -z "${slug:-}" ]]; then
        slug=$(printf '%s' "$raw" \
            | tr '[:upper:]' '[:lower:]' \
            | tr -cs 'a-z0-9' '-' \
            | sed -E 's/^-+//; s/-+$//')
    fi
    # Maksimum 48 karakter.
    slug="${slug:0:48}"
    slug="${slug%-}"
    if [[ -z "$slug" ]]; then
        slug="soru"
    fi
    printf '%s\n' "$slug"
}

# Bir dosyayı "### path" başlığıyla çıktıya ekler.
append_file_block() {
    local rel="$1"
    local abs="$2"
    local out="$3"
    {
        echo "### $rel"
        echo ""
        cat "$abs"
        echo ""
    } >> "$out"
}

# Bağlamı toplar: ana indeks + hedef domain(ler)in indeks+makaleleri.
# Sonucu $1 dosyasına yazar. Dosya sayısını stdout'a basar.
collect_context() {
    local out="$1"
    : > "$out"

    local count=0

    if [[ -f "$WIKI_DIR/_index.md" ]]; then
        append_file_block "wiki/_index.md" "$WIKI_DIR/_index.md" "$out"
        count=$((count + 1))
    fi

    if [[ -f "$WIKI_DIR/_glossary.md" ]]; then
        append_file_block "wiki/_glossary.md" "$WIKI_DIR/_glossary.md" "$out"
        count=$((count + 1))
    fi

    local d
    for d in "${TARGET_DOMAINS[@]}"; do
        local dom_dir="$WIKI_DIR/$d"
        if [[ ! -d "$dom_dir" ]]; then
            continue
        fi
        if [[ -f "$dom_dir/_index.md" ]]; then
            append_file_block "wiki/$d/_index.md" "$dom_dir/_index.md" "$out"
            count=$((count + 1))
        fi
        # Domain'in düz makaleleri (alt dizin yok).
        local f
        shopt -s nullglob
        for f in "$dom_dir"/*.md; do
            local base
            base="$(basename "$f")"
            if [[ "$base" == "_index.md" ]]; then
                continue
            fi
            append_file_block "wiki/$d/$base" "$f" "$out"
            count=$((count + 1))
        done
        shopt -u nullglob
    done

    # Cross-domain connections (varsa).
    if [[ -d "$WIKI_DIR/connections" ]]; then
        local f
        shopt -s nullglob
        for f in "$WIKI_DIR/connections"/*.md; do
            local base
            base="$(basename "$f")"
            append_file_block "wiki/connections/$base" "$f" "$out"
            count=$((count + 1))
        done
        shopt -u nullglob
    fi

    printf '%d\n' "$count"
}

# Q&A prompt şablonunu doldurur.
render_qa_prompt() {
    local ctx_file="$1"
    local out_tmp="$2"
    local hint="${DOMAIN:-tum domainler}"

    local ctx_content
    ctx_content="$(cat "$ctx_file")"

    jq -n \
        --rawfile tmpl "$QA_PROMPT" \
        --arg ctx "$ctx_content" \
        --arg q "$QUESTION" \
        --arg hint "$hint" \
        --raw-output \
        '$tmpl
           | gsub("\\{ilgili_makaleler\\}"; $ctx)
           | gsub("\\{soru\\}"; $q)
           | gsub("\\{domain_hint\\}"; $hint)' \
        > "$out_tmp"
}

# Filing prompt şablonunu doldurur.
render_filing_prompt() {
    local answer_file="$1"
    local ctx_file="$2"
    local out_tmp="$3"

    local answer_content ctx_content
    answer_content="$(cat "$answer_file")"
    ctx_content="$(cat "$ctx_file")"

    jq -n \
        --rawfile tmpl "$FILING_PROMPT" \
        --arg q "$QUESTION" \
        --arg ans "$answer_content" \
        --arg idx "$ctx_content" \
        --arg date "$TODAY" \
        --raw-output \
        '$tmpl
           | gsub("\\{soru\\}"; $q)
           | gsub("\\{cevap\\}"; $ans)
           | gsub("\\{current_indexes\\}"; $idx)
           | gsub("\\{tarih\\}"; $date)' \
        > "$out_tmp"
}

# Headless claude çağrısı — compile.sh ile aynı desen.
invoke_claude() {
    local prompt_tmp="$1"
    local out_tmp="$2"
    local err_tmp="$3"
    local rc=0

    set +e
    ( cd "$REPO_ROOT" && claude -p --permission-mode acceptEdits < "$prompt_tmp" ) \
        > "$out_tmp" 2> "$err_tmp"
    rc=$?
    set -e

    return "$rc"
}

ensure_log_header() {
    mkdir -p "$OUTPUTS_DIR"
    if [[ ! -f "$LOG_FILE" ]]; then
        {
            echo "# Q&A Logu — $TODAY"
            echo ""
            echo "Bu dosya \`scripts/qa.sh\` tarafından otomatik yazılır."
            echo ""
        } > "$LOG_FILE"
    fi
}

append_log() {
    local status="$1"
    local report_path="$2"
    local filing_status="$3"
    local err_tmp="${4:-}"

    {
        echo "---"
        echo ""
        echo "## Oturum: $(date -Iseconds)"
        echo ""
        echo "- Soru: $QUESTION"
        echo "- Domain: ${DOMAIN:-<all>}"
        echo "- Durum: $status"
        echo "- Rapor: $report_path"
        echo "- Filing: $filing_status"
        if [[ -n "$err_tmp" && -s "$err_tmp" ]]; then
            echo "- Hata çıktısı (ilk 20 satır):"
            echo ""
            echo '```'
            head -n 20 "$err_tmp"
            echo '```'
        fi
        echo ""
    } >> "$LOG_FILE"
}

# Raporu frontmatter ile outputs/reports/ altına yazar.
write_report() {
    local report_path="$1"
    local answer_file="$2"

    mkdir -p "$REPORTS_DIR"
    local tmp="${report_path}.tmp"

    {
        echo "---"
        echo "type: qa"
        # Tırnakları kaç.
        local q_escaped="${QUESTION//\"/\\\"}"
        echo "question: \"$q_escaped\""
        echo "domain: ${DOMAIN:-all}"
        echo "created: $TODAY"
        echo "---"
        echo ""
        echo "# Soru"
        echo ""
        echo "$QUESTION"
        echo ""
        cat "$answer_file"
        echo ""
    } > "$tmp"

    mv "$tmp" "$report_path"
}

# ---------------------------------------------------------------------------
# Ana akış
# ---------------------------------------------------------------------------

main() {
    parse_args "$@"
    check_deps
    resolve_target_domains "$DOMAIN"
    ensure_log_header

    info "Soru: $QUESTION"
    info "Domain: ${DOMAIN:-<tümü>}"

    local ctx_tmp qa_prompt_tmp answer_tmp err_tmp filing_prompt_tmp filing_out_tmp filing_err_tmp
    ctx_tmp="$(mktemp)"
    qa_prompt_tmp="$(mktemp)"
    answer_tmp="$(mktemp)"
    err_tmp="$(mktemp)"
    filing_prompt_tmp="$(mktemp)"
    filing_out_tmp="$(mktemp)"
    filing_err_tmp="$(mktemp)"

    # shellcheck disable=SC2064
    trap "rm -f '$ctx_tmp' '$qa_prompt_tmp' '$answer_tmp' '$err_tmp' '$filing_prompt_tmp' '$filing_out_tmp' '$filing_err_tmp'" EXIT

    # 1) Bağlamı topla.
    local file_count
    file_count="$(collect_context "$ctx_tmp")"
    info "Bağlam: $file_count dosya toplandı."
    if [[ "$file_count" -eq 0 ]]; then
        warn "Hiç wiki dosyası bulunamadı — Claude muhtemelen 'kaynakta yok' diyecek."
    fi

    # 2) Q&A promptunu doldur.
    if ! render_qa_prompt "$ctx_tmp" "$qa_prompt_tmp"; then
        die "Q&A promptu doldurulamadı."
    fi

    # 3) Claude'u çağır.
    info "Claude'a gönderiliyor..."
    local rc=0
    invoke_claude "$qa_prompt_tmp" "$answer_tmp" "$err_tmp" || rc=$?

    if [[ "$rc" -ne 0 ]]; then
        warn "Claude çağrısı başarısız (rc=$rc). Hata:"
        if [[ -s "$err_tmp" ]]; then
            head -n 20 "$err_tmp" >&2
        fi
        append_log "failed" "-" "skipped" "$err_tmp"
        exit 2
    fi

    if [[ ! -s "$answer_tmp" ]]; then
        warn "Claude boş cevap döndürdü."
        append_log "empty" "-" "skipped" "$err_tmp"
        exit 2
    fi

    # 4) Raporu kaydet.
    local slug report_path
    slug="$(slugify "$QUESTION")"
    report_path="$REPORTS_DIR/qa-$TODAY-$slug.md"
    write_report "$report_path" "$answer_tmp"
    info "Rapor kaydedildi: $report_path"

    # 5) Filing akışı (interaktif).
    local filing_status="not_offered"
    if [[ -t 0 && -t 1 ]]; then
        local ans=""
        # stdin tty olduğu için read direkt çalışır.
        read -r -p "Bu cevabı wiki'ye eklemek ister misin? [e/H] " ans || ans=""
        case "${ans,,}" in
            e|y|evet|yes)
                info "Filing yapılıyor..."
                if ! render_filing_prompt "$answer_tmp" "$ctx_tmp" "$filing_prompt_tmp"; then
                    warn "Filing promptu doldurulamadı."
                    filing_status="render_failed"
                else
                    local frc=0
                    invoke_claude "$filing_prompt_tmp" "$filing_out_tmp" "$filing_err_tmp" || frc=$?
                    if [[ "$frc" -eq 0 ]]; then
                        filing_status="filed"
                        info "Filing tamamlandı. Claude çıktısı:"
                        if [[ -s "$filing_out_tmp" ]]; then
                            sed 's/^/  /' "$filing_out_tmp"
                        fi
                        info "Değişiklikleri görmek için: git status wiki/"
                    else
                        filing_status="failed(rc=$frc)"
                        warn "Filing başarısız (rc=$frc):"
                        if [[ -s "$filing_err_tmp" ]]; then
                            head -n 20 "$filing_err_tmp" >&2
                        fi
                    fi
                fi
                ;;
            *)
                filing_status="declined"
                info "Filing atlandı."
                ;;
        esac
    else
        info "Non-interaktif mod — filing sorusu atlandı."
        filing_status="non_interactive"
    fi

    append_log "ok" "$report_path" "$filing_status" ""

    echo ""
    echo "========================================="
    echo "Q&A tamamlandı ($TODAY)"
    echo "========================================="
    echo "  Soru     : $QUESTION"
    echo "  Domain   : ${DOMAIN:-<tümü>}"
    echo "  Rapor    : $report_path"
    echo "  Filing   : $filing_status"
    echo "  Log      : $LOG_FILE"
    echo "========================================="
}

main "$@"
