#!/usr/bin/env bash
# compile.sh — wiki derleme tetikleyicisi.
#
# Kullanım:
#   ./scripts/compile.sh <domain> [makale-slug]
#
# Amaç:
#   - raw/<domain>/ içindeki kaynakları prompts/compile.md şablonuyla birleştirip
#     LLM'e gönderir; çıktıyı wiki/<domain>/<slug>.md olarak yazar.
#   - _index.md ve _glossary.md dosyalarını günceller.
set -euo pipefail

echo "TODO: implement compile.sh"
echo "Args: $*"
