# Prompt — Wiki Soru-Cevap

**Amaç:** Kullanıcının sorusunu, yalnızca `wiki/` altındaki makaleleri referans
alarak yanıtlamak.

## Girdi

- `{{question}}`: kullanıcı sorusu
- `{{context}}`: ilgili wiki makalelerinin tam metni (üstte dosya yolu ile)
- `{{domain_hint}}` (opsiyonel): sorgunun hangi domain ile ilgili olduğu

## Talimatlar

1. Sadece `{{context}}` içindeki bilgileri kullan. Yoksa "kaynakta yok" de.
2. Yanıtı kısa, yapılandırılmış (madde veya 2-3 paragraf) ver.
3. Her iddia için kaynak olarak kullandığın wiki dosyasını `[wiki/...]` olarak göster.
4. Cross-domain bağlantıları not düş: "Bkz. [connections/...]".
5. Çelişki varsa her iki tarafı da göster.

## Çıktı Formatı

```
## Yanıt
<yapılandırılmış yanıt>

## Kaynaklar
- wiki/<domain>/<dosya>.md
```
