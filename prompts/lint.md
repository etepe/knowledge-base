# Prompt — Wiki Sağlık Kontrolü

**Rol:** Sen bir bilgi tabanı denetçisisin. Aşağıda verilen tüm wiki
içeriğini okuyup kapsamlı bir sağlık raporu üretmekle görevlisin.

## Amaç

`wiki/` içindeki tüm dosyaları tarayarak kırık linkleri, içerik
tutarsızlıklarını, yetim makaleleri, eksik metadata'yı, duplicate'leri
ve keşfedilmemiş bağlantıları rapor et.

## Tüm Wiki İçeriği

{tum_wiki_dosyalari_ve_icerik}

## Kontrol Listesi

1. **KIRIK LİNKLER:** Tüm `[[wikilink]]` ve `[metin](./göreli.md)`
   referanslarını kontrol et. Hedef dosya yoksa raporla. Hedef dosya
   içindeki anchor (`#başlık`) yoksa da raporla.
2. **TUTARSIZLIKLAR:** Aynı kavramın farklı makalelerde çelişen
   tanımlarını tespit et (terim sözlüğü vs. makale içi tanım; iki farklı
   makaledeki aynı kavram için uyumsuz açıklamalar).
3. **YETİM MAKALELER:** Hiçbir `_index.md`, başka bir makale veya
   `wiki/_glossary.md`'den link verilmeyen makaleler.
4. **EKSİK VERİ:** Frontmatter'da boş alanlar (`title:`, `domain:`,
   `created:`, `updated:` boş/eksik), `sources` dizisi boş veya eksik
   makaleler, sözlükte tanımı eksik terimler.
5. **DUPLICATE:** Aynı konuyu anlatan birden fazla makale (başlık veya
   içerik örtüşmesi yüksekse).
6. **ÖNERİLER:** Mevcut makalelerden çıkarılabilecek ama henüz yazılmamış
   potansiyel yeni makale konuları (örn. bir makalede sık geçen ama
   kendi sayfası olmayan bir alt kavram).
7. **CROSS-DOMAIN:** Farklı domain'ler arası keşfedilmemiş bağlantılar
   (örn: FETM regime detection ↔ HMM-Crypto regime detection,
   geopolitical risk ↔ kripto piyasa rejimleri gibi).

## Çıktı Talimatı

Çıktıyı, `Write` aracını kullanarak **doğrudan**
`outputs/lint-report-{tarih}.md` dosyasına yaz. Dosya zaten varsa üzerine
yaz. Rapor formatı aşağıdaki gibi olmalı; her bulgu için **severity
(high/medium/low)** ve **önerilen aksiyon** zorunludur.

### Rapor Formatı

```
# Wiki Sağlık Raporu — {tarih}

## Özet
- Toplam bulgu: N (high: X, medium: Y, low: Z)
- Taranan dosya sayısı: ...
- Genel durum: <1-2 cümle özet>

## 1. Kırık Linkler
### [HIGH] <kısa başlık>
- Konum: `wiki/<domain>/<dosya>.md` → `[[hedef]]`
- Sorun: Hedef dosya mevcut değil.
- Önerilen Aksiyon: `wiki/<domain>/<hedef>.md` oluşturulmalı veya link kaldırılmalı.

_Bulgu yoksa:_ `_Bulgu yok._`

## 2. Tutarsızlıklar
### [MEDIUM] <kısa başlık>
- Konum: `wiki/<a>.md` vs `wiki/<b>.md`
- Sorun: ...
- Önerilen Aksiyon: ...

## 3. Yetim Makaleler
### [LOW] <dosya adı>
- Konum: `wiki/<domain>/<dosya>.md`
- Sorun: Hiçbir index veya makaleden link verilmemiş.
- Önerilen Aksiyon: `wiki/<domain>/_index.md`'e ekle.

## 4. Eksik Veri
### [MEDIUM] <dosya adı>
- Konum: `wiki/<domain>/<dosya>.md`
- Sorun: `sources:` dizisi boş.
- Önerilen Aksiyon: İlgili raw kaynaklarını ekle.

## 5. Duplicate Makaleler
### [HIGH|MEDIUM] <konu>
- Konum: `wiki/<a>.md` ve `wiki/<b>.md`
- Sorun: Aynı konu iki farklı dosyada işlenmiş.
- Önerilen Aksiyon: Birleştir veya birini diğerine referans yap.

## 6. Yeni Makale Önerileri
### [LOW] <önerilen başlık>
- Kaynak: Hangi mevcut makalelerde değiniliyor?
- Gerekçe: Neden ayrı bir makale olmalı?
- Önerilen Aksiyon: `wiki/<domain>/<slug>.md` olarak oluştur.

## 7. Cross-Domain Bağlantı Önerileri
### [LOW] <bağlantı başlığı>
- Domainler: `<domain-a>` ↔ `<domain-b>`
- Sorun: İki domain'de benzer kavramlar var ama aralarında link yok.
- Önerilen Aksiyon: `wiki/connections/<slug>.md` oluştur veya ilgili
  makalelere karşılıklı wikilink ekle.
```

Bir bölümde hiç bulgu yoksa, o bölümün altına tek satır olarak
`_Bulgu yok._` yaz. Severity etiketleri MUTLAKA `[HIGH]`, `[MEDIUM]` veya
`[LOW]` formatında olmalı. Önerilen aksiyon somut ve uygulanabilir olmalı
(hangi dosya, hangi alan).
