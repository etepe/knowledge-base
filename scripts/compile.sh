#!/usr/bin/env bash
# compile.sh — wiki derleme tetikleyicisi.
#
# Kullanım:
#   ./scripts/compile.sh [domain]
#
# Amaç:
#   - raw/<domain>/_manifest.json içindeki `status: "pending_compile"` kayıtları
#     bulur; her biri için prompts/compile-v2.md şablonunu doldurup headless
#     `claude -p` komutuna gönderir. Claude, wiki/ altındaki dosyaları
#     (_index.md, makaleler, connections/) doğrudan yazar/günceller.
#   - Başarılı derleme sonrası manifest kaydını `compiled` yapar ve
#     `compiled_at` tarihini bugüne çeker. Hata durumunda `failed` olarak
#     işaretler — otomatik yeniden denenmez.
#   - Günlük bir derleme logu tutar: outputs/compile-log-<YYYY-MM-DD>.md
#
# Domain argümanı verilmezse .kb-config.yaml'da listelenen tüm domain'ler
# taranır. (raw/general/ konfigürasyonda olmadığı için bilinçli olarak atlanır.)
#
# Gereksinimler:
#   - jq    (manifest okuma/güncelleme)
#   - claude CLI (wiki derleme)
#
# Manifest şeması: raw/_MANIFEST_SCHEMA.md

set -euo pipefail

# ---------------------------------------------------------------------------
# Sabitler
# ---------------------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/.kb-config.yaml"
PROMPT_TEMPLATE="$REPO_ROOT/prompts/compile-v2.md"
RAW_DIR="$REPO_ROOT/raw"
WIKI_DIR="$REPO_ROOT/wiki"
OUTPUTS_DIR="$REPO_ROOT/outputs"
TODAY="$(date +%F)"
LOG_FILE="$OUTPUTS_DIR/compile-log-$TODAY.md"

# Fallback domain listesi (config parse edilemezse).
FALLBACK_DOMAINS=(fetm hmm-crypto geopolitical)

# Sayaçlar (özet için).
COUNT_ATTEMPTED=0
COUNT_COMPILED=0
COUNT_FAILED=0
COUNT_SKIPPED_DOMAINS=0

# resolve_target_domains buraya yazar (global kullanmak şart, çünkü `die`
# bir process substitution içinde çağrılsa ana kabuğu öldürmez).
TARGET_DOMAINS=()

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
}

# .kb-config.yaml içindeki `domains:` bloğunu saf bash/awk ile okur.
# yq gerektirmez.
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

# Argümana göre hedef domain listesini belirler; sonucu TARGET_DOMAINS'e yazar.
# die() doğrudan ana kabukta çalışsın diye process substitution kullanmıyoruz.
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

