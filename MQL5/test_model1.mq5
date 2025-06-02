//+------------------------------------------------------------------+
//|         XAUUSD_ONNX_MULTIVAR.mq5                               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Vord & Iqbal"
#property version   "1.03" // Naik versi lagi buat penyesuaian
#include <Trade/Trade.mqh> // Pastikan include ini ada dan benar

// Input lot size
input double InpLots = 0.01;
// Input Magic Number
input ulong InpMagicNumber = 12345;
// Input Slippage dalam points
input ulong InpSlippage = 10;
// Input Max Spread dalam points
input int InpMaxSpread = 50;


// Model resource (pastikan file onnx sudah embed di project!)
#resource "Files/model1.test.onnx" as uchar ExtModel[]

#define SAMPLE_SIZE 120
#define N_FEATURES 6

long     ExtHandle = INVALID_HANDLE;
double   ExtMin[N_FEATURES]; // Min dari setiap fitur
double   ExtMax[N_FEATURES]; // Max dari setiap fitur
CTrade   ExtTrade; // Objek CTrade sudah di-include dari Trade.mqh

int      ExtPredictedClass = -1;
datetime ExtNextBar = 0;
datetime ExtNextDay = 0;

// Array input global [SAMPLE_SIZE][N_FEATURES]
float modelInputArray[SAMPLE_SIZE][N_FEATURES];

// --- price movement prediction
#define PRICE_UP   0
#define PRICE_SAME 1
#define PRICE_DOWN 2

//+------------------------------------------------------------------+
//| Helper fungsi untuk normalisasi (0-1)                            |
//+------------------------------------------------------------------+
double Normalize(double value, double min_val, double max_val)
  {
   if(max_val - min_val < 1e-9)
      return 0.0;
   return (value - min_val) / (max_val - min_val);
  }

//+------------------------------------------------------------------+
//| Ambil min & max dari masing-masing fitur dari N hari terakhir    |
//+------------------------------------------------------------------+
void GetMinMax()
  {
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_D1, 0, SAMPLE_SIZE, rates) != SAMPLE_SIZE)
     {
      PrintFormat("Gagal mengambil data D1 untuk MinMax. Data tersedia: %d", Bars(_Symbol, PERIOD_D1));
      return;
     }

   double minVals[N_FEATURES];
   double maxVals[N_FEATURES];

   ArrayInitialize(minVals, DBL_MAX);
   ArrayInitialize(maxVals, -DBL_MAX);

   for(int i = 0; i < SAMPLE_SIZE; i++)
     {
      double current_open = rates[i].open;
      double current_high = rates[i].high;
      double current_low = rates[i].low;
      double current_close = rates[i].close;
      double current_volume = (double)rates[i].tick_volume;
      double current_spread = (double)rates[i].spread;

      double values[N_FEATURES] = {
         current_open,
         current_high,
         current_low,
         current_close,
         current_volume,
         current_spread
      };

      for(int f = 0; f < N_FEATURES; f++)
        {
         if(values[f] < minVals[f]) minVals[f] = values[f];
         if(values[f] > maxVals[f]) maxVals[f] = values[f];
        }
     }
     
   for(int f = 0; f < N_FEATURES; f++)
     {
      if (maxVals[f] - minVals[f] < 1e-9) {
          maxVals[f] = minVals[f] + 1e-9; 
      }
      ExtMin[f] = minVals[f];
      ExtMax[f] = maxVals[f];
     }
  }

//+------------------------------------------------------------------+
//| Membuat input tensor [1, SAMPLE_SIZE, N_FEATURES] untuk inference|
//+------------------------------------------------------------------+
void PrepareInputTensor()
  {
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 1, SAMPLE_SIZE, rates) != SAMPLE_SIZE)
     {
      PrintFormat("Gagal mengambil data %s untuk Input Tensor. Data tersedia: %d", EnumToString(_Period), Bars(_Symbol, _Period));
      return;
     }

   for(int i = 0; i < SAMPLE_SIZE; i++)
     {
      double raw_open = rates[SAMPLE_SIZE-1-i].open;
      double raw_high = rates[SAMPLE_SIZE-1-i].high;
      double raw_low = rates[SAMPLE_SIZE-1-i].low;
      double raw_close = rates[SAMPLE_SIZE-1-i].close;
      double raw_volume = (double)rates[SAMPLE_SIZE-1-i].tick_volume;
      double raw_spread = (double)rates[SAMPLE_SIZE-1-i].spread;

      double raw_features[N_FEATURES] = {
         raw_open,
         raw_high,
         raw_low,
         raw_close,
         raw_volume,
         raw_spread
      };

      for(int f = 0; f < N_FEATURES; f++)
        {
         // Pemanggilan Normalize seharusnya sudah benar di sini
         modelInputArray[i][f] = (float)Normalize(raw_features[f], ExtMin[f], ExtMax[f]);
        }
     }
  }

