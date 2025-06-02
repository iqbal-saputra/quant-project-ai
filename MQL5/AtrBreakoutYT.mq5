#property copyright "Copyright 2025, Vord"
#property link "https://github.com/iqbal-saputra"
#property version "1.00"

#include <trade/trade.mqh>

input double Lots = 0.1;
input int TpPoints = 1000;
input int SlPoints = 500;
input int TslTriggerPoints = 200;
input int TslPoints = 100;
input string Commentary = "atr breakout";
input int Magic = 1;

input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input int AtrPeriods = 14;
input double TriggerFactor = 2.5;

int handleAtr;
int barsTotal;
CTrade trade;

int OnInit(void)
  {
   
   Print("this is the OnInit function...");
   trade.SetExpertMagicNumber(Magic);

   handleAtr = iATR(NULL, Timeframe, AtrPeriods);
   barsTotal = iBars(NULL, Timeframe);
   
   return(INIT_SUCCEEDED);
  }
  
void OnDeinit(const int reason){
   Print("this is on the OnDeinit function", reason,"...");
  }

void OnTick(void){

   for(int i = 0; i < PositionsTotal(); i++){
      ulong posTicket = PositionGetTicket(i);
      
      if(PositionGetSymbol(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double posPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSl = PositionGetDouble(POSITION_SL);
      double posTp = PositionGetDouble(POSITION_TP);
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
         if(bid > posPriceOpen + TslTriggerPoints * _Point){
            double sl = bid - TslPoints * _Point;
            sl = NormalizeDouble(sl, _Digits);
            
            if(sl > posSl){
               
            }
         }
      }
   }
   
   int bars = iBars(NULL, Timeframe);
   if(barsTotal != bars){
      barsTotal = bars;
   
      double atr[];
      CopyBuffer(handleAtr,0,1,1,atr);
      
      double open = iOpen(NULL,Timeframe,1);
      double close = iClose(NULL, Timeframe,1);
      
      if(open < close && close - open > atr[0]*TriggerFactor){
         Print("buy signal");
         executeBuy();
      }else if(open > close && open - close > atr[0]*TriggerFactor){
         Print("sell signal");
         executeSell();
      }
   }
}
  
void executeBuy(){
   double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   entry = NormalizeDouble(entry,_Digits);
   
   double tp = entry + TpPoints * _Point;
   tp = NormalizeDouble(tp, _Digits);
   
   double sl = entry - SlPoints * _Point;
   sl = NormalizeDouble(sl, _Digits);
   
   trade.Buy(Lots,NULL,entry,sl,tp, Commentary);
}

void executeSell(){
   double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   entry = NormalizeDouble(entry, _Digits);
   
   double tp = entry - TpPoints * _Point;
   tp = NormalizeDouble(tp,_Digits);
   
   double sl = entry + SlPoints * _Point;
   sl = NormalizeDouble(sl,_Digits);
   
   trade.Sell(Lots, NULL, entry, sl, tp, Commentary);
}

double Buy(int number, double anotherNumber){
   
   
   return (double)number + anotherNumber;
}