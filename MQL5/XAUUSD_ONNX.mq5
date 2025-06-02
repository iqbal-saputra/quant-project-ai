//+------------------------------------------------------------------+
//|                                                  XAUUSD_ONNX.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

input double InpLots = 0.01;    // Lots amount to open position

#resource "Files/model.xauusd.H1.120.onnx" as uchar ExtModel[]

#define SAMPLE_SIZE 120

long     ExtHandle=INVALID_HANDLE;
int      ExtPredictedClass=-1;
datetime ExtNextBar=0;
datetime ExtNextDay=0;
double    ExtMin=0.0;
double    ExtMax=0.0;
CTrade   ExtTrade;

//--- price movement prediction
#define PRICE_UP   0
#define PRICE_SAME 1
#define PRICE_DOWN 2

//+------------------------------------------------------------------+
//| Predict next price                                               |
//+------------------------------------------------------------------+
void PredictPrice(void)
  {
   static vectorf output_data(1);            // vector to get result
   static vectorf x_norm(SAMPLE_SIZE);       // vector for prices normalize

//--- check for normalization possibility
   if(ExtMin>=ExtMax)
     {
      ExtPredictedClass=-1;
      return;
     }
//--- request last bars
   if(!x_norm.CopyRates(_Symbol,_Period,COPY_RATES_CLOSE,1,SAMPLE_SIZE))
     {
      ExtPredictedClass=-1;
      return;
     }
   float last_close=x_norm[SAMPLE_SIZE-1];
//--- normalize prices
   x_norm-=ExtMin;
   x_norm/=(ExtMax-ExtMin);
//--- run the inference
   if(!OnnxRun(ExtHandle,ONNX_NO_CONVERSION,x_norm,output_data))
     {
      ExtPredictedClass=-1;
      return;
     }
//--- denormalize the price from the output value
   double predicted=output_data[0]*(ExtMax-ExtMin)+ExtMin;
//--- classify predicted price movement
   double delta=last_close-predicted;
   if(fabs(delta)<=0.00001)
      ExtPredictedClass=PRICE_SAME;
   else
     {
      if(delta<0)
         ExtPredictedClass=PRICE_UP;
      else
         ExtPredictedClass=PRICE_DOWN;
     }
  }

void GetMinMax(void)
  {
   vectorf close;
   close.CopyRates(_Symbol,PERIOD_D1,COPY_RATES_CLOSE,0,SAMPLE_SIZE);
   ExtMin=close.Min();
   ExtMax=close.Max();
  }

void CheckForOpen(void)
  {
   ENUM_ORDER_TYPE signal=WRONG_VALUE;
//--- check signals
   if(ExtPredictedClass==PRICE_DOWN)
      signal=ORDER_TYPE_SELL;    // sell condition
   else
     {
      if(ExtPredictedClass==PRICE_UP)
         signal=ORDER_TYPE_BUY;  // buy condition
     }

//--- open position if possible according to signal
   if(signal!=WRONG_VALUE && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      double price;
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(signal==ORDER_TYPE_SELL)
         price=bid;
      else
         price=ask;
      ExtTrade.PositionOpen(_Symbol,signal,InpLots,price,0.0,0.0);
     }
  }
  
void CheckForClose(void)
  {
   bool bsignal=false;
//--- position already selected before
   long type=PositionGetInteger(POSITION_TYPE);
//--- check signals
   if(type==POSITION_TYPE_BUY && ExtPredictedClass==PRICE_DOWN)
      bsignal=true;
   if(type==POSITION_TYPE_SELL && ExtPredictedClass==PRICE_UP)
      bsignal=true;

//--- close position if possible
   if(bsignal && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      ExtTrade.PositionClose(_Symbol,3);
      //--- open opposite
      CheckForOpen();
     }
  }

int OnInit()
  {
   if(_Symbol!="XAUUSD" || _Period!=PERIOD_H1)
     {
      Print("model must work with XAUUSD,H1");
      return(INIT_FAILED);
     }

//--- create a model from static buffer
   ExtHandle=OnnxCreateFromBuffer(ExtModel,ONNX_DEFAULT);
   if(ExtHandle==INVALID_HANDLE)
     {
      Print("OnnxCreateFromBuffer error ",GetLastError());
      return(INIT_FAILED);
     }

//--- since not all sizes defined in the input tensor we must set them explicitly
//--- first index - batch size, second index - series size, third index - number of series (only Close)
   const ulong input_shape[] = {1,SAMPLE_SIZE,1};
   if(!OnnxSetInputShape(ExtHandle,ONNX_DEFAULT,input_shape))
     {
      Print("OnnxSetInputShape error ",GetLastError());
      return(INIT_FAILED);
     }

//--- since not all sizes defined in the output tensor we must set them explicitly
//--- first index - batch size, must match the batch size of the input tensor
//--- second index - number of predicted prices (we only predict Close)
   const ulong output_shape[] = {1,1};
   if(!OnnxSetOutputShape(ExtHandle,0,output_shape))
     {
      Print("OnnxSetOutputShape error ",GetLastError());
      return(INIT_FAILED);
     }
//---
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
//---
   
  }

void OnTick()
  {
//--- check new day
   if(TimeCurrent()>=ExtNextDay)
     {
      GetMinMax();
      //--- set next day time
      ExtNextDay=TimeCurrent();
      ExtNextDay-=ExtNextDay%PeriodSeconds(PERIOD_D1);
      ExtNextDay+=PeriodSeconds(PERIOD_D1);
     }

//--- check new bar
   if(TimeCurrent()<ExtNextBar)
      return;
//--- set next bar time
   ExtNextBar=TimeCurrent();
   ExtNextBar-=ExtNextBar%PeriodSeconds();
   ExtNextBar+=PeriodSeconds();
//--- check min and max
   double close=iClose(_Symbol,_Period,0);
   if(ExtMin>close)
      ExtMin=close;
   if(ExtMax<close)
      ExtMax=close;

//--- predict next price
   PredictPrice();
//--- check trading according to prediction
   if(ExtPredictedClass>=0)
      if(PositionSelect(_Symbol))
         CheckForClose();
      else
         CheckForOpen();
  }
  
