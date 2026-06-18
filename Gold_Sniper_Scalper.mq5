//+------------------------------------------------------------------+
//|                                   Gold_Aggressive_Scalper_v18.00|
//|                           Copyright 2026, A Sopyyev              |
//|                AGRESİF EDİSYON - "PLASTİK ELDİVEN" MODÜLÜ        |
//|                     Version 18.00 - PRODUCTION READY             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, A Sopyyev"
#property link      ""
#property version   "18.00"
#property strict

#include <Trade\Trade.mqh>

//═══════════════════════════════════════════════════════════════════
//  AGRESİF AYARLAR (GÜNDE $30-$40 HEDEFLEYEN $50 HESAP İÇİN)
//═══════════════════════════════════════════════════════════════════

input group "════════ BOT MARKALAMA ════════"
string Input_BotTitle = "🏆 Gold Aggressive Scalper v18.00";

input group "════════ AGRESİF HFT VE GRID AYARLARI ════════"
input ENUM_TIMEFRAMES      Input_SignalTF          = PERIOD_M5;
input double               Input_InitialLot        = 0.03;            // $30-$40 hedefi için agresif 0.03 lot başlangıç
input int                  Input_MaxGridLevels     = 3;               // Agresif mod için maksimum 3 kademe (Sınır)
input int                  Input_GridStepPoints    = 350;             // Hızlı döngü için 350 Puan ($3.50 Altın adımı) mesafe

input group "════════ AGRESİF HEDEF VE STOP AYARLARI ════════"
input double Input_BasketTP_USD         = 2.00;                       // Hızlı döngü kâr hedefi ($2.00 kârda sepet kapanır)
input double Input_DailyProfitLimit_USD = 40.0;                       // Günlük agresif kâr hedefi
input int    Input_HardStopLossPoints   = 1100;                       // Maksimum 3. seviyeden sonra çalışacak mutlak koruma SL

input group "════════ PLASTİK ELDİVEN (TÜKENİŞ FİLTRESİ) ════════"
input double Input_MinWickRatio         = 0.50;                       // Mum gölgesinin muma oranı en az %50 olmalı (İğne filtre)
input int    Input_MaxAdxTrendLimit   = 40;                           // ADX sınırı
input int    Input_EMAFastPeriod      = 13;                           // Daha hızlı tepki için 13 EMA
input int    Input_EMASlowPeriod      = 34;                           // Daha hızlı tepki için 34 EMA
input int    Input_RSIPeriod          = 14;
input double Input_RSI_BullishEntry   = 40.0;                         
input double Input_RSI_BearishEntry   = 60.0;                         
input int    Input_ATR_Period         = 14;
input double Input_MinAtrPoints       = 30;                           

input group "════════ SEANS VE HABER KORUMALARI ════════"
input bool Input_UseNewsFilter       = true;                          
input int  Input_MinutesBeforeNews   = 15;                            // Agresif modda haber öncesi süreyi kısalttık
input int  Input_MinutesAfterNews    = 15;                            
input bool Input_UseSessionFilter    = true;                          
input int  Input_LondonOpenHour      = 7;                             
input int  Input_NYCloseHour         = 18;                            

input group "════════ GÜVENLİK SINIRLARI ════════"
input double Input_MinMarginLevelPct      = 350.0;                    // Kaldıraç sınırını agresif işlemler için esnettik
input double Input_MaxDrawdownPercent     = 70.0;                     // Hesabın yüksek riskle işlem yapabilmesi için esnetildi
input double Input_HardLotCap             = 0.06;                     
input ulong  Input_MagicNumber            = 99999;
input int    Input_SlippagePoints         = 30;
input int    Input_MaxSpreadPoints        = 40;                       

//═══════════════════════════════════════════════════════════════════
//  GLOBAL DEĞİŞKENLER
//═══════════════════════════════════════════════════════════════════

CTrade m_trade;

int g_rsiHandle      = INVALID_HANDLE;
int g_emaFastHandle  = INVALID_HANDLE;
int g_emaSlowHandle  = INVALID_HANDLE;
int g_emaMacroHandle = INVALID_HANDLE;
int g_adxHandle      = INVALID_HANDLE;
int g_atrHandle      = INVALID_HANDLE;

