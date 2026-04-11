# Prompt — Wiki Makalesi Derleme

**Amaç:** `raw/<domain>/` altındaki ham kaynaklardan tek bir wiki makalesi üretmek.

## Girdi

- `{{domain}}`: hedef domain (ör. `fetm`)
- `{{slug}}`: üretilecek makalenin dosya adı (ör. `regime-filtering`)
- `{{sources}}`: ham kaynak dosyalarının içerikleri (metin/alıntı)
- `{{existing_wiki}}` (opsiyonel): daha önce yazılmış ilgili makaleler

## Talimatlar

1. Verilen ham kaynakları oku ve ana kavramları çıkar.
2. `wiki/{{domain}}/{{slug}}.md` dosyasını şu iskeletle üret:
   - Başlık (`# ...`)
   - Kısa özet (2-3 cümle)
   - Ana bölümler (kavram, formül, örnek, uygulama)
   - Kaynak atıfları (`raw/{{domain}}/...`)
   - "İlgili Makaleler" bölümü
3. Yeni/önemli terimleri `wiki/_glossary.md` için `GLOSSARY_UPDATES:` bloğunda listele.
4. Tonu: nesnel, teknik, Türkçe.

## Çıktı Formatı

```
---FILE: wiki/{{domain}}/{{slug}}.md---
<makale içeriği>

---GLOSSARY_UPDATES---
- <terim>: <tanım>
```
