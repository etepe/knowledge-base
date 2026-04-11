# Knowledge Base — Ana İndeks

> LLM destekli kişisel bilgi tabanı. Ham kaynaklardan derlenen, alanlar arası
> bağlantılar kurulan ve sorgulanabilir bir wiki.

**Son güncelleme:** _henüz içerik yok_

---

## Domainler

- [FETM Stratejisi](./fetm/_index.md) — rejim filtreleme, FET volatilite, MACD-V vb.
- [HMM-Crypto](./hmm-crypto/_index.md) — gizli Markov modelleri, kripto piyasa durumları.
- [Jeopolitik & Enerji](./geopolitical/_index.md) — çokpoint analizleri, enerji akışları.
- [Cross-Domain Connections](./connections/) — domainler arası köprü makaleler.

## Yardımcı Kaynaklar

- [Terimler Sözlüğü](./_glossary.md)

## Son Güncellenen Makaleler

_(derleme sonrası otomatik güncellenecek)_

| Tarih | Domain | Başlık |
|-------|--------|--------|
| —     | —      | —      |

## Nasıl Katkı Sağlanır

1. Yeni ham kaynakları `raw/<domain>/` altına yerleştir.
2. `scripts/ingest.sh` ile triage yap.
3. `scripts/compile.sh` + `prompts/compile.md` ile wiki makalesi üret.
4. `scripts/lint.sh` ile tutarlılığı kontrol et.
5. Değişiklikleri commit'le.