//+------------------------------------------------------------------+
//| Prediksi harga berikutnya                                        |
//+------------------------------------------------------------------+
void PredictPrice()
  {
   static vectorf output_data(1); 

   if(!OnnxRun(ExtHandle, ONNX_NO_CONVERSION, modelInputArray, output_data))
     {
      Print("OnnxRun error ", GetLastError());
      ExtPredictedClass = -1; 
      return;
     }

   if (ExtMax[3] - ExtMin[3] < 1e-9) {
       Print("Rentang Min/Max untuk harga 'close' terlalu kecil. Denormalisasi mungkin tidak akurat.");
       ExtPredictedClass = -1;
       return;
   }
   
   double predicted_normalized_price = output_data[0];
   double predicted_actual_price = predicted_normalized_price * (ExtMax[3] - ExtMin[3]) + ExtMin[3];
   
   MqlRates current_bar_data[];
   if(CopyRates(_Symbol, _Period, 0, 1, current_bar_data) < 1) { 
        Print("Gagal mendapatkan harga close terakhir.");
        ExtPredictedClass = -1;
        return;
   }
   double last_close = current_bar_data[0].close;

   double delta = predicted_actual_price - last_close;
   double point_value = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double price_threshold = point_value * 10; 

   if(fabs(delta) <= price_threshold)
      ExtPredictedClass = PRICE_SAME;
   else
      ExtPredictedClass = (delta > 0) ? PRICE_UP : PRICE_DOWN;
  }

//+------------------------------------------------------------------+
//| Fungsi buka posisi                                               |
//+------------------------------------------------------------------+
void CheckForOpen(void)
  {
   if(PositionSelect(_Symbol))
     {
      return;
     }

   ENUM_ORDER_TYPE signal = WRONG_VALUE;
   if(ExtPredictedClass == PRICE_DOWN)
      signal = ORDER_TYPE_SELL;
   else if(ExtPredictedClass == PRICE_UP)
      signal = ORDER_TYPE_BUY;

   if(signal != WRONG_VALUE && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      // Ganti IsTradeContextBusy() dengan TerminalInfoInteger(TERMINAL_TRADE_BUSY)
      if(TerminalInfoInteger(TERMINAL_TRADE_BUSY) == 1) { 
         Print("Konteks trading sedang sibuk, coba lagi nanti.");
         return;
      }

      double current_spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if (current_spread_points > InpMaxSpread && InpMaxSpread > 0) { 
          PrintFormat("Spread saat ini (%d points) terlalu lebar. Maksimum: %d points.", (int)current_spread_points, InpMaxSpread);
          return;
      }

      double price;
      double stop_loss = 0.0; 
      double take_profit = 0.0;
      string comment = "VordIqbal_XAU_ONNX";

      if(signal == ORDER_TYPE_SELL)
         price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      else 
         price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      if (price <= 0) {
          Print("Harga bid/ask tidak valid untuk membuka posisi.");
          return;
      }

      ExtTrade.SetExpertMagicNumber(InpMagicNumber);
      ExtTrade.SetDeviationInPoints(InpSlippage);
      
      PrintFormat("Mencoba membuka posisi %s untuk %s sejumlah %f lot pada harga %.5f",
                  (signal == ORDER_TYPE_SELL ? "SELL" : "BUY"), _Symbol, InpLots, price);

      if(!ExtTrade.PositionOpen(_Symbol, signal, InpLots, price, stop_loss, take_profit, comment))
        {
         PrintFormat("Gagal membuka posisi: %d - %s", (int)ExtTrade.ResultRetcode(), ExtTrade.ResultComment());
        }
      else
        {
         PrintFormat("Posisi %s berhasil dibuka. Tiket: %d", (signal == ORDER_TYPE_SELL ? "SELL" : "BUY"), (int)ExtTrade.ResultOrder());
        }
     }
  }

