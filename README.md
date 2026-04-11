# Knowledge Base

LLM destekli, çok-alanlı kişisel bilgi tabanı. Ham kaynaklar tek yerde
saklanır, LLM tarafından derlenen wiki versiyon kontrol altındadır ve sorgular
üzerinden raporlar/slaytlar üretilir.

## Felsefe

- **raw/** dokunulmaz. Ham kaynaklar burada yaşar; asla yeniden yazılmaz.
- **wiki/** LLM tarafından yönetilir. Derleme, güncelleme ve lint işlemleri
  prompt şablonlarıyla yapılır.
- **outputs/** tüketilebilir çıktıları (rapor, slayt, görselleştirme) tutar.
- **scripts/** ince yardımcı araçlardır; iş mantığı prompt'larda yaşar.
- **prompts/** LLM'e verilecek yönergelerin kaynak gerçeğidir.

Akış:

```
raw/  ──►  prompts/ingest.md   ──►  triage notu
raw/  ──►  prompts/compile.md  ──►  wiki/<domain>/<slug>.md
wiki/ ──►  prompts/qa.md       ──►  outputs/reports/<tarih>-<konu>.md
wiki/ ──►  prompts/lint.md     ──►  tutarlılık raporu
```

## Dizin Yapısı

```
knowledge-base/
├── raw/                 # Ham kaynaklar (dokunulmaz)
│   ├── fetm/
│   ├── hmm-crypto/
│   ├── geopolitical/
│   └── general/
├── wiki/                # LLM tarafından üretilen/yönetilen wiki
│   ├── _index.md        # Ana indeks
│   ├── _glossary.md     # Terimler sözlüğü
│   ├── fetm/
│   ├── hmm-crypto/
│   ├── geopolitical/
│   └── connections/     # Cross-domain köprü makaleler
├── outputs/             # Sorgu çıktıları
│   ├── reports/
│   ├── slides/
│   └── visualizations/
├── scripts/             # Yardımcı araçlar
│   ├── ingest.sh
│   ├── compile.sh
│   ├── lint.sh
│   └── search.py
├── prompts/             # Claude Code / LLM prompt şablonları
│   ├── compile.md
│   ├── qa.md
│   ├── lint.md
│   └── ingest.md
├── .kb-config.yaml      # Konfigürasyon
├── .gitignore
└── README.md
```

## Domainler

- **fetm** — FETM (Filtered Exponential Trend Momentum) stratejisi; rejim
  filtreleme, FET volatilite, MACD-V vb.
- **hmm-crypto** — Gizli Markov Modelleri ve kripto piyasalarına uygulanışı.
- **geopolitical** — Enerji akışları, çokpoint analizleri, jeopolitik risk.

Yeni domain eklemek için `.kb-config.yaml` içine kaydını ekle, ardından
`raw/<domain>/` ve `wiki/<domain>/_index.md` dosyalarını oluştur.

## Hızlı Başlangıç

```bash
# 1) Yeni bir kaynağı ekle
./scripts/ingest.sh fetm /tmp/yeni-makale.pdf

# 2) Kaynaktan bir wiki makalesi derle
./scripts/compile.sh fetm regime-filtering

# 3) Wiki'yi denetle
./scripts/lint.sh

# 4) Wiki içinde ara
./scripts/search.py "rejim tespiti" --domain fetm
```

> Not: Scriptler şu an stub seviyesindedir. İş mantığı, `prompts/` altındaki
> şablonlarla birlikte ileride doldurulacaktır.

## .gitignore Kuralı

- `raw/` altındaki büyük/binary dosyalar (pdf, csv, parquet, video, resim…)
  git'e girmez.
- Ancak `raw/**/*.md`, `raw/**/*.txt`, `raw/**/*.yaml` gibi meta dosyalar dahildir.
- `wiki/` ve `outputs/` her zaman izlenir.

## Katkı Akışı

1. `raw/` altına yeni kaynakları yerleştir.
2. `prompts/ingest.md` ile triage yap, domain'i belirle.
3. `prompts/compile.md` ile wiki makalesini üret.
4. `prompts/lint.md` ile tutarlılığı kontrol et.
5. `_glossary.md` ve ilgili `_index.md` dosyalarını güncelle.
6. Commit → push.
