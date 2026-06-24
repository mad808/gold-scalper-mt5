//+------------------------------------------------------------------+
//|                                     Gold_Sniper_Scalper.mq5      |
//|                           Copyright 2026, A Sopyyev              |
//|                    Martingale Grid - $20 Min Deposit Edition      |
//|                    Version 16.30 - DYNAMIC RSI EDITION           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, A Sopyyev"
#property link      ""
#property version   "16.30"
#property strict

#include <Trade\Trade.mqh>

enum ENUM_LOT_PROGRESSION
{
   PROGRESSION_MULT = 0,   // Standart Çarpan Modu (Geometrik Artış)
   PROGRESSION_SAFE = 1    // Güvenli Mod (Doğrusal Artış)
};

//═══════════════════════════════════════════════════════════════════
//  GİRİŞ PARAMETRELERİ (PORTFÖY VE HACİM OPTİMİZASYONLARI)
//═══════════════════════════════════════════════════════════════════

input group "════════ SİSTEM KİMLİĞİ ════════"
string Input_BotTitle = "Turkmen Gold Scalper v16.30";

input group "════════ HACİM VE PORTFÖY AYARLARI ════════"
input ENUM_TIMEFRAMES      Input_SignalTF          = PERIOD_M5;
input bool                 Input_UseAutoLot        = true;            // Dinamik Hacim: Bakiye büyüdükçe lot oranını otomatik ayarlar
input double               Input_AutoLotStep_USD   = 60.0;            // Her 60$ bakiye artışında başlangıç lotunu 0.01 artırır
input double               Input_InitialLot        = 0.01;            // Dinamik Hacim kapalıyken kullanılacak sabit başlangıç lotu
input ENUM_LOT_PROGRESSION Input_LotProgression    = PROGRESSION_MULT; // Kademeli lot artış modeli (Çarpanlı)
input double               Input_LotMultiplier     = 1.6;             // Kademe lot çarpanı (1.6x)
input int                  Input_GridStepPoints    = 150;             // İki kademe arasındaki asgari mesafe (150 Puan = $1.50)
input int                  Input_MaxGridLevels     = 8;               // Tek bir yönde açılabilecek maksimum kademe sayısı (Maks 8)

input group "════════ HEDEF VE LİMİT AYARLARI ════════"
input bool   Input_UseMultiTP           = true;                       // Kademeli Kâr Al: İlk girişte 1 yerine 3 işlem açıp sırayla kapatır
input int    Input_MultiTP_StepPoints   = 30;                         // Kademeli TP Adımı: Her işlem arasındaki hedef farkı (Örn: 40, 70, 100 puan)
input bool   Input_UseSmartTrailing     = true;                       // AKILLI TP TAKİP: 40 puanı aşınca fiyat fırlarsa kârı izler, geri dönerse kapatır
input int    Input_TrailActivationPoints= 40;                         // Takip etmenin başlayacağı asgari kâr puanı
input int    Input_TrailStepPoints      = 15;                         // Geri çekilme toleransı (Puan bazında. En yüksek kârdan bu kadar düşerse kapatır)
input int    Input_BasketTP_Points      = 40;                         // Sepet maliyet ortalamasından kaç puan yukarıda kapatılacağı (MultiTP kapalıyken etkin)
input double Input_DailyProfitLimit_USD = 999999.0;                   // Günlük hedeflenen kâr limiti
input bool   Input_UseBasketTrailing    = false;                      
input double Input_BasketTrailFloor     = 0.20;

input group "════════ VOLATİLİTE VE TREND FİLTRELERİ ════════"
input bool   Input_UseDynamicAtrStep    = true;                       // Piyasa oynaklığına göre kademe aralıklarını dinamik genişletir
input double Input_AtrStepMultiplier    = 1.2;                        
input bool   Input_UseAdxFirstEntryFilter = false;                     // İlk giriş işleminde ADX trend gücü filtresini kullan
input bool   Input_UseAdxGridBlockFilter  = true;                      // Aşırı trend hareketlerinde yeni kademe eklemeyi durdurur (Önerilen)
input int    Input_MaxAdxTrendLimit     = 50;                         
input int    Input_GridAdxBlockLimit    = 55;                           

input group "════════ ZAMAN VE SEANS KONTROLLERİ ════════"
input bool Input_UseNewsFilter       = false;                         // Önemli ekonomik haber takvimini kontrol et
input int  Input_MinutesBeforeNews   = 15;                            
input int  Input_MinutesAfterNews    = 15;
input bool Input_UseSessionFilter    = false;                         // Seans saati kısıtlamasını etkinleştir
input int  Input_LondonOpenHour      = 7;                             
input int  Input_NYCloseHour         = 18;                            

