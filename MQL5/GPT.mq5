#property copyright "Copyright 2025, Vord"
#property link      "https://github.com/iqbal-saputra"
#property version   "1.00"

#include <Trade/Trade.mqh>

input double Lots             = 0.1;
input int    AtrPeriod        = 14;
input double TriggerFactor    = 1.5;
input double SlMultiplier     = 1.5;
input double TpMultiplier     = 2.5;
input ENUM_TIMEFRAMES TF     = PERIOD_M15;
input int    MaPeriod         = 50;

CTrade trade;
int handleATR, handleMA;
int lastBars;

int OnInit()
  {
   handleATR = iATR(_Symbol, TF, AtrPeriod);
   handleMA  = iMA(_Symbol, TF, MaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   lastBars = iBars(_Symbol, TF);
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   int barsNow = iBars(_Symbol, TF);
   if(barsNow == lastBars)
      return;
   lastBars = barsNow;

   // Ambil data ATR
   double atr[];
   if(CopyBuffer(handleATR, 0, 1, 1, atr) <= 0 || atr[0] == 0.0)
      return;

   // Ambil harga candle sebelumnya
   double open = iOpen(_Symbol, TF, 1);
   double close = iClose(_Symbol, TF, 1);
   double maVal[];
   if(CopyBuffer(handleMA, 0, 1, 1, maVal) <= 0)
      return;

   double priceNow = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl, tp;
   double range = MathAbs(close - open);
   double atrVal = atr[0];
   double ma = maVal[0];

   // BUY condition: candle bullish + range > atr + harga di atas MA
   if(close > open && range > (atrVal * TriggerFactor) && close > ma)
     {
      sl = priceNow - atrVal * SlMultiplier;
      tp = priceNow + atrVal * TpMultiplier;

      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);
      priceNow = NormalizeDouble(priceNow, _Digits);

      if(trade.Buy(Lots, _Symbol, priceNow, sl, tp))
         Print("BUY order placed");
     }
   // SELL condition: candle bearish + range > atr + harga di bawah MA
   else if(open > close && range > (atrVal * TriggerFactor) && close < ma)
     {
      priceNow = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = priceNow + atrVal * SlMultiplier;
      tp = priceNow - atrVal * TpMultiplier;

      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);
      priceNow = NormalizeDouble(priceNow, _Digits);

      if(trade.Sell(Lots, _Symbol, priceNow, sl, tp))
         Print("SELL order placed");
     }
  }