//+------------------------------------------------------------------+
//| Fungsi tutup posisi                                              |
//+------------------------------------------------------------------+
void CheckForClose(void)
  {
   if(!PositionSelect(_Symbol))
     {
      return;
     }

   bool close_signal = false;
   long position_type = PositionGetInteger(POSITION_TYPE);
   // Pastikan POSITION_OPEN_PRICE dikenali. Jika tidak, Trade.mqh mungkin bermasalah.
   double position_open_price = PositionGetDouble(POSITION_OPEN_PRICE); 

   if(position_type == POSITION_TYPE_BUY && ExtPredictedClass == PRICE_DOWN)
      close_signal = true;
   if(position_type == POSITION_TYPE_SELL && ExtPredictedClass == PRICE_UP)
      close_signal = true;

   if(close_signal && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      // Ganti IsTradeContextBusy() dengan TerminalInfoInteger(TERMINAL_TRADE_BUSY)
      if(TerminalInfoInteger(TERMINAL_TRADE_BUSY) == 1) {
         Print("Konteks trading sedang sibuk untuk menutup posisi, coba lagi nanti.");
         return;
      }
      
      ExtTrade.SetExpertMagicNumber(InpMagicNumber); 
      ExtTrade.SetDeviationInPoints(InpSlippage);
      
      // Pastikan PositionGetTicket() dipanggil tanpa argumen
      ulong ticket_to_close = PositionGetTicket(); 

      PrintFormat("Mencoba menutup posisi %s (Tiket: %d) untuk %s. Open Price: %.5f. Alasan: Prediksi berlawanan.",
                  (position_type == POSITION_TYPE_BUY ? "BUY" : "SELL"), ticket_to_close, _Symbol, position_open_price);

      if(!ExtTrade.PositionClose(ticket_to_close, InpSlippage)) 
        {
         PrintFormat("Gagal menutup posisi %d: %d - %s", ticket_to_close, (int)ExtTrade.ResultRetcode(), ExtTrade.ResultComment());
        }
      else
        {
         PrintFormat("Posisi %d berhasil ditutup.", ticket_to_close);
        }
     }
  }

//+------------------------------------------------------------------+
//| OnInit function                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Simpan MQL5InfoString ke variabel string dulu
   string prog_name = MQL5InfoString(MQL5_PROGRAM_NAME);
   string prog_version = MQL5InfoString(MQL5_PROGRAM_VERSION);
   PrintFormat("EA %s v%s sedang diinisialisasi...", prog_name, prog_version);

   if(_Symbol != "XAUUSD" || _Period != PERIOD_M15)
     {
      PrintFormat("EA ini HANYA untuk XAUUSD di timeframe M15! Simbol saat ini: %s, Timeframe: %s", _Symbol, EnumToString(_Period));
      Alert("EA XAUUSD_ONNX_MULTIVAR tidak bisa berjalan di simbol/timeframe ini. Silakan pindahkan ke chart XAUUSD, M15.");
      ExpertRemove(); 
      return INIT_FAILED; // Ganti INIT_FAILED_NORETRY menjadi INIT_FAILED
     }

   ExtHandle = OnnxCreateFromBuffer(ExtModel, ONNX_DEFAULT);
   if(ExtHandle == INVALID_HANDLE)
     {
      Print("OnnxCreateFromBuffer error ", GetLastError());
      Alert("Gagal memuat model ONNX!");
      return INIT_FAILED;
     }

   const ulong input_shape[] = {1, SAMPLE_SIZE, N_FEATURES}; 
   if(!OnnxSetInputShape(ExtHandle, 0, input_shape)) 
     {
      Print("OnnxSetInputShape error ", GetLastError());
      OnnxRelease(ExtHandle); 
      return INIT_FAILED;
     }

   const ulong output_shape[] = {1, 1}; 
   if(!OnnxSetOutputShape(ExtHandle, 0, output_shape)) 
     {
      Print("OnnxSetOutputShape error ", GetLastError());
      OnnxRelease(ExtHandle); 
      return INIT_FAILED;
     }
   
   GetMinMax();

   ExtNextDay = TimeCurrent() - (TimeCurrent() % PeriodSeconds(PERIOD_D1)) + PeriodSeconds(PERIOD_D1);
   ExtNextBar = TimeCurrent() - (TimeCurrent() % PeriodSeconds(_Period)) + PeriodSeconds(_Period);

   Print("Inisialisasi EA berhasil. Menunggu tick...");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| OnDeinit function                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   string prog_name = MQL5InfoString(MQL5_PROGRAM_NAME); // Simpan ke variabel string
   PrintFormat("EA %s sedang dideinisialisasi. Alasan: %d", prog_name, reason);
   if(ExtHandle != INVALID_HANDLE)
     {
      OnnxRelease(ExtHandle);
      ExtHandle = INVALID_HANDLE; 
      Print("ONNX Handle berhasil di-release.");
     }
  }
  
//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(TimeCurrent() < ExtNextBar)
      return; 
   
   ExtNextBar = TimeCurrent() - (TimeCurrent() % PeriodSeconds(_Period)) + PeriodSeconds(_Period);

   if(TimeCurrent() >= ExtNextDay)
     {
      Print("Pergantian hari terdeteksi, mengupdate MinMax...");
      GetMinMax();
      ExtNextDay = TimeCurrent() - (TimeCurrent() % PeriodSeconds(PERIOD_D1)) + PeriodSeconds(PERIOD_D1);
     }

   PrepareInputTensor();
   PredictPrice();

   if(ExtPredictedClass >= 0) 
     {
      if(PositionSelect(_Symbol)) 
        {
         // Filter berdasarkan magic number jika hanya mau menutup posisi yg dibuka EA ini
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            CheckForClose();
         }
        }
      else
        {
         CheckForOpen();
        }
     }
  }
//+------------------------------------------------------------------+