input group "════════ SİNYAL VE GİRİŞ ALGORİTMASI ════════"
input bool   Input_UseRsiFilter         = true;                       // Giriş tutarlılığı için RSI filtresini kullan (Önerilen)
input bool   Input_UseDynamicRsi        = true;                       // DİNAMİK RSI: Sakin piyasada (ADX < 25) sınırları esnetir, ralli anında daraltır
input double Input_RSIOverbought        = 70.0;                       // Güçlü trendde (ADX >= 25) SELL için azami RSI sınırı
input double Input_RSIOversold          = 30.0;                       // Güçlü trendde (ADX >= 25) BUY için asgari RSI sınırı
input double Input_RsiOversold_Ranging  = 48.0;                       // Yatay/Sakin piyasada (ADX < 25) BUY için esnetilmiş RSI sınırı (Gevşek sinyal)
input double Input_RsiOverbought_Ranging = 52.0;                      // Yatay/Sakin piyasada (ADX < 25) SELL için esnetilmiş RSI sınırı (Gevşek sinyal)
input double Input_AdxTrendThreshold    = 25.0;                       // Trend ve yatay piyasa ayrım sınırı (ADX)
input int    Input_RSIPeriod            = 14;
input int    Input_EMAFastPeriod        = 13;                               
input int    Input_EMASlowPeriod        = 34;                               
input bool   Input_UseMacroFilter       = false;                            

input group "════════ RİSK YÖNETİMİ VE SINIRLAR ════════"
input bool   Input_UseBasketSL_USD      = true;                       // Akıllı Sigorta: Dolar bazlı sepet zarar durdurmayı aktif et
input double Input_BasketSL_USD         = 5.00;                       // Sepet Zarar Durdur (USD): Sepet toplam zararı bu miktara ulaştığında kapatılır
input int    Input_MaxBasketTimeMinutes   = 240;
input double Input_MinMarginLevelPct      = 100.0;                    // Yeni işlem açılması için gerekli asgari marjin seviyesi (%)
input double Input_MaxDrawdownPercent     = 95.0;                     // Maksimum hesap sermaye kaybı koruma sınırı (%)
input double Input_HardLotCap             = 5.00;                     // Sistem tarafından açılabilecek en yüksek lot sınırı
input int    Input_MinGridIntervalSeconds = 10;
input ulong  Input_MagicNumber            = 55555;
input int    Input_SlippagePoints         = 50;
input int    Input_MaxSpreadPoints        = 45;

//═══════════════════════════════════════════════════════════════════
//  GLOBAL DEĞİŞKENLER
//═══════════════════════════════════════════════════════════════════

CTrade m_trade;

int g_rsiHandle      = INVALID_HANDLE;
int g_emaFastHandle  = INVALID_HANDLE;
int g_emaSlowHandle  = INVALID_HANDLE;
int g_emaMacroHandle = INVALID_HANDLE;
int g_atrHandle      = INVALID_HANDLE;
int g_adxHandle      = INVALID_HANDLE;

datetime g_LastBarTime = 0;
bool     g_Initialized = false;

int    g_buyCount  = 0,  g_sellCount  = 0;
double g_buyProfit = 0,  g_sellProfit = 0;
double g_lowestBuyPrice   = 999999.0;
double g_highestSellPrice = 0.0;
double g_lastBuyLot  = 0.0;
double g_lastSellLot = 0.0;

double g_avgBuyPrice = 0.0;                                           
double g_avgSellPrice = 0.0;                                          

double g_maxBuyPointsReached = 0.0;                                   // BUY sepeti için ulaşılan en yüksek puan
double g_maxSellPointsReached = 0.0;                                  // SELL sepeti için ulaşılan en yüksek puan

datetime g_LastGridBuyTime  = 0;
datetime g_LastGridSellTime = 0;

double g_MaxBasketProfitReached[2] = {0.0, 0.0};
double g_CachedDailyProfit = 0.0;

//═══════════════════════════════════════════════════════════════════
//  YARDIMCI FONKSiyonLAR
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

double GetDynamicStepPoints()
{
   if(!Input_UseDynamicAtrStep) return (double)Input_GridStepPoints;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_atrHandle, 0, 1, 1, buf) > 0)
   {
      double pts = (buf[0] / _Point) * Input_AtrStepMultiplier;
      if(pts < 120.0) pts = 120.0;                                    
      if(pts > 400.0) pts = 400.0;
      return pts;
   }
   return (double)Input_GridStepPoints;
}

double GetDynamicBasketTP()
{
   return (double)Input_BasketTP_Points;
}

