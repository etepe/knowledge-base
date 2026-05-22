---
title: "MACD-V: Volatility Normalised Momentum"
authors: ["Alex Spiroglou"]
year: 2022
draft_date: 2022-05-04
source_type: paper
source_url: "https://www.naaim.org/wp-content/uploads/2022/05/MACD-V-Alex-Spiroglou-WEB.pdf"
award: "NAAIM Founders Award 2022"
pages: 43
attachment: "macd-v-spiroglou-2022.pdf"
domain: fetm
status: pending_compile
added_at: 2026-05-22
key_concepts:
  - MACD-V
  - volatility normalization
  - ATR(26)
  - PPO
  - momentum lifecycle roadmap
  - trend regime filter
  - range rules
  - swing filters
  - MACD-VH
tags:
  - "#fetm"
  - "#momentum"
  - "#volatility"
  - "#paper"
---

# MACD-V: Volatility Normalised Momentum — Spiroglou (2022)

PDF: [[macd-v-spiroglou-2022.pdf]]
Kaynak: https://www.naaim.org/wp-content/uploads/2022/05/MACD-V-Alex-Spiroglou-WEB.pdf
Ödül: **NAAIM Founders Award 2022**

## Tek Cümle

Klasik MACD'nin zaman/piyasa arası karşılaştırılamazlık sorunu, MACD spread'inin
ATR(26) ile normalize edilip 100 ile çarpılmasıyla çözülür → **boundless ama
ölçekli** bir momentum osilatörü.

## Formül

```
MACD-V = [(EMA(12) - EMA(26)) / ATR(26)] * 100
```

ATR: Welles Wilder'ın Average True Range'i, 26-bar SMMA.
Yorum: "Ortalama volatilitesinin üstünde kalan momentum miktarı, yüzde olarak."

## Klasik MACD'nin 5 Kısıtı (Spiroglou'ya göre)

1. **Zaman boyunca**: 1957'de MACD max 1.56; 2019-21'de 86.31. Mukayese imkânsız.
2. **Piyasalar arası**: S&P 500 MACD = 65 vs EUR MACD = -0.007 → kıyaslanamaz.
3. **Momentum framework eksikliği**: "OBOS" ya da "strong/weak" tanımı yok.
4. **Signal line accuracy**: %0 (parametrik yön belirsizliği).
5. **Signal line timing**: gecikme.

PPO normalize ediyor ama fiyatla (`%` cinsinden), bu da volatiliteyi gizliyor
ve piyasalar arası kıyaslamayı yine kaybediyor.

## MACD-V Ranges (zaman/piyasa stabil)

| Range            | Pay (S&P 500 1975-2021) | Yorum                          |
|------------------|-------------------------|--------------------------------|
| `> 150`          | 4.4%                    | **Overbought** (extreme)       |
| `50 → 150`       | ~36%                    | Strong bullish momentum        |
| `-50 → 50`       | ~45%                    | Neutral / low momentum         |
| `-150 → -50`     | ~14%                    | Strong bearish momentum        |
| `< -150`         | 0.6%                    | **Oversold** (extreme)         |

Aynı eşikler Bund ve Natural Gas için de ~%95 datayı `±150` arasında tutuyor —
**farklı vol DNA'sına rağmen birleşik tanım**.

## Trend Regime Filter v.1 — Range Rules

Filter: `Close >` veya `< EMA(200)` (Bullish / Bearish Stage).

- **Bullish Stage**: tüm `>150` overbought okumaları burada; declines `MACD-V > -100`
  seviyesinde durur (data %99.4'ü). Yani bull market'te dip `-100`.
- **Bearish Stage**: tüm `<-150` oversold okumaları burada; rallies `MACD-V < 100`
  seviyesinde durur (%99.8). Yani bear market rally tavanı `+100`.

Aynı kurallar S&P 500 (1975-), Bund (1991-), Natural Gas (1991-) için tutuyor.
Bu Andrew Cardwell'in RSI range rules fikrinin MACD-V karşılığı.

## Diğer Bileşenler (4.4.3 - 6)

- **Trend Regime Filter v.2 + Swing Filters**: ATR-tabanlı swing line ile rejim
  alt-segmentasyonu (Spiroglou'nun tercihi % yerine ATR-swing).
- **Momentum Lifecycle RoadMap**: 4 evreli (accumulation → expansion → climax →
  contraction) genel çerçeve.
- **MACD-VH** = Signal Line - MACD-V (Volatility Normalised Histogram).
- Klasik araçlara uyarlamalar:
  - LBR 3/10 "Sardine" oscillator
  - Alex Elder Impulse "Plus" System
  - Dukascopy Diamond "Refined"
  - "77 & 70" System

## FETM Bağlamı

- `wiki/fetm/macd-v.md` placeholder'ının birincil kaynağı.
- **FETM = Filtered Exponential Trend Momentum** ⇒ MACD-V doğrudan **trend
  momentum** bileşeni; ATR-normalizasyonu ise [[fet-volatility-merrill-sinclair-2014]]
  ile felsefe paydaşı (her ikisi de "vol-aware" yaklaşım).
- 200-EMA rejim filtresi + MACD-V range rules, FETM'in "filtered" katmanına
  doğrudan adapte edilebilir.

## Açık Sorular / Wiki'ye Taşınacaklar

- [ ] Kripto piyasalarında `±150` eşiği hâlâ %95'i kapsıyor mu? (BTC, ETH,
      yüksek vol altcoinleri için ayrı kalibrasyon gerekir mi?)
- [ ] ATR(26) yerine farklı vol estimator (FET, realized, GARCH) ile değiştirme
      etkisi — [[fet-volatility-merrill-sinclair-2014]] ile köprü.
- [ ] HMM-tabanlı rejim filtresi ile MACD-V range rules birleşimi (cross-domain:
      [[hmm-crypto]]).
- [ ] Pine Script / Python referans implementasyonu (`outputs/` altında).
- [ ] MACD-VH'nin signal line crossover timing avantajı — backtest.

## Referans Kaynaklar (makaleden)

- Appel, G. *Technical Analysis: Power Tools for Active Investors*.
- DeMark, T. *The New Science of Technical Analysis*.
- Wilder, J. W. — ATR original.
- Aspray, T. (1986) — MACD Histogram.
- Cardwell, A. — RSI range rules.