datetime g_LastBarTime = 0;
bool     g_Initialized = false;

int    g_buyCount  = 0,  g_sellCount  = 0;
double g_buyProfit = 0,  g_sellProfit = 0;
double g_lowestBuyPrice   = 999999.0;
double g_highestSellPrice = 0.0;
double g_lastBuyLot  = 0.0;
double g_lastSellLot = 0.0;

double g_CachedDailyProfit = 0.0;

//═══════════════════════════════════════════════════════════════════
//  YARDIMCI FONKSİYONLAR
//═══════════════════════════════════════════════════════════════════

datetime GetTodayStart()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   now.hour = 0; now.min = 0; now.sec = 0;
   return StructToTime(now);
}

bool IsActiveSession()
{
   if(!Input_UseSessionFilter) return true;
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;
   if(dt.day_of_week == 5 && h >= Input_NYCloseHour) return false;
   return (h >= Input_LondonOpenHour && h < Input_NYCloseHour);
}

bool IsNewsTime()
{
   if(!Input_UseNewsFilter)       return false;
   if(MQLInfoInteger(MQL_TESTER)) return false;

   datetime now   = TimeCurrent();
   datetime tFrom = now - (datetime)(Input_MinutesAfterNews  * 60);
   datetime tTo   = now + (datetime)(Input_MinutesBeforeNews * 60);

   MqlCalendarValue values[];
   int total = CalendarValueHistory(values, tFrom, tTo, "US");
   for(int i = 0; i < total; i++)
   {
      MqlCalendarEvent ev;
      if(CalendarEventById(values[i].event_id, ev))
         if(ev.importance == CALENDAR_IMPORTANCE_HIGH) return true;
   }
   return false;
}

double CalcDailyClosedProfit()
{
   datetime today = GetTodayStart();
   if(!HistorySelect(today, TimeCurrent())) return 0.0;
   double pnl = 0.0;
   int total  = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC)  != (long)Input_MagicNumber) continue;
      if(HistoryDealGetString (ticket, DEAL_SYMBOL) != _Symbol)                 continue;
      pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      pnl += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      pnl += HistoryDealGetDouble(ticket, DEAL_SWAP);
   }
   return pnl;
}

double NormalizeLot(double lot)
{
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step > 0)
   {
      lot = MathRound(lot / step) * step;
      int d = (int)MathRound(-MathLog10(step));
      if(d < 0) d = 0;
      lot = NormalizeDouble(lot, d);
   }
   if(lot < minLot)           lot = minLot;
   if(lot > maxLot)           lot = maxLot;
   if(lot > Input_HardLotCap) lot = Input_HardLotCap;
   return lot;
}

double GetCommissionForPosition(ulong positionId)
{
   double commission = 0.0;
   if(HistorySelectByPosition(positionId))
   {
      int n = HistoryDealsTotal();
      for(int i = 0; i < n; i++)
      {
         ulong dt = HistoryDealGetTicket(i);
         if(dt > 0) commission += HistoryDealGetDouble(dt, DEAL_COMMISSION);
      }
   }
   return commission;
}

void CalculateBasketStats()
{
   g_buyCount  = 0;  g_sellCount  = 0;
   g_buyProfit = 0;  g_sellProfit = 0;
   g_lowestBuyPrice   = 999999.0;
   g_highestSellPrice = 0.0;
   g_lastBuyLot  = 0.0;
   g_lastSellLot = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString (POSITION_SYMBOL) != _Symbol)                continue;
      if(PositionGetInteger(POSITION_MAGIC)  != (long)Input_MagicNumber) continue;

      double price  = PositionGetDouble (POSITION_PRICE_OPEN);
      double lot    = PositionGetDouble (POSITION_VOLUME);
      double profit = PositionGetDouble (POSITION_PROFIT)
                    + PositionGetDouble (POSITION_SWAP)
                    + GetCommissionForPosition((ulong)PositionGetInteger(POSITION_IDENTIFIER));
      long   type   = PositionGetInteger(POSITION_TYPE);

      if(type == POSITION_TYPE_BUY)
      {
         g_buyCount++;
         g_buyProfit += profit;
         if(price < g_lowestBuyPrice)  g_lowestBuyPrice  = price;
         if(lot   > g_lastBuyLot)      g_lastBuyLot      = lot;
      }
      else if(type == POSITION_TYPE_SELL)
      {
         g_sellCount++;
         g_sellProfit += profit;
         if(price > g_highestSellPrice) g_highestSellPrice = price;
         if(lot   > g_lastSellLot)      g_lastSellLot      = lot;
      }
   }
}

