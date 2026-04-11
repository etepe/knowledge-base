#!/usr/bin/env bash
# lint.sh — wiki sağlık kontrolü.
#
# Kullanım:
#   ./scripts/lint.sh [domain]
#
# Amaç:
#   - wiki/ altındaki tüm .md dosyalarını tek prompt olarak toplayıp
#     prompts/lint.md şablonuna yerleştirir ve headless `claude -p` komutuna
#     gönderir. Claude, 7 kategori üzerinden (kırık linkler, tutarsızlıklar,
#     yetim makaleler, eksik veri, duplicate, yeni makale önerileri,
#     cross-domain bağlantılar) sağlık raporu üretir ve sonucu doğrudan
#     outputs/lint-report-<YYYY-MM-DD>.md dosyasına yazar.
#   - Domain argümanı verilirse yalnızca wiki/<domain>/ altındaki dosyalar
#     taranır. Verilmezse wiki/ altındaki tüm .md dosyaları (root'taki
#     _index.md ve _glossary.md dahil) taranır.
#   - Günlük bir lint logu tutar: outputs/lint-log-<YYYY-MM-DD>.md
#
# Gereksinimler:
#   - jq    (prompt doldurma)
#   - claude CLI (lint çalıştırma)

set -euo pipefail

# ---------------------------------------------------------------------------
# Sabitler
# ---------------------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/.kb-config.yaml"
PROMPT_TEMPLATE="$REPO_ROOT/prompts/lint.md"
WIKI_DIR="$REPO_ROOT/wiki"
OUTPUTS_DIR="$REPO_ROOT/outputs"
TODAY="$(date +%F)"
LOG_FILE="$OUTPUTS_DIR/lint-log-$TODAY.md"
REPORT_FILE="$OUTPUTS_DIR/lint-report-$TODAY.md"

# Fallback domain listesi (config parse edilemezse).
FALLBACK_DOMAINS=(fetm hmm-crypto geopolitical)

# resolve_target_domains buraya yazar.
# Boş dizi => tüm wiki/ taranır; tek eleman => sadece o domain.
TARGET_DOMAINS=()

# Toplanan wiki dosyaları ve birleştirilmiş içerik.
WIKI_FILES=()
WIKI_BLOB=""

# Sayaçlar (özet için).
COUNT_FILES_SCANNED=0
COUNT_PROMPT_BYTES=0
RC=0
REPORT_EXISTS="no"

# ---------------------------------------------------------------------------
# Yardımcı fonksiyonlar
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

check_deps() {
    if ! command -v jq >/dev/null 2>&1; then
        die "'jq' bulunamadı. Kurulum: https://jqlang.github.io/jq/download/"
    fi
    if ! command -v claude >/dev/null 2>&1; then
        die "'claude' CLI bulunamadı. Kurulum: https://docs.claude.com/en/docs/claude-code"
    fi
    if [[ ! -f "$PROMPT_TEMPLATE" ]]; then
        die "Prompt şablonu yok: $PROMPT_TEMPLATE"
    fi
    if [[ ! -f "$CONFIG_FILE" ]]; then
        die "Konfigürasyon dosyası yok: $CONFIG_FILE"
    fi
    if [[ ! -d "$WIKI_DIR" ]]; then
        die "Wiki dizini yok: $WIKI_DIR"
    fi
}

# .kb-config.yaml içindeki `domains:` bloğunu saf awk ile okur.
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

# Argümana göre tarama kapsamını belirler.
# Argüman yoksa TARGET_DOMAINS boş kalır (tüm wiki taranır).
# Argüman varsa geçerli bir domain olmalı; TARGET_DOMAINS o tek elemanı alır.
resolve_target_domains() {
    local arg="${1:-}"
    if [[ -z "$arg" ]]; then
        TARGET_DOMAINS=()
        return 0
    fi

    local all_domains
    mapfile -t all_domains < <(read_domains_from_config)

    local d
    for d in "${all_domains[@]}"; do
        if [[ "$d" == "$arg" ]]; then
            TARGET_DOMAINS=("$d")
            return 0
        fi
    done
    die "Bilinmeyen domain: '$arg'. Tanımlı domain'ler: ${all_domains[*]}"
}

ensure_log_header() {
    mkdir -p "$OUTPUTS_DIR"
    if [[ ! -f "$LOG_FILE" ]]; then
        {
            echo "# Lint Logu — $TODAY"
            echo ""
            echo "Bu dosya \`scripts/lint.sh\` tarafından otomatik yazılır."
            echo "Her bölüm bir lint oturumunu temsil eder."
            echo ""
        } > "$LOG_FILE"
    fi
    {
        echo "---"
        echo ""
        echo "## Oturum: $(date -Iseconds)"
        echo ""
    } >> "$LOG_FILE"
}

