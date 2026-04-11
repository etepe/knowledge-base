# Prompt — Kaynak Alımı (Ingest)

**Amaç:** Yeni bir ham kaynağı (makale, rapor, not, transkript) sisteme alırken
ilk triage'i yapmak: özet çıkarmak, domain belirlemek, potansiyel wiki başlıkları
önermek.

## Girdi

- `{{source_path}}`: `raw/.../dosya` yolu
- `{{source_content}}`: kaynağın tam/kısmi içeriği
- `{{known_domains}}`: `[fetm, hmm-crypto, geopolitical]`

## Talimatlar

1. Kaynağı oku ve 3-5 cümlelik özet çıkar.
2. Hangi domain(ler)e ait olduğunu belirle (birden fazla olabilir).
3. Öne çıkan 5-10 kavram/terim listele.
4. Bu kaynaktan türetilebilecek 1-3 wiki makalesi başlığı öner (slug formatında).
5. Bilinen wiki makaleleriyle potansiyel bağlantıları belirt.

## Çıktı Formatı

```
## Özet
<3-5 cümle>

## Domain
- primary: <domain>
- secondary: [<domain>, ...]

## Anahtar Kavramlar
- <terim>

## Önerilen Wiki Makaleleri
- wiki/<domain>/<slug>.md — <kısa gerekçe>

## Bağlantılar
- <mevcut wiki dosyası> ile ilişki: <açıklama>
```
