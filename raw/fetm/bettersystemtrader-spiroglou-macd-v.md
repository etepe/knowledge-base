---
title: The Volatility-Normalized MACD That Fixes Momentum Trading Signals — Alex Spiroglou (Better System Trader)
source_url: "https://bettersystemtrader.com/the-new-indicator-that-improves-momentum-trading-signals-alex-spiroglou/"
source_type: podcast
domain: fetm
status: pending_compile
added_at: 2026-05-22
tags:
  - #fetm
  - #momentum
  - #macd-v
  - #interview
---

# The Volatility-Normalized MACD That Fixes Momentum Trading Signals — Alex Spiroglou (Better System Trader)

Kaynak: https://bettersystemtrader.com/the-new-indicator-that-improves-momentum-trading-signals-alex-spiroglou/

> Not: Better System Trader podcast interview with Alex Spiroglou on MACD-V.

---

# The new indicator that improves momentum trading signals – Alex Spiroglou

By   [Andrew Swanscott](https://bettersystemtrader.com/author/aswanscotpg-com-au/ "View all posts by Andrew Swanscott")  /  June 13, 2024

Most traders who use momentum indicators have accepted a hidden limitation in their toolbox. The MACD – arguably the most widely used momentum indicator after RSI – carries a structural flaw that makes it unreliable across different markets and across time. When applied to the S&P 500 in 2023, its absolute readings mean something completely different than when applied to natural gas or a currency pair. You can’t set a single overbought level and use it everywhere. That’s not a minor inconvenience – it’s a fundamental problem that undermines systematic strategy building.

Alex, who won the CMT Association Charles Dow Award in 2022 for his research paper “MACD-V: Volatility Normalised MACD,” spent nearly a decade solving this problem. His solution – normalising the MACD by volatility rather than by price – creates a momentum indicator that is genuinely comparable across markets, across time, and across securities. The result is what he calls the MACD-V, and in this episode of Better System Trader, he walks through exactly how it works and why it matters for systematic traders.

If you’ve ever wondered why your MACD settings that work well on equities fall apart when you apply them to commodities, or why you can’t define a reliable overbought level that holds up over decades, this episode has the answer.

**Watch the full episode below, then read on for the complete breakdown.**

Table of Contents

[Toggle](#)

### **The Core Problem: Why Standard Momentum Indicators Fail**

Alex begins by constructing a clear taxonomy of momentum indicators. On one side you have range-bound indicators like RSI, Stochastics, and %B. These are normalised from 0 to 100, which means their values are comparable across time and across securities. An RSI reading of 60 in 1980 means roughly the same thing as an RSI reading of 60 in 2023. You can define overbought and oversold levels that apply universally.

On the other side are unbound indicators like MACD and Rate of Change. These don’t have a fixed scale – they move with the absolute price of the underlying instrument. This creates a major problem: the MACD on the S&P 500, now trading above 5,000 points, produces absolute readings that are incomparable to what it showed when the index was at 1,000. The indicator grows with the market, not with momentum. Worse, the same MACD settings on natural gas, which is measured in dollars per million BTUs, will produce readings that are numerically incomparable to the S&P version. You cannot define a single overbought level that applies to both markets.

Each category has the reverse set of problems. Range-bound indicators can’t adapt to sustained trends – they get “pinned” at extreme levels and generate false divergence signals. Unbound indicators adapt to trends well but can’t be standardised. Alex set out to get the best of both worlds.

### **Why Normalising by Price Doesn’t Fully Work**

The first approach Alex tested was normalising the MACD by price – essentially dividing the MACD by the longer moving average and expressing the result as a percentage. This is sometimes called the PPO (Percent Price Oscillator). It does solve the cross-time comparison problem partially.

But when Alex tested this across three very different asset classes – the S&P 500, natural gas, and German Bund fixed income – he found the overbought/oversold levels were still inconsistent. For the S&P 500, 95% of values fell within -2% and +2%. For the Bund, it was -0.7% to +0.7%. For natural gas, a wildly oscillating market, the range extended to -7% to +7%.

The percentage normalisation couldn’t account for the different volatility structures of different markets. A 5% move in Bitcoin is noise; a 5% move in sterling against the dollar is a Brexit-level event. Price normalisation didn’t solve the real underlying problem.

### **The Volatility Normalisation Breakthrough**

The insight was straightforward once Alex identified the root cause. The reason the PPO produced different overbought levels across markets wasn’t price – it was volatility. Each market has a different natural volatility profile, and the indicator needed to account for that.

The MACD-V formula divides the difference between the two exponential moving averages not by price but by the Average True Range (ATR) of the longer look-back period. Specifically:

*MACD-V = (EMA12 – EMA26) / ATR26 x 100*

When Alex applied this normalisation across the same three markets – S&P 500, natural gas, and German Bund – the overbought and oversold levels converged to the same values. The same thresholds that defined extreme momentum on equities also defined extreme momentum on commodities and fixed income. The indicator had become genuinely universal.

### **The Seven-Range Momentum Lifecycle Model**

One of the most practical outputs of the MACD-V is what Alex calls the “lifecycle roadmap” – a seven-range framework that tells you exactly which stage of the momentum cycle a market is in at any point. The ranges are defined by specific MACD-V threshold levels.

The key levels are:

* **Above +150:** The “risk” or “rallying strongly” range. Momentum is 1.5 times its own volatility. This is where strong trends live. Because the indicator is unbound, it can extend to 200, 250, even 300 in powerful trend environments – giving you a genuine read on how strong momentum really is.
* **+50 to +150:** Rallying range. Positive momentum but not at peak intensity.
* **-50 to +50 for 20+ bars:** The “ranging” definition. This is one of the most valuable features of the MACD-V – it provides a systematic, objective definition of a ranging market. If the indicator stays within these bounds for 20 bars, the market is ranging.
* **-50 to -150:** Reversing to the downside.
* **Below -150:** Strong downside momentum.

This lifecycle model gives systematic traders a consistent framework for defining market regimes that works the same way on every instrument they trade.

### **Using MACD-V as a Regime Filter (Not a Signal Generator)**

Alex is explicit about one key distinction: he does not use the MACD-V for signal generation. The standard 12-26 setting is intermediate-term momentum – too slow for entry signals. If you use the signal line crossover, by the time the crossover triggers after a momentum extreme, the market has often already reversed significantly.

What the MACD-V excels at is regime filtering – identifying which type of strategy should be active in current conditions. Some specific applications Alex uses:

* **Trend filter:** When the MACD-V crosses zero, it has approximately 96-98% correlation with price crossing the 50-bar moving average. This means you can use it as a trend filter without separately plotting a moving average.
* **Setup quality filter:** If you have a breakout strategy, you might restrict entry signals to times when the MACD-V is above +50 (in the rallying range) to filter for higher-quality trend environments.
* **Mean reversion filter:** Restrict mean-reversion entries to when the MACD-V is in the ranging range (within -50 to +50).
* **Trend-specific overbought/oversold levels:** Building on Andy Cardwell’s work on range rules, Alex found that MACD-V overbought/oversold levels are different when price is above versus below the 200-day moving average. This allows regime-specific threshold calibration.

### **Divergences and Pattern Recognition**

Because the MACD-V values are normalised and comparable over time, you can build systematic divergence signals. Alex describes labelling swing highs and swing lows on the MACD-V from right to left and comparing them with corresponding price swing highs and lows. A bearish divergence is defined as price making higher swing highs and higher swing lows while MACD-V makes lower swing highs and lower swing lows. This definition can be written as precise code and incorporated into back-tests.

This is impossible with the standard MACD because its values aren’t meaningful in absolute terms – you can’t define a divergence threshold that applies consistently. With the MACD-V, you can.

### **Alex’s Broader Multi-Timeframe Framework**

The MACD-V doesn’t exist in isolation. Alex uses it as one component of a multi-timeframe, multi-factor process that includes:

* **Monthly chart – Business cycle:** Based on Martin Pring’s six-stage model using bonds, stocks, and commodities as relative performance signals.
* **Weekly chart – Macro setup:** Commitment of Traders (COT) data, sentiment readings, seasonals, and business cycle positioning. This determines the macro backdrop but not trade entry.
* **Daily chart – Technical execution:** The “core four” of technical analysis: trend, momentum (where MACD-V lives), volatility, and relative strength.
* **Trade-level framework – The “4S”:** Setup, Signal, Stop, and Size. The MACD-V regime filter defines the setup conditions; a separate entry trigger (bar patterns, shorter-term oscillators) provides the signal; the stop is determined by the entry logic; position size is calculated to target a defined volatility contribution to the portfolio.

Alex points out explicitly that the MACD-V is not a holy grail. Fundamental factors – why markets should move – are the primary drivers. The MACD-V is a tool for understanding where you are in the momentum lifecycle and whether current conditions favour the type of strategy you want to run.

### **Extending Volatility Normalisation to Other Indicators**

The same normalisation technique applies to any unbound, absolute-price indicator. Alex has tested it on Rate of Change, the COPPOCK Curve, and the LBR 3-10 oscillator that Linda Raschke uses. He notes that Timothy Masters has also written about volatility normalisation in his books.

The MACD-V is now available on StockCharts, Metastock, and MT4, and was being programmed for TradingView at the time of recording. Alex has also published the MACDV histogram – normalising Alex Elder’s MACD histogram by the same ATR approach – with overbought/oversold levels at +40 and -40 for the standard 12-26 settings.

### Get the show notes & transcript

### **Related episodes**

* [A New, More Responsive Indicator with John Ehlers](https://bettersystemtrader.com/103-a-new-responsive-indicator-with-john-ehlers/)
* [The Magic of Momentum Trading with Alan Clement](https://bettersystemtrader.com/172-the-magic-of-momentum-trading-alan-clement/)
* [Linda Raschke on Trading Edges, Modelling Markets and Day Trading Techniques](https://bettersystemtrader.com/049-linda-raschke/)

---

**Want more on momentum trading and technical indicators?** Subscribe to the [Better System Trader](https://bettersystemtrader.com) podcast for weekly interviews with the world’s top systematic traders and quantitative researchers.