bool SendOrder(ENUM_POSITION_TYPE type, double lot)
{
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double price  = (type == POSITION_TYPE_BUY)
                   ? NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), digits)
                   : NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), digits);

   double hardSL = 0.0;
   if(type == POSITION_TYPE_BUY)
      hardSL = NormalizeDouble(price - Input_HardStopLossPoints * _Point, digits);
   else
      hardSL = NormalizeDouble(price + Input_HardStopLossPoints * _Point, digits);

   m_trade.SetExpertMagicNumber(Input_MagicNumber);
   m_trade.SetDeviationInPoints((ulong)Input_SlippagePoints);

   bool ok = (type == POSITION_TYPE_BUY)
             ? m_trade.Buy (lot, _Symbol, price, hardSL, 0, "Aggressive_v18")
             : m_trade.Sell(lot, _Symbol, price, hardSL, 0, "Aggressive_v18");

   if(ok)
      PrintFormat("🚀 Emir Gönderildi | %s | Lot: %.2f | Fiyat: %s | Sunucu SL: %s",
                  (type==POSITION_TYPE_BUY?"BUY":"SELL"), lot, DoubleToString(price,digits), DoubleToString(hardSL,digits));
   else
      PrintFormat("❌ Sipariş Hatası | Kod: %u | %s",
                  m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription());
   return ok;
}

void SyncHardStopLoss(ENUM_POSITION_TYPE type, double targetSL)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double cleanSL = NormalizeDouble(targetSL, digits);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString (POSITION_SYMBOL) != _Symbol)                continue;
      if(PositionGetInteger(POSITION_MAGIC)  != (long)Input_MagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)   != (long)type)              continue;

      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);

      if(MathAbs(currentSL - cleanSL) > _Point)
      {
         m_trade.PositionModify(ticket, cleanSL, currentTP);
      }
   }
}

void CloseAllPositions(ENUM_POSITION_TYPE type)
{
   for(int attempt = 1; attempt <= 5; attempt++)
   {
      bool anyOpen = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString (POSITION_SYMBOL) != _Symbol)                continue;
         if(PositionGetInteger(POSITION_MAGIC)  != (long)Input_MagicNumber) continue;
         if(PositionGetInteger(POSITION_TYPE)   != (long)type)              continue;
         anyOpen = true;
         m_trade.SetDeviationInPoints((ulong)(Input_SlippagePoints * attempt));
         if(m_trade.PositionClose(ticket)) anyOpen = false;
      }
      if(!anyOpen) break;
      uint t0 = GetTickCount();
      while(GetTickCount() - t0 < 100) { /* bekleme döngüsü */ }
   }
}

//═══════════════════════════════════════════════════════════════════
//  "PLASTİK ELDİVEN" (IĞNE KONTROL METODU)
//═══════════════════════════════════════════════════════════════════

bool CheckPlasticGlove(ENUM_POSITION_TYPE type)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, Input_SignalTF, 1, 1, rates) < 1) return false;

   double o = rates[0].open;
   double h = rates[0].high;
   double l = rates[0].low;
   double c = rates[0].close;

   double range = h - l;
   if(range <= 0) return false;

   // Alım sinyali için: Düşen bıçağı tutarken mumu aşağı itmişler ama fiyat yukarı çekilmiş olmalı (Alt gölge uzunluğu)
   if(type == POSITION_TYPE_BUY)
   {
      double lowerWick = MathMin(o, c) - l;
      double wickRatio = lowerWick / range;
      if(wickRatio >= Input_MinWickRatio)
      {
         PrintFormat("🧤 Plastik Eldiven Devrede | BUY Onaylandı | Alt İğne Oranı: %.2f (Hedef: %.2f)", wickRatio, Input_MinWickRatio);
         return true;
      }
   }
   // Satış sinyali için: Yükselen bıçağı tutarken mumu yukarı itmişler ama fiyat aşağı çekilmiş olmalı (Üst gölge uzunluğu)
   else if(type == POSITION_TYPE_SELL)
   {
      double upperWick = h - MathMax(o, c);
      double wickRatio = upperWick / range;
      if(wickRatio >= Input_MinWickRatio)
      {
         PrintFormat("🧤 Plastik Eldiven Devrede | SELL Onaylandı | Üst İğne Oranı: %.2f (Hedef: %.2f)", wickRatio, Input_MinWickRatio);
         return true;
      }
   }

   return false;
}

