# Prompt — Q&A Cevabını Wiki'ye File Etme

Kullanıcı, aşağıdaki soruya verilen cevabı wiki'ye kalıcı olarak eklemek
istiyor. Cevabı uygun bir `wiki/<domain>/` altına gerçek bir makale haline
getir.

## Girdi

### Soru

{soru}

### Q&A Cevabı

{cevap}

### Mevcut Wiki İndeksleri

{current_indexes}

### Tarih

{tarih}

## Talimatlar

1. Cevabın hangi domain'e ait olduğunu belirle (indekslerden ve içerikten).
   Belirsizse, en iyi eşleşen domain'i seç.

2. Uygun bir dosya adı üret: `wiki/<domain>/<konsept-slug>.md`.
   - Eğer mevcut indeksteki `[ ] <dosya>.md` placeholder'larından biriyle
     örtüşüyorsa onu kullan.
   - Yeni bir konsept ise kısa, ASCII, dash'li bir slug üret.

3. **Eğer aynı dosya zaten varsa:** yeni bilgiyi mevcut makaleye entegre et
   (dup etme, çelişki varsa ikisini de göster). Frontmatter'daki `updated`
   alanını `{tarih}` yap.

4. **Eğer dosya yoksa:** aşağıdaki şablonla yeni makale oluştur:

   ```
   ---
   title: <Konsept Adı>
   domain: <domain>
   sources:
     - qa: outputs/reports/qa-<tarih>-<slug>.md
   created: {tarih}
   updated: {tarih}
   related: []
   ---

   # <Konsept Adı>

   <Q&A cevabından türetilmiş markdown içerik. [[wikilink]] referanslarını
   koru. "kaynakta yok" veya belirsizlik notları varsa ilgili bölümlere
   işaret olarak bırak.>

   ## Kaynaklar
   - Q&A: `outputs/reports/qa-<tarih>-<slug>.md`
   - <varsa mevcut wiki makaleleri, [[wikilink]] ile>

   ## İlgili Konular
   - <ilgili makaleler, varsa>
   ```

5. **Domain `_index.md` güncellemesi:**
   - Yeni makaleyi "Makaleler" listesine ekle (varsa `[ ]`'i `[x]` yap;
     yoksa yeni satır ekle).
   - Başka hiçbir bölümü silme / yeniden yazma.

6. **Ana `wiki/_index.md` güncellemesi:**
   - "Son Güncellenen Makaleler" tablosuna bir satır ekle:
     `| {tarih} | <domain> | [<başlık>](./<domain>/<dosya>.md) |`
   - Placeholder satırı (`| — | — | — |`) varsa onu kaldır.

7. **Glossary:** Eğer cevap yeni bir terim tanıtıyorsa `wiki/_glossary.md`
   tablosuna tek satır ekle. Zorunlu değil.

8. Başka hiçbir dosyayı değiştirme. Raw/ altına dokunma.

## Çıktı

Yaptığın değişikliklerin kısa bir özetini (hangi dosyalar yazıldı/
güncellendi) metin olarak döndür. Dosya yazma işlemleri için Edit/Write
araçlarını kullan.
