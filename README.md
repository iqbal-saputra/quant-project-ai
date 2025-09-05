# 📈 AOL_AI – XAUUSD Trading AI

Proyek ini bertujuan untuk membangun **AI Trading Bot** berbasis **machine learning** untuk pasangan mata uang **XAU/USD (Gold vs USD)** dengan timeframe **M15**. Sistem ini menggabungkan data historis, preprocessing, dan model machine learning (ONNX) untuk menghasilkan sinyal trading yang dapat dieksekusi otomatis melalui **MetaTrader 5 (MQL5 Expert Advisor)**.

---

## 🚀 Fitur Utama
- **Data Historis XAU/USD**: Menggunakan data M15 sejak 2020.
- **Arsitektur Model**: Beberapa rancangan arsitektur deep learning (lihat file arsitektur).
- **Model ONNX**: Model final disimpan dalam format `ONNX` agar mudah digunakan lintas platform.
- **Integrasi MQL5 (MT5)**: Script `AOL_AI.mq5` sebagai Expert Advisor untuk eksekusi sinyal trading langsung di MetaTrader 5.
- **Notebook Analisis**: `AOL_AI.ipynb` untuk preprocessing data, eksplorasi, training model, dan evaluasi.


---

## 🧠 Workflow
1. **Data Collection**  
   Dataset historis XAU/USD timeframe M15 (`XAUUSD_M15_DATA.csv`) berisi:  
   - Timestamp  
   - Open, High, Low, Close (OHLC)  
   - Volume  

2. **Modeling**  
   - Arsitektur diuji dalam beberapa versi (`model1_architecture.png`, dll).  
   - Model akhir diekspor ke format **ONNX** (`M15.XAUUSD.onnx`).

3. **Integration**  
   - `AOL_AI.mq5` membaca model ONNX → menghasilkan sinyal trading (BUY/SELL/HOLD).  
   - Eksekusi otomatis melalui MetaTrader 5 (MT5).

---

## ⚙️ Cara Menjalankan
### 1. Training Model (Opsional)
- Buka `AOL_AI.ipynb`
- Jalankan semua sel untuk preprocessing, training, dan evaluasi.
- Model hasil training akan disimpan sebagai `M15.XAUUSD.onnx`.

### 2. Deploy ke MetaTrader 5
- Salin `AOL_AI.mq5` ke folder `Experts` di MT5.
- Salin `M15.XAUUSD.onnx` ke folder `Files` MT5.
- Jalankan EA di chart XAU/USD timeframe M15.

---

## 📊 Dataset
- **Sumber**: Data historis XAU/USD M15 (2020–sekarang).
- **Fitur**:  
  - OHLCV (Open, High, Low, Close, Volume)  
  - Time-based (timestamp)  
- **Tujuan**: Prediksi arah pergerakan harga (klasifikasi sinyal trading).

---

## 📌 Catatan
- Project ini masih dalam tahap pengembangan (experimental).
- Backtesting dan forward testing diperlukan sebelum digunakan pada akun real.
- Risiko trading tetap menjadi tanggung jawab pengguna.

---