int GetStepPointsForLevel(int level)
{
   double base = GetDynamicStepPoints();
   double mult = 1.0;
   if     (level == 2) mult = 1.1;                                    
   else if(level == 3) mult = 1.3;
   else if(level == 4) mult = 1.6;
   else if(level >= 5) mult = 2.0;
   return (int)MathRound(base * mult);
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

double CalculateAutoLot()
{
   if(!Input_UseAutoLot) return Input_InitialLot;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(Input_AutoLotStep_USD <= 0) return Input_InitialLot;
   
   double dynamicLot = (balance / Input_AutoLotStep_USD) * 0.01;
   return NormalizeLot(dynamicLot);
}

double CalculateNextLot(double lastLot, int nextLevel)
{
   double nextLot = lastLot;
   double base = CalculateAutoLot();                                  
   
   if(Input_LotProgression == PROGRESSION_MULT)
   {
      nextLot = lastLot * Input_LotMultiplier;
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(nextLot < lastLot + step) nextLot = lastLot + step;
   }
   else
   {
      if     (nextLevel == 1) nextLot = base * 1.0;
      else if(nextLevel == 2) nextLot = base * 1.0;
      else if(nextLevel == 3) nextLot = base * 2.0;
      else if(nextLevel == 4) nextLot = base * 2.0;
      else                    nextLot = base * 3.0;
   }
   return NormalizeLot(nextLot);
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

// Sepetin ağırlıklı ortalama açılış fiyatını bulur
double CalculateBasketAveragePrice(ENUM_POSITION_TYPE type)
{
   double totalLot = 0.0;
   double totalValue = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)Input_MagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != (long)type) continue;
      
      double price = PositionGetDouble(POSITION_PRICE_OPEN);
      double lot = PositionGetDouble(POSITION_VOLUME);
      
      totalLot += lot;
      totalValue += (price * lot);
   }
   
   if(totalLot > 0) return (totalValue / totalLot);
   return 0.0;
}

void CalculateBasketStats()
{
   g_buyCount  = 0;  g_sellCount  = 0;
   g_buyProfit = 0;  g_sellProfit = 0;
   g_lowestBuyPrice   = 999999.0;
   g_highestSellPrice = 0.0;
   g_lastBuyLot  = 0.0;
   g_lastSellLot = 0.0;

   double totalBuyWeightedPrice = 0.0;
   double totalBuyVolume = 0.0;
   double totalSellWeightedPrice = 0.0;
   double totalSellVolume = 0.0;

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
         
         totalBuyWeightedPrice += price * lot;
         totalBuyVolume += lot;
      }
      else if(type == POSITION_TYPE_SELL)
      {
         g_sellCount++;
         g_sellProfit += profit;
         if(price > g_highestSellPrice) g_highestSellPrice = price;
         if(lot   > g_lastSellLot)      g_lastSellLot      = lot;
         
         totalSellWeightedPrice += price * lot;
         totalSellVolume += lot;
      }
   }

   g_avgBuyPrice  = (totalBuyVolume > 0)  ? (totalBuyWeightedPrice / totalBuyVolume)   : 0.0;
   g_avgSellPrice = (totalSellVolume > 0) ? (totalSellWeightedPrice / totalSellVolume) : 0.0;
}

bool SendOrder(ENUM_POSITION_TYPE type, double lot, string comment = "TGS_v16.10")
{
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double price  = (type == POSITION_TYPE_BUY)
                   ? NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), digits)
                   : NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), digits);

   m_trade.SetExpertMagicNumber(Input_MagicNumber);
   m_trade.SetDeviationInPoints((ulong)Input_SlippagePoints);

   bool ok = (type == POSITION_TYPE_BUY)
             ? m_trade.Buy (lot, _Symbol, price, 0, 0, comment)
             : m_trade.Sell(lot, _Symbol, price, 0, 0, comment);

   if(ok)
      PrintFormat("🚀 Emir Gönderildi | %s | Lot: %.2f | Fiyat: %s | Etiket: %s",
                  (type==POSITION_TYPE_BUY?"BUY":"SELL"), lot, DoubleToString(price,digits), comment);
   else
      PrintFormat("❌ Sipariş Hatası | Kod: %u | %s",
                  m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription());
   return ok;
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

datetime GetOldestPositionOpenTime(ENUM_POSITION_TYPE type)
{
   datetime oldest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString (POSITION_SYMBOL) != _Symbol)                continue;
      if(PositionGetInteger(POSITION_MAGIC)  != (long)Input_MagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)   != (long)type)              continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || t < oldest) oldest = t;
   }
   return oldest;
}

// 3 Kademeli Kâr Al (Split TP) işlemlerinin durumunu denetler
bool IsMultiTPActive(ENUM_POSITION_TYPE type)
{
   if(!Input_UseMultiTP) return false;
   
   // Eğer sepetimizde grid işlemlerinden herhangi biri varsa MultiTP pasif olur, sepet birleşir.
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)Input_MagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != (long)type) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(comment != "TGS_TP1" && comment != "TGS_TP2" && comment != "TGS_TP3")
         return false; 
   }
   return true;
}

//═══════════════════════════════════════════════════════════════════
//  BİLGİ PANELİ (SMART CASUAL)
//═══════════════════════════════════════════════════════════════════

