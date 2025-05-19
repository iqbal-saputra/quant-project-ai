#property copyright "Copyright 2025, Vord"
#property link "https://github.com/iqbal-saputra"
#property version "1.00"

input ENUM_TIMEFRAMES Timeframe = PERIOD_M5;

input int AtrPeriods = 14;

int handleAtr;

int OnInit(void)
  {
   
   Print("this is the OnInit function...");

   handleAtr = iATR(NULL, Timeframe, AtrPeriods);
   
   return(INIT_SUCCEEDED);
  }
  
void OnDeinit(const int reason)
  {
   Print("this is on the OnDeinit function", reason,"...");
  }

void OnTick(void)
  {
   double atr[];
   CopyBuffer(handleAtr,0,1,1,atr);
   
   double open = iOpen(NULL, Timeframe, 1);
   double close = iClose(NULL, Timeframe, 1);   


  }
  
 