//═══════════════════════════════════════════════════════════════════
//  BİLGİ PANELİ
//═══════════════════════════════════════════════════════════════════

void DrawLabel(string name, string text, int x, int y, color clr)
{
   string obj = "GSS_Dash_" + name;
   if(ObjectFind(0, obj) < 0)
   {
      ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj, OBJPROP_CORNER,     CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, obj, OBJPROP_ANCHOR,     ANCHOR_RIGHT_LOWER);
      ObjectSetString (0, obj, OBJPROP_FONT,       "Consolas");
      ObjectSetInteger(0, obj, OBJPROP_FONTSIZE,   9);
      ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj, OBJPROP_HIDDEN,     true);
   }
   ObjectSetString (0, obj, OBJPROP_TEXT,      text);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_COLOR,     clr);
}

void UpdateDashboard()
{
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity      = AccountInfoDouble(ACCOUNT_EQUITY);
   double totalFloat  = g_buyProfit + g_sellProfit;
   double dynamicSL   = balance * (Input_MaxDrawdownPercent / 100.0);
   bool   inSession   = IsActiveSession();
   bool   newsLock    = IsNewsTime();

   double adxLive = 0, rsiLive = 0;
   double tmpBuf[];
   ArraySetAsSeries(tmpBuf, true);
   if(CopyBuffer(g_adxHandle, 0, 0, 1, tmpBuf) > 0) adxLive = tmpBuf[0];
   if(CopyBuffer(g_rsiHandle, 0, 0, 1, tmpBuf) > 0) rsiLive = tmpBuf[0];

   string status = inSession ? "AGRESIF AKTIF" : "SEANS DISI BEKLEMEDE";
   color  sc     = inSession ? C'0xFF,0x55,0x00' : C'0xFF,0xAA,0x00';

   if(newsLock)
      { status = "HABER BLOKAJI";         sc = C'0xFF,0xAA,0x00'; }
   if(marginLevel > 0 && marginLevel < Input_MinMarginLevelPct)
      { status = "KRITIK MARJIN UYARISI"; sc = C'0xFF,0x00,0x00'; }
   if(g_CachedDailyProfit >= Input_DailyProfitLimit_USD)
      { status = "GUNLUK HEDEF TAMAMLANDI"; sc = C'0x00,0xFF,0x00'; }
   if(totalFloat <= -dynamicSL)
      { status = "ACIL ACIL STOP AKTIF"; sc = C'0xFF,0x00,0x00'; }

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   string nextBT = (g_buyCount  > 0 && g_buyCount  < Input_MaxGridLevels)
      ? DoubleToString(g_lowestBuyPrice   - Input_GridStepPoints * _Point, digits) : "---";
   string nextST = (g_sellCount > 0 && g_sellCount < Input_MaxGridLevels)
      ? DoubleToString(g_highestSellPrice + Input_GridStepPoints * _Point, digits) : "---";

   color w = clrWhite, g = clrGold;

   DrawLabel("L14_Ind",    "  ▸ Live ADX: "  + DoubleToString(adxLive,1) +
                            "  |  Live RSI: " + DoubleToString(rsiLive,1),   15, 15,  clrLightGray);
   DrawLabel("L13_Daily",  "  ▸ Gunluk K/Z:         $" + DoubleToString(g_CachedDailyProfit,2) +
                            " / Hedef $" + DoubleToString(Input_DailyProfitLimit_USD,2),
                            15, 31, g_CachedDailyProfit >= Input_DailyProfitLimit_USD ? clrLime : w);
   DrawLabel("L12_Margin", "  ▸ Marjin Seviyesi:   " + (marginLevel>0 ? DoubleToString(marginLevel,1)+"%" : "LIMITSIZ"), 15, 47,  w);
   DrawLabel("L11_TotPnL", "  ▸ Anlik Yuzen K/Z:   $" + DoubleToString(totalFloat,2) +
                            "  | Acil DD Stop: -$" + DoubleToString(dynamicSL,1), 15, 63,  totalFloat>=0?clrLime:clrRed);
   DrawLabel("L10_SGrid",  "  ▸ SELL Kurtarma:     " + nextST, 15, 79,  clrTomato);
   DrawLabel("L9_BGrid",   "  ▸ BUY  Kurtarma:     " + nextBT, 15, 95,  clrAquamarine);
   DrawLabel("L8_SPnL",    "  ▸ SELL Sepet K/Z:    $" + DoubleToString(g_sellProfit,2) +
                            "  [" + IntegerToString(g_sellCount) + "/" + IntegerToString(Input_MaxGridLevels) + " Sev]", 15,111, w);
   DrawLabel("L7_BPnL",    "  ▸ BUY  Sepet K/Z:    $" + DoubleToString(g_buyProfit,2) +
                            "  [" + IntegerToString(g_buyCount)  + "/" + IntegerToString(Input_MaxGridLevels) + " Sev]", 15,127, w);
   DrawLabel("L6_TP",      "  ▸ Sepet Hedefi:      $" + DoubleToString(Input_BasketTP_USD,2), 15,143, clrLightGray);
   DrawLabel("L5_Equity",  "  ▸ Varlik (Equity):   $" + DoubleToString(equity,2),  15,159, w);
   DrawLabel("L4_Balance", "  ▸ Bakiye (Balance):  $" + DoubleToString(balance,2), 15,175, w);
   DrawLabel("L3_Status",  "  ▸ Durum:             " + status,                     15,195, sc);
   DrawLabel("L2_Title",   Input_BotTitle + " [HIGH RISK]",                         15,215, C'0xFF,0x33,0x00');
   Comment("");
}

