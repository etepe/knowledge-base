---
title: "Volatility Estimation via First Exit Times"
authors: ["Chris Merrill", "Euan Sinclair"]
year: 2014
draft_date: 2014-12-15
source_type: paper
source_url: "https://ssrn.com/abstract=3904792"
ssrn_id: 3904792
pages: 8
attachment: "fet-volatility-merrill-sinclair-2014.pdf"
domain: fetm
status: pending_compile
added_at: 2026-05-22
key_concepts:
  - first exit time
  - FET volatility
  - barrier estimator
  - Brownian motion
  - Jensen bias correction
  - online volatility estimation
tags:
  - "#fetm"
  - "#volatility"
  - "#paper"
---

# Volatility Estimation via First Exit Times — Merrill & Sinclair (2014)

PDF: [[fet-volatility-merrill-sinclair-2014.pdf]]
SSRN: https://ssrn.com/abstract=3904792

## Özet

Volatilite tahmininde klasik yaklaşım, fiyatları sabit zaman aralıklarında
örnekleyip (close-to-close veya OHLC tabanlı) zaman serisi üzerinden istatistik
çıkarmaktır. Bu makale alternatif bir bakış sunar: **fiyat ne kadar uzağa gitti**
yerine **belirli bir mesafeyi ne kadar hızlı kat etti** sorusunu sorar.

Log-fiyat etrafına simetrik bir koridor `±Δ` çizilir; fiyat sınıra dokunduğunda
geçen süre `τᵢ` not edilir, koridor yeni fiyat etrafında resetlenir. Bu da
rastgele bir ilk-çıkış-süresi (first exit time) dizisi üretir.

Brownian motion varsayımı ve ihmal edilebilir drift altında:

$$E[\tau] = \frac{\Delta^2}{\sigma^2} \;\;\Rightarrow\;\; \sigma = \frac{\Delta}{\sqrt{E[\tau]}}$$

Naif tahmin `σ̂ = Δ / √τ̄` Jensen eşitsizliği nedeniyle yanlıdır. İkinci-mertebe
Taylor açılımıyla Bias-düzeltilmiş tahminci elde edilir; n=1 için 0.8, n=5 için
0.952, n=50 için 0.995 çarpanıyla yanlılık hızla yok olur (Tablo 1).

## Neden Önemli (FETM bağlamı)

- **`fet-volatility.md` wiki makalesinin birincil referansı.** Domain
  `_index.md` zaten bu placeholder'ı bekliyor.
- FETM stratejisinin "vol-aware" bileşenlerinin (rejim filtreleme + MACD-V)
  teorik tabanı: koridor-tabanlı tahminci, fiyat **hareket ettiğinde** hedge
  eden trader'ın doğal volatilite kavramıdır (Hodges & Neuberger, 1989).
- 0.30 vol, 0.01 koridor, 20-günlük yolda Monte Carlo karşılaştırması:
  barrier estimator std = 0.028, eş-bilgi close-to-close estimator std = 0.048.
  Yaklaşık **2× daha verimli**.

## Anahtar Formüller

| Konsept                          | İfade                                                  |
|----------------------------------|--------------------------------------------------------|
| Beklenen ilk çıkış süresi        | `E[τ] = Δ² / σ²`                                       |
| Volatilite tahmincisi            | `σ = Δ / √E[τ]`                                        |
| `τ` varyansı (Borodin-Salminen)  | `Var(τ) = (2Δ²)/(3σ²) = (2/3)·E[τ]²`                   |
| Jensen-düzeltilmiş tahminci      | `σ̂_corr = σ̂_naive · (1 + 1/(4n))⁻¹`                  |
| Tek-gözlem yanlılık çarpanı      | 0.8 (n=1) → 0.995 (n=50)                               |

## Kritik Alıntılar

> "Instead of asking, 'how far did the price move?' we will ask, 'how fast did
> the price move?'"

> "To achieve an optimal balance between transaction costs and risk a trader
> will hedge every time the underlying 'moves enough'. This is our Δ parameter."

## Açık Sorular / Wiki'ye Taşınacaklar

- [ ] Δ seçimi: kripto için tipik mesafe (`0.5%`, `1%`, ATR-oranlı?) — FETM
      parametrelendirmesi.
- [ ] Drift'in ihmal edilmediği rejimlerde sapma (cripto'da var).
- [ ] Bid-ask ve kesikli trading altında bias — makale §"An Example".
- [ ] Online güncelleme: barrier hits arası ekstrapolasyon formülü.
- [ ] MACD-V ile bağlantı: koridor-temelli vol, momentum normalizasyonunda
      kullanılabilir mi?

## Referanslar (makaleden)

- Borodin, A. & Salminen, P. (2002). *Handbook of Brownian Motion — Facts and
  Formulae.* Birkhäuser.
- Cho, D. & Frees, E. (1988). "Estimating the Volatility of Discrete Stock
  Prices." *Journal of Finance* 43, 451–466.
- Hodges, S. & Neuberger, A. (1989). "Optimal Replication of Contingent Claims
  Under Transaction Costs." *Review of Futures Markets* 8, 222–239.
- Poon, S. (2005). *A Practical Guide to Forecasting Financial Market
  Volatility.* Wiley.