ensure_log_header() {
    mkdir -p "$OUTPUTS_DIR"
    if [[ ! -f "$LOG_FILE" ]]; then
        {
            echo "# Derleme Logu — $TODAY"
            echo ""
            echo "Bu dosya \`scripts/compile.sh\` tarafından otomatik yazılır."
            echo "Her bölüm bir derleme oturumunu, her girdi bir kaynak dosyayı temsil eder."
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

load_current_index() {
    local domain="$1"
    local idx_file="$WIKI_DIR/$domain/_index.md"
    if [[ -f "$idx_file" ]]; then
        cat "$idx_file"
    else
        echo "(indeks henüz yok)"
    fi
}

find_pending() {
    local manifest="$1"
    if ! jq empty "$manifest" >/dev/null 2>&1; then
        warn "Geçersiz JSON: $manifest — domain atlanıyor."
        return 1
    fi
    jq -r '.sources[]? | select(.status=="pending_compile") | .filename' "$manifest"
}

# Prompt şablonunu jq --rawfile ile güvenli şekilde doldurur.
# jq gsub binary-safe olduğu için özel karakterler (/, \, $, &, newline) ile
# uğraşmak gerekmez.
render_prompt() {
    local raw_file="$1"
    local domain="$2"
    local index_content="$3"
    local out_tmp="$4"

    local raw_content
    raw_content="$(cat "$raw_file")"

    jq -n \
        --rawfile tmpl "$PROMPT_TEMPLATE" \
        --arg raw "$raw_content" \
        --arg idx "$index_content" \
        --arg dom "$domain" \
        --arg date "$TODAY" \
        --raw-output \
        '$tmpl
           | gsub("\\{raw_content\\}"; $raw)
           | gsub("\\{current_index\\}"; $idx)
           | gsub("\\{domain\\}"; $dom)
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

# Manifest kaydını atomik güncelle: jq | tmp | mv.
update_manifest() {
    local manifest="$1"
    local filename="$2"
    local new_status="$3"
    local tmp="${manifest}.tmp"

    jq \
        --arg f "$filename" \
        --arg s "$new_status" \
        --arg d "$TODAY" \
        '.sources |= map(
            if .filename == $f
            then .status = $s
                 | .compiled_at = (if $s == "compiled" then $d else .compiled_at end)
            else .
            end
        )' "$manifest" > "$tmp"

    mv "$tmp" "$manifest"
}

append_log() {
    local domain="$1"
    local filename="$2"
    local status="$3"
    local rc="$4"
    local out_tmp="$5"
    local err_tmp="$6"

    {
        echo "### \`$domain/$filename\` — $status (rc=$rc)"
        echo ""
        echo "- Zaman: $(date -Iseconds)"
        if [[ -s "$out_tmp" ]]; then
            echo "- Claude çıktısı (ilk 10 satır):"
            echo ""
            echo '```'
            head -n 10 "$out_tmp"
            echo '```'
        fi
        if [[ "$rc" -ne 0 && -s "$err_tmp" ]]; then
            echo "- Hata çıktısı:"
            echo ""
            echo '```'
            head -n 20 "$err_tmp"
            echo '```'
        fi
        echo ""
    } >> "$LOG_FILE"
}

process_source() {
    local domain="$1"
    local filename="$2"
    local manifest="$3"

    local raw_file="$RAW_DIR/$domain/$filename"
    local prompt_tmp out_tmp err_tmp
    prompt_tmp="$(mktemp)"
    out_tmp="$(mktemp)"
    err_tmp="$(mktemp)"

    # Tmpfile temizliği — hem başarı hem hata yolunda.
    # shellcheck disable=SC2064
    trap "rm -f '$prompt_tmp' '$out_tmp' '$err_tmp'" RETURN

    COUNT_ATTEMPTED=$((COUNT_ATTEMPTED + 1))
    info "[$domain] İşleniyor: $filename"

    if [[ ! -f "$raw_file" ]]; then
        warn "Kaynak dosya yok: $raw_file — 'failed' olarak işaretleniyor."
        echo "Kaynak dosya bulunamadı: $raw_file" > "$err_tmp"
        update_manifest "$manifest" "$filename" "failed"
        append_log "$domain" "$filename" "failed" 1 "$out_tmp" "$err_tmp"
        COUNT_FAILED=$((COUNT_FAILED + 1))
        return 0
    fi

    local index_content
    index_content="$(load_current_index "$domain")"

    if ! render_prompt "$raw_file" "$domain" "$index_content" "$prompt_tmp"; then
        warn "Prompt doldurulamadı: $filename"
        echo "render_prompt başarısız oldu" > "$err_tmp"
        update_manifest "$manifest" "$filename" "failed"
        append_log "$domain" "$filename" "failed" 1 "$out_tmp" "$err_tmp"
        COUNT_FAILED=$((COUNT_FAILED + 1))
        return 0
    fi

    local rc=0
    invoke_claude "$prompt_tmp" "$out_tmp" "$err_tmp" || rc=$?

    if [[ "$rc" -eq 0 ]]; then
        update_manifest "$manifest" "$filename" "compiled"
        append_log "$domain" "$filename" "compiled" "$rc" "$out_tmp" "$err_tmp"
        COUNT_COMPILED=$((COUNT_COMPILED + 1))
        info "[$domain] OK $filename → compiled"
    else
        update_manifest "$manifest" "$filename" "failed"
        append_log "$domain" "$filename" "failed" "$rc" "$out_tmp" "$err_tmp"
        COUNT_FAILED=$((COUNT_FAILED + 1))
        warn "[$domain] HATA $filename → failed (rc=$rc)"
    fi
}

process_domain() {
    local domain="$1"
    local manifest="$RAW_DIR/$domain/_manifest.json"

    if [[ ! -f "$manifest" ]]; then
        warn "Manifest yok, atlanıyor: $manifest"
        COUNT_SKIPPED_DOMAINS=$((COUNT_SKIPPED_DOMAINS + 1))
        return 0
    fi

    local pending
    if ! pending="$(find_pending "$manifest")"; then
        COUNT_SKIPPED_DOMAINS=$((COUNT_SKIPPED_DOMAINS + 1))
        return 0
    fi

    if [[ -z "$pending" ]]; then
        info "[$domain] 0 pending_compile kaydı."
        return 0
    fi

    info "[$domain] pending_compile kayıtları işleniyor..."
    while IFS= read -r filename; do
        [[ -z "$filename" ]] && continue
        process_source "$domain" "$filename" "$manifest"
    done <<< "$pending"
}

print_summary() {
    echo ""
    echo "========================================="
    echo "Derleme özeti ($TODAY)"
    echo "========================================="
    echo "  Denenen       : $COUNT_ATTEMPTED"
    echo "  Basarili      : $COUNT_COMPILED"
    echo "  Hatali        : $COUNT_FAILED"
    echo "  Atlanan dom.  : $COUNT_SKIPPED_DOMAINS"
    echo "  Log dosyasi   : $LOG_FILE"
    echo "========================================="
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
    check_deps
    resolve_target_domains "${1:-}"
    ensure_log_header

    local d
    for d in "${TARGET_DOMAINS[@]}"; do
        process_domain "$d"
    done

    print_summary
}

main "$@"
