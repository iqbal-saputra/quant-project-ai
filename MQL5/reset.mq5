//+------------------------------------------------------------------+
//|                XAUUSD_ONNX_MULTIVAR_FILTERED.mq5                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Vord & Iqbal"
#property version   "1.10"
#include <Trade/Trade.mqh>

input double InpLots = 0.01;

#resource "Files/model1.test.onnx" as uchar ExtModel[]

#define SAMPLE_SIZE 120
#define N_FEATURES 6

long     ExtHandle = INVALID_HANDLE;
double   ExtMin[N_FEATURES];
double   ExtMax[N_FEATURES];
CTrade   ExtTrade;

int      ExtPredictedClass = -1;
datetime ExtNextBar = 0;
datetime ExtNextDay = 0;

// --- price movement prediction
#define PRICE_UP   0
#define PRICE_SAME 1
#define PRICE_DOWN 2

// --- Filter Parameters
input double MinDelta     = 5.0;     // pip threshold (XAUUSD: 1 pip = 10 point)
input int    ATR_Period   = 14;
input double SL_ATR_Mult  = 1.5;
input double TP_ATR_Mult  = 2.0;
input double Trail_ATR_Mult = 1.0;

// ATR Filter
input double ATR_Filter_Mult = 1.1;   // ATR sekarang > ATR_Filter_Mult * ATR rata-rata

// Jam aktif trading (opsional)
input int StartHour = 8;
input int EndHour   = 18;

// --- ATR handle global biar tidak repeatedly call iATR (lebih efisien!)
int handleATR = INVALID_HANDLE;

double Normalize(double value, double minv, double maxv)
{
   if(maxv-minv < 1e-8)
      return 0.0;
   return (value - minv) / (maxv - minv);
}

// ATR: gunakan handleATR global, tarik data pakai CopyBuffer
double GetATR(int period, int shift=0)
{
    double atrBuffer[];
    if(handleATR == INVALID_HANDLE) return 0.0;
    if(CopyBuffer(handleATR, 0, shift, 1, atrBuffer) > 0)
        return atrBuffer[0];
    else
        return 0.0;
}

double GetATRMean(int period, int mult=3)
{
    double atrBuffer[];
    int size = period * mult;
    if(handleATR == INVALID_HANDLE) return 0.0;
    if(CopyBuffer(handleATR, 0, 0, size, atrBuffer) >= size)
    {
        double sum=0;
        for(int i=0;i<size;i++) sum += atrBuffer[i];
        return sum/size;
    }
    return 0.0;
}

void GetMinMax()
{
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M15, 0, SAMPLE_SIZE, rates) != SAMPLE_SIZE)
      return;

   double minVals[N_FEATURES];
   double maxVals[N_FEATURES];

   ArrayInitialize(minVals, DBL_MAX);
   ArrayInitialize(maxVals, -DBL_MAX);

   for(int i = 0; i < SAMPLE_SIZE; i++)
   {
      double values[N_FEATURES] = {
         rates[i].open,
         rates[i].high,
         rates[i].low,
         rates[i].close,
         rates[i].tick_volume,
         rates[i].spread
      };

      for(int f = 0; f < N_FEATURES; f++)
      {
         if(values[f] < minVals[f]) minVals[f] = values[f];
         if(values[f] > maxVals[f]) maxVals[f] = values[f];
      }
   }
   for(int f = 0; f < N_FEATURES; f++)
   {
      ExtMin[f] = minVals[f];
      ExtMax[f] = maxVals[f];
   }
}

void PrepareInputTensor(float &InputTensor[][N_FEATURES])
{
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M15, 1, SAMPLE_SIZE, rates) != SAMPLE_SIZE)
      return;

   for(int i = 0; i < SAMPLE_SIZE; i++)
   {
      double raw[N_FEATURES] = {
         rates[SAMPLE_SIZE-1-i].open,
         rates[SAMPLE_SIZE-1-i].high,
         rates[SAMPLE_SIZE-1-i].low,
         rates[SAMPLE_SIZE-1-i].close,
         rates[SAMPLE_SIZE-1-i].tick_volume,
         rates[SAMPLE_SIZE-1-i].spread
      };
      for(int f = 0; f < N_FEATURES; f++)
         InputTensor[i][f] = (float)Normalize(raw[f], ExtMin[f], ExtMax[f]);
   }
}

double PredictPrice(float &InputTensor[][N_FEATURES])
{
   static vectorf output_data(1);
   if(!OnnxRun(ExtHandle, ONNX_NO_CONVERSION, InputTensor, output_data))
   {
      Print("OnnxRun ERROR! ", GetLastError());
      ExtPredictedClass = -1;
      return 0.0;
   }
   double predicted = output_data[0] * (ExtMax[3] - ExtMin[3]) + ExtMin[3];
   double last_close = iClose(_Symbol, _Period, 0);
   double delta = predicted - last_close;

   if(MathAbs(delta) <= (MinDelta * _Point))
      ExtPredictedClass = PRICE_SAME;
   else
      ExtPredictedClass = (delta > 0) ? PRICE_UP : PRICE_DOWN;

   return delta;
}

