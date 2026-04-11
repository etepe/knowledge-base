# Prompt — Wiki Tutarlılık Kontrolü

**Amaç:** `wiki/` içinde tutarlılık, bağlantı bütünlüğü ve terim kullanım
kontrolü yapmak.

## Girdi

- `{{wiki_tree}}`: tüm wiki dosya yollarının listesi
- `{{files}}`: incelenecek dosyaların içerikleri
- `{{glossary}}`: `wiki/_glossary.md` içeriği

## Kontrol Listesi

1. **Kırık bağlantılar:** `./...md` referansları var olan dosyalara işaret etmeli.
2. **Eksik terimler:** Makale içindeki teknik terimler sözlükte olmalı.
3. **Çoğalmış tanımlar:** Aynı terim farklı makalelerde çelişkili tanımlanmamalı.
4. **Orphan makale:** Hiçbir `_index.md`'den erişilemeyen makaleler.
5. **Stil:** Başlık seviyeleri (`#`, `##`) tutarlı, kaynak atıfları mevcut.

## Çıktı Formatı

```
## Bulgular
### Kritik
- <dosya>: <sorun>

### Uyarı
- <dosya>: <sorun>

## Öneriler
- <düzeltme önerisi>
```
