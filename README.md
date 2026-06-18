# 🏆 Gold Aggressive Scalper v18.00 - MT5

`Gold Aggressive Scalper v18.00` is an advanced, high-frequency algorithmic trading robot written in MQL5 for MetaTrader 5. It is specifically optimized to aggressively trade **XAUUSD (Gold)** on the M5 timeframe. 

The bot uses dynamic trend tracking, volume filters, and a specialized candlestick exhaustion filter nicknamed the **"Plastic Glove"** to scalp fast momentum reversals safely.

---

## 💡 How the Strategy Works

Instead of blindly taking reversals, the EA checks three layers of filter validation before executing any trade:

1. **Macro Trend Guard:** Built around the 200 Exponential Moving Average (EMA) on the H1 timeframe. The bot only opens BUY positions during structural bull markets and SELL positions during structural bear markets.
2. **Local Pullback Tracker:** Tracks the convergence of EMA 13 and EMA 34 on the M5 execution chart, combined with RSI oversold/overbought boundaries.
3. **The "Plastic Glove" (Wick Exhaustion Filter):** When a trend signal is triggered, the bot analyzes the wick structure of the last completed candle. To prevent catching a "falling knife", a BUY trade is only opened if the lower wick forms at least **50%** of the candle's total height, indicating that seller momentum has officially failed.

---

## ⚙️ Core Parameters

| Variable Group | Parameter | Default | Description |
| :--- | :--- | :--- | :--- |
| **BOT BRANDING** | `Input_BotTitle` | `🏆 Gold Aggressive Scalper v18.00` | Custom dashboard title displayed on the chart. |
| **HFT & GRID** | `Input_InitialLot` | `0.03` | Entry position size (highly aggressive for micro accounts). |
| | `Input_MaxGridLevels` | `3` | Maximum allowed positions per direction (1 entry + 2 recovery steps). |
| | `Input_GridStepPoints` | `350` | Spacing distance (points) before opening a recovery layer. |
| **TARGETS** | `Input_BasketTP_USD` | `$2.00` | Basket exit target in USD to secure profits fast. |
| | `Input_DailyProfitLimit_USD`| `$40.00` | Hard cap on daily profit; pauses EA when reached. |
| | `Input_HardStopLossPoints`| `1100` | Broker-side physical SL safety margin (points). |
| **PLASTIC GLOVE**| `Input_MinWickRatio` | `0.50` | Minimum wick-to-candle ratio (50% shadow required). |
| **SAFETY** | `Input_MaxDrawdownPercent`| `70.0%` | Hard equity limit to protect against catastrophic market events. |

---

## 🚀 Recommended Configuration

* **Symbol:** `XAUUSD` (Gold)
* **Timeframe:** `M5`
* **Account Type:** Hedging (highly recommended), tight spread (Raw/ECN), 1:500 leverage or higher.
* **Capital Requirements:** Designed for accounts between $50 and $100.

---

## ⚠️ Disclaimer

This trading algorithm operates with **extremely high leverage and aggression**. While the "Plastic Glove" and macro EMA filters are designed to filter out bad entries, trading Gold with small deposits carries an inherent risk of total capital loss. 

* **Use on a Demo Account first.**
* Never trade with capital you cannot afford to lose.
* Past performance does not guarantee future results.