# wiki/ altındaki hedef .md dosyalarını deterministik (sıralı) şekilde toplar.
# TARGET_DOMAINS boşsa tüm wiki/ taranır; doluysa wiki/<domain>/ altı.
collect_wiki_files() {
    local scan_root
    if [[ ${#TARGET_DOMAINS[@]} -eq 0 ]]; then
        scan_root="$WIKI_DIR"
    else
        scan_root="$WIKI_DIR/${TARGET_DOMAINS[0]}"
        if [[ ! -d "$scan_root" ]]; then
            die "Domain dizini yok: $scan_root"
        fi
    fi

    mapfile -t WIKI_FILES < <(find "$scan_root" -type f -name "*.md" | LC_ALL=C sort)
    COUNT_FILES_SCANNED=${#WIKI_FILES[@]}

    if [[ "$COUNT_FILES_SCANNED" -eq 0 ]]; then
        die "Taranacak .md dosyası bulunamadı: $scan_root"
    fi
}

# WIKI_FILES içindeki her dosyayı `### wiki/<rel_path>` başlığı ve markdown
# fence'i ile birleştirip WIKI_BLOB'a yazar. Nested markdown'un Claude
# tarafından doğru parse edilmesi için dış fence `~~~~markdown` kullanılır
# (4 tilde, yaygın iç `\`\`\`` fence'leriyle çakışmaz).
build_wiki_blob() {
    local blob_tmp
    blob_tmp="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$blob_tmp'" RETURN

    local f rel
    for f in "${WIKI_FILES[@]}"; do
        rel="${f#"$REPO_ROOT/"}"
        {
            echo "### $rel"
            echo ""
            echo "~~~~markdown"
            cat "$f"
            echo "~~~~"
            echo ""
        } >> "$blob_tmp"
    done

    WIKI_BLOB="$(cat "$blob_tmp")"
    COUNT_PROMPT_BYTES=${#WIKI_BLOB}
}

# Prompt şablonunu jq --rawfile ile güvenli şekilde doldurur.
render_prompt() {
    local out_tmp="$1"

    jq -n \
        --rawfile tmpl "$PROMPT_TEMPLATE" \
        --arg blob "$WIKI_BLOB" \
        --arg date "$TODAY" \
        --raw-output \
        '$tmpl
           | gsub("\\{tum_wiki_dosyalari_ve_icerik\\}"; $blob)
           | gsub("\\{tarih\\}"; $date)' \
        > "$out_tmp"
}

# claude -p headless çağrısı. stdin üzerinden prompt verir, stdout/stderr'i
# ayrı tmpfile'lara yakalar, exit kodu döndürür.
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

verify_report_exists() {
    if [[ -f "$REPORT_FILE" ]]; then
        REPORT_EXISTS="yes"
    else
        REPORT_EXISTS="no"
    fi
}

append_log() {
    local rc="$1"
    local out_tmp="$2"
    local err_tmp="$3"
    local scope
    if [[ ${#TARGET_DOMAINS[@]} -eq 0 ]]; then
        scope="tüm wiki"
    else
        scope="domain=${TARGET_DOMAINS[0]}"
    fi

    {
        echo "### Lint oturumu — $scope (rc=$rc)"
        echo ""
        echo "- Zaman: $(date -Iseconds)"
        echo "- Taranan dosya sayısı: $COUNT_FILES_SCANNED"
        echo "- Prompt boyutu (byte): $COUNT_PROMPT_BYTES"
        echo "- Rapor dosyası: \`outputs/lint-report-$TODAY.md\` (var mı: $REPORT_EXISTS)"
        if [[ -s "$out_tmp" ]]; then
            echo "- Claude stdout (ilk 20 satır):"
            echo ""
            echo '```'
            head -n 20 "$out_tmp"
            echo '```'
        fi
        if [[ "$rc" -ne 0 && -s "$err_tmp" ]]; then
            echo "- Hata çıktısı (ilk 20 satır):"
            echo ""
            echo '```'
            head -n 20 "$err_tmp"
            echo '```'
        fi
        echo ""
    } >> "$LOG_FILE"
}

print_summary() {
    local scope
    if [[ ${#TARGET_DOMAINS[@]} -eq 0 ]]; then
        scope="tüm wiki"
    else
        scope="domain=${TARGET_DOMAINS[0]}"
    fi

    echo ""
    echo "========================================="
    echo "Lint özeti ($TODAY)"
    echo "========================================="
    echo "  Kapsam          : $scope"
    echo "  Taranan dosya   : $COUNT_FILES_SCANNED"
    echo "  Prompt boyutu   : $COUNT_PROMPT_BYTES byte"
    echo "  Claude rc       : $RC"
    echo "  Rapor olustu mu : $REPORT_EXISTS"
    echo "  Rapor dosyasi   : $REPORT_FILE"
    echo "  Log dosyasi     : $LOG_FILE"
    echo "========================================="
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
    check_deps
    resolve_target_domains "${1:-}"
    ensure_log_header

    info "Wiki dosyaları toplanıyor..."
    collect_wiki_files
    info "Toplam $COUNT_FILES_SCANNED dosya bulundu."

    info "Prompt hazırlanıyor..."
    build_wiki_blob

    local prompt_tmp out_tmp err_tmp
    prompt_tmp="$(mktemp)"
    out_tmp="$(mktemp)"
    err_tmp="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$prompt_tmp' '$out_tmp' '$err_tmp'" EXIT

    if ! render_prompt "$prompt_tmp"; then
        die "Prompt doldurulamadı (jq render hatası)."
    fi

    info "Claude çağrılıyor (prompt boyutu: $COUNT_PROMPT_BYTES byte)..."
    RC=0
    invoke_claude "$prompt_tmp" "$out_tmp" "$err_tmp" || RC=$?

    verify_report_exists
    append_log "$RC" "$out_tmp" "$err_tmp"

    if [[ "$RC" -eq 0 && "$REPORT_EXISTS" == "yes" ]]; then
        info "OK — rapor hazır: $REPORT_FILE"
    elif [[ "$RC" -eq 0 && "$REPORT_EXISTS" == "no" ]]; then
        warn "Claude başarıyla döndü ancak rapor dosyası bulunamadı: $REPORT_FILE"
    else
        warn "Claude hata ile döndü (rc=$RC). Ayrıntı için: $LOG_FILE"
    fi

    print_summary
}

main "$@"
