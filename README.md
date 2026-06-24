# 🤖 Turkmen Gold Sniper Scalper v16.30 (MQL5)

![XAUUSD](https://img.shields.io/badge/Asset-XAUUSD%20(Gold)-gold?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-blue?style=for-the-badge)
![Strategy](https://img.shields.io/badge/Strategy-Martingale%20Grid-red?style=for-the-badge)

**Turkmen Gold Sniper Scalper** is a high-frequency trading (HFT) Expert Advisor (EA) designed specifically for the Gold (XAUUSD) market. It combines **Dynamic RSI/ADX filters** with a sophisticated **Martingale Grid** system, optimized for small accounts (starting from $20).

---

## 🚀 Key Features

*   **⚡ 3-Stage Multi-TP:** Instead of one target, the bot splits the initial entry into 3 positions with different profit targets to maximize gain in volatile moves.
*   **🧠 Dynamic RSI Logic:** Automatically adjusts entry sensitivity based on market volatility (ADX). It's aggressive in ranging markets and conservative during trends.
*   **📏 ATR-Based Grid:** No fixed distances. The bot measures market "breath" using ATR and widens the grid steps during high volatility to prevent "blown accounts."
*   **🛡️ Smart Protection:** 
    *   **Equity Guard:** Hard stop-loss based on percentage of balance.
    *   **Margin Check:** Prevents opening new levels if the account margin is too low.
    *   **News Filter & Session Control:** Option to stop trading during high-impact news or outside of London/New York sessions.
*   **📈 Smart Trailing:** A trailing take-profit that locks in gains if the price suddenly spikes in your favor.

---

## 🛠 Trading Strategy

1.  **Market Analysis:** The bot uses a 3-layer filter (EMA 13/34 on M5 and EMA 200 on H1) to determine the trend direction.
2.  **Entry:** Enters a trade when RSI reaches oversold/overbought levels *only if* the trend matches.
3.  **Grid Management:** If the price moves against the trade, it opens calculated levels using a **1.6x Multiplier** (customizable) to average the price.
4.  **Exit:** Closes the entire basket when the weighted average profit reaches the target (default: 40 points).

---

## ⚙️ Input Parameters

| Category | Parameter | Default Value | Description |
| :--- | :--- | :--- | :--- |
| **Volume** | `AutoLot` | `True` | Scales lot size based on balance. |
| | `AutoLotStep` | `$60.0` | Adds 0.01 lot for every $60. |
| **Grid** | `MaxGridLevels` | `8` | Maximum levels to open in one direction. |
| | `LotMultiplier` | `1.6` | Geometric growth for recovery trades. |
| **Signal** | `UseDynamicRsi` | `True` | Changes RSI limits based on ADX. |
| **Risk** | `BasketSL_USD` | `$5.00` | Hard dollar stop-loss per basket. |
| | `MaxDrawdown%` | `95.0%` | Emergency account protection. |

---

## 📥 Installation

1.  Download the `Gold_Sniper_Scalper.mq5` file.
2.  Open your **MetaTrader 5** terminal.
3.  Go to `File > Open Data Folder`.
4.  Navigate to `MQL5 > Experts`.
5.  Paste the file here.
6.  Restart MT5, drag the bot onto an **XAUUSD M5** chart.
7.  **Enable Algo Trading** in the top toolbar.

---

## ⚠️ Risk Disclaimer

Trading Forex and Gold carries a high level of risk. The Martingale strategy can result in the total loss of your deposit if not managed with strict risk settings. **Never trade with money you cannot afford to lose.**

---

## 👤 Author
**Abdyleziz Sopyyev**
Full-Stack & MQL5 Developer based in Ashgabat, Turkmenistan.

[![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?style=flat-square&logo=telegram&logoColor=white)](https://t.me/S_EZIZ) [![Upwork](https://img.shields.io/badge/Upwork-6FDA44?style=flat-square&logo=upwork&logoColor=white)](https://www.upwork.com/freelancers/~01f661b192d926ede0)

***