void CheckForOpen(ENUM_ORDER_TYPE signal)
{
   if(signal != ORDER_TYPE_BUY && signal != ORDER_TYPE_SELL) return;
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;

   double price;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(signal==ORDER_TYPE_SELL)
      price=bid;
   else
      price=ask;

   double atr = GetATR(ATR_Period);
   if(atr <= 0) atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20;

   double sl=0.0, tp=0.0;
   if(signal==ORDER_TYPE_BUY)
   {
      sl = price - SL_ATR_Mult * atr;
      tp = price + TP_ATR_Mult * atr;
   }
   else if(signal==ORDER_TYPE_SELL)
   {
      sl = price + SL_ATR_Mult * atr;
      tp = price - TP_ATR_Mult * atr;
   }

   ExtTrade.PositionOpen(_Symbol,signal,InpLots,price,sl,tp);
}

void ApplyTrailingStop()
{
    double atr = GetATR(ATR_Period);
    if(atr <= 0) return;
    double trail = Trail_ATR_Mult * atr;

    if(PositionSelect(_Symbol))
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        long type = PositionGetInteger(POSITION_TYPE);

        if(type == POSITION_TYPE_BUY)
        {
            double current_sl = PositionGetDouble(POSITION_SL);
            double new_sl = price - trail;
            if(new_sl > current_sl && new_sl < price)
                ExtTrade.PositionModify(_Symbol, new_sl, PositionGetDouble(POSITION_TP));
        }
        else if(type == POSITION_TYPE_SELL)
        {
            double price_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double current_sl = PositionGetDouble(POSITION_SL);
            double new_sl = price_ask + trail;
            if((current_sl == 0.0 || new_sl < current_sl) && new_sl > price_ask)
                ExtTrade.PositionModify(_Symbol, new_sl, PositionGetDouble(POSITION_TP));
        }
    }
}

void CheckForClose(void)
{
   bool bsignal=false;
   long type=PositionGetInteger(POSITION_TYPE);
   if(type==POSITION_TYPE_BUY && ExtPredictedClass==PRICE_DOWN)
      bsignal=true;
   if(type==POSITION_TYPE_SELL && ExtPredictedClass==PRICE_UP)
      bsignal=true;

   if(bsignal && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      ExtTrade.PositionClose(_Symbol,3);
   }
}

int OnInit()
{
   if(_Symbol != "XAUUSD" || _Period != PERIOD_M15)
   {
      Print("model must work with XAUUSD,M15");
      return INIT_FAILED;
   }

   ExtHandle = OnnxCreateFromBuffer(ExtModel, ONNX_DEFAULT);
   if(ExtHandle == INVALID_HANDLE)
   {
      Print("OnnxCreateFromBuffer error ", GetLastError());
      return INIT_FAILED;
   }

   // --- Setup ATR handle (once)
   handleATR = iATR(_Symbol, PERIOD_M15, ATR_Period);
   if(handleATR == INVALID_HANDLE)
   {
      Print("iATR handle error ", GetLastError());
      return INIT_FAILED;
   }

   const ulong input_shape[] = {1, SAMPLE_SIZE, N_FEATURES};
   if(!OnnxSetInputShape(ExtHandle, ONNX_DEFAULT, input_shape))
   {
      Print("OnnxSetInputShape error ", GetLastError());
      return INIT_FAILED;
   }

   const ulong output_shape[] = {1, 1};
   if(!OnnxSetOutputShape(ExtHandle, 0, output_shape))
   {
      Print("OnnxSetOutputShape error ", GetLastError());
      return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(TimeCurrent() >= ExtNextDay)
   {
      GetMinMax();
      ExtNextDay = TimeCurrent() - TimeCurrent() % PeriodSeconds(PERIOD_D1) + PeriodSeconds(PERIOD_D1);
   }
   if(TimeCurrent() < ExtNextBar) return;
   ExtNextBar = TimeCurrent() - TimeCurrent() % PeriodSeconds() + PeriodSeconds();

   // ML Inferensi
   float InputTensor[SAMPLE_SIZE][N_FEATURES];
   PrepareInputTensor(InputTensor);
   double delta = PredictPrice(InputTensor);

   // ATR Filter
   double atr_now = GetATR(ATR_Period);
   double atr_avg = GetATRMean(ATR_Period, 3);
   bool atrFilterOK = (atr_now > (ATR_Filter_Mult * atr_avg) && atr_now > 0);

   // Candle confirmation
   double open = iOpen(_Symbol, _Period, 1);
   double close = iClose(_Symbol, _Period, 1);

   ENUM_ORDER_TYPE signal = WRONG_VALUE;
   if(ExtPredictedClass==PRICE_DOWN)
      signal=ORDER_TYPE_SELL;
   else if(ExtPredictedClass==PRICE_UP)
      signal=ORDER_TYPE_BUY;

   bool candleOK = false;
   if(signal == ORDER_TYPE_BUY && close > open)
      candleOK = true;
   if(signal == ORDER_TYPE_SELL && close < open)
      candleOK = true;

   // Jam aktif
   MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
   int jam = tm.hour;
   bool jamOK = (jam >= StartHour && jam <= EndHour);

   // Filter utama: Semua harus true
   if(MathAbs(delta) > (MinDelta * _Point)
      && atrFilterOK
      && candleOK
      && jamOK)
   {
      if(PositionSelect(_Symbol))
         CheckForClose();
      else
         CheckForOpen(signal);
   }
   ApplyTrailingStop();
}
//+------------------------------------------------------------------+