void DrawLabel(string name, string text, int x, int y, color clr)
{
   string obj = "TGS_Dash_" + name;
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

   string status = inSession ? "SİSTEM AKTİF" : "GEVŞEK SEANS AKTİF";
   color  sc     = inSession ? C'0x00,0xAA,0xFF'    : C'0xFF,0xAA,0x00';

   if(newsLock)
      { status = "HABER ENGELİ AKTİF";            sc = C'0xFF,0xAA,0x00'; }
   if(marginLevel > 0 && marginLevel < Input_MinMarginLevelPct)
      { status = "DÜŞÜK MARJİN - GRID ENGEL";     sc = C'0xFF,0xAA,0x00'; }
   if(g_CachedDailyProfit >= Input_DailyProfitLimit_USD)
      { status = "GÜNLÜK HEDEF TAMAMLANDI";       sc = C'0x00,0xFF,0x00'; }
   if(totalFloat <= -dynamicSL)
      { status = "ACİL KORUMA LİMİTİ";            sc = C'0xFF,0x00,0x00'; }

   int nextBS = GetStepPointsForLevel(g_buyCount);
   int nextSS = GetStepPointsForLevel(g_sellCount);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   string nextBT = (g_buyCount  > 0 && g_buyCount  < Input_MaxGridLevels)
      ? DoubleToString(g_lowestBuyPrice   - nextBS * _Point, digits) : "---";
   string nextST = (g_sellCount > 0 && g_sellCount < Input_MaxGridLevels)
      ? DoubleToString(g_highestSellPrice + nextSS * _Point, digits) : "---";

   string buyAvgStr  = (g_buyCount > 0)  ? DoubleToString(g_avgBuyPrice, digits)  : "---";
   string sellAvgStr = (g_sellCount > 0) ? DoubleToString(g_avgSellPrice, digits) : "---";

   string slStr = Input_UseBasketSL_USD ? "-$" + DoubleToString(Input_BasketSL_USD, 2) : "KAPALI";

   color w = clrWhite, g = clrGold;

   DrawLabel("L14_Ind",    "  ▸ Live ADX: "  + DoubleToString(adxLive,1) +
                            "  |  Live RSI: " + DoubleToString(rsiLive,1),   15, 15,  clrLightGray);
   DrawLabel("L13_Daily",  "  ▸ Günlük K/Z:         $" + DoubleToString(g_CachedDailyProfit,2) +
                            " / Hedef $" + DoubleToString(Input_DailyProfitLimit_USD,2),
                            15, 31, g_CachedDailyProfit >= Input_DailyProfitLimit_USD ? clrLime : w);
   DrawLabel("L12_Margin", "  ▸ Marjin Seviyesi:   " + (marginLevel>0 ? DoubleToString(marginLevel,1)+"%" : "LİMİTSİZ"), 15, 47,  w);
   DrawLabel("L11_TotPnL", "  ▸ Toplam Yüzen K/Z:  $" + DoubleToString(totalFloat,2) +
                            "  |  Max SL: -$" + DoubleToString(dynamicSL,1), 15, 63,  totalFloat>=0?clrLime:clrRed);
   DrawLabel("L10_SGrid",  "  ▸ SELL Sonraki Grid: " + nextST + "  (" + IntegerToString(nextSS) + " pts)", 15, 79,  clrTomato);
   DrawLabel("L9_BGrid",   "  ▸ BUY  Sonraki Grid: " + nextBT + "  (" + IntegerToString(nextBS) + " pts)", 15, 95,  clrAquamarine);
   DrawLabel("L8_SPnL",    "  ▸ SELL Sepet K/Z:    $" + DoubleToString(g_sellProfit,2) +
                            "  [" + IntegerToString(g_sellCount) + "/" + IntegerToString(Input_MaxGridLevels) + " Lvl] (Ort: " + sellAvgStr + ")", 15,111, w);
   DrawLabel("L7_BPnL",    "  ▸ BUY  Sepet K/Z:    $" + DoubleToString(g_buyProfit,2) +
                            "  [" + IntegerToString(g_buyCount)  + "/" + IntegerToString(Input_MaxGridLevels) + " Lvl] (Ort: " + buyAvgStr + ")", 15,127, w);
   
   string tpTypeStr = Input_UseMultiTP ? "ÜÇLÜ KADEMELİ" : "SABİT " + IntegerToString(Input_BasketTP_Points) + " Pts";
   DrawLabel("L6_TP",      "  ▸ Sepet Hedefi:      " + tpTypeStr + " | Sepet SL: " + slStr, 15,143, clrLightGray);
   DrawLabel("L5_Equity",  "  ▸ Varlık (Equity):   $" + DoubleToString(equity,2) + " | Başlangıç Lot: " + DoubleToString(CalculateAutoLot(),2),  15,159, w);
   DrawLabel("L4_Balance", "  ▸ Bakiye (Balance):  $" + DoubleToString(balance,2), 15,175, w);
   DrawLabel("L3_Status",  "  ▸ Durum:             " + status,                     15,195, sc);
   DrawLabel("L2_Title",   Input_BotTitle + " [PRO SCALPER]",               15,215, g);
   Comment("");
}

void ClearDashboard()
{
   ObjectsDeleteAll(0, "TGS_Dash_");
   Comment("");
}

