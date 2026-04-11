# `_manifest.json` — Şema Tanımı

Her `raw/<domain>/` dizini altında opsiyonel bir `_manifest.json` dosyası
bulunabilir. Bu dosya, `scripts/compile.sh` için hangi kaynakların
derlenmeye hazır olduğunu belirtir ve derleme sonrası durumu izler.

## Konum

```
raw/<domain>/_manifest.json
```

Bir domain manifest'i yoksa, `compile.sh` o domain'i uyarı ile atlar.

## Kök Şema

```json
{
  "domain": "fetm",
  "sources": [ { ... } ]
}
```

| Alan      | Tip      | Zorunlu | Açıklama                                         |
|-----------|----------|---------|--------------------------------------------------|
| `domain`  | string   | evet    | Bu manifest'in ait olduğu domain adı.            |
| `sources` | object[] | evet    | Kaynak kayıtlarının listesi (boş olabilir).      |

## Kaynak Kaydı

```json
{
  "filename": "regime-paper.md",
  "status": "pending_compile",
  "source_type": "article",
  "added_at": "2026-04-11",
  "compiled_at": null,
  "summary": "",
  "key_concepts": [],
  "notes": ""
}
```

| Alan           | Tip       | Zorunlu | Açıklama                                                                                   |
|----------------|-----------|---------|--------------------------------------------------------------------------------------------|
| `filename`     | string    | evet    | `raw/<domain>/` altındaki dosya adı (göreli, alt dizin içerebilir).                        |
| `status`       | string    | evet    | Lifecycle durumu. İzinli değerler aşağıda.                                                 |
| `source_type`  | string    | hayır   | Örn. `article`, `book`, `paper`, `transcript`, `note`, `report`.                           |
| `added_at`     | string    | evet    | `YYYY-MM-DD`. Kaynağın manifest'e eklendiği tarih.                                         |
| `compiled_at`  | string?   | hayır   | `YYYY-MM-DD` veya `null`. Başarılı derleme sonrası script tarafından doldurulur.           |
| `summary`      | string    | hayır   | Kısa özet. `ingest.sh` veya elle doldurulur.                                               |
| `key_concepts` | string[]  | hayır   | Anahtar kavram/terimler.                                                                   |
| `notes`        | string    | hayır   | Serbest not.                                                                               |

## `status` — İzinli Değerler

- **`pending_compile`** — Derleme bekliyor. `compile.sh` bu durumdaki kayıtları
  hedef alır.
- **`compiled`** — Başarıyla derlendi. `compile.sh` otomatik olarak bu değere
  çeker ve `compiled_at`'i günün tarihiyle doldurur.
- **`failed`** — Son derleme denemesi hata verdi. **Otomatik yeniden denenmez.**
  Yeniden denemek için elle `pending_compile`'a çekilmesi gerekir. Hata
  ayrıntıları `outputs/compile-log-<tarih>.md` içindedir.
- **`skip`** — Kullanıcı bu kaynağı derlemeden hariç tutmak istiyor. Script
  dokunmaz.

### Geçiş Kuralları

```
pending_compile ──(başarı)──▶ compiled
pending_compile ──(hata)────▶ failed
failed ──(elle)─────────────▶ pending_compile   (yeniden deneme için)
* ──(elle)──────────────────▶ skip              (hariç tut)
```

## Tam Örnek

```json
{
  "domain": "fetm",
  "sources": [
    {
      "filename": "regime-paper-2024.md",
      "status": "pending_compile",
      "source_type": "paper",
      "added_at": "2026-04-10",
      "compiled_at": null,
      "summary": "Rejim filtreleme yaklaşımı ve FET volatilite ilişkisi.",
      "key_concepts": ["regime filtering", "FET volatility", "MACD-V"],
      "notes": "Öncelikli — fetm domain'inin ilk makalesi olacak."
    },
    {
      "filename": "eski-notlar.md",
      "status": "compiled",
      "source_type": "note",
      "added_at": "2026-04-05",
      "compiled_at": "2026-04-08",
      "summary": "Eski el notları, rejim tespiti üzerine.",
      "key_concepts": ["regime detection"],
      "notes": ""
    }
  ]
}
```

## Script ile Etkileşim

- `scripts/compile.sh`:
  - Sadece `status == "pending_compile"` kayıtlarını işler.
  - Başarı → `status = "compiled"`, `compiled_at = <bugün>`.
  - Hata → `status = "failed"` (otomatik yeniden denenmez).
  - Manifest güncellemeleri `jq` + `tmpfile + mv` ile atomik yapılır.

- `scripts/ingest.sh` (gelecek):
  - Yeni kayıtları `pending_compile` statüsüyle manifest'e ekleyecek,
    `summary` ve `key_concepts` alanlarını dolduracak.