void ClearDashboard()
{
   ObjectsDeleteAll(0, "GSS_Dash_");
   Comment("");
}

//═══════════════════════════════════════════════════════════════════
//  SEPET KONTROLÜ
//═══════════════════════════════════════════════════════════════════

void CheckBasketStatus()
{
   for(int dir = 0; dir < 2; dir++)
   {
      ENUM_POSITION_TYPE aType = (dir==0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      int    cnt  = (dir==0) ? g_buyCount  : g_sellCount;
      double net  = (dir==0) ? g_buyProfit : g_sellProfit;

      if(cnt > 0)
      {
         if(net >= Input_BasketTP_USD)
         {
            CloseAllPositions(aType);
            PrintFormat("💰 Agresif Sepet Hedefi ($%.2f) Yakalandı! | %s | Kâr: $%.2f", Input_BasketTP_USD, (dir==0?"BUY":"SELL"), net);
            return;
         }
      }
   }
}

//═══════════════════════════════════════════════════════════════════
//  ON INIT
//═══════════════════════════════════════════════════════════════════

int OnInit()
{
   PrintFormat("=== %s agresif sürüm başlatılıyor ===", Input_BotTitle);

   uint fill = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if     ((fill & SYMBOL_FILLING_FOK) != 0) m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((fill & SYMBOL_FILLING_IOC) != 0) m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else                                      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   g_rsiHandle      = iRSI (_Symbol, Input_SignalTF,  Input_RSIPeriod,     PRICE_CLOSE);
   g_emaFastHandle  = iMA  (_Symbol, Input_SignalTF,  Input_EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHandle  = iMA  (_Symbol, Input_SignalTF,  Input_EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_emaMacroHandle = iMA  (_Symbol, PERIOD_H1,       200,                 0, MODE_EMA, PRICE_CLOSE);
   g_adxHandle      = iADX (_Symbol, Input_SignalTF,  14);
   g_atrHandle      = iATR (_Symbol, Input_SignalTF,  Input_ATR_Period);

   if(g_rsiHandle==INVALID_HANDLE || g_emaFastHandle==INVALID_HANDLE ||
      g_emaSlowHandle==INVALID_HANDLE || g_emaMacroHandle==INVALID_HANDLE ||
      g_adxHandle==INVALID_HANDLE || g_atrHandle==INVALID_HANDLE)
   {
      Print("❌ İndikatörler yüklenemedi.");
      return INIT_FAILED;
   }

   g_Initialized = true;
   PrintFormat("⚠️ UYARI: Agresif Mod Aktif! Yüksek risk seviyesi algılandı.");
   return INIT_SUCCEEDED;
}

//═══════════════════════════════════════════════════════════════════
//  ON DEINIT
//═══════════════════════════════════════════════════════════════════

void OnDeinit(const int reason)
{
   ClearDashboard();
   if(g_rsiHandle      != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
   if(g_emaFastHandle  != INVALID_HANDLE) IndicatorRelease(g_emaFastHandle);
   if(g_emaSlowHandle  != INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle);
   if(g_emaMacroHandle != INVALID_HANDLE) IndicatorRelease(g_emaMacroHandle);
   if(g_adxHandle      != INVALID_HANDLE) IndicatorRelease(g_adxHandle);
   if(g_atrHandle      != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   PrintFormat("Agresif bot durduruldu. Kod: %d", reason);
}

//═══════════════════════════════════════════════════════════════════
//  ON TICK
//═══════════════════════════════════════════════════════════════════

void OnTick()
{
   if(!g_Initialized) return;

   CalculateBasketStats();
   g_CachedDailyProfit = CalcDailyClosedProfit();
   UpdateDashboard();

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(_Point <= 0) return;

   // Makas aralığı filtresi
   double currentSpread = (ask - bid) / _Point;
   if(currentSpread > Input_MaxSpreadPoints) return;

   // ── 1) AGRESİF ACİL STOP SİSTEMİ ──────────────────────────────
   double totalFloat = g_buyProfit + g_sellProfit;
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double dynSL      = balance * (Input_MaxDrawdownPercent / 100.0);

   if(totalFloat <= -dynSL)
   {
      CloseAllPositions(POSITION_TYPE_BUY);
      CloseAllPositions(POSITION_TYPE_SELL);
      PrintFormat("🚨 ACİL STOP TETİKLENDİ | Zarar: -$%.2f | Maksimum Tolere Edilen: -$%.2f", MathAbs(totalFloat), dynSL);
      return;
   }

   // ── 2) SEPET KÂR SORGULAMA ────────────────────────────────────
   CheckBasketStatus();

   // ── 3) GÜNLÜK HEDEF KORUMASI ──────────────────────────────────
   if(g_CachedDailyProfit >= Input_DailyProfitLimit_USD) return;

   // ── 4) MARJİN KONTROLÜ ────────────────────────────────────────
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   bool   canGrid     = (marginLevel <= 0 || marginLevel >= Input_MinMarginLevelPct);

   // ── 5) BAR TESPİTİ ────────────────────────────────────────────
   datetime barTime[];
   ArraySetAsSeries(barTime, true);
   if(CopyTime(_Symbol, Input_SignalTF, 0, 1, barTime) < 1) return;

   bool isNewBar    = (barTime[0] != g_LastBarTime);
   bool entryNewBar = isNewBar;

   if(isNewBar && (g_buyCount > 0 || g_sellCount > 0))
      entryNewBar = false; 

   // ── 6A) KURTARMA SEVİYESİ 1 & 2 (BUY GRID) ────────────────────
   if(g_buyCount > 0 && g_buyCount < Input_MaxGridLevels)
   {
      double trigger = g_lowestBuyPrice - Input_GridStepPoints * _Point;
      if(bid <= trigger)
      {
         if(canGrid && (g_lastBuyLot + 0.01) <= Input_HardLotCap)
         {
            // Agresif grid artışı
            double nextLot = NormalizeLot(g_lastBuyLot + 0.01); 
            if(SendOrder(POSITION_TYPE_BUY, nextLot))
            {
               int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
               double newTargetSL = NormalizeDouble(bid - (Input_HardStopLossPoints * 0.4) * _Point, digits);
               SyncHardStopLoss(POSITION_TYPE_BUY, newTargetSL);
            }
         }
      }
   }

   // ── 6B) KURTARMA SEVİYESİ 1 & 2 (SELL GRID) ───────────────────
   if(g_sellCount > 0 && g_sellCount < Input_MaxGridLevels)
   {
      double trigger = g_highestSellPrice + Input_GridStepPoints * _Point;
      if(ask >= trigger)
      {
         if(canGrid && (g_lastSellLot + 0.01) <= Input_HardLotCap)
         {
            // Agresif grid artışı
            double nextLot = NormalizeLot(g_lastSellLot + 0.01); 
            if(SendOrder(POSITION_TYPE_SELL, nextLot))
            {
               int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
               double newTargetSL = NormalizeDouble(ask + (Input_HardStopLossPoints * 0.4) * _Point, digits);
               SyncHardStopLoss(POSITION_TYPE_SELL, newTargetSL);
            }
         }
      }
   }

   // ── 7) PLASTİK ELDİVENLİ SNIPER GİRİŞİ (YENİ BARDA) ─────────────
   if(g_buyCount == 0 && g_sellCount == 0 && entryNewBar)
   {
      if(!IsActiveSession())  { g_LastBarTime = barTime[0]; return; }
      if(IsNewsTime())        { g_LastBarTime = barTime[0]; return; }

      double rsiV[], emaF[], emaS[], emaM[], adxV[], atrV[];
      ArraySetAsSeries(rsiV, true); ArraySetAsSeries(emaF, true);
      ArraySetAsSeries(emaS, true); ArraySetAsSeries(emaM, true);
      ArraySetAsSeries(adxV, true); ArraySetAsSeries(atrV, true);

      if(CopyBuffer(g_rsiHandle,      0, 1, 1, rsiV) < 1) return;
      if(CopyBuffer(g_emaFastHandle,  0, 1, 1, emaF) < 1) return;
      if(CopyBuffer(g_emaSlowHandle,  0, 1, 1, emaS) < 1) return;
      if(CopyBuffer(g_emaMacroHandle, 0, 1, 1, emaM) < 1) return;
      if(CopyBuffer(g_adxHandle,      0, 1, 1, adxV) < 1) return;
      if(CopyBuffer(g_atrHandle,      0, 1, 1, atrV) < 1) return;

      g_LastBarTime = barTime[0]; 

      double rsi = rsiV[0];
      double adx = adxV[0];
      double atr = atrV[0];

      if(atr < Input_MinAtrPoints * _Point) return;
      if(adx > Input_MaxAdxTrendLimit) return;

      double closeBar = 0.0;
      double closeBuf[];
      ArraySetAsSeries(closeBuf, true);
      if(CopyClose(_Symbol, Input_SignalTF, 1, 1, closeBuf) >= 1)
         closeBar = closeBuf[0];
      else
         return;

      // H1 Trend Filtresi
      bool localBull  = (emaF[0] > emaS[0]); 
      bool localBear  = (emaF[0] < emaS[0]); 
      bool macroBull  = (closeBar > emaM[0]);
      bool macroBear  = (closeBar < emaM[0]);

      // BUY Giriş (Plastik eldiven alt iğneyi kontrol eder)
      if(macroBull && localBull && rsi <= Input_RSI_BullishEntry)
      {
         if(CheckPlasticGlove(POSITION_TYPE_BUY))
         {
            SendOrder(POSITION_TYPE_BUY, NormalizeLot(Input_InitialLot));
         }
      }
      // SELL Giriş (Plastik eldiven üst iğneyi kontrol eder)
      else if(macroBear && localBear && rsi >= Input_RSI_BearishEntry)
      {
         if(CheckPlasticGlove(POSITION_TYPE_SELL))
         {
            SendOrder(POSITION_TYPE_SELL, NormalizeLot(Input_InitialLot));
         }
      }
   }
}
//+------------------------------------------------------------------+