//═══════════════════════════════════════════════════════════════════
//  SEPET DURUM KONTROLÜ (KADEMELİ TP VE SABİT SEPET TP YÖNETİMİ)
//═══════════════════════════════════════════════════════════════════

void CheckBasketStatus()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // BUY SEPETİ KONTROLÜ
   if(g_buyCount > 0)
   {
      datetime oldest = GetOldestPositionOpenTime(POSITION_TYPE_BUY);
      if(oldest > 0 && (long)(TimeCurrent()-oldest) > (long)(Input_MaxBasketTimeMinutes*60))
      {
         CloseAllPositions(POSITION_TYPE_BUY);
         PrintFormat("Zaman aşımı nedeniyle pozisyonlar kapatıldı | BUY | Net: $%.2f", g_buyProfit);
         return;
      }

      double currentPoints = (bid - g_avgBuyPrice) / _Point;
      if(currentPoints > g_maxBuyPointsReached)
         g_maxBuyPointsReached = currentPoints;

      // ── MÜHENDİSLİK GÜNCELLEMESİ: 3 KADEMELİ AKILLI TP (Grid açılmamışsa çalışır) ──
      if(g_buyCount <= 3 && IsMultiTPActive(POSITION_TYPE_BUY))
      {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != (long)Input_MagicNumber) continue;
            if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
            
            string comment = PositionGetString(POSITION_COMMENT);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            
            int tpPoints = Input_BasketTP_Points;
            if(comment == "TGS_TP2") tpPoints += Input_MultiTP_StepPoints;
            if(comment == "TGS_TP3") tpPoints += (Input_MultiTP_StepPoints * 2);
            
            double targetPrice = openPrice + (tpPoints * _Point);
            if(bid >= targetPrice)
            {
               m_trade.PositionClose(ticket);
               PrintFormat("💰 Kademeli Kâr Alındı | BUY | Giriş: %.2f | Hedef: +%d Puan | Kâr: $%.2f", openPrice, tpPoints, PositionGetDouble(POSITION_PROFIT));
            }
         }
      }
      else // Standart / Akıllı Trailing TP mantığı (Grid açılmışsa veya MultiTP kapalıysa)
      {
         if(Input_UseSmartTrailing)
         {
            if(g_maxBuyPointsReached >= Input_TrailActivationPoints)
            {
               double trailingFloor = g_maxBuyPointsReached - Input_TrailStepPoints;
               if(currentPoints <= trailingFloor && g_buyProfit > 0)
               {
                  CloseAllPositions(POSITION_TYPE_BUY);
                  PrintFormat("💰 Akıllı Trailing TP Tetiklendi | BUY | Zirve Puan: %.1f | Kapanış Puan: %.1f | Net: $%.2f", 
                              g_maxBuyPointsReached, currentPoints, g_buyProfit);
                  g_maxBuyPointsReached = 0.0;
                  return;
               }
            }
         }
         else
         {
            double targetPrice = g_avgBuyPrice + (Input_BasketTP_Points * _Point);
            if(bid >= targetPrice)
            {
               CloseAllPositions(POSITION_TYPE_BUY);
               PrintFormat("Kâr hedefi gerçekleşti | BUY | Ortalama: %s | Hedef: %s | Net: $%.2f", 
                           DoubleToString(g_avgBuyPrice, _Digits), DoubleToString(targetPrice, _Digits), g_buyProfit);
               return;
            }
         }
      }
      
      // Dolar Bazlı Akıllı Sepet SL (Zarar Durdurma Kontrolü)
      if(Input_UseBasketSL_USD)
      {
         if(g_buyProfit <= -Input_BasketSL_USD)
         {
            CloseAllPositions(POSITION_TYPE_BUY);
            PrintFormat("Zarar durdurma tetiklendi | BUY | Sepet Zararı: $%.2f (Limit: -$%.2f)", g_buyProfit, Input_BasketSL_USD);
            return;
         }
      }
   }

   // SELL SEPETİ KONTROLÜ
   if(g_sellCount > 0)
   {
      datetime oldest = GetOldestPositionOpenTime(POSITION_TYPE_SELL);
      if(oldest > 0 && (long)(TimeCurrent()-oldest) > (long)(Input_MaxBasketTimeMinutes*60))
      {
         CloseAllPositions(POSITION_TYPE_SELL);
         PrintFormat("Zaman aşımı nedeniyle pozisyonlar kapatıldı | SELL | Net: $%.2f", g_sellProfit);
         return;
      }

      double currentPoints = (g_avgSellPrice - ask) / _Point;
      if(currentPoints > g_maxSellPointsReached)
         g_maxSellPointsReached = currentPoints;

      // ── MÜHENDİSLİK GÜNCELLEMESİ: 3 KADEMELİ AKILLI TP (Grid açılmamışsa çalışır) ──
      if(g_sellCount <= 3 && IsMultiTPActive(POSITION_TYPE_SELL))
      {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != (long)Input_MagicNumber) continue;
            if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
            
            string comment = PositionGetString(POSITION_COMMENT);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            
            int tpPoints = Input_BasketTP_Points;
            if(comment == "TGS_TP2") tpPoints += Input_MultiTP_StepPoints;
            if(comment == "TGS_TP3") tpPoints += (Input_MultiTP_StepPoints * 2);
            
            double targetPrice = openPrice - (tpPoints * _Point);
            if(ask <= targetPrice)
            {
               m_trade.PositionClose(ticket);
               PrintFormat("💰 Kademeli Kâr Alındı | SELL | Giriş: %.2f | Hedef: +%d Puan | Kâr: $%.2f", openPrice, tpPoints, PositionGetDouble(POSITION_PROFIT));
            }
         }
      }
      else // Standart / Akıllı Trailing TP mantığı (Grid açılmışsa veya MultiTP kapalıysa)
      {
         if(Input_UseSmartTrailing)
         {
            if(g_maxSellPointsReached >= Input_TrailActivationPoints)
            {
               double trailingFloor = g_maxSellPointsReached - Input_TrailStepPoints;
               if(currentPoints <= trailingFloor && g_sellProfit > 0)
               {
                  CloseAllPositions(POSITION_TYPE_SELL);
                  PrintFormat("💰 Akıllı Trailing TP Tetiklendi | SELL | Zirve Puan: %.1f | Kapanış Puan: %.1f | Net: $%.2f", 
                              g_maxSellPointsReached, currentPoints, g_sellProfit);
                  g_maxSellPointsReached = 0.0;
                  return;
               }
            }
         }
         else
         {
            double targetPrice = g_avgSellPrice - (Input_BasketTP_Points * _Point);
            if(ask <= targetPrice)
            {
               CloseAllPositions(POSITION_TYPE_SELL);
               PrintFormat("Kâr hedefi gerçekleşti | SELL | Ortalama: %s | Hedef: %s | Net: $%.2f", 
                           DoubleToString(g_avgSellPrice, _Digits), DoubleToString(targetPrice, _Digits), g_sellProfit);
               return;
            }
         }
      }
      
      // Dolar Bazlı Akıllı Sepet SL (Zarar Durdurma Kontrolü)
      if(Input_UseBasketSL_USD)
      {
         if(g_sellProfit <= -Input_BasketSL_USD)
         {
            CloseAllPositions(POSITION_TYPE_SELL);
            PrintFormat("Zarar durdurma tetiklendi | SELL | Sepet Zararı: $%.2f (Limit: -$%.2f)", g_sellProfit, Input_BasketSL_USD);
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
   PrintFormat("=== %s başlatılıyor ===", Input_BotTitle);

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t==0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==(long)Input_MagicNumber)
      {
         PrintFormat("⚠️ UYARI: Magic %llu ile zaten açık işlemler var – çakışan bot kontrolü yapın",
                     Input_MagicNumber, _Symbol);
         break;
      }
   }

   uint fill = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if     ((fill & SYMBOL_FILLING_FOK) != 0) m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((fill & SYMBOL_FILLING_IOC) != 0) m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else                                      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   g_rsiHandle      = iRSI (_Symbol, Input_SignalTF,  Input_RSIPeriod,     PRICE_CLOSE);
   g_emaFastHandle  = iMA  (_Symbol, Input_SignalTF,  Input_EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHandle  = iMA  (_Symbol, Input_SignalTF,  Input_EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_emaMacroHandle = iMA  (_Symbol, PERIOD_H1,       200,                 0, MODE_EMA, PRICE_CLOSE);
   g_atrHandle      = iATR (_Symbol, PERIOD_H1,       14);
   g_adxHandle      = iADX (_Symbol, Input_SignalTF,  14);

   if(g_rsiHandle==INVALID_HANDLE      || g_emaFastHandle==INVALID_HANDLE ||
      g_emaSlowHandle==INVALID_HANDLE  || g_emaMacroHandle==INVALID_HANDLE ||
      g_atrHandle==INVALID_HANDLE      || g_adxHandle==INVALID_HANDLE)
   {
      Print("❌ İndikatörler yüklenemedi.");
      return INIT_FAILED;
   }

   g_Initialized = true;
   PrintFormat("✅ Bot Hazır | Hedef Ortalama TP: %d Puan | Başlangıç Lotu: %.2f", Input_BasketTP_Points, CalculateAutoLot());
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
   if(g_atrHandle      != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_adxHandle      != INVALID_HANDLE) IndicatorRelease(g_adxHandle);
   PrintFormat("Bot durduruldu. Kod: %d", reason);
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
   if((ask - bid) / _Point > Input_MaxSpreadPoints) return;

   // ── 1) ACİL DURDURMA SİSTEMİ ──────────────────────────────────
   double totalFloat = g_buyProfit + g_sellProfit;
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double dynSL      = balance * (Input_MaxDrawdownPercent / 100.0);

   if(totalFloat <= -dynSL)
   {
      CloseAllPositions(POSITION_TYPE_BUY);
      CloseAllPositions(POSITION_TYPE_SELL);
      PrintFormat("🚨 ACİL DURDURMA TETİKLENDİ | Yüzen Zarar: -$%.2f | Limit: -$%.2f", MathAbs(totalFloat), dynSL);
      return;
   }

   // ── 2) SEPET HEDEF KONTROLÜ ───────────────────────────────────
   CheckBasketStatus();

   // ── 3) GÜNLÜK KÂR LİMİT KİLİDİ ─────────────────────────────────
   if(g_CachedDailyProfit >= Input_DailyProfitLimit_USD) return;

   // ── 4) MARJİN KONTROLÜ ────────────────────────────────────────
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   bool   canGrid     = (marginLevel <= 0 || marginLevel >= Input_MinMarginLevelPct);

   // ── 5) YENİ BAR TESPİTİ VE HAFIZA GÜNCELLEME ──────────────────
   datetime barTime[];
   ArraySetAsSeries(barTime, true);
   if(CopyTime(_Symbol, Input_SignalTF, 0, 1, barTime) < 1) return;

   bool isNewBar    = (barTime[0] != g_LastBarTime);
   bool entryNewBar = isNewBar;

   if(isNewBar)
   {
      g_LastBarTime = barTime[0]; // HAFIZA BUG'I DÜZELTİLDİ: Sinyal olmasa bile bar hafızası hemen güncellenir.
   }

   if(g_buyCount == 0) g_maxBuyPointsReached = 0.0;
   if(g_sellCount == 0) g_maxSellPointsReached = 0.0;

   if(entryNewBar && (g_buyCount > 0 || g_sellCount > 0))
      entryNewBar = false;

   // ── 6A) BUY GRID YÖNETİMİ ─────────────────────────────────────
   if(g_buyCount > 0 && g_buyCount < Input_MaxGridLevels)
   {
      double adxBuf[];
      ArraySetAsSeries(adxBuf, true);
      bool adxOk = true;
      if(Input_UseAdxGridBlockFilter && CopyBuffer(g_adxHandle, 0, 0, 1, adxBuf) > 0 && adxBuf[0] > Input_GridAdxBlockLimit)
         adxOk = false;

      if(adxOk)
      {
         int    step    = GetStepPointsForLevel(g_buyCount);
         double trigger = g_lowestBuyPrice - step * _Point;
         if(bid <= trigger && TimeCurrent() - g_LastGridBuyTime >= Input_MinGridIntervalSeconds)
         {
            if(canGrid)
            {
               double lot = CalculateNextLot(g_lastBuyLot, g_buyCount + 1);
               if(SendOrder(POSITION_TYPE_BUY, lot, "TGS_Grid"))
                  g_LastGridBuyTime = TimeCurrent();
            }
            else
            {
               static datetime wB = 0;
               if(TimeCurrent()-wB > 60)
               { Print("⚠️ BUY Grid Engellendi – Marjin: ",DoubleToString(marginLevel,1),"%"); wB=TimeCurrent(); }
            }
         }
      }
   }

   // ── 6B) SELL GRID YÖNETİMİ ────────────────────────────────────
   if(g_sellCount > 0 && g_sellCount < Input_MaxGridLevels)
   {
      double adxBuf[];
      ArraySetAsSeries(adxBuf, true);
      bool adxOk = true;
      if(Input_UseAdxGridBlockFilter && CopyBuffer(g_adxHandle, 0, 0, 1, adxBuf) > 0 && adxBuf[0] > Input_GridAdxBlockLimit)
         adxOk = false;

      if(adxOk)
      {
         int    step    = GetStepPointsForLevel(g_sellCount);
         double trigger = g_highestSellPrice + step * _Point;
         if(ask >= trigger && TimeCurrent() - g_LastGridSellTime >= Input_MinGridIntervalSeconds)
         {
            if(canGrid)
            {
               double lot = CalculateNextLot(g_lastSellLot, g_sellCount + 1);
               if(SendOrder(POSITION_TYPE_SELL, lot, "TGS_Grid"))
                  g_LastGridSellTime = TimeCurrent();
            }
            else
            {
               static datetime wS = 0;
               if(TimeCurrent()-wS > 60)
               { Print("⚠️ SELL Grid Engellendi – Marjin: ",DoubleToString(marginLevel,1),"%"); wS=TimeCurrent(); }
            }
         }
      }
   }

   // ── 7) İLK GİRİŞ SİNYALİ (M5 BAR AÇILIŞINDA) ───────────────────
   if(g_buyCount == 0 && g_sellCount == 0 && entryNewBar)
   {
      if(Input_UseSessionFilter && !IsActiveSession()) { g_LastBarTime = barTime[0]; return; }
      if(IsNewsTime())                                { g_LastBarTime = barTime[0]; return; }

      double rsiV[], emaF[], emaS[], emaM[], adxV[];
      ArraySetAsSeries(rsiV, true); ArraySetAsSeries(emaF, true);
      ArraySetAsSeries(emaS, true); ArraySetAsSeries(emaM, true);
      ArraySetAsSeries(adxV, true);

      if(CopyBuffer(g_rsiHandle,      0, 1, 1, rsiV) < 1) return;
      if(CopyBuffer(g_emaFastHandle,  0, 1, 1, emaF) < 1) return;
      if(CopyBuffer(g_emaSlowHandle,  0, 1, 1, emaS) < 1) return;
      if(CopyBuffer(g_emaMacroHandle, 0, 1, 1, emaM) < 1) return;
      if(CopyBuffer(g_adxHandle,      0, 1, 1, adxV) < 1) return;

      g_LastBarTime = barTime[0]; 

      double rsi = rsiV[0];
      double adx = adxV[0];

      // Dinamik RSI Sınır Belirleme Algoritması
      double rsiLimit_Oversold = Input_RSIOversold; 
      double rsiLimit_Overbought = Input_RSIOverbought;

      if(Input_UseDynamicRsi)
      {
         if(adx < Input_AdxTrendThreshold)
         {
            // Yatay / Sakin piyasa: RSI sınırları esnetilir (Sık işlem)
            rsiLimit_Oversold = Input_RsiOversold_Ranging;   
            rsiLimit_Overbought = Input_RsiOverbought_Ranging; 
         }
         else
         {
            // Güçlü Trend piyasası: RSI sınırları daraltılır (Maksimum koruma)
            rsiLimit_Oversold = Input_RSIOversold;   
            rsiLimit_Overbought = Input_RSIOverbought; 
         }
      }

      if(Input_UseAdxFirstEntryFilter && adx > Input_MaxAdxTrendLimit)
      {
         PrintFormat("🔍 Giriş Pas Geçildi: ADX %.1f > Limit %d", adx, Input_MaxAdxTrendLimit);
         return;
      }

      bool localBull  = (emaF[0] > emaS[0]);
      bool localBear  = (emaF[0] < emaS[0]);
      
      double closeBar = 0.0;
      double closeBuf[];
      ArraySetAsSeries(closeBuf, true);
      if(CopyClose(_Symbol, Input_SignalTF, 1, 1, closeBuf) >= 1)
         closeBar = closeBuf[0];
      else
         return;

      bool macroBull  = (!Input_UseMacroFilter || closeBar > emaM[0]);
      bool macroBear  = (!Input_UseMacroFilter || closeBar < emaM[0]);

      // Sinyal Süzgeci
      bool buySignal  = (macroBull && localBull);
      if(Input_UseRsiFilter)
         buySignal = buySignal && (rsi <= rsiLimit_Oversold);

      bool sellSignal = (macroBear && localBear);
      if(Input_UseRsiFilter)
         sellSignal = sellSignal && (rsi >= rsiLimit_Overbought);

      // BUY GİRİŞ SİNYALİ
      if(buySignal)
      {
         PrintFormat("📈 BUY Sinyali | RSI:%.1f ADX:%.1f EMAf:%.2f EMAs:%.2f", rsi, adx, emaF[0], emaS[0]);
         if(Input_UseMultiTP)
         {
            SendOrder(POSITION_TYPE_BUY, NormalizeLot(CalculateAutoLot()), "TGS_TP1");
            SendOrder(POSITION_TYPE_BUY, NormalizeLot(CalculateAutoLot()), "TGS_TP2");
            SendOrder(POSITION_TYPE_BUY, NormalizeLot(CalculateAutoLot()), "TGS_TP3");
         }
         else
         {
            SendOrder(POSITION_TYPE_BUY, NormalizeLot(CalculateAutoLot()), "TGS_v16.10");
         }
         g_LastGridBuyTime = TimeCurrent();
      }
      // SELL GİRİŞ SİNYALİ
      else if(sellSignal)
      {
         PrintFormat("📉 SELL Sinyali | RSI:%.1f ADX:%.1f EMAf:%.2f EMAs:%.2f", rsi, adx, emaF[0], emaS[0]);
         if(Input_UseMultiTP)
         {
            SendOrder(POSITION_TYPE_SELL, NormalizeLot(CalculateAutoLot()), "TGS_TP1");
            SendOrder(POSITION_TYPE_SELL, NormalizeLot(CalculateAutoLot()), "TGS_TP2");
            SendOrder(POSITION_TYPE_SELL, NormalizeLot(CalculateAutoLot()), "TGS_TP3");
         }
         else
         {
            SendOrder(POSITION_TYPE_SELL, NormalizeLot(CalculateAutoLot()), "TGS_v16.10");
         }
         g_LastGridSellTime = TimeCurrent();
      }
      else
      {
         // İzleme günlükleri
         if(macroBull && localBull)
            PrintFormat("🔍 BUY kurulumu aktif, tetiklenme bekleniyor... RSI: %.1f", rsi);
         else if(macroBear && localBear)
            PrintFormat("🔍 SELL kurulumu aktif, tetiklenme bekleniyor... RSI: %.1f", rsi);
      }
   }
}
